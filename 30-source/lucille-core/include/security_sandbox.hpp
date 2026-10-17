#pragma once

#include <string>
#include <vector>
#include <cstdint>
#include <sys/types.h>

namespace lucille {

struct SecurityIntegrityReport {
    bool soul_exists{false};
    std::string soul_path;
    std::string soul_sha256;
    bool is_immutable_flag_set{false}; // chattr +i
    bool sha256_match{false};
    std::string expected_sha256;
};

struct CgroupConfig {
    std::string slice_path{"/sys/fs/cgroup/lucille.slice"};
    uint64_t memory_high_bytes{0};
    bool is_active{false};
    std::string status_msg;
};

struct OverlayFsConfig {
    std::string lower_dir;
    std::string upper_dir{"/tmp/agent_upper"};
    std::string work_dir{"/tmp/agent_work"};
    std::string merged_dir{"/tmp/agent_merged"};
    bool is_prepared{false};
};

struct LandlockConfig {
    std::string workspace_path;
    int abi_version{0};
    bool applied{false};
    std::string status_msg;
};

class SecuritySandbox {
public:
    // Security check on SOUL.md system prompt
    static SecurityIntegrityReport verify_soul_integrity(
        const std::string& soul_path,
        const std::string& expected_sha256 = ""
    );

    // Apply prctl(PR_SET_NO_NEW_PRIVS, 1, 0, 0, 0)
    static bool apply_no_new_privs(std::string& err_msg);

    // Setup Cgroups v2 lucille.slice with memory.high at 75% of RAM
    static CgroupConfig setup_cgroups_slice(uint64_t total_ram_bytes);

    // Attach process PID to Cgroup slice
    static bool attach_process_to_cgroup(const std::string& slice_path, pid_t pid);

    // Prepare ephemeral OverlayFS directory layout
    static OverlayFsConfig prepare_ephemeral_overlay(
        const std::string& base_workspace,
        const std::string& upper_dir = "/tmp/agent_upper",
        const std::string& work_dir = "/tmp/agent_work",
        const std::string& merged_dir = "/tmp/agent_merged"
    );

    // Compute SHA-256 hash of a file
    static std::string calculate_file_sha256(const std::string& file_path);

    // Check if FS_IMMUTABLE_FL is set on file (chattr +i)
    static bool check_fs_immutable_flag(const std::string& file_path);

    // Apply Landlock LSM: read-only on /, read-write inside workspace_path.
    // Must be called in the child process after fork(), before exec().
    // Internally calls PR_SET_NO_NEW_PRIVS before landlock_restrict_self().
    static LandlockConfig apply_landlock_sandbox(const std::string& workspace_path);
};

} // namespace lucille
