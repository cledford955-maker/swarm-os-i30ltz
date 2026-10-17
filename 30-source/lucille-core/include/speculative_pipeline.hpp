#pragma once

#include <string>
#include <vector>
#include <functional>
#include <future>
#include <mutex>
#include <atomic>
#include <cstdint>

namespace lucille {

// A completed code block extracted from the Kimi streaming output
struct PipelineBlock {
    size_t      index{0};           // emission order
    std::string block_text;         // raw source text of the block
    std::string language;           // "cpp", "dart", "python", ...
    bool        audit_passed{false};
    std::string audit_cot;          // DeepSeek-R1 chain-of-thought output
    std::string audit_error;
    uint32_t    audit_latency_ms{0};
};

struct PipelineMetrics {
    std::string glm_report;          // GLM 5.6 triage summary
    uint32_t    token_density{0};    // estimated tokens / KiB of source
    uint32_t    compiler_warnings{0};
    uint32_t    compiler_errors{0};
};

struct PipelineResult {
    std::vector<PipelineBlock> blocks;
    PipelineMetrics            metrics;
    size_t   total_blocks{0};
    size_t   passed_blocks{0};
    size_t   rejected_blocks{0};
    uint32_t pipeline_latency_ms{0};
    bool     pipeline_complete{false};
    bool     used_mock_backends{false}; // true = simulated models, not real output
    std::string error_message;
};

// Receives streaming text chunks (from Kimi or any model), detects
// brace-balanced / indent-complete code blocks, and fires a callback
// for each complete block so it can be concurrently audited.
class StreamingBlockBuffer {
public:
    using BlockCallback = std::function<void(std::string block, size_t index)>;

    explicit StreamingBlockBuffer(std::string language = "cpp");

    // Feed the next chunk of streaming text. May fire callback 0..N times.
    void feed(const std::string& chunk);

    // Signal end-of-stream; flushes any remaining partial block.
    void flush();

    void set_callback(BlockCallback cb) { on_block_complete_ = std::move(cb); }
    size_t blocks_emitted() const { return block_index_.load(); }

private:
    std::string language_;
    std::string current_block_;    // text being accumulated for this block
    int         brace_depth_{0};
    bool        in_block_{false};  // true once we've seen the opening {
    // Lexer state (brace languages) — carried across feed() chunks
    char        quote_{0};         // active string/char delimiter, 0 = none
    bool        escape_{false};
    bool        line_comment_{false};
    bool        block_comment_{false};
    char        prev_{0};
    std::atomic<size_t> block_index_{0};
    mutable std::mutex  mutex_;
    BlockCallback       on_block_complete_;

    void try_emit();
    void split_python_block();
    bool is_block_starter(const std::string& line) const;
};

// Orchestrates three concurrent threads:
//   Thread A  — Kimi 2.6 Coder streaming (simulated via feed() calls)
//   Thread B  — DeepSeek-R1 concurrent audit of each completed block
//   Thread C  — GLM 5.6 metric triage running in parallel
//
// Real network calls are injected via the three callable fields below
// (or SwarmRouter::set_pipeline_backends). A throwing audit fails closed;
// a throwing stream leaves pipeline_complete=false.
class SpeculativePipeline {
public:
    // Injection points — swap these out with real HTTP/gRPC stubs
    using KimiStreamFn  = std::function<void(
        const std::string& prompt,
        const std::string& code,
        StreamingBlockBuffer& buf  // pipeline calls buf.feed() on each chunk
    )>;
    using DeepSeekAuditFn = std::function<bool(
        const std::string& block,
        const std::string& language,
        std::string& out_cot,
        std::string& out_err
    )>;
    using GlmTriageFn = std::function<PipelineMetrics(
        const std::string& compiler_logs,
        const std::string& source_context
    )>;

    KimiStreamFn    kimi_stream{nullptr};
    DeepSeekAuditFn deepseek_audit{nullptr};
    GlmTriageFn     glm_triage{nullptr};

    // Install simulated implementations (tests / offline). Results are
    // flagged used_mock_backends so they can't pass for real model output.
    void use_mock_backends();

    // Run the full concurrent pipeline.
    // compiler_logs is the most recent build output (fed to GLM in parallel).
    PipelineResult run(
        const std::string& prompt,
        const std::string& source_code,
        const std::string& language,
        const std::string& compiler_logs = ""
    );

private:
    bool mock_backends_{false};
};

} // namespace lucille
