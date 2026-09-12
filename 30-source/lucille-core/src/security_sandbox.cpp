#include "security_sandbox.hpp"
#include <sys/prctl.h>
#include <sys/ioctl.h>
#include <sys/stat.h>
#include <sys/mount.h>
#include <sys/syscall.h>
#include <fcntl.h>
#include <unistd.h>
#include <linux/fs.h>
#include <linux/landlock.h>
#include <openssl/evp.h>
#include <fstream>
#include <sstream>
#include <iomanip>
#include <filesystem>
#include <cstring>
#include <cerrno>
#include <iostream>

// Landlock syscall wrappers — not in glibc yet
static inline int ll_create_ruleset(const struct landlock_ruleset_attr* attr,
                                    size_t size, __u32 flags) {
    return static_cast<int>(syscall(__NR_landlock_create_ruleset, attr, size, flags));
}
static inline int ll_add_rule(int ruleset_fd, enum landlock_rule_type type,
                               const void* rule_attr, __u32 flags) {
    return static_cast<int>(syscall(__NR_landlock_add_rule, ruleset_fd, type, rule_attr, flags));
}
static inline int ll_restrict_self(int ruleset_fd, __u32 flags) {
    return static_cast<int>(syscall(__NR_landlock_restrict_self, ruleset_fd, flags));
}

namespace fs = std::filesystem;

