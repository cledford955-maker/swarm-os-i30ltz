#include "speculative_pipeline.hpp"

#include <iostream>
#include <sstream>
#include <chrono>
#include <thread>
#include <algorithm>
#include <cctype>

namespace lucille {

// ---- StreamingBlockBuffer -----------------------------------------------

StreamingBlockBuffer::StreamingBlockBuffer(std::string language)
    : language_(std::move(language)) {}

static std::string trim(const std::string& s) {
    size_t a = 0, b = s.size();
    while (a < b && std::isspace((unsigned char)s[a])) ++a;
    while (b > a && std::isspace((unsigned char)s[b - 1])) --b;
    return s.substr(a, b - a);
}

// Returns true if a source line looks like the start of a named block
// (function/method/class/struct definition), not just an opening brace.
bool StreamingBlockBuffer::is_block_starter(const std::string& line) const {
    std::string t = trim(line);
    if (t.empty()) return false;

    if (language_ == "python") {
        return t.rfind("def ", 0) == 0 || t.rfind("class ", 0) == 0 || t.rfind("async def ", 0) == 0;
    }

    // C++, Dart, Java, etc. — line must NOT be a bare `{` or just a closing brace
    if (t == "{" || t == "}") return false;

    // Must not start with common non-definition keywords that open braces
    const char* noise[] = {"if ", "for ", "while ", "switch ", "else", nullptr};
    for (int i = 0; noise[i]; ++i) {
        if (t.rfind(noise[i], 0) == 0) return false;
    }

    // Heuristic: contains a `(` (parameter list) or is `class`/`struct`/`enum`
    return t.find('(') != std::string::npos
        || t.rfind("class ", 0) == 0
        || t.rfind("struct ", 0) == 0
        || t.rfind("enum ", 0) == 0
        || t.rfind("namespace ", 0) == 0;
}

void StreamingBlockBuffer::feed(const std::string& chunk) {
    std::lock_guard<std::mutex> lock(mutex_);
    pending_ += chunk;

    // Process pending text character by character
    size_t i = 0;
    while (i < pending_.size()) {
        char c = pending_[i];

        // For brace-delimited languages, track depth
        if (language_ != "python") {
            if (c == '{') {
                ++brace_depth_;
                in_block_ = true;
                current_block_ += c;
                ++i;
                continue;
            }
            if (c == '}') {
                current_block_ += c;
                ++i;
                if (brace_depth_ > 0) --brace_depth_;
                if (brace_depth_ == 0 && in_block_) {
                    try_emit();
                }
                continue;
            }
        }

        // Accumulate characters
        if (c == '\n') {
            // For Python: check if this completed line is a block starter
            if (language_ == "python") {
                // (already at \n) — check if the accumulated line is a block starter
                if (!current_block_.empty() && is_block_starter(current_block_)) {
                    // New block starting — emit previous if any
                    if (in_block_) try_emit();
                    in_block_ = true;
                }
            }
            current_block_ += c;
        } else {
            current_block_ += c;
            // Detect block starters in brace languages (accumulate until first {)
            if (language_ != "python" && !in_block_) {
                // Check if we've buffered a complete line that looks like a def
                // (will actually open on the next `{` character above)
            }
        }
        ++i;
    }
    pending_.clear();
}

void StreamingBlockBuffer::try_emit() {
    std::string block = trim(current_block_);
    current_block_.clear();
    in_block_ = false;
    brace_depth_ = 0;

    if (block.size() < 4) return; // too short to be meaningful

    size_t idx = block_index_.fetch_add(1);
    if (on_block_complete_) {
        on_block_complete_(std::move(block), idx);
    }
}

void StreamingBlockBuffer::flush() {
    std::lock_guard<std::mutex> lock(mutex_);
    if (!current_block_.empty()) {
        std::string block = trim(current_block_);
        current_block_.clear();
        if (block.size() >= 4) {
            size_t idx = block_index_.fetch_add(1);
            if (on_block_complete_) {
                on_block_complete_(std::move(block), idx);
            }
        }
    }
}

// ---- Mock backends -------------------------------------------------------

static void mock_kimi_stream(
    const std::string& /*prompt*/,
    const std::string& code,
    StreamingBlockBuffer& buf
) {
    // Simulate Kimi 2.6 streaming a multi-function patch in chunks
    // In production, replace with chunked HTTP/SSE reads from the Kimi API.
    const std::vector<std::string> simulated_chunks = {
        "// Kimi 2.6 Coder — speculative patch\n\n",
        "bool validate_input(const std::string& s) {\n",
        "    if (s.empty()) return false;\n",
        "    for (char c : s) {\n",
        "        if (!std::isprint((unsigned char)c)) return false;\n",
        "    }\n",
        "    return true;\n",
        "}\n\n",
        "int compute_checksum(const uint8_t* data, size_t len) {\n",
        "    int sum = 0;\n",
        "    for (size_t i = 0; i < len; ++i) sum ^= data[i];\n",
        "    return sum;\n",
        "}\n\n",
        "void apply_patch(const std::string& diff) {\n",
        "    // checkpoint before mutating workspace\n",
        "    auto cp = CheckpointJournal::create_checkpoint(\".\", \"kimi-patch\");\n",
        "    if (!cp.ok) return;\n",
        "    // ... apply logic ...\n",
        "}\n",
    };

    for (const auto& chunk : simulated_chunks) {
        buf.feed(chunk);
        std::this_thread::sleep_for(std::chrono::milliseconds(15)); // simulate network latency
    }
}

static bool mock_deepseek_audit(
    const std::string& block,
    const std::string& /*language*/,
    std::string& out_cot,
    std::string& out_err
) {
    // Simulate DeepSeek-R1 chain-of-thought invariant check
    // In production, replace with a real API call to DeepSeek-R1.
    std::this_thread::sleep_for(std::chrono::milliseconds(30)); // simulate audit latency

    bool has_dangerous = block.find("system(") != std::string::npos
                      || block.find("DROP TABLE") != std::string::npos
                      || block.find("rm -rf") != std::string::npos;

    if (has_dangerous) {
        out_err = "DeepSeek-R1: dangerous syscall pattern detected";
        return false;
    }

    std::ostringstream cot;
    cot << "<think>\n"
        << "  Block size: " << block.size() << " bytes\n"
        << "  Memory safety: no raw pointer arithmetic visible\n"
        << "  Exception safety: return-paths look balanced\n"
        << "  Race conditions: no shared state mutation detected\n"
        << "</think>\n"
        << "[PASS] Invariants preserved.";
    out_cot = cot.str();
    return true;
}

static PipelineMetrics mock_glm_triage(
    const std::string& compiler_logs,
    const std::string& source_context
) {
    // Simulate GLM 5.6 compiler log analysis running concurrently
    std::this_thread::sleep_for(std::chrono::milliseconds(20));

    PipelineMetrics m;
    size_t warns = 0, errs = 0;
    std::istringstream ss(compiler_logs);
    std::string line;
    while (std::getline(ss, line)) {
        if (line.find("warning:") != std::string::npos) ++warns;
        if (line.find("error:")   != std::string::npos) ++errs;
    }

    m.compiler_warnings = static_cast<uint32_t>(warns);
    m.compiler_errors   = static_cast<uint32_t>(errs);

    // Estimate token density: ~1 token per 4 chars of source
    m.token_density = source_context.empty() ? 0
        : static_cast<uint32_t>((source_context.size() / 4) * 1024 / source_context.size());

    std::ostringstream report;
    report << "[GLM-5.6 Triage] compiler_warnings=" << warns
           << " compiler_errors=" << errs
           << " token_density≈" << m.token_density << " tok/KiB"
           << " | No critical panics. Memory high threshold stable.";
    m.glm_report = report.str();
    return m;
}

void SpeculativePipeline::use_mock_backends() {
    kimi_stream    = mock_kimi_stream;
    deepseek_audit = mock_deepseek_audit;
    glm_triage     = mock_glm_triage;
}

// ---- Pipeline orchestration ---------------------------------------------

PipelineResult SpeculativePipeline::run(
    const std::string& prompt,
    const std::string& source_code,
    const std::string& language,
    const std::string& compiler_logs
) {
    auto t0 = std::chrono::steady_clock::now();
    PipelineResult result;
    audit_results_.clear();

    if (!kimi_stream || !deepseek_audit || !glm_triage) {
        result.error_message = "SpeculativePipeline: backends not configured — call use_mock_backends()";
        return result;
    }

    // Pending audit futures: each completed block fires an async DeepSeek-R1 call
    std::vector<std::future<PipelineBlock>> audit_futures;
    std::mutex                              futures_mutex;

    // Wire the block buffer — each completed block immediately launches an async audit
    StreamingBlockBuffer buf(language);
    buf.set_callback([&](std::string block, size_t idx) {
        std::cout << "[Pipeline] Block " << idx << " complete ("
                  << block.size() << " bytes) → dispatching DeepSeek-R1 audit\n";

        // Capture by value so the async lambda owns the data
        auto fut = std::async(std::launch::async,
            [this, b = std::move(block), idx, &language]() -> PipelineBlock {
                auto t_start = std::chrono::steady_clock::now();
                PipelineBlock pb;
                pb.index      = idx;
                pb.block_text = b;
                pb.language   = language;

                pb.audit_passed = deepseek_audit(
                    pb.block_text, language, pb.audit_cot, pb.audit_error
                );

                pb.audit_latency_ms = static_cast<uint32_t>(
                    std::chrono::duration_cast<std::chrono::milliseconds>(
                        std::chrono::steady_clock::now() - t_start).count());

                std::cout << "[Pipeline] Block " << idx
                          << (pb.audit_passed ? " PASS" : " REJECT")
                          << " (" << pb.audit_latency_ms << "ms)\n";
                return pb;
            });

        std::lock_guard<std::mutex> lk(futures_mutex);
        audit_futures.push_back(std::move(fut));
    });

    // Thread C — GLM 5.6 triage runs fully in parallel from the start
    auto glm_future = std::async(std::launch::async,
        [this, &compiler_logs, &source_code]() -> PipelineMetrics {
            std::cout << "[Pipeline] GLM-5.6 triage started (parallel)\n";
            auto m = glm_triage(compiler_logs, source_code);
            std::cout << "[Pipeline] " << m.glm_report << "\n";
            return m;
        });

    // Thread A — Kimi streaming (feeds completed chunks into buf, which fires callbacks)
    std::cout << "[Pipeline] Kimi-2.6 streaming started\n";
    kimi_stream(prompt, source_code, buf);
    buf.flush(); // emit any trailing partial block

    std::cout << "[Pipeline] Kimi stream complete — "
              << buf.blocks_emitted() << " blocks emitted. Waiting for audits...\n";

    // Collect all audit results (futures may already be done due to concurrency)
    {
        std::lock_guard<std::mutex> lk(futures_mutex);
        for (auto& fut : audit_futures) {
            if (fut.valid()) {
                PipelineBlock pb = fut.get();
                if (pb.audit_passed) ++result.passed_blocks;
                else ++result.rejected_blocks;
                result.blocks.push_back(std::move(pb));
            }
        }
    }

    // Sort blocks back into emission order
    std::sort(result.blocks.begin(), result.blocks.end(),
        [](const PipelineBlock& a, const PipelineBlock& b) { return a.index < b.index; });

    result.total_blocks    = result.blocks.size();
    result.metrics         = glm_future.get();
    result.pipeline_complete = true;
    result.pipeline_latency_ms = static_cast<uint32_t>(
        std::chrono::duration_cast<std::chrono::milliseconds>(
            std::chrono::steady_clock::now() - t0).count());

    std::cout << "[Pipeline] Complete: " << result.total_blocks << " blocks, "
              << result.passed_blocks << " passed, "
              << result.rejected_blocks << " rejected, "
              << result.pipeline_latency_ms << "ms total\n";

    return result;
}

} // namespace lucille
