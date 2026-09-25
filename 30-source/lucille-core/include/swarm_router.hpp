#pragma once

#include <string>
#include <vector>
#include <map>
#include <memory>
#include <functional>
#include "safety_gate.hpp"
#include "process_manager.hpp"
#include "speculative_pipeline.hpp"
#include "shm_telemetry.hpp"
#include "entropy_filter.hpp"
#include "consensus_gate.hpp"

namespace lucille {

enum class SwarmModelType {
    Kimi26Coder,        // Flagship code patches, refactoring, AST generation
    GLM56,              // Flagship journal triage, log analysis, user intent
    DeepSeekR1,         // Flagship CoT safety proofs, invariant validation
    DeepSeekV4Flash,    // Fast structural verification
    Hermes3Agent,       // Sandboxed tool & browser execution
    LocalGGUF,          // Local quantized fallback (llama.cpp)
    
    // High-Efficiency Budget Tier Models
    DeepSeekV3,         // Budget dense coding & AST evaluation ($0.14 / 1M)
    GLM4Flash,          // Budget rapid log triage & test eval ($0.05 / 1M)
    Qwen25Coder32B,     // Budget SOTA code generation & evaluation ($0.18 / 1M)
    Gemini20FlashLite   // Budget UI wireframing & Flutter layout ($0.075 / 1M)
};

struct SwarmTaskRequest {
    std::string task_id;
    std::string user_instruction;
    std::string target_file;
    std::string file_content;
    std::string language; // "cpp", "dart", "python", "json"
    std::string workspace_dir; // absolute path to git repo root; empty = dry-run only
    bool require_two_tier_speculation{true};
    bool allow_tool_execution{true};
};

struct SwarmTaskResponse {
    std::string task_id;
    bool success{false};
    std::string draft_patch;
    std::string drafter_model;
    std::string auditor_model;
    std::string deepseek_cot_proof;
    bool safety_verified{false};
    bool git_apply_verified{false};
    bool ast_verified{false};
    std::string execution_output;
    std::string error_message;
    uint32_t total_latency_ms{0};
    bool used_local_fallback{false};
    std::string checkpoint_id;  // git SHA from SafetyGate::checkpoint_and_apply; empty if no workspace
    bool high_risk{false};          // diff touches systemd/firewall/kernel/boot/privileges
    bool consensus_approved{false}; // 2-of-2 gate passed (always true for low-risk diffs)
    std::vector<std::string> consensus_triggers;
};

class SwarmRouter {
public:
    explicit SwarmRouter(std::shared_ptr<ProcessManager> process_mgr = nullptr);
    ~SwarmRouter() = default;

    // Route and execute two-tier speculative task (sequential, legacy)
    SwarmTaskResponse route_and_execute(const SwarmTaskRequest& req);

    // Pipelined async speculative execution:
    //   Kimi streams → completed blocks audited concurrently by DeepSeek-R1
    //   GLM 5.6 triage runs in parallel from the start.
    // compiler_logs: most recent build output; entropy-filtered before GLM
    // sees it. Uses backends from set_pipeline_backends(); until those are
    // set, runs simulated backends and flags result.used_mock_backends.
    PipelineResult route_speculative_pipeline(
        const SwarmTaskRequest& req,
        const std::string& compiler_logs = ""
    );

    // Tier 1: Rapid Code & Patch Drafting (Kimi 2.6 Coder / GLM 5.6)
    std::string draft_code_patch(
        const SwarmTaskRequest& req,
        SwarmModelType selected_model,
        std::string& out_model_name
    );

    // Tier 2: DeepSeek-R1 Invariant & Safety Proof Verification
    bool audit_patch_with_deepseek(
        const std::string& patch,
        const std::string& original_code,
        std::string& out_cot_proof,
        std::string& out_error
    );

    // Tier 3: Sandboxed Execution via Hermes 3 Agent
    bool execute_tool_in_sandbox(
        const std::string& tool_name,
        const std::string& tool_args_json,
        std::string& out_execution_result,
        std::string& out_error
    );

    // Install real model clients for route_speculative_pipeline().
    void set_pipeline_backends(
        SpeculativePipeline::KimiStreamFn    kimi_stream,
        SpeculativePipeline::DeepSeekAuditFn deepseek_audit,
        SpeculativePipeline::GlmTriageFn     glm_triage
    );

    // Install real voters for the 2-of-2 consensus gate on high-risk diffs.
    // Until set, route_and_execute() blocks every high-risk diff.
    void set_consensus_backends(ConsensusGate::AuditFn syntax_audit,
                                ConsensusGate::AuditFn risk_audit);

    // Diagnostics from the most recent entropy filtering of compiler logs
    const EntropyFilter::CleanResult& last_log_filter() const { return last_log_filter_; }

    SafetyGate& get_safety_gate() { return safety_gate_; }

    // Select optimal model for a specific task category
    SwarmModelType select_model_for_task(const std::string& task_category);

private:
    std::shared_ptr<ProcessManager> process_manager_;
    SafetyGate safety_gate_;
    ShmTelemetryBuffer shm_buf_;  // high-freq telemetry ring → /dev/shm/swarm_telemetry_shm
    SpeculativePipeline::KimiStreamFn    pipeline_kimi_;
    SpeculativePipeline::DeepSeekAuditFn pipeline_audit_;
    SpeculativePipeline::GlmTriageFn     pipeline_glm_;
    EntropyFilter::CleanResult           last_log_filter_;
    ConsensusGate                        consensus_gate_;

    // Simulated LLM API response generators / mock runners
    std::string call_kimi_coder(const std::string& prompt, const std::string& code);
    std::string call_glm_triage(const std::string& prompt, const std::string& logs);
    std::string call_deepseek_r1(const std::string& diff, const std::string& context, bool& out_is_safe);
    std::string call_local_gguf(const std::string& prompt);
};

} // namespace lucille