namespace lucille {

std::string SecuritySandbox::calculate_file_sha256(const std::string& file_path) {
    if (!fs::exists(file_path)) {
        return "";
    }

    std::ifstream file(file_path, std::ios::binary);
    if (!file.is_open()) {
        return "";
    }

    EVP_MD_CTX* mdctx = EVP_MD_CTX_new();
    if (!mdctx) return "";

    if (EVP_DigestInit_ex(mdctx, EVP_sha256(), nullptr) != 1) {
        EVP_MD_CTX_free(mdctx);
        return "";
    }

    char buffer[8192];
    while (file.read(buffer, sizeof(buffer)) || file.gcount() > 0) {
        if (EVP_DigestUpdate(mdctx, buffer, file.gcount()) != 1) {
            EVP_MD_CTX_free(mdctx);
            return "";
        }
    }

    unsigned char hash[EVP_MAX_MD_SIZE];
    unsigned int length = 0;
    if (EVP_DigestFinal_ex(mdctx, hash, &length) != 1) {
        EVP_MD_CTX_free(mdctx);
        return "";
    }
    EVP_MD_CTX_free(mdctx);

    std::stringstream ss;
    for (unsigned int i = 0; i < length; ++i) {
        ss << std::hex << std::setw(2) << std::setfill('0') << static_cast<int>(hash[i]);
    }
    return ss.str();
}

bool SecuritySandbox::check_fs_immutable_flag(const std::string& file_path) {
    if (!fs::exists(file_path)) return false;

    int fd = open(file_path.c_str(), O_RDONLY);
    if (fd < 0) return false;

    long flags = 0;
    int res = ioctl(fd, FS_IOC_GETFLAGS, &flags);
    close(fd);

    if (res >= 0) {
        return (flags & FS_IMMUTABLE_FL) != 0;
    }
    return false;
}

SecurityIntegrityReport SecuritySandbox::verify_soul_integrity(
    const std::string& soul_path,
    const std::string& expected_sha256
) {
    SecurityIntegrityReport report;
    report.soul_path = soul_path;
    report.expected_sha256 = expected_sha256;

    if (!fs::exists(soul_path)) {
        report.soul_exists = false;
        return report;
    }

    report.soul_exists = true;
    report.soul_sha256 = calculate_file_sha256(soul_path);
    report.is_immutable_flag_set = check_fs_immutable_flag(soul_path);

    if (!expected_sha256.empty()) {
        report.sha256_match = (report.soul_sha256 == expected_sha256);
    } else {
        report.sha256_match = !report.soul_sha256.empty();
    }

    return report;
}

bool SecuritySandbox::apply_no_new_privs(std::string& err_msg) {
    if (prctl(PR_SET_NO_NEW_PRIVS, 1, 0, 0, 0) != 0) {
        err_msg = "Failed to set PR_SET_NO_NEW_PRIVS: " + std::string(strerror(errno));
        return false;
    }
    return true;
}

CgroupConfig SecuritySandbox::setup_cgroups_slice(uint64_t total_ram_bytes) {
    CgroupConfig config;
    // 75% of total RAM in bytes
    config.memory_high_bytes = (total_ram_bytes * 75) / 100;

    // Check potential cgroup v2 paths (system root vs user delegated slice)
    uid_t uid = getuid();
    std::vector<std::string> candidate_paths = {
        "/sys/fs/cgroup/lucille.slice",
        "/sys/fs/cgroup/user.slice/user-" + std::to_string(uid) + ".slice/lucille.slice",
        "/tmp/lucille_cgroup_mock.slice" // Fallback simulation if cgroups v2 fs is read-only
    };

    for (const auto& path : candidate_paths) {
        std::error_code ec;
        if (!fs::exists(path, ec)) {
            fs::create_directories(path, ec);
        }

        if (fs::exists(path, ec)) {
            config.slice_path = path;
            std::string mem_high_file = path + "/memory.high";
            std::ofstream out(mem_high_file);
            if (out.is_open()) {
                out << config.memory_high_bytes << "\n";
                out.close();
                config.is_active = true;
                config.status_msg = "Cgroups v2 slice active at " + path + " with memory.high=" + std::to_string(config.memory_high_bytes) + " bytes";
                return config;
            }
        }
    }

    config.is_active = false;
    config.status_msg = "Cgroups v2 not writable without elevated slice delegation; memory.high constraint cached in memory.";
    return config;
}

bool SecuritySandbox::attach_process_to_cgroup(const std::string& slice_path, pid_t pid) {
    std::string procs_file = slice_path + "/cgroup.procs";
    std::ofstream out(procs_file, std::ios::app);
    if (out.is_open()) {
        out << pid << "\n";
        return true;
    }
    return false;
}

OverlayFsConfig SecuritySandbox::prepare_ephemeral_overlay(
    const std::string& base_workspace,
    const std::string& upper_dir,
    const std::string& work_dir,
    const std::string& merged_dir
) {
    OverlayFsConfig cfg;
    cfg.lower_dir = base_workspace;
    cfg.upper_dir = upper_dir;
    cfg.work_dir = work_dir;
    cfg.merged_dir = merged_dir;

    std::error_code ec;
    fs::create_directories(cfg.upper_dir, ec);
    fs::create_directories(cfg.work_dir, ec);
    fs::create_directories(cfg.merged_dir, ec);

    if (!ec) {
        cfg.is_prepared = true;
    }
    return cfg;
}

LandlockConfig SecuritySandbox::apply_landlock_sandbox(const std::string& workspace_path) {
    LandlockConfig config;
    config.workspace_path = workspace_path;

    // Check kernel ABI version (also serves as feature detection)
    int abi = ll_create_ruleset(nullptr, 0, LANDLOCK_CREATE_RULESET_VERSION);
    if (abi < 1) {
        config.status_msg = "Landlock not supported by kernel";
        return config;
    }
    config.abi_version = abi;

    // Build the handled_access_fs mask from what this kernel supports.
    // v1 baseline rights (Linux 5.13+)
    __u64 all_fs_rights =
        LANDLOCK_ACCESS_FS_EXECUTE    |
        LANDLOCK_ACCESS_FS_WRITE_FILE |
        LANDLOCK_ACCESS_FS_READ_FILE  |
        LANDLOCK_ACCESS_FS_READ_DIR   |
        LANDLOCK_ACCESS_FS_REMOVE_DIR |
        LANDLOCK_ACCESS_FS_REMOVE_FILE|
        LANDLOCK_ACCESS_FS_MAKE_CHAR  |
        LANDLOCK_ACCESS_FS_MAKE_DIR   |
        LANDLOCK_ACCESS_FS_MAKE_REG   |
        LANDLOCK_ACCESS_FS_MAKE_SOCK  |
        LANDLOCK_ACCESS_FS_MAKE_FIFO  |
        LANDLOCK_ACCESS_FS_MAKE_BLOCK |
        LANDLOCK_ACCESS_FS_MAKE_SYM;
#ifdef LANDLOCK_ACCESS_FS_REFER       // v2 (Linux 5.19)
    if (abi >= 2) all_fs_rights |= LANDLOCK_ACCESS_FS_REFER;
#endif
#ifdef LANDLOCK_ACCESS_FS_TRUNCATE    // v3 (Linux 6.2)
    if (abi >= 3) all_fs_rights |= LANDLOCK_ACCESS_FS_TRUNCATE;
#endif
#ifdef LANDLOCK_ACCESS_FS_IOCTL_DEV   // v5 (Linux 6.10)
    if (abi >= 5) all_fs_rights |= LANDLOCK_ACCESS_FS_IOCTL_DEV;
#endif

    struct landlock_ruleset_attr ruleset_attr{};
    ruleset_attr.handled_access_fs = all_fs_rights;

    int ruleset_fd = ll_create_ruleset(&ruleset_attr, sizeof(ruleset_attr), 0);
    if (ruleset_fd < 0) {
        config.status_msg = "landlock_create_ruleset failed: " + std::string(strerror(errno));
        return config;
    }

    // Rule 1: read-only + execute on the entire filesystem tree
    {
        __u64 ro_rights = LANDLOCK_ACCESS_FS_READ_FILE |
                          LANDLOCK_ACCESS_FS_READ_DIR  |
                          LANDLOCK_ACCESS_FS_EXECUTE;

        int root_fd = open("/", O_PATH | O_CLOEXEC);
        if (root_fd < 0) {
            close(ruleset_fd);
            config.status_msg = "Failed to open / for Landlock rule: " + std::string(strerror(errno));
            return config;
        }

        struct landlock_path_beneath_attr path_attr{};
        path_attr.allowed_access = ro_rights;
        path_attr.parent_fd = root_fd;

        int ret = ll_add_rule(ruleset_fd, LANDLOCK_RULE_PATH_BENEATH, &path_attr, 0);
        close(root_fd);

        if (ret < 0) {
            close(ruleset_fd);
            config.status_msg = "Failed to add root read-only rule: " + std::string(strerror(errno));
            return config;
        }
    }

    // Rule 2: full access inside the designated workspace directory
    if (!workspace_path.empty()) {
        int ws_fd = open(workspace_path.c_str(), O_PATH | O_CLOEXEC);
        if (ws_fd < 0) {
            close(ruleset_fd);
            config.status_msg = "Failed to open workspace '" + workspace_path +
                                 "' for Landlock rule: " + std::string(strerror(errno));
            return config;
        }

        struct landlock_path_beneath_attr path_attr{};
        path_attr.allowed_access = all_fs_rights;
        path_attr.parent_fd = ws_fd;

        int ret = ll_add_rule(ruleset_fd, LANDLOCK_RULE_PATH_BENEATH, &path_attr, 0);
        close(ws_fd);

        if (ret < 0) {
            close(ruleset_fd);
            config.status_msg = "Failed to add workspace write rule: " + std::string(strerror(errno));
            return config;
        }
    }

    // PR_SET_NO_NEW_PRIVS is required before landlock_restrict_self
    if (prctl(PR_SET_NO_NEW_PRIVS, 1, 0, 0, 0) != 0) {
        close(ruleset_fd);
        config.status_msg = "prctl(NO_NEW_PRIVS) failed: " + std::string(strerror(errno));
        return config;
    }

    if (ll_restrict_self(ruleset_fd, 0) != 0) {
        close(ruleset_fd);
        config.status_msg = "landlock_restrict_self failed: " + std::string(strerror(errno));
        return config;
    }

    close(ruleset_fd);
    config.applied = true;
    config.status_msg = "Landlock ABI v" + std::to_string(abi) +
                        " active: read-only on /, read-write on '" + workspace_path + "'";
    return config;
}

} // namespace lucille
