#pragma once
// lucille-core: HITL Client — call hitl_daemon before running restricted commands
//
// Drop into lucille-core's ShellExecutor::run() immediately before exec().
// The daemon is contacted via Unix socket; the call blocks until approval/rejection
// or timeout (at which point the daemon auto-rejects for safety).

#include <atomic>
#include <cstring>
#include <stdexcept>
#include <string>

#include <sys/socket.h>
#include <sys/time.h>   // struct timeval (SO_RCVTIMEO)
#include <sys/un.h>
#include <unistd.h>
#include <errno.h>

// JSON serialisation without a library (minimal, safe for our fixed schema)
namespace lucille {
namespace hitl {

// ─────────────────────────────────────────────────────────────────────────────
// HitlDecision
// ─────────────────────────────────────────────────────────────────────────────
enum class HitlDecision { APPROVE, REJECT };

struct HitlResponse {
    HitlDecision decision;
    std::string  reason;
    std::string  req_id;
};

// ─────────────────────────────────────────────────────────────────────────────
// HitlClient — synchronous Unix socket client
// ─────────────────────────────────────────────────────────────────────────────
class HitlClient {
public:
    // recv_timeout_sec: hard wall-clock limit per call; set just above the
    // daemon's approval_timeout_sec so a dead daemon doesn't stall forever.
    explicit HitlClient(const std::string& socket_path = "/run/swarm/hitl.sock",
                        int recv_timeout_sec = 130)
        : socket_path_(socket_path), recv_timeout_sec_(recv_timeout_sec) {}

    // check_command() — send the command to hitl_daemon for HITL approval.
    // Blocks until the daemon responds (which blocks until the human decides,
    // or the daemon's approval_timeout_sec elapses).
    //
    // Returns HitlResponse with decision=APPROVE/REJECT.
    // If the daemon is unreachable, returns APPROVE with a warning in reason
    // (fail-open policy) — swap to REJECT for strict fail-safe behaviour.
    HitlResponse check_command(const std::string& command,
                                const std::string& cwd = "") {
        // Build JSON request — atomic counter, safe across threads
        static std::atomic<uint64_t> seq{0};
        std::string req_id = "req-" + std::to_string(++seq);
        std::string payload = R"({"req_id":")" + req_id + R"(","command":")" +
                              json_escape(command) + R"(","cwd":")" +
                              json_escape(cwd) + "\"}\n";

        int fd = ::socket(AF_UNIX, SOCK_STREAM, 0);
        if (fd < 0) {
            return fail_open(req_id, "socket() failed: " + std::string(strerror(errno)));
        }
        struct FdGuard { int fd; ~FdGuard() { ::close(fd); } } g{fd};

        // Set recv timeout slightly above the daemon's approval_timeout_sec (default 120s)
        // so a hung/crashed daemon never blocks the caller thread forever.
        struct timeval tv{};
        tv.tv_sec  = recv_timeout_sec_;
        tv.tv_usec = 0;
        ::setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof(tv));
        ::setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &tv, sizeof(tv));

        // Connect
        struct sockaddr_un addr{};
        addr.sun_family = AF_UNIX;
        ::strncpy(addr.sun_path, socket_path_.c_str(), sizeof(addr.sun_path) - 1);
        if (::connect(fd, reinterpret_cast<struct sockaddr*>(&addr), sizeof(addr)) < 0) {
            return fail_open(req_id, "connect to HITL daemon failed: " +
                             std::string(strerror(errno)) +
                             " (is hitl_daemon.py running?)");
        }

        // Send
        if (!send_all(fd, payload)) {
            return fail_open(req_id, "send to HITL daemon failed");
        }

        // Receive response (newline-delimited JSON)
        std::string resp_raw = recv_line(fd);
        if (resp_raw.empty()) {
            return fail_open(req_id, "empty response from HITL daemon");
        }

        return parse_response(resp_raw, req_id);
    }

private:
    std::string socket_path_;
    int         recv_timeout_sec_;

    // Fail-open: if the daemon is down, allow command to proceed.
    // Change to fail_closed() for stricter safety.
    static HitlResponse fail_open(const std::string& req_id, const std::string& reason) {
        return {HitlDecision::APPROVE, "[HITL daemon unreachable — fail-open] " + reason, req_id};
    }

    static bool send_all(int fd, const std::string& data) {
        size_t sent = 0;
        while (sent < data.size()) {
            ssize_t n = ::write(fd, data.data() + sent, data.size() - sent);
            if (n <= 0) return false;
            sent += static_cast<size_t>(n);
        }
        return true;
    }

    static std::string recv_line(int fd, size_t max = 4096) {
        std::string out;
        char c;
        while (out.size() < max) {
            ssize_t n = ::read(fd, &c, 1);
            if (n < 0) {
                // SO_RCVTIMEO fired — treat as EOF so fail_open path handles it
                if (errno == EAGAIN || errno == EWOULDBLOCK) break;
                break;
            }
            if (n == 0) break;   // peer closed
            if (c == '\n') break;
            out += c;
        }
        return out;
    }

    static HitlResponse parse_response(const std::string& raw, const std::string& req_id) {
        // Minimal JSON field extraction (no full parser needed for our fixed schema)
        auto extract = [&](const std::string& key) -> std::string {
            std::string needle = "\"" + key + "\":\"";
            auto pos = raw.find(needle);
            if (pos == std::string::npos) return "";
            pos += needle.size();
            auto end = raw.find('"', pos);
            if (end == std::string::npos) return "";
            return raw.substr(pos, end - pos);
        };

        std::string dec    = extract("decision");
        std::string reason = extract("reason");
        std::string rid    = extract("req_id");
        if (rid.empty()) rid = req_id;

        HitlDecision decision = (dec == "APPROVE") ? HitlDecision::APPROVE : HitlDecision::REJECT;
        return {decision, reason, rid};
    }

    static std::string json_escape(const std::string& s) {
        std::string out;
        out.reserve(s.size());
        for (char c : s) {
            if      (c == '"')  out += "\\\"";
            else if (c == '\\') out += "\\\\";
            else if (c == '\n') out += "\\n";
            else if (c == '\r') out += "\\r";
            else if (c == '\t') out += "\\t";
            else                out += c;
        }
        // Truncate to 512 chars so notifications are readable.
        // Strip trailing incomplete escape sequences (dangling '\') after resize.
        if (out.size() > 512) {
            out.resize(509);
            while (!out.empty() && out.back() == '\\') out.pop_back();
            out += "...";
        }
        return out;
    }
};

// ─────────────────────────────────────────────────────────────────────────────
// Convenience: check and throw if rejected
// ─────────────────────────────────────────────────────────────────────────────
inline void require_approval(HitlClient& client,
                              const std::string& command,
                              const std::string& cwd = "") {
    auto resp = client.check_command(command, cwd);
    if (resp.decision == HitlDecision::REJECT) {
        throw std::runtime_error(
            "[HITL] Command rejected by human operator: " + resp.reason +
            " | cmd: " + command.substr(0, 100));
    }
}

} // namespace hitl
} // namespace lucille
