#pragma once

#include <string>
#include <vector>
#include <cstdint>

namespace lucille {

struct CompilerDiagnostic {
    std::string file_path;
    uint32_t line{0};
    uint32_t column{0};
    std::string severity; // "error", "fatal error", "warning", "note"
    std::string message;
    std::string raw_line;
    std::string code_snippet;
    uint32_t context_start_line{0};
    uint32_t context_end_line{0};
};

struct KimiRepairPayload {
    std::string model_target{"Kimi-2.6-Coder"};
    std::vector<CompilerDiagnostic> diagnostics;
    std::string raw_compiler_output;
    std::string structured_repair_prompt;
    bool has_errors{false};
    uint32_t total_errors{0};
    uint32_t total_warnings{0};
};

class ErrorInterceptor {
public:
    ErrorInterceptor() = default;

    // Parse full compiler stream output (GCC, Clang)
    KimiRepairPayload parse_compiler_output(const std::string& compiler_output, uint32_t context_lines = 5);

    // Parse single diagnostic line
    bool parse_line(const std::string& line, CompilerDiagnostic& out_diag);

    // Extract surrounding source lines from disk
    static std::string extract_source_context(
        const std::string& file_path,
        uint32_t target_line,
        uint32_t target_col,
        uint32_t context_radius,
        uint32_t& out_start_line,
        uint32_t& out_end_line
    );

    // Format prompt payload for Kimi 2.6 Coder automated repair loop
    static std::string generate_kimi_repair_json(const KimiRepairPayload& payload);
};

} // namespace lucille
