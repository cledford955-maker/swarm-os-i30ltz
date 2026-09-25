#include "telemetry_daemon.hpp"
#include "shm_telemetry.hpp"
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <ifaddrs.h>
#include <unistd.h>
#include <fcntl.h>
#include <poll.h>
#include <openssl/crypto.h>
#include <openssl/sha.h>
#include <openssl/evp.h>
#include <sys/sysinfo.h>
#include <fstream>
#include <sstream>
#include <iostream>
#include <algorithm>
#include <cstring>
#include <filesystem>

namespace fs = std::filesystem;

namespace lucille {

static const std::string kWebSocketMagicGuid = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11";

namespace {

constexpr size_t kMaxHttpHeader   = 16 * 1024;   // handshake request cap
constexpr size_t kMaxFramePayload = 64 * 1024;   // client frame cap
constexpr auto   kHandshakeTimeout = std::chrono::seconds(5);
// Tokens that are public (in source/docs) and must never guard this socket
bool is_public_default_token(const std::string& t) {
    return t == "swarm_mesh_secret_token" || t == "swarm-token-2026";
}

std::string json_escape(const std::string& in) {
    std::string out;
    for (unsigned char c : in) {
        switch (c) {
            case '"':  out += "\\\""; break;
            case '\\': out += "\\\\"; break;
            case '\n': out += "\\n"; break;
            case '\r': out += "\\r"; break;
            case '\t': out += "\\t"; break;
            default:
                if (c < 0x20) { char b[8]; snprintf(b, sizeof(b), "\\u%04x", c); out += b; }
                else out += static_cast<char>(c);
        }
    }
    return out;
}

std::string hitl_challenge_json(const HitlChallenge& chal) {
    std::stringstream ss;
    ss << "{\"event\":\"hitl_challenge\","
       << "\"challenge_id\":\"" << json_escape(chal.challenge_id) << "\","
       << "\"command\":\"" << json_escape(chal.command) << "\","
       << "\"risk_level\":\"" << json_escape(chal.risk_level) << "\","
       << "\"timeout_seconds\":" << (chal.expires_at - chal.created_at) << ","
       << "\"expires_at\":" << chal.expires_at << "}";
    return ss.str();
}

// Tailscale assigns from the CGNAT block 100.64.0.0/10
bool is_tailscale_ipv4(const std::string& ip) {
    struct in_addr a{};
    if (inet_pton(AF_INET, ip.c_str(), &a) != 1) return false;
    uint32_t h = ntohl(a.s_addr);
    return (h & 0xFFC00000u) == 0x64400000u;
}

// Write everything or give up after ~1 s of back-pressure (fd is non-blocking)
bool write_all(int fd, const void* data, size_t len) {
    const char* p = static_cast<const char*>(data);
    while (len > 0) {
        ssize_t n = ::send(fd, p, len, MSG_NOSIGNAL);
        if (n > 0) { p += n; len -= static_cast<size_t>(n); continue; }
        if (n < 0 && errno == EINTR) continue;
        if (n < 0 && (errno == EAGAIN || errno == EWOULDBLOCK)) {
            struct pollfd pfd{fd, POLLOUT, 0};
            if (poll(&pfd, 1, 1000) <= 0) return false;
            continue;
        }
        return false;
    }
    return true;
}

// Parse one client→server frame from buf. Returns 1 = frame parsed (consumed
// from buf), 0 = need more bytes, -1 = protocol violation.
int parse_client_frame(std::string& buf, uint8_t& opcode, bool& fin, std::string& payload) {
    if (buf.size() < 2) return 0;
    const auto b0 = static_cast<uint8_t>(buf[0]);
    const auto b1 = static_cast<uint8_t>(buf[1]);
    fin    = (b0 & 0x80) != 0;
    opcode = b0 & 0x0F;
    if (!(b1 & 0x80)) return -1;                 // RFC 6455: clients must mask
    uint64_t len = b1 & 0x7F;
    size_t off = 2;
    if (len == 126) {
        if (buf.size() < 4) return 0;
        len = (uint64_t(uint8_t(buf[2])) << 8) | uint8_t(buf[3]);
        off = 4;
    } else if (len == 127) {
        if (buf.size() < 10) return 0;
        len = 0;
        for (int i = 0; i < 8; ++i) len = (len << 8) | uint8_t(buf[2 + i]);
        off = 10;
    }
    if (len > kMaxFramePayload) return -1;
    if ((opcode & 0x08) && (len > 125 || !fin)) return -1;   // control frame rules
    if (buf.size() < off + 4 + len) return 0;

    const char* mask = buf.data() + off;
    payload.assign(buf, off + 4, static_cast<size_t>(len));
    for (size_t i = 0; i < payload.size(); ++i) payload[i] ^= mask[i % 4];
    buf.erase(0, off + 4 + static_cast<size_t>(len));
    return 1;
}

std::string header_value(const std::string& req, const std::string& name) {
    // Case-insensitive header lookup
    std::string lower(req.size(), '\0');
    std::transform(req.begin(), req.end(), lower.begin(), [](unsigned char c) { return std::tolower(c); });
    std::string key = "\r\n" + name + ":";
    std::transform(key.begin(), key.end(), key.begin(), [](unsigned char c) { return std::tolower(c); });
    auto pos = lower.find(key);
    if (pos == std::string::npos) return "";
    pos += key.size();
    auto end = req.find("\r\n", pos);
    std::string v = req.substr(pos, end == std::string::npos ? std::string::npos : end - pos);
    while (!v.empty() && (v.front() == ' ' || v.front() == '\t')) v.erase(0, 1);
    while (!v.empty() && (v.back() == ' ' || v.back() == '\t')) v.pop_back();
    return v;
}

bool token_equals(const std::string& a, const std::string& b) {
    return !a.empty() && a.size() == b.size() && CRYPTO_memcmp(a.data(), b.data(), a.size()) == 0;
}

} // namespace

std::string TelemetryDaemon::discover_tailscale_ip(const std::string& interface_name) {
    struct ifaddrs* ifaddr = nullptr;
    if (getifaddrs(&ifaddr) == -1) {
        return "127.0.0.1";
    }

    std::string by_name, by_range;
    for (struct ifaddrs* ifa = ifaddr; ifa != nullptr; ifa = ifa->ifa_next) {
        if (ifa->ifa_addr == nullptr || ifa->ifa_addr->sa_family != AF_INET) continue;
        char host[NI_MAXHOST];
        if (getnameinfo(ifa->ifa_addr, sizeof(struct sockaddr_in), host, NI_MAXHOST, nullptr, 0, NI_NUMERICHOST) != 0)
            continue;
        std::string ip_str(host);
        if (by_name.empty() && interface_name == ifa->ifa_name) by_name = ip_str;
        if (by_range.empty() && is_tailscale_ipv4(ip_str)) by_range = ip_str;
    }

    freeifaddrs(ifaddr);
    if (!by_name.empty())  return by_name;
    if (!by_range.empty()) return by_range;
    return "127.0.0.1"; // Fallback to loopback
}

TelemetryDaemon::TelemetryDaemon(uint16_t port, std::string bind_interface, std::string auth_token)
    : port_(port),
      bind_interface_(std::move(bind_interface)),
      auth_token_(std::move(auth_token)) {}

TelemetryDaemon::~TelemetryDaemon() {
    stop();
}

bool TelemetryDaemon::start() {
    if (is_running_) return true;

    // The socket accepts HITL approvals and emergency rollback — never run open
    if (auth_token_.empty() || is_public_default_token(auth_token_)) {
        std::cerr << "[TelemetryDaemon] Refusing to start: set a real mesh auth token "
                     "(empty/default token would let any peer approve HITL or roll back)\n";
        return false;
    }

    bound_ip_ = discover_tailscale_ip(bind_interface_);

    server_fd_ = socket(AF_INET, SOCK_STREAM | SOCK_NONBLOCK | SOCK_CLOEXEC, 0);
    if (server_fd_ < 0) {
        std::cerr << "[TelemetryDaemon] Failed to create socket: " << strerror(errno) << "\n";
        return false;
    }

    int opt = 1;
    setsockopt(server_fd_, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));

