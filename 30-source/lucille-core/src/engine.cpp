#include "engine.hpp"
#include <iostream>
#include <sstream>
#include <iomanip>
#include <filesystem>
#include <chrono>

namespace fs = std::filesystem;

namespace lucille {

LucilleEngine::LucilleEngine(EngineConfig config)
    : config_(std::move(config)) {
    ipc_server_ = std::make_unique<IpcServer>(config_.socket_path);
    error_interceptor_ = std::make_unique<ErrorInterceptor>();
}

LucilleEngine::~LucilleEngine() {
    stop();
}

bool LucilleEngine::start() {
    std::cout << "[LucilleEngine] Starting Lucille AI Core Daemon (C++20 Engine)...\n";

    // 1. Boot & Initialization Phase
    boot_diag_ = Bootloader::run_boot_sequence();
    if (!boot_diag_.boot_success) {
        std::cerr << "[LucilleEngine] Boot sequence failed: " << boot_diag_.error_message << "\n";
        return false;
    }

    std::cout << "[LucilleEngine] [OK] Non-root check passed (UID=" << boot_diag_.uid
              << ", User=" << boot_diag_.username << ")\n";
    std::cout << "[LucilleEngine] [OK] CPU Topology: " << boot_diag_.hardware.logical_cores
              << " logical cores (" << boot_diag_.hardware.p_cores.size() << " P-cores, "
              << boot_diag_.hardware.e_cores.size() << " E-cores), Model: "
              << boot_diag_.hardware.cpu_model << "\n";
    std::cout << "[LucilleEngine] [OK] Memory: " << (boot_diag_.hardware.total_ram_bytes / (1024 * 1024))
              << " MB RAM\n";
    std::cout << "[LucilleEngine] [OK] Display: Wayland=" << (boot_diag_.display.is_wayland_active ? "Active" : "Inactive")
              << ", Gamescope=" << (boot_diag_.display.is_gamescope_active ? "Active" : "Inactive")
              << " (Display=" << boot_diag_.display.wayland_display << ")\n";

    // 2. Thread Affinity Setup
    affinity_manager_ = std::make_unique<AffinityManager>(boot_diag_.hardware);
    // Pin engine main/dispatcher thread to E-cores
    affinity_manager_->pin_current_thread(WorkerThreadRole::BackgroundIO);

    // 3. Security & Sandbox Phase
    // Verify SOUL.md system prompt integrity
    soul_report_ = SecuritySandbox::verify_soul_integrity(config_.soul_path, config_.expected_soul_sha256);
    std::cout << "[LucilleEngine] [OK] System Prompt Integrity (SOUL.md):\n";
    std::cout << "   - Path: " << soul_report_.soul_path << " (Exists=" << (soul_report_.soul_exists ? "YES" : "NO") << ")\n";
    std::cout << "   - SHA-256: " << soul_report_.soul_sha256 << "\n";
    std::cout << "   - Immutable Flag (chattr +i): " << (soul_report_.is_immutable_flag_set ? "ENFORCED" : "UNSET/NORMAL") << "\n";

    // Setup Cgroups v2 Slice (75% RAM limit)
    cgroup_config_ = SecuritySandbox::setup_cgroups_slice(boot_diag_.hardware.total_ram_bytes);
    std::cout << "[LucilleEngine] [OK] Cgroups v2 Slice: " << cgroup_config_.slice_path
              << " (memory.high=" << (cgroup_config_.memory_high_bytes / (1024 * 1024)) << " MB, Status: "
              << cgroup_config_.status_msg << ")\n";

    // Setup Ephemeral OverlayFS Layer
    overlay_config_ = SecuritySandbox::prepare_ephemeral_overlay(
        config_.workspace_dir,
        config_.upper_dir,
        config_.work_dir,
        config_.merged_dir
    );
    std::cout << "[LucilleEngine] [OK] Ephemeral OverlayFS prepared at " << overlay_config_.upper_dir << "\n";

    // 4. IPC Server Initialization
    std::string err_ipc;
    if (!ipc_server_->initialize(err_ipc)) {
        std::cerr << "[LucilleEngine] Failed to initialize IPC server: " << err_ipc << "\n";
        return false;
    }
    setup_ipc_handlers();
    std::cout << "[LucilleEngine] [OK] Non-blocking UNIX IPC Socket active at " << config_.socket_path
              << " (permissions 0660)\n";

    // 5. Asynchronous Epoll Process Manager
    process_manager_ = std::make_unique<ProcessManager>(cgroup_config_.slice_path);
    std::string err_epoll;
    if (!process_manager_->initialize(err_epoll)) {
        std::cerr << "[LucilleEngine] Failed to initialize Epoll process manager: " << err_epoll << "\n";
        return false;
    }

    // Set real-time stream output callbacks
    process_manager_->set_output_callback([this](pid_t pid, ProcessStreamType stype, const std::string& data) {
        std::string stream_name = (stype == ProcessStreamType::Stdout) ? "STDOUT" : "STDERR";
        std::cout << "[SubAgent:" << pid << ":" << stream_name << "] " << data;
        
        // Broadcast stream data to local UI via IPC socket
        std::stringstream json_stream;
        json_stream << "{\"event\":\"stream\",\"pid\":" << pid
                    << ",\"type\":\"" << stream_name << "\",\"data\":\""
                    << data << "\"}\n";
        ipc_server_->broadcast(json_stream.str());
    });

    process_manager_->set_exit_callback([this](pid_t pid, int exit_code) {
        std::cout << "[SubAgent:" << pid << "] Exited with code " << exit_code << "\n";
        std::stringstream json_exit;
        json_exit << "{\"event\":\"process_exit\",\"pid\":" << pid
                  << ",\"exit_code\":" << exit_code << "}\n";
        ipc_server_->broadcast(json_exit.str());
    });

    // 6. Companion mesh socket — HITL approvals reach the phone through it
    hitl_manager_ = std::make_shared<HitlSecurityManager>();
    if (!config_.mesh_auth_token.empty()) {
        telemetry_ = std::make_unique<TelemetryDaemon>(
            config_.telemetry_port, config_.mesh_interface, config_.mesh_auth_token);
        telemetry_->set_hitl_manager(hitl_manager_);
        if (!telemetry_->start()) {
            std::cerr << "[LucilleEngine] Companion socket not started — HITL approvals will be denied\n";
            telemetry_.reset();
        }
    } else {
        std::cerr << "[LucilleEngine] SWARM_AUTH_TOKEN unset — companion socket off, HITL approvals will be denied\n";
    }

    is_running_ = true;

    // Launch Epoll worker thread (pinned to E-cores)
    epoll_thread_ = std::thread([this]() {
        affinity_manager_->pin_current_thread(WorkerThreadRole::EpollMultiplexer);
        process_manager_->run_epoll_loop();
    });

    // Launch IPC epoll event loop thread (pinned to E-cores)
    ipc_dispatcher_thread_ = std::thread([this]() {
        affinity_manager_->pin_current_thread(WorkerThreadRole::BackgroundIO);
        ipc_server_->run_event_loop(); // blocks until ipc_server_->shutdown()
    });

    std::cout << "[LucilleEngine] Engine daemon initialized and running successfully.\n";
    return true;
}

void LucilleEngine::stop() {
    if (!is_running_) return;
    std::cout << "[LucilleEngine] Stopping engine daemon...\n";
    is_running_ = false;

    if (process_manager_) {
        process_manager_->stop_epoll_loop();
        process_manager_->shutdown();
    }

    if (ipc_server_) {
        ipc_server_->shutdown();
    }

    if (telemetry_) telemetry_->stop();

    if (epoll_thread_.joinable()) epoll_thread_.join();
    if (ipc_dispatcher_thread_.joinable()) ipc_dispatcher_thread_.join();

    std::cout << "[LucilleEngine] Engine stopped.\n";
}

pid_t LucilleEngine::dispatch_subagent(
    const std::string& agent_name,
    const std::vector<std::string>& argv,
    bool use_ephemeral_overlay
) {
    if (!is_running_ || !process_manager_) return -1;

    std::string target_workdir = use_ephemeral_overlay ? overlay_config_.upper_dir : config_.workspace_dir;
    
    // Spawn with PR_SET_NO_NEW_PRIVS and Cgroups v2 attachment
    pid_t pid = process_manager_->spawn_agent(
        agent_name,
        argv,
        target_workdir,
        true, // enforce sandbox
        {
            {"LUCILLE_AGENT", agent_name},
            {"LUCILLE_IPC_SOCK", config_.socket_path}
        }
    );

    std::cout << "[LucilleEngine] Spawned subagent '" << agent_name << "' (PID=" << pid
              << ", Sandboxed=true, Overlay=" << target_workdir << ")\n";
    return pid;
}

bool LucilleEngine::request_human_approval(const std::string& command, uint32_t timeout_sec) {
    if (!hitl_manager_ || !telemetry_ || !telemetry_->is_running()) {
        std::cerr << "[LucilleEngine] HITL denied (no companion socket): " << command << "\n";
        return false;
    }
    HitlChallenge chal = hitl_manager_->create_challenge(command, timeout_sec);
    telemetry_->broadcast_hitl_challenge(chal);
    std::cout << "[LucilleEngine] HITL challenge " << chal.challenge_id << " sent to companion (" << chal.risk_level << ")\n";
    return hitl_manager_->await_challenge_resolution(chal.challenge_id, timeout_sec);
}

KimiRepairPayload LucilleEngine::analyze_build_failure(const std::string& compiler_output) {
    return error_interceptor_->parse_compiler_output(compiler_output);
}

void LucilleEngine::setup_ipc_handlers() {
    ipc_server_->set_handler([this](const std::string& req) -> std::string {
        return handle_ipc_command(req);
    });
}

std::string LucilleEngine::handle_ipc_command(const std::string& raw_request) {
    // Strip trailing newlines
    std::string req = raw_request;
    while (!req.empty() && (req.back() == '\n' || req.back() == '\r')) {
        req.pop_back();
    }

    if (req == "ping" || req == "PING") {
        return "{\"status\":\"ok\",\"response\":\"pong\"}\n";
    } else if (req == "status") {
        std::stringstream ss;
        ss << "{\n"
           << "  \"status\": \"running\",\n"
           << "  \"user\": \"" << boot_diag_.username << "\",\n"
           << "  \"uid\": " << boot_diag_.uid << ",\n"
           << "  \"p_cores\": " << boot_diag_.hardware.p_cores.size() << ",\n"
           << "  \"e_cores\": " << boot_diag_.hardware.e_cores.size() << ",\n"
           << "  \"total_ram_mb\": " << (boot_diag_.hardware.total_ram_bytes / (1024 * 1024)) << ",\n"
           << "  \"cgroup_memory_high_mb\": " << (cgroup_config_.memory_high_bytes / (1024 * 1024)) << ",\n"
           << "  \"soul_sha256\": \"" << soul_report_.soul_sha256 << "\",\n"
           << "  \"active_processes\": " << (process_manager_ ? process_manager_->get_active_process_count() : 0) << "\n"
           << "}\n";
        return ss.str();
    } else if (req == "topology") {
        std::stringstream ss;
        ss << "{\"logical_cores\":" << boot_diag_.hardware.logical_cores
           << ",\"cpu_model\":\"" << boot_diag_.hardware.cpu_model << "\"}\n";
        return ss.str();
    } else if (req.rfind("repair:", 0) == 0) {
        std::string compiler_diag = req.substr(7);
        auto payload = analyze_build_failure(compiler_diag);
        return payload.structured_repair_prompt + "\n";
    }

    return "{\"status\":\"error\",\"message\":\"unknown command: " + req + "\"}\n";
}

} // namespace lucille
