#pragma once

#include <string>
#include <vector>
#include <memory>
#include <thread>
#include <atomic>
#include <mutex>
#include <map>
#include <functional>
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
    std::atomic<bool> is_running_{false};

    std::shared_ptr<HitlSecurityManager> hitl_manager_;
    std::shared_ptr<MeshSyncEngine> sync_engine_;
    std::shared_ptr<ProcessManager> process_manager_;

    ShmTelemetryBuffer shm_buffer_;

    std::thread server_thread_;
    std::thread telemetry_broadcaster_thread_;
    std::mutex clients_mutex_;
    std::vector<int> client_fds_;

    void run_server_loop();
    void run_telemetry_loop();
    void handle_client_socket(int client_fd);
    bool perform_websocket_handshake(int client_fd, const std::string& request);
    void process_websocket_frame(int client_fd, const std::string& payload);
    void send_websocket_frame(int client_fd, const std::string& text);

    TelemetryMetrics collect_system_metrics();
};

} // namespace lucille