    struct sockaddr_in addr;
    std::memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_port = htons(port_);
    inet_pton(AF_INET, bound_ip_.c_str(), &addr.sin_addr);

    if (bind(server_fd_, reinterpret_cast<struct sockaddr*>(&addr), sizeof(addr)) < 0) {
        // Tailscale address not bindable yet — fall back to loopback only,
        // never INADDR_ANY (that would expose the socket on LAN/public links)
        addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
        if (bind(server_fd_, reinterpret_cast<struct sockaddr*>(&addr), sizeof(addr)) < 0) {
            std::cerr << "[TelemetryDaemon] Failed to bind to " << bound_ip_ << ":" << port_
                      << " (" << strerror(errno) << ")\n";
            close(server_fd_);
            server_fd_ = -1;
            return false;
        }
        bound_ip_ = "127.0.0.1";
    }

    if (listen(server_fd_, SOMAXCONN) < 0) {
        std::cerr << "[TelemetryDaemon] Failed to listen: " << strerror(errno) << "\n";
        close(server_fd_);
        server_fd_ = -1;
        return false;
    }

    if (pipe2(wake_pipe_, O_NONBLOCK | O_CLOEXEC) < 0) {
        std::cerr << "[TelemetryDaemon] Failed to create wake pipe: " << strerror(errno) << "\n";
        close(server_fd_);
        server_fd_ = -1;
        return false;
    }

