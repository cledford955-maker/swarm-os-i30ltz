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

std::string TelemetryDaemon::discover_tailscale_ip(const std::string& interface_name) {
    struct ifaddrs* ifaddr = nullptr;
    if (getifaddrs(&ifaddr) == -1) {
        return "127.0.0.1";
    }

    std::string tailscale_ip;
    for (struct ifaddrs* ifa = ifaddr; ifa != nullptr; ifa = ifa->ifa_next) {
        if (ifa->ifa_addr == nullptr) continue;

        if (ifa->ifa_addr->sa_family == AF_INET) {
            char host[NI_MAXHOST];
            if (getnameinfo(ifa->ifa_addr, sizeof(struct sockaddr_in), host, NI_MAXHOST, nullptr, 0, NI_NUMERICHOST) == 0) {
                std::string if_name(ifa->ifa_name);
                std::string ip_str(host);

                if (if_name == interface_name || ip_str.rfind("100.", 0) == 0) {
                    tailscale_ip = ip_str;
                    break;
                }
            }
        }
    }

    freeifaddrs(ifaddr);
    if (!tailscale_ip.empty()) return tailscale_ip;
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
    bound_ip_ = discover_tailscale_ip(bind_interface_);

    server_fd_ = socket(AF_INET, SOCK_STREAM, 0);
    if (server_fd_ < 0) {
        std::cerr << "[TelemetryDaemon] Failed to create socket: " << strerror(errno) << "\n";
        return false;
    }

    int opt = 1;
    setsockopt(server_fd_, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));
#ifdef SO_REUSEPORT
    setsockopt(server_fd_, SOL_SOCKET, SO_REUSEPORT, &opt, sizeof(opt));
#endif

    struct sockaddr_in addr;
    std::memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_port = htons(port_);
    inet_pton(AF_INET, bound_ip_.c_str(), &addr.sin_addr);

    if (bind(server_fd_, reinterpret_cast<struct sockaddr*>(&addr), sizeof(addr)) < 0) {
        // Fallback to INADDR_ANY if specific Tailscale IP bind is not yet active
        addr.sin_addr.s_addr = INADDR_ANY;
        if (bind(server_fd_, reinterpret_cast<struct sockaddr*>(&addr), sizeof(addr)) < 0) {
            std::cerr << "[TelemetryDaemon] Failed to bind to " << bound_ip_ << ":" << port_
                      << " (" << strerror(errno) << ")\n";
            close(server_fd_);
            server_fd_ = -1;
            return false;
        }
        bound_ip_ = "0.0.0.0";
    }

    if (listen(server_fd_, SOMAXCONN) < 0) {
        std::cerr << "[TelemetryDaemon] Failed to listen: " << strerror(errno) << "\n";
        close(server_fd_);
        server_fd_ = -1;
        return false;
    }

    is_running_ = true;
    std::cout << "[TelemetryDaemon] ✓ WebSocket Telemetry Server listening on "
              << bound_ip_ << ":" << port_ << " (Tailscale interface: " << bind_interface_ << ")\n";

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
    if (!is_running_) return;
    is_running_ = false;

    if (server_fd_ >= 0) {
        shutdown(server_fd_, SHUT_RDWR);
        close(server_fd_);
        server_fd_ = -1;
    }

    {
        std::lock_guard<std::mutex> lock(clients_mutex_);
        for (int cfd : client_fds_) {
            if (cfd >= 0) {
                shutdown(cfd, SHUT_RDWR);
                close(cfd);
            }
        }
        client_fds_.clear();
    }

    if (server_thread_.joinable()) server_thread_.join();
    if (telemetry_broadcaster_thread_.joinable()) telemetry_broadcaster_thread_.join();
    std::cout << "[TelemetryDaemon] WebSocket server stopped.\n";
}

