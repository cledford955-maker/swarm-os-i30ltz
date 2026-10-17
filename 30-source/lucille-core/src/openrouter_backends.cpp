#include "openrouter_backends.hpp"
#include "http_client.hpp"
#include <iostream>
#include <sstream>
#include <chrono>

namespace lucille {

// Minimal JSON string escaping (sufficient for prompts and code)
static std::string esc(const std::string& s) {
    std::string out;
    out.reserve(s.size() + s.size() / 8);
    for (char c : s) {
        switch (c) {
            case '"':  out += "\\\""; break;
            case '\\': out += "\\\\"; break;
            case '\n': out += "\\n"; break;
            case '\r': out += "\\r"; break;
            case '\t': out += "\\t"; break;
            default:
                if (static_cast<unsigned char>(c) < 0x20)
                    out += ' ';
                else
                    out += c;
        }
    }
    return out;
}

OpenRouterBackends::OpenRouterBackends(OpenRouterConfig cfg)
    : cfg_(std::move(cfg)) {}

std::string OpenRouterBackends::build_request(
    const std::string& model,
    const std::string& system_prompt,
    const std::string& user_content,
    bool stream
) {
    std::ostringstream j;
    j << "{\"model\":\"" << model << "\""
      << ",\"messages\":["
      << "{\"role\":\"system\",\"content\":\"" << esc(system_prompt) << "\"},"
      << "{\"role\":\"user\",\"content\":\"" << esc(user_content) << "\"}"
      << "],\"stream\":" << (stream ? "true" : "false")
      << ",\"max_tokens\":4096"
      << "}";
    return j.str();
}

// Find "content":"<value>" in a JSON string — minimal, no full parser
static std::string find_json_str(const std::string& json, const std::string& key) {
    std::string needle = "\"" + key + "\":\"";
    auto pos = json.find(needle);
    if (pos == std::string::npos) return "";
    pos += needle.size();
    std::string val;
    for (size_t i = pos; i < json.size(); ++i) {
        if (json[i] == '\\' && i + 1 < json.size()) { val += json[++i]; continue; }
        if (json[i] == '"') break;
        val += json[i];
    }
    return val;
}

std::string OpenRouterBackends::extract_content(const std::string& body) {
    return find_json_str(body, "content");
}

std::string OpenRouterBackends::extract_delta(const std::string& sse_data) {
    return find_json_str(sse_data, "content");
}

// ---- Pipeline backends ------------------------------------------------

SpeculativePipeline::KimiStreamFn OpenRouterBackends::kimi_stream_fn() const {
    auto cfg = cfg_;
    return [cfg](const std::string& prompt, const std::string& code,
                 StreamingBlockBuffer& buf) {
        std::string body = build_request(
            cfg.kimi_model,
            "You are a code generation engine. Output ONLY raw source code, no markdown fences, no commentary.",
            prompt + "\n\nExisting code:\n" + code,
            true);

        auto resp = HttpClient::post_sse(
            cfg.base_url, cfg.api_key, body,
            [&buf](const std::string& line) -> bool {
                if (line == "[DONE]") return false;
                std::string delta = extract_delta(line);
                if (!delta.empty()) buf.feed(delta);
                return true;
            },
            300);

        buf.flush();
        if (!resp.ok() && !resp.error.empty())
            throw std::runtime_error("Kimi stream error: " + resp.error);
    };
}

SpeculativePipeline::DeepSeekAuditFn OpenRouterBackends::deepseek_audit_fn() const {
    auto cfg = cfg_;
    return [cfg](const std::string& block, const std::string& language,
                 std::string& out_cot, std::string& out_err) -> bool {
        std::string body = build_request(
            cfg.deepseek_model,
            "You are a code safety auditor. Analyze the code block for: "
            "1) Memory safety (use-after-free, buffer overflows, null derefs) "
            "2) Concurrency bugs (races, deadlocks) "
            "3) Security flaws (injection, privilege escalation) "
            "4) Logic errors. "
            "Start with <think>...</think> for your reasoning. "
            "End with exactly [APPROVE] if safe or [REJECT] if not.",
            "Language: " + language + "\n\n```\n" + block + "\n```");

        auto resp = HttpClient::post_json(cfg.base_url, cfg.api_key, body, 120);
        if (!resp.ok()) {
            out_err = "DeepSeek audit HTTP " + std::to_string(resp.status_code) + ": " + resp.error;
            return false;
        }

        out_cot = extract_content(resp.body);
        if (out_cot.find("[REJECT]") != std::string::npos) {
            out_err = "DeepSeek-R1 rejected block";
            return false;
        }
        return true;
    };
}

SpeculativePipeline::GlmTriageFn OpenRouterBackends::glm_triage_fn() const {
    auto cfg = cfg_;
    return [cfg](const std::string& compiler_logs,
                 const std::string& source_context) -> PipelineMetrics {
        PipelineMetrics m;
        std::string body = build_request(
            cfg.glm_model,
            "You are a compiler log analyst. Summarize the build output. "
            "Count warnings and errors. Identify the root cause of each error. "
            "Output a concise triage report.",
            "Compiler output:\n" + compiler_logs +
            "\n\nSource context:\n" + source_context);

        auto resp = HttpClient::post_json(cfg.base_url, cfg.api_key, body, 60);
        if (resp.ok()) {
            m.glm_report = extract_content(resp.body);
        } else {
            m.glm_report = "[GLM triage failed: " + resp.error + "]";
        }

        // Count occurrences in the original logs
        size_t pos = 0;
        while ((pos = compiler_logs.find("warning:", pos)) != std::string::npos)
            { ++m.compiler_warnings; ++pos; }
        pos = 0;
        while ((pos = compiler_logs.find("error:", pos)) != std::string::npos)
            { ++m.compiler_errors; ++pos; }

        if (!source_context.empty())
            m.token_density = static_cast<uint32_t>(
                source_context.size() * 4 / std::max(source_context.size() / 1024, size_t(1)));

        return m;
    };
}

// ---- Consensus gate voters --------------------------------------------

ConsensusGate::AuditFn OpenRouterBackends::kimi_syntax_voter() const {
    auto cfg = cfg_;
    return [cfg](const std::string& diff, const std::string& context) -> ConsensusVote {
        auto t0 = std::chrono::steady_clock::now();
        ConsensusVote v;
        v.model_name = "Kimi-K2-Instruct";
        v.dimension  = "syntax_validity";

        std::string body = build_request(
            cfg.kimi_model,
            "You are a syntax auditor for system configuration diffs. "
            "Check: valid syntax, no deprecated directives, library references resolve. "
            "Reply ONLY with [APPROVE] or [REJECT] followed by a one-line reason.",
            "Context: " + context + "\n\nDiff:\n" + diff);

        auto resp = HttpClient::post_json(cfg.base_url, cfg.api_key, body, 30);
        if (!resp.ok()) {
            v.approved = false;
            v.rationale = "HTTP error: " + resp.error;
        } else {
            v.rationale = extract_content(resp.body);
            v.approved = v.rationale.find("[APPROVE]") != std::string::npos;
        }

        v.latency_ms = static_cast<uint32_t>(
            std::chrono::duration_cast<std::chrono::milliseconds>(
                std::chrono::steady_clock::now() - t0).count());
        return v;
    };
}

ConsensusGate::AuditFn OpenRouterBackends::deepseek_risk_voter() const {
    auto cfg = cfg_;
    return [cfg](const std::string& diff, const std::string& context) -> ConsensusVote {
        auto t0 = std::chrono::steady_clock::now();
        ConsensusVote v;
        v.model_name = "DeepSeek-R1";
        v.dimension  = "risk_escalation";

        std::string body = build_request(
            cfg.deepseek_model,
            "You are a security risk auditor for system diffs. Analyze for: "
            "1) Privilege escalation (capabilities, setuid, sudo) "
            "2) Race conditions in new unit directives "
            "3) Rollback safety (can this be undone?) "
            "4) Network exposure (new listening ports, policy loosening). "
            "Use <think>...</think> for reasoning. "
            "End with exactly [APPROVE] or [REJECT] and a one-line summary.",
            "Context: " + context + "\n\nDiff:\n" + diff);

        auto resp = HttpClient::post_json(cfg.base_url, cfg.api_key, body, 60);
        if (!resp.ok()) {
            v.approved = false;
            v.rationale = "HTTP error: " + resp.error;
        } else {
            v.rationale = extract_content(resp.body);
            v.approved = v.rationale.find("[APPROVE]") != std::string::npos;
        }

        v.latency_ms = static_cast<uint32_t>(
            std::chrono::duration_cast<std::chrono::milliseconds>(
                std::chrono::steady_clock::now() - t0).count());
        return v;
    };
}

} // namespace lucille