    is_running_ = true;
    std::cout << "[TelemetryDaemon] ✓ WebSocket Telemetry Server listening on "
              << bound_ip_ << ":" << port_ << " (Tailscale interface: " << bind_interface_
              << ", heartbeat " << heartbeat_interval_.count() << "ms × " << heartbeat_max_missed_ << ")\n";

    {
        std::string shm_err;
        if (shm_buffer_.open_writer(shm_err)) {
            std::cout << "[TelemetryDaemon] ✓ SHM ring buffer open: " << kShmName
                      << " (" << kShmSize << " bytes, " << kShmCapacity << " slots)\n";
        } else {
            std::cerr << "[TelemetryDaemon] WARNING: SHM unavailable (" << shm_err
                      << ") — falling back to WebSocket-only broadcast\n";
        }
    }

    server_thread_ = std::thread(&TelemetryDaemon::run_server_loop, this);
    telemetry_broadcaster_thread_ = std::thread(&TelemetryDaemon::run_telemetry_loop, this);

    return true;
}

void TelemetryDaemon::stop() {
    if (!is_running_.exchange(false)) return;

    // Wake the loop; it closes every socket itself before exiting, so no fd
    // is closed while another thread might still be using it.
    const char b = 1;
    while (write(wake_pipe_[1], &b, 1) < 0 && errno == EINTR) {}

    if (server_thread_.joinable()) server_thread_.join();
    if (telemetry_broadcaster_thread_.joinable()) telemetry_broadcaster_thread_.join();

    close(wake_pipe_[0]); close(wake_pipe_[1]);
    wake_pipe_[0] = wake_pipe_[1] = -1;
    std::cout << "[TelemetryDaemon] WebSocket server stopped.\n";
}

size_t TelemetryDaemon::client_count() {
    std::lock_guard<std::mutex> lock(clients_mutex_);
    size_t n = 0;
    for (const auto& [fd, c] : clients_) if (c.upgraded && !c.dead) ++n;
    return n;
}

bool TelemetryDaemon::authorized(const std::string& request) const {
    std::string bearer = header_value(request, "Authorization");
    if (bearer.rfind("Bearer ", 0) == 0 && token_equals(bearer.substr(7), auth_token_)) return true;
    if (token_equals(header_value(request, "X-Swarm-Auth"), auth_token_)) return true;

    // ?token= in the request line (browsers can't set WebSocket headers)
    auto line_end = request.find("\r\n");
    std::string line = request.substr(0, line_end);
    auto q = line.find("token=");
    if (q != std::string::npos && (line[q - 1] == '?' || line[q - 1] == '&')) {
        auto end = line.find_first_of("& ", q);
        if (token_equals(line.substr(q + 6, end == std::string::npos ? std::string::npos : end - q - 6), auth_token_))
            return true;
    }
    return false;
}

