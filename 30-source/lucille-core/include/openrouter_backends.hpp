#pragma once

#include <string>
#include "speculative_pipeline.hpp"
#include "consensus_gate.hpp"

namespace lucille {

// Configurable model IDs and the OpenRouter API key. Defaults match the
// swarm.dart catalog (cheapest models that cover each role).
struct OpenRouterConfig {
    std::string api_key;
    std::string base_url{"https://openrouter.ai/api/v1/chat/completions"};
    std::string kimi_model{"moonshotai/kimi-k2-instruct"};
    std::string deepseek_model{"deepseek/deepseek-r1-0528"};
    std::string glm_model{"zhipu/glm-z1-flash"};
};

// Creates real KimiStreamFn / DeepSeekAuditFn / GlmTriageFn / consensus
// AuditFn that call OpenRouter over HTTPS. Each function is self-contained
// and thread-safe (one CURL handle per call).
class OpenRouterBackends {
public:
    explicit OpenRouterBackends(OpenRouterConfig cfg);

    // Pipeline backends
    SpeculativePipeline::KimiStreamFn    kimi_stream_fn()    const;
    SpeculativePipeline::DeepSeekAuditFn deepseek_audit_fn() const;
    SpeculativePipeline::GlmTriageFn     glm_triage_fn()     const;

    // Consensus gate voters
    ConsensusGate::AuditFn kimi_syntax_voter()   const;
    ConsensusGate::AuditFn deepseek_risk_voter()  const;

private:
    OpenRouterConfig cfg_;

    // Build the JSON body for a chat/completions request.
    static std::string build_request(
        const std::string& model,
        const std::string& system_prompt,
        const std::string& user_content,
        bool stream = false
    );

    // Extract the assistant's content from a non-streaming response body.
    static std::string extract_content(const std::string& response_body);

    // Extract a delta content chunk from one SSE data line.
    static std::string extract_delta(const std::string& sse_data);
};

} // namespace lucille
