#pragma once

#include <string>
#include <vector>
#include <memory>
#include <thread>
#include <atomic>
#include <mutex>
#include <map>
#include <functional>
#include <chrono>
#include "hitl_security.hpp"
#include "mesh_sync.hpp"
#include "bootloader.hpp"
#include "process_manager.hpp"
#include "shm_telemetry.hpp"

namespace lucille {

struct TelemetryMetrics {
    float cpu_load{0.0f};
    uint64_t ram_total_mb{0};
    uint64_t ram_free_mb{0};
    uint64_t vram_total_mb{0};
    uint64_t vram_used_mb{0};
    std::string quant_mode{"q4_k_m"};
    uint32_t active_agents{0};
    std::vector<std::string> recent_terminal_logs;
};

// WebSocket server for the companion phones on the Tailscale mesh (:9091).
//
// Security: WebSocket upgrades must carry the mesh token (Authorization:
// Bearer <t>, X-Swarm-Auth: <t>, or ?token=<t>); start() refuses an empty or
// default token. If the Tailscale address can't be bound it falls back to
// loopback, never 0.0.0.0. Plain HTTP GETs get an unauthenticated status JSON.
//
// Heartbeat: every heartbeat interval (default 5 s) each client gets a ping;
// a client with no pong for max_missed intervals (default 3) is dropped.
//
// One poll() thread owns every socket; broadcast_*() may be called from any
// thread and write under clients_mutex_.
class TelemetryDaemon {
public:
    explicit TelemetryDaemon(
        uint16_t port = 9091,
        std::string bind_interface = "tailscale0",
        std::string auth_token = "swarm_mesh_secret_token"
    );
    ~TelemetryDaemon();

    // Disable copy
    TelemetryDaemon(const TelemetryDaemon&) = delete;
    TelemetryDaemon& operator=(const TelemetryDaemon&) = delete;

    bool start();
    void stop();
    bool is_running() const { return is_running_; }

    // Call before start(). Defaults: 5000 ms, 3 missed pongs.
    void set_heartbeat(std::chrono::milliseconds interval, int max_missed = 3) {
        heartbeat_interval_ = interval;
        heartbeat_max_missed_ = max_missed;
    }
    size_t client_count();   // upgraded (authenticated) WebSocket clients

    // Broadcast live telemetry & log events
    void broadcast_metrics(const TelemetryMetrics& metrics);
    void broadcast_log_line(const std::string& ansi_log);
    void broadcast_hitl_challenge(const HitlChallenge& chal);

    // Dependency references
    void set_hitl_manager(std::shared_ptr<HitlSecurityManager> hitl) { hitl_manager_ = hitl; }
    void set_sync_engine(std::shared_ptr<MeshSyncEngine> sync) { sync_engine_ = sync; }
    void set_process_manager(std::shared_ptr<ProcessManager> proc) { process_manager_ = proc; }

    std::string get_bound_ip() const { return bound_ip_; }
    uint16_t get_bound_port() const { return port_; }

    static std::string discover_tailscale_ip(const std::string& interface_name = "tailscale0");

private:
    uint16_t port_;
    std::string bind_interface_;
    std::string auth_token_;
    std::string bound_ip_;
    int server_fd_{-1};
    int wake_pipe_[2]{-1, -1};      // stop() writes to [1] to break poll()
    std::atomic<bool> is_running_{false};
    std::chrono::milliseconds heartbeat_interval_{5000};
    int heartbeat_max_missed_{3};

    std::shared_ptr<HitlSecurityManager> hitl_manager_;
    std::shared_ptr<MeshSyncEngine> sync_engine_;
    std::shared_ptr<ProcessManager> process_manager_;

    ShmTelemetryBuffer shm_buffer_;

    std::thread server_thread_;
    std::thread telemetry_broadcaster_thread_;
    struct Client {
        std::string inbuf;
        bool upgraded{false};
        bool dead{false};               // write failed / protocol error — drop next pass
        std::chrono::steady_clock::time_point connected_at;
        std::chrono::steady_clock::time_point last_pong;
    };
    std::mutex clients_mutex_;          // guards clients_; held by the loop while it works
    std::map<int, Client> clients_;     // fd → state; only the loop thread adds/removes

    void run_server_loop();
    void run_telemetry_loop();
    void accept_clients();
    void service_client(int fd, Client& c);
    void handle_http_request(int fd, Client& c);
    void run_heartbeat(std::chrono::steady_clock::time_point now);
    bool authorized(const std::string& request) const;
    bool perform_websocket_handshake(int client_fd, const std::string& request);
    void process_websocket_frame(int client_fd, const std::string& payload);
    // Unlocked primitives — callers hold clients_mutex_ (or own the fd)
    bool send_frame(int client_fd, uint8_t opcode, const std::string& payload);
    void send_websocket_frame(int client_fd, const std::string& text);
    void broadcast_text(const std::string& text);

    TelemetryMetrics collect_system_metrics();
};

} // namespace lucille
