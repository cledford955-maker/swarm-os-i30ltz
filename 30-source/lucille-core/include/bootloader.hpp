#pragma once

#include <string>
#include <vector>
#include <cstdint>

namespace lucille {

struct HardwareTopology {
    uint32_t logical_cores{0};
    uint32_t physical_cores{0};
    uint64_t total_ram_bytes{0};
    uint64_t free_ram_bytes{0};
    std::string cpu_model;
    bool has_hybrid_architecture{false};
    std::vector<uint32_t> p_cores;
    std::vector<uint32_t> e_cores;
};

struct DisplayEnvironment {
    bool is_wayland_active{false};
    bool is_gamescope_active{false};
    std::string wayland_display;
    std::string gamescope_display;
    std::string session_type;
    std::string xdg_runtime_dir;
};

struct BootDiagnostics {
    bool is_non_root{false};
    uid_t uid{0};
    gid_t gid{0};
    std::string username;
    HardwareTopology hardware;
    DisplayEnvironment display;
    bool boot_success{false};
    std::string error_message;
};

class Bootloader {
public:
    static BootDiagnostics run_boot_sequence();
    static bool verify_non_root(std::string& err_msg);
    static HardwareTopology probe_hardware_topology();
    static DisplayEnvironment probe_display_environment();
};

} // namespace lucille
