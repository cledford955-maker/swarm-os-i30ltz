#pragma once

#include <string>
#include <memory>
#include <thread>
#include <atomic>
#include "bootloader.hpp"
#include "ipc_server.hpp"
#include "security_sandbox.hpp"
#include "error_interceptor.hpp"
#include "affinity_manager.hpp"
#include "process_manager.hpp"
#include "hitl_security.hpp"
#include "telemetry_daemon.hpp"
#include "swarm_router.hpp"
#include "openrouter_backends.hpp"

namespace lucille {

struct EngineConfig {
    std::string socket_path{"/tmp/lucille_ipc.sock"};
    std::string soul_path{"SOUL.md"};
    std::string expected_soul_sha256;
    std::string workspace_dir{"."};
    std::string upper_dir{"/tmp/agent_upper"};
    std::string work_dir{"/tmp/agent_work"};
    std::string merged_dir{"/tmp/agent_merged"};
    bool enforce_strict_immutability{false};
    // Companion mesh socket (HITL approvals, telemetry). Started only when
    // mesh_auth_token is set to a non-default value (SWARM_AUTH_TOKEN).
    uint16_t telemetry_port{9091};
    std::string mesh_interface{"tailscale0"};
    std::string mesh_auth_token;
    // OpenRouter API key for real model backends (pipeline + consensus).
    // When empty, the router uses simulated models and flags mock output.
    std::string openrouter_api_key;
};

class LucilleEngine {
public:
    explicit LucilleEngine(EngineConfig config = {});
    ~LucilleEngine();

    // Disable copy
    LucilleEngine(const LucilleEngine&) = delete;
    LucilleEngine& operator=(const LucilleEngine&) = delete;

    // Boot & Initialize
    bool start();
    void stop();
    bool is_running() const { return is_running_; }

    // Execute sub-agent (e.g. "Hermes Agent", "OpenClaw")
    pid_t dispatch_subagent(
        const std::string& agent_name,
        const std::vector<std::string>& argv,
        bool use_ephemeral_overlay = true
    );

    // Ask the user's phone to approve a risky action. Blocks up to
    // timeout_sec. Returns false (deny) when no companion socket is running,
    // on rejection, or on timeout — never approves by default.
    bool request_human_approval(const std::string& command, uint32_t timeout_sec = 60);

    // Route a task through the legacy sequential path (draft → audit →
    // consensus → HITL → checkpoint). Exposes the router over the engine.
    SwarmTaskResponse route_task(const SwarmTaskRequest& req);

    // Run the full streaming pipeline end-to-end: Kimi streams → DeepSeek
    // audits blocks concurrently → consensus gate → HITL → checkpoint/apply.
    // Metrics logged to stdout + shared memory.
    FullPipelineResult run_pipeline(const SwarmTaskRequest& req, const std::string& compiler_logs = "");

    SwarmRouter* router() { return router_.get(); }

    // Manual or programmatic compiler error healing request
    KimiRepairPayload analyze_build_failure(const std::string& compiler_output);

    // Accessors
    const BootDiagnostics& get_diagnostics() const { return boot_diag_; }
    const SecurityIntegrityReport& get_soul_report() const { return soul_report_; }
    const CgroupConfig& get_cgroup_config() const { return cgroup_config_; }
    const OverlayFsConfig& get_overlay_config() const { return overlay_config_; }

private:
    EngineConfig config_;
    std::atomic<bool> is_running_{false};

    BootDiagnostics boot_diag_;
    SecurityIntegrityReport soul_report_;
    CgroupConfig cgroup_config_;
    OverlayFsConfig overlay_config_;

    std::unique_ptr<IpcServer> ipc_server_;
    std::unique_ptr<AffinityManager> affinity_manager_;
    std::unique_ptr<ProcessManager> process_manager_;
    std::unique_ptr<ErrorInterceptor> error_interceptor_;
    std::shared_ptr<HitlSecurityManager> hitl_manager_;
    std::unique_ptr<TelemetryDaemon> telemetry_;
    std::unique_ptr<SwarmRouter> router_;

    std::thread epoll_thread_;
    std::thread ipc_dispatcher_thread_;

    void setup_ipc_handlers();
    std::string handle_ipc_command(const std::string& raw_request);
};

} // namespace lucille
