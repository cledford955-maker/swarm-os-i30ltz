#include "http_client.hpp"
#include <curl/curl.h>
#include <sstream>

namespace lucille {

// libcurl write callback for buffered (non-streaming) responses
static size_t write_buf(char* ptr, size_t size, size_t nmemb, void* userdata) {
    auto* buf = static_cast<std::string*>(userdata);
    size_t bytes = size * nmemb;
    buf->append(ptr, bytes);
    return bytes;
}

// SSE write callback: accumulates bytes and fires the callback for each
// complete "data: ..." line. Partial lines are held across calls.
struct SseState {
    HttpClient::SseCallback cb;
    std::string             partial;
    bool                    aborted{false};
};

static size_t write_sse(char* ptr, size_t size, size_t nmemb, void* userdata) {
    auto* st = static_cast<SseState*>(userdata);
    if (st->aborted) return 0;
    size_t bytes = size * nmemb;
    st->partial.append(ptr, bytes);

    // Process complete lines
    size_t pos;
    while ((pos = st->partial.find('\n')) != std::string::npos) {
        std::string line = st->partial.substr(0, pos);
        st->partial.erase(0, pos + 1);

        // Trim trailing \r
        if (!line.empty() && line.back() == '\r') line.pop_back();

        // SSE: only forward "data:" lines (skip comments, event:, id:, retry:)
        if (line.rfind("data:", 0) == 0) {
            std::string payload = line.substr(5);
            // Trim leading space after "data:"
            if (!payload.empty() && payload[0] == ' ') payload.erase(0, 1);
            if (!st->cb(payload)) {
                st->aborted = true;
                return 0;
            }
        }
    }
    return bytes;
}

static CURL* make_handle(const std::string& url, const std::string& bearer_token,
                          const std::string& json_body, struct curl_slist*& headers,
                          uint32_t timeout_sec) {
    CURL* curl = curl_easy_init();
    if (!curl) return nullptr;

    curl_easy_setopt(curl, CURLOPT_URL, url.c_str());
    curl_easy_setopt(curl, CURLOPT_POST, 1L);
    curl_easy_setopt(curl, CURLOPT_POSTFIELDS, json_body.c_str());
    curl_easy_setopt(curl, CURLOPT_POSTFIELDSIZE, static_cast<long>(json_body.size()));
    curl_easy_setopt(curl, CURLOPT_TIMEOUT, static_cast<long>(timeout_sec));

    headers = nullptr;
    headers = curl_slist_append(headers, "Content-Type: application/json");
    if (!bearer_token.empty()) {
        std::string auth = "Authorization: Bearer " + bearer_token;
        headers = curl_slist_append(headers, auth.c_str());
    }
    headers = curl_slist_append(headers, "HTTP-Referer: https://swarmos.dev");
    headers = curl_slist_append(headers, "X-Title: SWARM-OS-Lucille");
    curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headers);

    // TLS
    curl_easy_setopt(curl, CURLOPT_SSL_VERIFYPEER, 1L);
    curl_easy_setopt(curl, CURLOPT_SSL_VERIFYHOST, 2L);

    return curl;
}

HttpClient::Response HttpClient::post_json(
    const std::string& url, const std::string& bearer_token,
    const std::string& json_body, uint32_t timeout_sec
) {
    Response resp;
    struct curl_slist* headers = nullptr;
    CURL* curl = make_handle(url, bearer_token, json_body, headers, timeout_sec);
    if (!curl) { resp.error = "curl_easy_init failed"; return resp; }

    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, write_buf);
    curl_easy_setopt(curl, CURLOPT_WRITEDATA, &resp.body);

    CURLcode rc = curl_easy_perform(curl);
    if (rc != CURLE_OK) {
        resp.error = curl_easy_strerror(rc);
    } else {
        curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &resp.status_code);
    }

    curl_slist_free_all(headers);
    curl_easy_cleanup(curl);
    return resp;
}

HttpClient::Response HttpClient::post_sse(
    const std::string& url, const std::string& bearer_token,
    const std::string& json_body, SseCallback on_line, uint32_t timeout_sec
) {
    Response resp;
    struct curl_slist* headers = nullptr;
    CURL* curl = make_handle(url, bearer_token, json_body, headers, timeout_sec);
    if (!curl) { resp.error = "curl_easy_init failed"; return resp; }

    // Accept SSE content type
    headers = curl_slist_append(headers, "Accept: text/event-stream");
    curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headers);

    SseState state;
    state.cb = std::move(on_line);
    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, write_sse);
    curl_easy_setopt(curl, CURLOPT_WRITEDATA, &state);

    CURLcode rc = curl_easy_perform(curl);
    if (rc != CURLE_OK && !state.aborted) {
        resp.error = curl_easy_strerror(rc);
    } else {
        curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &resp.status_code);
    }

    curl_slist_free_all(headers);
    curl_easy_cleanup(curl);
    return resp;
}

} // namespace lucille
