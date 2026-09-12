#include "bootloader.hpp"
#include <unistd.h>
#include <sys/types.h>
#include <sys/sysinfo.h>
#include <pwd.h>
#include <fstream>
#include <sstream>
#include <filesystem>
#include <iostream>
#include <algorithm>
#include <cstdlib>

namespace fs = std::filesystem;

namespace lucille {

bool Bootloader::verify_non_root(std::string& err_msg) {
    uid_t uid = getuid();
    uid_t euid = geteuid();

    if (uid == 0 || euid == 0) {
        err_msg = "FATAL: lucille-core must be executed under unprivileged user context (getuid != 0). Root execution denied for safety.";
        return false;
    }
    return true;
}

HardwareTopology Bootloader::probe_hardware_topology() {
    HardwareTopology topo;

    // Logical core count
    long nprocs = sysconf(_SC_NPROCESSORS_ONLN);
    topo.logical_cores = (nprocs > 0) ? static_cast<uint32_t>(nprocs) : 1;

    // RAM stats
    struct sysinfo si;
    if (sysinfo(&si) == 0) {
        topo.total_ram_bytes = static_cast<uint64_t>(si.totalram) * si.mem_unit;
        topo.free_ram_bytes = static_cast<uint64_t>(si.freeram) * si.mem_unit;
    }

    // Parse /proc/cpuinfo for model name & physical core topology
    std::ifstream cpuinfo("/proc/cpuinfo");
    std::string line;
    while (std::getline(cpuinfo, line)) {
        if (line.rfind("model name", 0) == 0) {
            auto colon = line.find(':');
            if (colon != std::string::npos && topo.cpu_model.empty()) {
                topo.cpu_model = line.substr(colon + 2);
            }
        }
    }

    // Inspect CPU topology for hybrid architecture (P-cores vs E-cores)
    // On Linux kernel, cpu_capacity or max_freq reveals P-cores vs E-cores
    std::vector<std::pair<uint32_t, uint64_t>> core_capacities; // core_id, max_freq/capacity

    for (uint32_t i = 0; i < topo.logical_cores; ++i) {
        std::string cap_path = "/sys/devices/system/cpu/cpu" + std::to_string(i) + "/cpu_capacity";
        std::string freq_path = "/sys/devices/system/cpu/cpu" + std::to_string(i) + "/cpufreq/cpuinfo_max_freq";
        
        uint64_t metric = 1000;
        if (fs::exists(cap_path)) {
            std::ifstream cap_file(cap_path);
            cap_file >> metric;
        } else if (fs::exists(freq_path)) {
            std::ifstream freq_file(freq_path);
            freq_file >> metric;
        }
        core_capacities.push_back({i, metric});
    }

    if (!core_capacities.empty()) {
        uint64_t max_metric = 0;
        uint64_t min_metric = UINT64_MAX;
        for (const auto& [core_id, metric] : core_capacities) {
            max_metric = std::max(max_metric, metric);
            min_metric = std::min(min_metric, metric);
        }

        // If there is significant asymmetry (> 15% difference in capacity/freq), classify as hybrid
        if (max_metric > 0 && min_metric > 0 && (max_metric - min_metric) > (max_metric * 0.15)) {
            topo.has_hybrid_architecture = true;
            uint64_t threshold = min_metric + (max_metric - min_metric) / 2;
            for (const auto& [core_id, metric] : core_capacities) {
                if (metric >= threshold) {
                    topo.p_cores.push_back(core_id);
                } else {
                    topo.e_cores.push_back(core_id);
                }
            }
        } else {
            // Uniform architecture: allocate lower half to P-cores and upper half to E-cores / I/O
            topo.has_hybrid_architecture = false;
            uint32_t half = std::max<uint32_t>(1, topo.logical_cores / 2);
            for (uint32_t i = 0; i < topo.logical_cores; ++i) {
                if (i < half) {
                    topo.p_cores.push_back(i);
                } else {
                    topo.e_cores.push_back(i);
                }
            }
        }
    }

    topo.physical_cores = static_cast<uint32_t>(topo.p_cores.size() + topo.e_cores.size());
    return topo;
}

DisplayEnvironment Bootloader::probe_display_environment() {
    DisplayEnvironment env;

    const char* wayland_disp = std::getenv("WAYLAND_DISPLAY");
    if (wayland_disp && wayland_disp[0] != '\0') {
        env.is_wayland_active = true;
        env.wayland_display = wayland_disp;
    }

    const char* gamescope_disp = std::getenv("GAMESCOPE_WAYLAND_DISPLAY");
    if (gamescope_disp && gamescope_disp[0] != '\0') {
        env.is_gamescope_active = true;
        env.gamescope_display = gamescope_disp;
    }

    const char* sess_type = std::getenv("XDG_SESSION_TYPE");
    if (sess_type) {
        env.session_type = sess_type;
    }

    const char* runtime_dir = std::getenv("XDG_RUNTIME_DIR");
    if (runtime_dir) {
        env.xdg_runtime_dir = runtime_dir;
        // Verify wayland socket if not explicitly set
        if (!env.is_wayland_active) {
            std::string default_socket = std::string(runtime_dir) + "/wayland-0";
            if (fs::exists(default_socket)) {
                env.is_wayland_active = true;
                env.wayland_display = "wayland-0";
            }
        }
    }

    return env;
}

BootDiagnostics Bootloader::run_boot_sequence() {
    BootDiagnostics diag;
    diag.uid = getuid();
    diag.gid = getgid();

    struct passwd* pw = getpwuid(diag.uid);
    if (pw) {
        diag.username = pw->pw_name;
    } else {
        diag.username = "unknown";
    }

    std::string err;
    diag.is_non_root = verify_non_root(err);
    if (!diag.is_non_root) {
        diag.boot_success = false;
        diag.error_message = err;
        return diag;
    }

    diag.hardware = probe_hardware_topology();
    diag.display = probe_display_environment();
    diag.boot_success = true;

    return diag;
}

} // namespace lucille