bool TelemetryDaemon::perform_websocket_handshake(int client_fd, const std::string& request) {
    std::string key = header_value(request, "Sec-WebSocket-Key");
    if (key.empty()) return false;

    std::string accept_input = key + kWebSocketMagicGuid;

    unsigned char sha1_res[20];
    SHA1(reinterpret_cast<const unsigned char*>(accept_input.data()), accept_input.length(), sha1_res);

    char base64_accept[64];
    EVP_EncodeBlock(reinterpret_cast<unsigned char*>(base64_accept), sha1_res, 20);

    std::stringstream response;
    response << "HTTP/1.1 101 Switching Protocols\r\n"
             << "Upgrade: websocket\r\n"
             << "Connection: Upgrade\r\n"
             << "Sec-WebSocket-Accept: " << base64_accept << "\r\n\r\n";

    std::string resp_str = response.str();
    return write_all(client_fd, resp_str.data(), resp_str.size());
}

bool TelemetryDaemon::send_frame(int client_fd, uint8_t opcode, const std::string& payload) {
    std::vector<uint8_t> frame;
    frame.push_back(0x80 | (opcode & 0x0F)); // FIN + opcode (server frames are unmasked)

    size_t len = payload.length();
    if (len <= 125) {
        frame.push_back(static_cast<uint8_t>(len));
    } else if (len <= 65535) {
        frame.push_back(126);
        frame.push_back((len >> 8) & 0xFF);
        frame.push_back(len & 0xFF);
    } else {
        frame.push_back(127);
        for (int i = 7; i >= 0; --i) {
            frame.push_back((len >> (i * 8)) & 0xFF);
        }
    }

    frame.insert(frame.end(), payload.begin(), payload.end());
    if (write_all(client_fd, frame.data(), frame.size())) return true;

    auto it = clients_.find(client_fd);
    if (it != clients_.end()) it->second.dead = true;   // loop drops it
    return false;
}

void TelemetryDaemon::send_websocket_frame(int client_fd, const std::string& text) {
    send_frame(client_fd, 0x1, text);
}

void TelemetryDaemon::broadcast_text(const std::string& text) {
    std::lock_guard<std::mutex> lock(clients_mutex_);
    for (auto& [fd, c] : clients_) {
        if (c.upgraded && !c.dead) send_frame(fd, 0x1, text);
    }
}

void TelemetryDaemon::broadcast_metrics(const TelemetryMetrics& metrics) {
    std::stringstream ss;
    ss << "{\"event\":\"telemetry_metrics\","
       << "\"cpu_load\":" << metrics.cpu_load << ","
       << "\"ram_total_mb\":" << metrics.ram_total_mb << ","
       << "\"ram_free_mb\":" << metrics.ram_free_mb << ","
       << "\"vram_total_mb\":" << metrics.vram_total_mb << ","
       << "\"vram_used_mb\":" << metrics.vram_used_mb << ","
       << "\"quant_mode\":\"" << metrics.quant_mode << "\","
       << "\"active_agents\":" << metrics.active_agents << "}";
    broadcast_text(ss.str());
}

void TelemetryDaemon::broadcast_log_line(const std::string& ansi_log) {
    std::stringstream ss;
    ss << "{\"event\":\"terminal_stream\",\"log\":\"";
    for (char c : ansi_log) {
        if (c == '"') ss << "\\\"";
        else if (c == '\\') ss << "\\\\";
        else if (c == '\n') ss << "\\n";
        else if (c == '\r') ss << "\\r";
        else ss << c;
    }
    ss << "\"}";
    broadcast_text(ss.str());
}

void TelemetryDaemon::broadcast_hitl_challenge(const HitlChallenge& chal) {
    broadcast_text(hitl_challenge_json(chal));
}

