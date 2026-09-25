#include "safety_gate.hpp"
#include "checkpoint_journal.hpp"
#include <iostream>
#include <sstream>
#include <fstream>
#include <cmath>
#include <algorithm>
#include <stack>
#include <filesystem>
#include <unistd.h>
#include <sys/wait.h>

namespace fs = std::filesystem;

namespace lucille {

SafetyGate::SafetyGate(uint32_t p95_threshold_ms)
    : p95_threshold_ms_(p95_threshold_ms),
      last_state_change_(std::chrono::steady_clock::now()) {
    
    // Register default schemas for core tools
    register_tool_schema({
        "run_command",
        {"command"},
        {{"command", "string"}, {"timeout_ms", "int"}, {"sandboxed", "bool"}}
    });

    register_tool_schema({
        "write_file",
        {"path", "content"},
        {{"path", "string"}, {"content", "string"}, {"overwrite", "bool"}}
    });

    register_tool_schema({
        "openclaw_browser",
        {"action", "url"},
        {{"action", "string"}, {"url", "string"}, {"selector", "string"}}
    });
}

CheckpointResult SafetyGate::checkpoint_and_apply(
    const std::string& workspace_dir,
    const std::string& diff_patch,
    const std::string& label,
    std::string& out_error
) {
    // Step 1: dry-run check before touching anything
    if (!verify_git_apply_check(workspace_dir, diff_patch, out_error)) {
        return CheckpointResult{false, "", label, "Dry-run failed: " + out_error};
    }

    // Step 2: snapshot current state
    CheckpointResult cp = CheckpointJournal::create_checkpoint(workspace_dir, label);
    if (!cp.ok) {
        out_error = "Checkpoint creation failed: " + cp.status_msg;
        return cp;
    }
    std::cout << "[SafetyGate] " << cp.status_msg << "\n";

    // Step 3: write patch to a temp file and apply it
    std::string temp_patch = "/tmp/lucille_apply_" + std::to_string(getpid()) + ".diff";
    {
        std::ofstream out(temp_patch);
        if (!out.is_open()) {
            out_error = "Failed to write patch to temp file";
            CheckpointJournal::rollback_to_checkpoint(workspace_dir, cp.checkpoint_id);
            cp.ok = false;
            return cp;
        }
        out << diff_patch;
    }

    int pipe_fd[2];
    pipe(pipe_fd);
    pid_t pid = fork();
    if (pid == 0) {
        close(pipe_fd[0]);
        dup2(pipe_fd[1], STDERR_FILENO);
        close(pipe_fd[1]);
        if (!workspace_dir.empty()) chdir(workspace_dir.c_str());
        execlp("git", "git", "apply", "--ignore-whitespace", temp_patch.c_str(), nullptr);
        _exit(127);
    }
    close(pipe_fd[1]);
    std::string stderr_out;
    char buf[1024]; ssize_t n = 0;
    while ((n = read(pipe_fd[0], buf, sizeof(buf) - 1)) > 0) { buf[n] = '\0'; stderr_out += buf; }
    close(pipe_fd[0]);
    int status = 0; waitpid(pid, &status, 0);
    fs::remove(temp_patch);

    // Step 4: if apply failed, roll back instantly
    if (!WIFEXITED(status) || WEXITSTATUS(status) != 0) {
        out_error = "git apply failed: " + (stderr_out.empty() ? "unknown error" : stderr_out);
        auto rb = CheckpointJournal::rollback_to_checkpoint(workspace_dir, cp.checkpoint_id);
        std::cout << "[SafetyGate] Patch failed — " << rb.status_msg << "\n";
        cp.ok = false;
        cp.status_msg = out_error;
        return cp;
    }

    std::cout << "[SafetyGate] Patch applied on checkpoint " << cp.checkpoint_id.substr(0, 8) << "\n";
    return cp;
}

bool SafetyGate::verify_git_apply_check(
    const std::string& workspace_dir,
    const std::string& diff_patch,
    std::string& out_error
) {
    if (diff_patch.empty()) {
        out_error = "Empty diff patch provided";
        return false;
    }

    // Create temporary patch file
    std::string temp_patch = "/tmp/lucille_patch_" + std::to_string(getpid()) + "_" + std::to_string(rand()) + ".diff";
    {
        std::ofstream out(temp_patch);
        if (!out.is_open()) {
            out_error = "Failed to create temporary patch file";
            return false;
        }
        out << diff_patch;
    }

    // Execute: git apply --check <temp_patch> in workspace_dir
    int pipe_fd[2];
    if (pipe(pipe_fd) < 0) {
        fs::remove(temp_patch);
        out_error = "Failed to create pipe for git apply";
        return false;
    }

    pid_t pid = fork();
    if (pid < 0) {
        close(pipe_fd[0]);
        close(pipe_fd[1]);
        fs::remove(temp_patch);
        out_error = "Failed to fork git apply process";
        return false;
    }

    if (pid == 0) {
        close(pipe_fd[0]);
        dup2(pipe_fd[1], STDERR_FILENO);
        close(pipe_fd[1]);

        // With a workspace: full dry-run against its files. Without one there
        // is nothing to apply against, so only parse the patch (--stat never
        // touches the working tree) — this rejects corrupt/malformed diffs.
        if (!workspace_dir.empty()) {
            if (chdir(workspace_dir.c_str()) != 0) _exit(126);
            execlp("git", "git", "apply", "--check", "--ignore-whitespace", temp_patch.c_str(), nullptr);
        } else {
            execlp("git", "git", "apply", "--stat", temp_patch.c_str(), nullptr);
        }
        _exit(127);
    }

    close(pipe_fd[1]);
    std::string stderr_output;
    char buffer[1024];
    ssize_t bytes = 0;
    while ((bytes = read(pipe_fd[0], buffer, sizeof(buffer) - 1)) > 0) {
        buffer[bytes] = '\0';
        stderr_output += buffer;
    }
    close(pipe_fd[0]);

    int status = 0;
    waitpid(pid, &status, 0);
    fs::remove(temp_patch);

    if (WIFEXITED(status) && WEXITSTATUS(status) == 0) {
        return true;
    }

    out_error = "git apply --check failed: " + (stderr_output.empty() ? "conflict or malformed patch" : stderr_output);
    return false;
}

bool SafetyGate::verify_ast_syntax(
    const std::string& language,
    const std::string& code,
    std::string& out_error
) {
    if (code.empty()) return true;

    // Structural bracket/parentheses and quotes verification
    std::stack<std::pair<char, size_t>> brackets;
    bool in_string = false;
    char str_char = '\0';
    bool in_line_comment = false;
    bool in_block_comment = false;

    for (size_t i = 0; i < code.size(); ++i) {
        char c = code[i];
        char next = (i + 1 < code.size()) ? code[i + 1] : '\0';

        if (in_line_comment) {
            if (c == '\n') in_line_comment = false;
            continue;
        }

        if (in_block_comment) {
            if (c == '*' && next == '/') {
                in_block_comment = false;
                ++i;
            }
            continue;
        }

        if (in_string) {
            if (c == '\\') {
                ++i; // Skip escaped character
            } else if (c == str_char) {
                in_string = false;
            }
            continue;
        }

        // Comment starters
        if (c == '/' && next == '/') {
            in_line_comment = true;
            ++i;
            continue;
        }
        if (c == '/' && next == '*') {
            in_block_comment = true;
            ++i;
            continue;
        }

        // String quotes
        if (c == '"' || c == '\'') {
            in_string = true;
            str_char = c;
            continue;
        }

        // Bracket matching
        if (c == '(' || c == '{' || c == '[') {
            brackets.push({c, i});
        } else if (c == ')' || c == '}' || c == ']') {
            if (brackets.empty()) {
                out_error = std::string("Unmatched closing bracket '") + c + "' at byte offset " + std::to_string(i);
                return false;
            }
            char open_b = brackets.top().first;
            if ((c == ')' && open_b != '(') ||
                (c == '}' && open_b != '{') ||
                (c == ']' && open_b != '[')) {
                out_error = std::string("Mismatched bracket '") + c + "' against '" + open_b + "'";
                return false;
            }
            brackets.pop();
        }
    }

    if (in_string) {
        out_error = "Unterminated string literal detected";
        return false;
    }
    if (in_block_comment) {
        out_error = "Unterminated block comment detected";
        return false;
    }
    if (!brackets.empty()) {
        out_error = std::string("Unclosed bracket '") + brackets.top().first + "' starting at offset " + std::to_string(brackets.top().second);
        return false;
    }

    return true;
}

void SafetyGate::register_tool_schema(const ToolSchemaDefinition& schema) {
    std::lock_guard<std::mutex> lock(schema_mutex_);
    tool_schemas_[schema.tool_name] = schema;
}

bool SafetyGate::validate_tool_call_json(
    const std::string& tool_name,
    const std::string& json_args,
    std::string& out_error
) {
    std::lock_guard<std::mutex> lock(schema_mutex_);
    auto it = tool_schemas_.find(tool_name);
    if (it == tool_schemas_.end()) {
        // Unknown tool: allow with warning or require registration
        return true;
    }

    const auto& schema = it->second;

    // Check balanced JSON braces
    if (!verify_ast_syntax("json", json_args, out_error)) {
        out_error = "Tool arguments are not valid JSON: " + out_error;
        return false;
    }

    // Verify required fields exist in JSON string
    for (const auto& req_field : schema.required_fields) {
        std::string pattern1 = "\"" + req_field + "\"";
        if (json_args.find(pattern1) == std::string::npos) {
            out_error = "Missing required schema field: '" + req_field + "' in tool '" + tool_name + "'";
            return false;
        }
    }

    return true;
}

void SafetyGate::record_request_latency(uint32_t latency_ms, bool is_error) {
    std::lock_guard<std::mutex> lock(latency_mutex_);

    latency_window_.push_back(latency_ms);
    if (latency_window_.size() > max_window_size_) {
        latency_window_.pop_front();
    }

    if (is_error || latency_ms > p95_threshold_ms_) {
        consecutive_failures_++;
    } else {
        if (consecutive_failures_ > 0) consecutive_failures_--;
    }

    update_circuit_state_locked();
}

uint32_t SafetyGate::get_rolling_p95_latency() const {
    std::lock_guard<std::mutex> lock(latency_mutex_);
    if (latency_window_.empty()) return 0;

    std::vector<uint32_t> sorted(latency_window_.begin(), latency_window_.end());
    std::sort(sorted.begin(), sorted.end());

    size_t p95_idx = static_cast<size_t>(std::ceil(0.95 * sorted.size())) - 1;
    return sorted[p95_idx];
}

void SafetyGate::update_circuit_state_locked() {
    uint32_t p95 = 0;
    if (!latency_window_.empty()) {
        std::vector<uint32_t> sorted(latency_window_.begin(), latency_window_.end());
        std::sort(sorted.begin(), sorted.end());
        size_t idx = static_cast<size_t>(std::ceil(0.95 * sorted.size())) - 1;
        p95 = sorted[idx];
    }

    auto now = std::chrono::steady_clock::now();

    if (circuit_state_ == CircuitBreakerState::Closed) {
        if (p95 > p95_threshold_ms_ || consecutive_failures_ >= 3) {
            circuit_state_ = CircuitBreakerState::Open;
            last_state_change_ = now;
            std::cout << "[SafetyGate] ⚠️ Circuit breaker TRIPPED (p95=" << p95
                      << "ms > threshold=" << p95_threshold_ms_
                      << "ms). Falling back to Local GGUF endpoint.\n";
        }
    } else if (circuit_state_ == CircuitBreakerState::Open) {
        // After 10 seconds, try half-open state
        if (std::chrono::duration_cast<std::chrono::seconds>(now - last_state_change_).count() >= 10) {
            circuit_state_ = CircuitBreakerState::HalfOpen;
            last_state_change_ = now;
            std::cout << "[SafetyGate] Circuit breaker entering HALF-OPEN testing state.\n";
        }
    } else if (circuit_state_ == CircuitBreakerState::HalfOpen) {
        if (consecutive_failures_ == 0 && p95 <= p95_threshold_ms_) {
            circuit_state_ = CircuitBreakerState::Closed;
            last_state_change_ = now;
            std::cout << "[SafetyGate] ✓ Circuit breaker CLOSED (cloud latency restored: p95=" << p95 << "ms).\n";
        }
    }
}

bool SafetyGate::should_fallback_to_local_gguf() {
    std::lock_guard<std::mutex> lock(latency_mutex_);
    update_circuit_state_locked();
    return (circuit_state_ == CircuitBreakerState::Open);
}

void SafetyGate::reset_circuit() {
    std::lock_guard<std::mutex> lock(latency_mutex_);
    latency_window_.clear();
    consecutive_failures_ = 0;
    circuit_state_ = CircuitBreakerState::Closed;
    last_state_change_ = std::chrono::steady_clock::now();
}

std::string SafetyGate::format_kv_cache_prefix(
    const std::string& soul_content,
    const std::string& soul_sha256,
    uint32_t logical_cores,
    uint64_t ram_mb,
    const std::string& gpu_model
) {
    std::stringstream ss;
    ss << "<|system|>\n"
       << "# Lucille AI Invariant Directives\n"
       << "[PROMPT_HASH_SHA256=" << soul_sha256 << "]\n"
       << "[HARDWARE_STATE: LogicalCores=" << logical_cores
       << ", RAM=" << ram_mb << "MB, GPU=" << gpu_model << "]\n"
       << soul_content << "\n"
       << "<|end_system|>\n";
    return ss.str();
}

} // namespace lucille
