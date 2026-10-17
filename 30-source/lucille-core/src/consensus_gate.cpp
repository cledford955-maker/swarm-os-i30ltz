#include "consensus_gate.hpp"

#include <iostream>
#include <sstream>
#include <future>
#include <chrono>
#include <thread>
#include <algorithm>
#include <cctype>

namespace lucille {

// ---- High-risk classifier -----------------------------------------------

// Patterns that flag a diff as touching a high-risk system area.
// Checked against both the file paths in the diff header and the diff body.
struct RiskPattern {
    const char* pattern;
    const char* trigger_name;
};

static constexpr RiskPattern kPathPatterns[] = {
    // systemd
    { ".service",               "systemd:unit_service"  },
    { ".timer",                 "systemd:unit_timer"    },
    { ".socket",                "systemd:unit_socket"   },
    { "/etc/systemd/",          "systemd:etc_dir"       },
    { "/usr/lib/systemd/",      "systemd:lib_dir"       },
    // firewall
    { "nftables",               "firewall:nftables"     },
    { "iptables",               "firewall:iptables"     },
    { "firewalld",              "firewall:firewalld"     },
    { "/etc/nftables",          "firewall:nftables_etc" },
    // kernel / sysctl
    { "/etc/sysctl",            "kernel:sysctl_etc"     },
    { "/proc/sys/",             "kernel:proc_sys"       },
    { "/etc/modules",           "kernel:modules"        },
    { "modprobe",               "kernel:modprobe"       },
    // boot / crypto
    { "crypttab",               "crypto:crypttab"       },
    { "fstab",                  "boot:fstab"            },
    { "/boot/",                 "boot:boot_dir"         },
    { "grub",                   "boot:grub"             },
    { "cryptsetup",             "crypto:cryptsetup"     },
    { nullptr,                  nullptr                 },
};

static constexpr RiskPattern kContentPatterns[] = {
    // systemd unit directives
    { "ExecStart=",             "systemd:ExecStart"     },
    { "ExecStartPre=",          "systemd:ExecStartPre"  },
    { "After=",                 "systemd:After"         },
    { "Requires=",              "systemd:Requires"      },
    { "WantedBy=",              "systemd:WantedBy"      },
    { "CapabilityBoundingSet=", "systemd:Capabilities"  },
    { "AmbientCapabilities=",   "systemd:Capabilities"  },
    // privilege escalation
    { "setuid",                 "priv:setuid"           },
    { "setcap ",                "priv:setcap"           },
    { "CAP_SYS_ADMIN",          "priv:CAP_SYS_ADMIN"    },
    { "CAP_NET_ADMIN",          "priv:CAP_NET_ADMIN"    },
    { "CAP_SYS_MODULE",         "priv:CAP_SYS_MODULE"   },
    // firewall rule syntax
    { "nft add rule",           "firewall:nft_rule"     },
    { "iptables -",             "firewall:iptables_cmd" },
    { "INPUT DROP",             "firewall:INPUT_DROP"   },
    { "OUTPUT DROP",            "firewall:OUTPUT_DROP"  },
    // sysctl keys
    { "kernel.",                "kernel:sysctl_kernel"  },
    { "net.ipv",                "kernel:sysctl_net"     },
    { "vm.swappiness",          "kernel:sysctl_vm"      },
    { nullptr,                  nullptr                 },
};

static std::string to_lower(const std::string& s) {
    std::string out(s.size(), '\0');
    std::transform(s.begin(), s.end(), out.begin(),
                   [](unsigned char c){ return std::tolower(c); });
    return out;
}

bool ConsensusGate::classify_high_risk(
    const std::string& diff_patch,
    std::vector<std::string>& out_reasons
) {
    std::string lower = to_lower(diff_patch);
    bool flagged = false;

    // Patterns are written in natural case (ExecStart=, CAP_SYS_ADMIN) and
    // compared case-insensitively — lowercase them too, or they never match.
    // Path patterns are checked against the whole diff (headers and body).
    for (int i = 0; kPathPatterns[i].pattern; ++i) {
        if (lower.find(to_lower(kPathPatterns[i].pattern)) != std::string::npos) {
            out_reasons.emplace_back(kPathPatterns[i].trigger_name);
            flagged = true;
        }
    }

    // Content patterns: added AND removed lines — deleting a firewall DROP
    // policy or a capability restriction is as risky as adding one.
    std::istringstream ss(diff_patch);
    std::string line;
    while (std::getline(ss, line)) {
        if (line.empty() || (line[0] != '+' && line[0] != '-')) continue;
        if (line.rfind("+++", 0) == 0 || line.rfind("---", 0) == 0) continue; // file headers
        std::string lline = to_lower(line);
        for (int i = 0; kContentPatterns[i].pattern; ++i) {
            if (lline.find(to_lower(kContentPatterns[i].pattern)) != std::string::npos) {
                const std::string trigger(kContentPatterns[i].trigger_name);
                if (std::find(out_reasons.begin(), out_reasons.end(), trigger) == out_reasons.end())
                    out_reasons.emplace_back(trigger);
                flagged = true;
            }
        }
    }

    return flagged;
}

// ---- Mock backends -------------------------------------------------------

static ConsensusVote mock_kimi_syntax(const std::string& diff, const std::string&) {
    std::this_thread::sleep_for(std::chrono::milliseconds(25));
    auto t0 = std::chrono::steady_clock::now();

    ConsensusVote v;
    v.model_name = "Kimi-2.6-Coder";
    v.dimension  = "syntax_validity";

    // Reject if the diff introduces obviously malformed systemd directives
    bool bad = diff.find("ExecStart=rm -rf") != std::string::npos
            || diff.find("ExecStart=/bin/sh -c 'rm") != std::string::npos;

    v.approved  = !bad;
    v.rationale = bad
        ? "Syntax audit: detected destructive ExecStart directive. REJECTED."
        : "Syntax audit: unit format valid, directives well-formed, "
          "no deprecated keys, library references resolved. APPROVED.";

    v.latency_ms = static_cast<uint32_t>(
        std::chrono::duration_cast<std::chrono::milliseconds>(
            std::chrono::steady_clock::now() - t0).count()) + 25;
    return v;
}

static ConsensusVote mock_deepseek_risk(const std::string& diff, const std::string&) {
    std::this_thread::sleep_for(std::chrono::milliseconds(35));
    auto t0 = std::chrono::steady_clock::now();

    ConsensusVote v;
    v.model_name = "DeepSeek-R1";
    v.dimension  = "risk_escalation";

    // Flag any capability grants that include SYS_ADMIN without explicit justification
    bool escalation = diff.find("CAP_SYS_ADMIN") != std::string::npos
                   || diff.find("setuid root") != std::string::npos
                   || diff.find("INPUT DROP") != std::string::npos;

    v.approved  = !escalation;

    std::ostringstream cot;
    cot << "<think>\n"
        << "  1. Permission escalation scan: "
        << (escalation ? "FLAGGED — CAP_SYS_ADMIN or equivalent detected\n" : "clean\n")
        << "  2. Race condition analysis: no shared state in new unit directives\n"
        << "  3. Rollback safety: systemctl disable + revert script viable\n"
        << "  4. Network exposure: ";
    if (diff.find("INPUT DROP") != std::string::npos)
        cot << "firewall policy change detected — FLAGGED\n";
    else
        cot << "no new listening ports or policy loosening\n";
    cot << "</think>\n"
        << (escalation ? "[REJECT] Privilege escalation or policy risk detected."
                       : "[APPROVE] No privilege escalation, race conditions, or unsafe rollback paths.");

    v.rationale  = cot.str();
    v.latency_ms = static_cast<uint32_t>(
        std::chrono::duration_cast<std::chrono::milliseconds>(
            std::chrono::steady_clock::now() - t0).count()) + 35;
    return v;
}

void ConsensusGate::use_mock_backends() {
    mock_backends_     = true;
    kimi_syntax_audit  = mock_kimi_syntax;
    deepseek_risk_audit= mock_deepseek_risk;
}

// ---- Gate evaluation -----------------------------------------------------

ConsensusResult ConsensusGate::evaluate(
    const std::string& diff_patch,
    const std::string& context
) {
    auto t0 = std::chrono::steady_clock::now();
    ConsensusResult result;
    result.used_mock_backends = mock_backends_;

    // Fast path: classify without any model calls
    std::vector<std::string> reasons;
    result.is_high_risk = classify_high_risk(diff_patch, reasons);

    if (!result.is_high_risk) {
        result.approved = true;
        return result;
    }

    result.triggers = reasons;
    std::cout << "[ConsensusGate] High-risk diff detected. Triggers: ";
    for (size_t i = 0; i < reasons.size(); ++i) {
        std::cout << reasons[i] << (i + 1 < reasons.size() ? ", " : "\n");
    }

    // Fail closed: a high-risk diff is never approved without both voters
    if (!kimi_syntax_audit || !deepseek_risk_audit) {
        result.rejection_reason = "ConsensusGate: audit backends not configured — high-risk diff blocked";
        result.approved = false;
        return result;
    }
    std::cout << "[ConsensusGate] Dispatching Kimi + DeepSeek-R1 concurrently (2-of-2 required)...\n";

    // A voter that throws counts as a rejection (fail closed)
    auto safe_vote = [&](const AuditFn& fn, const char* model, const char* dim) {
        try {
            return fn(diff_patch, context);
        } catch (const std::exception& e) {
            ConsensusVote v;
            v.model_name = model;
            v.dimension  = dim;
            v.approved   = false;
            v.rationale  = std::string("audit failed: ") + e.what();
            return v;
        }
    };

    // Both audits run concurrently — wall-clock time = max(kimi, deepseek), not sum
    auto kimi_future = std::async(std::launch::async,
        [&]() { return safe_vote(kimi_syntax_audit, "Kimi-2.6-Coder", "syntax_validity"); });
    auto deepseek_future = std::async(std::launch::async,
        [&]() { return safe_vote(deepseek_risk_audit, "DeepSeek-R1", "risk_escalation"); });

    ConsensusVote kimi_vote     = kimi_future.get();
    ConsensusVote deepseek_vote = deepseek_future.get();

    result.votes.push_back(kimi_vote);
    result.votes.push_back(deepseek_vote);

    std::cout << "[ConsensusGate] " << kimi_vote.model_name
              << " [" << kimi_vote.dimension << "]: "
              << (kimi_vote.approved ? "APPROVED" : "REJECTED")
              << " (" << kimi_vote.latency_ms << "ms)\n";
    std::cout << "[ConsensusGate] " << deepseek_vote.model_name
              << " [" << deepseek_vote.dimension << "]: "
              << (deepseek_vote.approved ? "APPROVED" : "REJECTED")
              << " (" << deepseek_vote.latency_ms << "ms)\n";

    // 2-of-2: both must approve
    result.approved = kimi_vote.approved && deepseek_vote.approved;

    if (!result.approved) {
        std::ostringstream rejection;
        if (!kimi_vote.approved)
            rejection << "[Kimi] " << kimi_vote.rationale << "\n";
        if (!deepseek_vote.approved)
            rejection << "[DeepSeek-R1] " << deepseek_vote.rationale;
        result.rejection_reason = rejection.str();
        std::cout << "[ConsensusGate] BLOCKED — patch rejected before HITL queue\n";
    } else {
        std::cout << "[ConsensusGate] 2-of-2 APPROVED — forwarding to HITL queue\n";
    }

    result.total_latency_ms = static_cast<uint32_t>(
        std::chrono::duration_cast<std::chrono::milliseconds>(
            std::chrono::steady_clock::now() - t0).count());

    return result;
}

} // namespace lucille
