#pragma once

#include <string>
#include <vector>
#include <map>
#include <chrono>
#include <mutex>
#include <deque>
#include "checkpoint_journal.hpp"

namespace lucille {

struct ToolSchemaDefinition {
    std::string tool_name;
    std::vector<std::string> required_fields;
    std::map<std::string, std::string> field_types; // "string", "int", "bool", "array", "object"
};

enum class CircuitBreakerState {
    Closed,   // Normal operation (cloud endpoint active)
    Open,     // Tripped (fallback to local GGUF active)
    HalfOpen  // Testing cloud recovery
};

class SafetyGate {
public:
    explicit SafetyGate(uint32_t p95_threshold_ms = 1500);
    ~SafetyGate() = default;

    // 1. Git Apply Dry-Run Checker + Checkpoint-then-Apply
    // Non-empty workspace_dir: `git apply --check` against that tree.
    // Empty workspace_dir: syntax-only (`git apply --stat`), no files touched.
    static bool verify_git_apply_check(
        const std::string& workspace_dir,
        const std::string& diff_patch,
        std::string& out_error
    );

    // Checkpoint → apply patch → rollback on failure.
    // Returns the CheckpointResult so the caller can confirm or rollback later.
    static CheckpointResult checkpoint_and_apply(
        const std::string& workspace_dir,
        const std::string& diff_patch,
        const std::string& label,
        std::string& out_error
    );

    // 2. Structural & AST Syntax Validator (C++, Dart/Flutter, Python, JSON)
    static bool verify_ast_syntax(
        const std::string& language,
        const std::string& code,
        std::string& out_error
    );

    // 3. Strict JSON Schema Validation for Tool Calls
    void register_tool_schema(const ToolSchemaDefinition& schema);
    bool validate_tool_call_json(
        const std::string& tool_name,
        const std::string& json_args,
        std::string& out_error
    );

    // 4. Rolling p95 Latency Circuit Breaker (1500ms threshold)
    void record_request_latency(uint32_t latency_ms, bool is_error = false);
    bool should_fallback_to_local_gguf();
    uint32_t get_rolling_p95_latency() const;
    CircuitBreakerState get_circuit_state() const { return circuit_state_; }
    void reset_circuit();

    // 5. KV-Cache Prefix Formatter (SOUL.md + Hardware State)
    static std::string format_kv_cache_prefix(
        const std::string& soul_content,
        const std::string& soul_sha256,
        uint32_t logical_cores,
        uint64_t ram_mb,
        const std::string& gpu_model
    );

private:
    uint32_t p95_threshold_ms_{1500};
    mutable std::mutex latency_mutex_;
    std::deque<uint32_t> latency_window_; // Last 50 requests
    size_t max_window_size_{50};
    uint32_t consecutive_failures_{0};
    CircuitBreakerState circuit_state_{CircuitBreakerState::Closed};
    std::chrono::steady_clock::time_point last_state_change_;

    std::mutex schema_mutex_;
    std::map<std::string, ToolSchemaDefinition> tool_schemas_;

    void update_circuit_state_locked();
};

} // namespace lucille
