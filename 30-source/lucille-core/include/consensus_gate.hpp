#pragma once

#include <string>
#include <vector>
#include <functional>
#include <cstdint>

namespace lucille {

// One model's vote on a high-risk diff
struct ConsensusVote {
    std::string model_name;
    std::string dimension;   // "syntax_validity" | "risk_escalation"
    bool        approved{false};
    std::string rationale;   // model's reasoning / CoT snippet
    uint32_t    latency_ms{0};
};

struct ConsensusResult {
    bool                       approved{false}; // true only when ALL votes pass
    bool                       is_high_risk{false};
    std::vector<ConsensusVote> votes;
    std::string                rejection_reason;
    uint32_t                   total_latency_ms{0};
};

// Detects whether a unified diff touches high-risk system areas and, if so,
// requires 2-of-2 model votes before the patch is allowed to proceed.
//
// High-risk triggers:
//   - systemd unit files  (*.service, *.timer, *.socket, /etc/systemd/)
//   - firewall configs    (nftables, iptables, /etc/nftables.conf)
//   - kernel parameters   (/proc/sys/, sysctl, /etc/sysctl.d/)
//   - boot/crypto         (crypttab, fstab, /boot/, grub)
//
// Model A — Kimi 2.6 Coder: syntactic validity, format, library dependencies
// Model B — DeepSeek-R1:    permission escalation, race conditions, rollback safety
class ConsensusGate {
public:
    // Injection points — replace with real API stubs; mocks ship by default.
    using AuditFn = std::function<ConsensusVote(
        const std::string& diff,
        const std::string& context   // extra metadata (file list, system state)
    )>;

    AuditFn kimi_syntax_audit{nullptr};
    AuditFn deepseek_risk_audit{nullptr};

    // Install default mock implementations
    void use_mock_backends();

    // Classify the diff and, if high-risk, run both audits concurrently.
    // Non-high-risk diffs return immediately with approved=true, is_high_risk=false.
    ConsensusResult evaluate(
        const std::string& diff_patch,
        const std::string& context = ""
    );

    // Pure classifier — no model calls. Returns true if the diff touches a
    // high-risk area. Also fills out_reasons with matching trigger names.
    static bool classify_high_risk(
        const std::string& diff_patch,
        std::vector<std::string>& out_reasons
    );
};

} // namespace lucille