TelemetryMetrics TelemetryDaemon::collect_system_metrics() {
    TelemetryMetrics m;

    // 1. CPU Load
    std::ifstream loadavg("/proc/loadavg");
    if (loadavg.is_open()) {
        loadavg >> m.cpu_load;
    }

    // 2. RAM stats
    struct sysinfo si;
    if (sysinfo(&si) == 0) {
        m.ram_total_mb = (static_cast<uint64_t>(si.totalram) * si.mem_unit) / (1024 * 1024);
        m.ram_free_mb = (static_cast<uint64_t>(si.freeram) * si.mem_unit) / (1024 * 1024);
    }

    // 3. VRAM stats
    std::ifstream vram_file("/sys/class/drm/card0/device/mem_info_vram_total");
    if (vram_file.is_open()) {
        uint64_t bytes = 0;
        vram_file >> bytes;
        m.vram_total_mb = bytes / (1024 * 1024);
    } else {
        m.vram_total_mb = 4096; // Fallback APU
    }

    // 4. Quant Mode
    m.quant_mode = (m.vram_total_mb >= 12000) ? "q8_0" : "q4_k_m";

    // 5. Active agents
    if (process_manager_) {
        m.active_agents = static_cast<uint32_t>(process_manager_->get_active_process_count());
    }

    return m;
}

void TelemetryDaemon::process_websocket_frame(int client_fd, const std::string& payload) {
    if (payload.empty()) return;

    // Handle HITL challenge response from companion
    if (payload.find("\"action\":\"hitl_response\"") != std::string::npos && hitl_manager_) {
        // Extract challenge_id and approve flag
        std::string chal_id;
        auto pos = payload.find("\"challenge_id\":\"");
        if (pos != std::string::npos) {
            pos += 16;
            auto epos = payload.find("\"", pos);
            if (epos != std::string::npos) chal_id = payload.substr(pos, epos - pos);
        }

        bool approved = (payload.find("\"approved\":true") != std::string::npos);
        if (!chal_id.empty()) {
            // false = unknown, already answered, or expired
            bool ok = hitl_manager_->resolve_challenge(chal_id, approved);
            send_websocket_frame(client_fd, std::string("{\"event\":\"hitl_resolved\",\"challenge_id\":\"")
                + json_escape(chal_id) + "\",\"accepted\":" + (ok ? "true" : "false") + "}");
        }
    }
    // Handle emergency freeze
    else if (payload.find("\"action\":\"emergency_freeze\"") != std::string::npos) {
        auto pos = payload.find("\"pid\":");
        if (pos != std::string::npos) {
            pid_t pid = std::stoi(payload.substr(pos + 6));
            HitlSecurityManager::emergency_freeze_process(pid);
            send_websocket_frame(client_fd, "{\"status\":\"ok\",\"event\":\"process_frozen\",\"pid\":" + std::to_string(pid) + "}");
        }
    }
    // Handle emergency unfreeze
    else if (payload.find("\"action\":\"emergency_unfreeze\"") != std::string::npos) {
        auto pos = payload.find("\"pid\":");
        if (pos != std::string::npos) {
            pid_t pid = std::stoi(payload.substr(pos + 6));
            HitlSecurityManager::emergency_unfreeze_process(pid);
            send_websocket_frame(client_fd, "{\"status\":\"ok\",\"event\":\"process_unfrozen\",\"pid\":" + std::to_string(pid) + "}");
        }
    }
    // Handle emergency Btrfs rollback
    else if (payload.find("\"action\":\"emergency_rollback\"") != std::string::npos) {
        std::string snap = "pre_build_latest";
        std::string log;
        bool ok = HitlSecurityManager::emergency_btrfs_rollback(snap, log);
        send_websocket_frame(client_fd, "{\"status\":\"" + std::string(ok ? "ok" : "error") + "\",\"event\":\"btrfs_rollback\",\"log\":\"" + log + "\"}");
    }
}

// ---- Server loop (sole owner of every socket) ------------------------------

