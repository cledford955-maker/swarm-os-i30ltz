#pragma once

#include <string>
#include <vector>
#include <functional>
#include <cstdint>

namespace lucille {

// Thin libcurl wrapper for JSON-over-HTTPS. Thread-safe: each call creates
// its own CURL handle, so multiple threads can call concurrently.
class HttpClient {
public:
    struct Response {
        long   status_code{0};
        std::string body;
        std::string error;
        bool ok() const { return status_code >= 200 && status_code < 300; }
    };

    // Streaming callback: receives each raw SSE line ("data: {...}").
    // Return false to abort the stream.
    using SseCallback = std::function<bool(const std::string& line)>;

    // POST JSON, wait for the full response.
    static Response post_json(
        const std::string& url,
        const std::string& bearer_token,
        const std::string& json_body,
        uint32_t timeout_sec = 120
    );

    // POST JSON with streaming (SSE). The callback fires once per "data:"
    // line. Returns when the stream ends or the callback returns false.
    static Response post_sse(
        const std::string& url,
        const std::string& bearer_token,
        const std::string& json_body,
        SseCallback on_line,
        uint32_t timeout_sec = 300
    );
};

} // namespace lucille
