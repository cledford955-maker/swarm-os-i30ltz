#include <iostream>
#include <csignal>
#include <atomic>
#include <thread>
#include <chrono>
#include <cstdlib>
#include "engine.hpp"

static std::atomic<bool> g_shutdown_requested{false};

static void sig_handler(int sig) {
    if (sig == SIGINT || sig == SIGTERM) {
        g_shutdown_requested = true;
    }
}

int main(int argc, char* argv[]) {
    std::signal(SIGINT, sig_handler);
    std::signal(SIGTERM, sig_handler);

    std::cout << "=====================================================\n";
    std::cout << "           LUCILLE AI — NATIVE C++20 ENGINE          \n";
    std::cout << "=====================================================\n";

    lucille::EngineConfig config;
    config.socket_path = "/tmp/lucille_ipc.sock";
    config.soul_path = "SOUL.md";
    if (const char* tok = std::getenv("SWARM_AUTH_TOKEN")) config.mesh_auth_token = tok;

    for (int i = 1; i < argc; ++i) {
        std::string arg = argv[i];
        if (arg == "--socket" && i + 1 < argc) {
            config.socket_path = argv[++i];
        } else if (arg == "--soul" && i + 1 < argc) {
            config.soul_path = argv[++i];
        } else if (arg == "--workspace" && i + 1 < argc) {
            config.workspace_dir = argv[++i];
        } else if (arg == "--telemetry-port" && i + 1 < argc) {
            config.telemetry_port = static_cast<uint16_t>(std::stoi(argv[++i]));
        } else if (arg == "--help" || arg == "-h") {
            std::cout << "Usage: lucille-core [OPTIONS]\n"
                      << "  --socket <path>     UNIX domain socket path (default: /tmp/lucille_ipc.sock)\n"
                      << "  --soul <path>       SOUL.md prompt file path (default: SOUL.md)\n"
                      << "  --workspace <path>  Base workspace directory (default: .)\n"
                      << "  --telemetry-port N  Companion WebSocket port (default: 9091; needs SWARM_AUTH_TOKEN)\n";
            return 0;
        }
    }

    lucille::LucilleEngine engine(config);
    if (!engine.start()) {
        std::cerr << "[Main] Failed to start Lucille Core Engine.\n";
        return 1;
    }

    std::cout << "[Main] Lucille Core Engine is active and listening for sub-agents and UI events.\n";
    std::cout << "[Main] Press Ctrl+C to terminate.\n";

    while (!g_shutdown_requested && engine.is_running()) {
        std::this_thread::sleep_for(std::chrono::milliseconds(200));
    }

    std::cout << "\n[Main] Shutdown signal caught. Gracefully stopping daemon...\n";
    engine.stop();
    std::cout << "[Main] Lucille Core Engine exited cleanly.\n";

    return 0;
}