void TelemetryDaemon::accept_clients() {
    for (;;) {
        int cfd = accept4(server_fd_, nullptr, nullptr, SOCK_NONBLOCK | SOCK_CLOEXEC);
        if (cfd < 0) {
            if (errno == EINTR) continue;
            break;   // EAGAIN or transient error
        }
        auto now = std::chrono::steady_clock::now();
        Client c;
        c.connected_at = now;
        c.last_pong    = now;
        clients_.emplace(cfd, std::move(c));
    }
}

void TelemetryDaemon::handle_http_request(int fd, Client& c) {
    const std::string& req = c.inbuf;
    const bool wants_ws = !header_value(req, "Sec-WebSocket-Key").empty();

    if (!wants_ws) {
        // Plain HTTP status for health checks — no control surface here
        std::string json_status = "{\"status\":\"running\",\"node\":\"lucille-swarm-os\",\"port\":"
                                  + std::to_string(port_) + "}\n";
        std::string http_resp = "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nConnection: close\r\n\r\n" + json_status;
        write_all(fd, http_resp.data(), http_resp.size());
        c.dead = true;
        return;
    }

    if (!authorized(req)) {
        const std::string r = "HTTP/1.1 401 Unauthorized\r\nContent-Length: 0\r\nConnection: close\r\n\r\n";
        write_all(fd, r.data(), r.size());
        std::cerr << "[TelemetryDaemon] Rejected WebSocket upgrade on fd=" << fd << ": bad or missing token\n";
        c.dead = true;
        return;
    }

    if (!perform_websocket_handshake(fd, req)) { c.dead = true; return; }
    c.inbuf.erase(0, c.inbuf.find("\r\n\r\n") + 4);   // keep any frames sent right after
    c.upgraded  = true;
    c.last_pong = std::chrono::steady_clock::now();
    send_websocket_frame(fd, "{\"event\":\"connected\",\"server\":\"lucille_telemetry_daemon\",\"version\":\"2026.2\","
                             "\"heartbeat_ms\":" + std::to_string(heartbeat_interval_.count()) + "}");

    // A phone that was offline still gets every approval still waiting on it
    if (hitl_manager_) {
        for (const auto& chal : hitl_manager_->get_pending_challenges())
            send_websocket_frame(fd, hitl_challenge_json(chal));
    }
}

void TelemetryDaemon::service_client(int fd, Client& c) {
    char buf[4096];
    for (;;) {
        ssize_t n = read(fd, buf, sizeof(buf));
        if (n > 0) { c.inbuf.append(buf, static_cast<size_t>(n)); continue; }
        if (n == 0) { c.dead = true; return; }                       // peer closed
        if (errno == EINTR) continue;
        if (errno == EAGAIN || errno == EWOULDBLOCK) break;
        c.dead = true; return;
    }

    if (!c.upgraded) {
        if (c.inbuf.find("\r\n\r\n") == std::string::npos) {
            if (c.inbuf.size() > kMaxHttpHeader) c.dead = true;
            return;
        }
        handle_http_request(fd, c);
        if (c.dead || !c.upgraded) return;
    }

    for (;;) {
        uint8_t opcode = 0; bool fin = false; std::string payload;
        int r = parse_client_frame(c.inbuf, opcode, fin, payload);
        if (r == 0) break;
        if (r < 0 || !fin || opcode == 0x0) {                       // bad / fragmented
            send_frame(fd, 0x8, std::string("\x03\xEA", 2));          // 1002 protocol error
            c.dead = true; return;
        }
        switch (opcode) {
            case 0x1:                                               // text
                try {
                    process_websocket_frame(fd, payload);
                } catch (const std::exception& e) {                 // e.g. stoi on a bad pid
                    send_websocket_frame(fd, "{\"status\":\"error\",\"message\":\"bad request\"}");
                }
                break;
            case 0x8: send_frame(fd, 0x8, payload.substr(0, 2)); c.dead = true; return;
            case 0x9: send_frame(fd, 0xA, payload); break;          // client ping → pong
            case 0xA: c.last_pong = std::chrono::steady_clock::now(); break;
            default:  send_frame(fd, 0x8, std::string("\x03\xEB", 2)); c.dead = true; return;
        }
    }
    if (c.inbuf.size() > kMaxFramePayload + 14) c.dead = true;
}