bool TelemetryDaemon::perform_websocket_handshake(int client_fd, const std::string& request) {
    auto pos = request.find("Sec-WebSocket-Key: ");
    if (pos == std::string::npos) return false;

    pos += 19;
    auto end_pos = request.find("\r\n", pos);
    if (end_pos == std::string::npos) return false;
    std::string key = request.substr(pos, end_pos - pos);

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
    write(client_fd, resp_str.data(), resp_str.size());
    return true;
}

void TelemetryDaemon::send_websocket_frame(int client_fd, const std::string& text) {
    std::vector<uint8_t> frame;
    frame.push_back(0x81); // Text frame, FIN bit set

    size_t len = text.length();
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

    frame.insert(frame.end(), text.begin(), text.end());
    write(client_fd, frame.data(), frame.size());
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

    std::string json_str = ss.str();
    std::lock_guard<std::mutex> lock(clients_mutex_);
    for (int cfd : client_fds_) {
        send_websocket_frame(cfd, json_str);
    }
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

    std::string json_str = ss.str();
    std::lock_guard<std::mutex> lock(clients_mutex_);
    for (int cfd : client_fds_) {
        send_websocket_frame(cfd, json_str);
    }
}

void TelemetryDaemon::broadcast_hitl_challenge(const HitlChallenge& chal) {
    std::stringstream ss;
    ss << "{\"event\":\"hitl_challenge\","
       << "\"challenge_id\":\"" << chal.challenge_id << "\","
       << "\"command\":\"" << chal.command << "\","
       << "\"risk_level\":\"" << chal.risk_level << "\","
       << "\"timeout_seconds\":60,"
       << "\"expires_at\":" << chal.expires_at << "}";

    std::string json_str = ss.str();
    std::lock_guard<std::mutex> lock(clients_mutex_);
    for (int cfd : client_fds_) {
        send_websocket_frame(cfd, json_str);
    }
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
            hitl_manager_->resolve_challenge(chal_id, approved);
            send_websocket_frame(client_fd, "{\"status\":\"ok\",\"message\":\"challenge resolved\"}");
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

void TelemetryDaemon::handle_client_socket(int client_fd) {
    char buffer[4096];
    ssize_t bytes = read(client_fd, buffer, sizeof(buffer) - 1);
    if (bytes <= 0) {
        close(client_fd);
        return;
    }
    buffer[bytes] = '\0';
    std::string req(buffer, bytes);

    if (req.find("Upgrade: websocket") != std::string::npos || req.find("upgrade: websocket") != std::string::npos) {
        if (perform_websocket_handshake(client_fd, req)) {
            {
                std::lock_guard<std::mutex> lock(clients_mutex_);
                client_fds_.push_back(client_fd);
            }
            send_websocket_frame(client_fd, "{\"event\":\"connected\",\"server\":\"lucille_telemetry_daemon\",\"version\":\"2026.1\"}");
        } else {
            close(client_fd);
        }
    } else {
        // Plain HTTP JSON status response
        std::string json_status = "{\"status\":\"running\",\"node\":\"lucille-swarm-os\",\"port\":9091}\n";
        std::string http_resp = "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\n" + json_status;
        write(client_fd, http_resp.data(), http_resp.size());
        close(client_fd);
    }
}

void TelemetryDaemon::run_server_loop() {
    while (is_running_) {
        struct pollfd pfd;
        pfd.fd = server_fd_;
        pfd.events = POLLIN;
        pfd.revents = 0;

        int ret = poll(&pfd, 1, 100); // 100ms poll timeout
        if (ret <= 0) continue;

        if (pfd.revents & POLLIN) {
            struct sockaddr_in client_addr;
            socklen_t len = sizeof(client_addr);
            int cfd = accept(server_fd_, reinterpret_cast<struct sockaddr*>(&client_addr), &len);
            if (cfd >= 0) {
                std::thread(&TelemetryDaemon::handle_client_socket, this, cfd).detach();
            }
        }
    }
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
