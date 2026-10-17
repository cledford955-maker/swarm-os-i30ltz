#pragma once

#include <string>
#include <vector>
#include <map>
#include <mutex>
#include <condition_variable>
#include <chrono>
#include <sys/types.h>

namespace lucille {

enum class ChallengeStatus {
    Pending,
    Approved,
    Rejected,
    Expired
};

struct HitlChallenge {
    std::string challenge_id;
    std::string command;
    std::string risk_level; // "CRITICAL", "HIGH", "MEDIUM"
    int64_t created_at{0};
    int64_t expires_at{0};
    ChallengeStatus status{ChallengeStatus::Pending};
};

class HitlSecurityManager {
public:
    HitlSecurityManager();
    ~HitlSecurityManager() = default;

    // Check if command contains high-risk patterns
    static bool is_high_risk_command(const std::string& cmd, std::string& out_reason);

    // Create a 60-second interactive challenge
    HitlChallenge create_challenge(const std::string& command, uint32_t timeout_sec = 60);

    // Resolve challenge from Companion App response
    bool resolve_challenge(const std::string& challenge_id, bool approved);

    // Block calling thread until challenge is approved, rejected, or expired
    bool await_challenge_resolution(const std::string& challenge_id, uint32_t timeout_sec = 60);

    // Emergency Remote Control Actions
    static bool emergency_freeze_process(pid_t pid);
    static bool emergency_unfreeze_process(pid_t pid);
    static bool emergency_btrfs_rollback(const std::string& snapshot_name, std::string& out_log);

    std::vector<HitlChallenge> get_pending_challenges();

private:
    std::mutex mutex_;
    std::condition_variable cv_;
    std::map<std::string, HitlChallenge> challenges_;

    static std::string generate_challenge_id();
};

} // namespace lucille