void TelemetryDaemon::run_heartbeat(std::chrono::steady_clock::time_point now) {
    const auto deadline = heartbeat_interval_ * heartbeat_max_missed_;
    for (auto& [fd, c] : clients_) {
        if (c.dead) continue;
        if (!c.upgraded) {
            if (now - c.connected_at > kHandshakeTimeout) c.dead = true;   // stalled handshake
            continue;
        }
        if (now - c.last_pong > deadline) {
            std::cerr << "[TelemetryDaemon] Heartbeat timeout — dropping fd=" << fd << "\n";
            send_frame(fd, 0x8, std::string("\x03\xE9", 2));   // 1001 going away
            c.dead = true;
            continue;
        }
        send_frame(fd, 0x9, "hb");
    }
}

void TelemetryDaemon::run_server_loop() {
    using clock = std::chrono::steady_clock;
    auto next_heartbeat = clock::now() + heartbeat_interval_;
    std::vector<struct pollfd> pfds;
    std::vector<int> fds;

    while (is_running_) {
        pfds.clear(); fds.clear();
        pfds.push_back({wake_pipe_[0], POLLIN, 0});
        pfds.push_back({server_fd_, POLLIN, 0});
        {
            std::lock_guard<std::mutex> lock(clients_mutex_);
            for (const auto& [fd, c] : clients_) {
                pfds.push_back({fd, POLLIN, 0});
                fds.push_back(fd);
            }
        }

        auto wait = std::chrono::duration_cast<std::chrono::milliseconds>(next_heartbeat - clock::now());
        int timeout = static_cast<int>(std::clamp<long long>(wait.count(), 0, 100));
        int ret = poll(pfds.data(), pfds.size(), timeout);
        if (ret < 0 && errno != EINTR) {
            std::cerr << "[TelemetryDaemon] poll(): " << strerror(errno) << "\n";
            break;
        }
        if (pfds[0].revents & POLLIN) break;   // stop() requested

        std::lock_guard<std::mutex> lock(clients_mutex_);
        if (ret > 0) {
            if (pfds[1].revents & POLLIN) accept_clients();
            for (size_t i = 0; i < fds.size(); ++i) {
                short ev = pfds[i + 2].revents;
                if (!ev) continue;
                auto it = clients_.find(fds[i]);
                if (it == clients_.end()) continue;
                if (ev & (POLLIN | POLLHUP | POLLERR)) service_client(fds[i], it->second);
            }
        }

        auto now = clock::now();
        if (now >= next_heartbeat) {
            run_heartbeat(now);
            next_heartbeat = now + heartbeat_interval_;
        }

        for (auto it = clients_.begin(); it != clients_.end();) {
            if (it->second.dead) { close(it->first); it = clients_.erase(it); }
            else ++it;
        }
    }

    // Shutdown: this thread owns the sockets, so it closes them
    std::lock_guard<std::mutex> lock(clients_mutex_);
    for (auto& [fd, c] : clients_) {
        if (c.upgraded) send_frame(fd, 0x8, std::string("\x03\xE9", 2));
        close(fd);
    }
    clients_.clear();
    close(server_fd_);
    server_fd_ = -1;
}

void TelemetryDaemon::run_telemetry_loop() {
    while (is_running_) {
        std::this_thread::sleep_for(std::chrono::milliseconds(200));
        if (!is_running_) break;

        TelemetryMetrics metrics = collect_system_metrics();

        // Write into the lock-free SHM ring buffer for zero-copy local readers
        if (shm_buffer_.is_open()) {
            shm_buffer_.write(
                metrics.cpu_load,
                metrics.active_agents,
                metrics.ram_total_mb,
                metrics.ram_free_mb,
                metrics.vram_total_mb,
                metrics.vram_used_mb,
                metrics.quant_mode.c_str()
            );
        }

        broadcast_metrics(metrics);
    }
}

} // namespace lucille
