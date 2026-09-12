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

    std::thread epoll_thread_;
    std::thread ipc_dispatcher_thread_;

    void setup_ipc_handlers();
    std::string handle_ipc_command(const std::string& raw_request);
};

} // namespace lucille
