#include "error_interceptor.hpp"
#include <regex>
#include <fstream>
#include <sstream>
#include <filesystem>
#include <iostream>
#include <algorithm>

namespace fs = std::filesystem;

namespace lucille {

// Match GCC/Clang diagnostic format: file:line:col: severity: message
// e.g., "src/main.cpp:42:15: error: no matching function for call to 'foo'"
// or "src/engine.hpp:12:5: fatal error: 'missing.h' file not found"
static const std::regex kDiagRegex(
    R"(^([^:\s]+):(\d+):(\d+):\s*(error|fatal error|warning|note):\s*(.+)$)",
    std::regex::ECMAScript | std::regex::optimize
);

// Fallback for file:line: severity: message (without col)
static const std::regex kDiagNoColRegex(
    R"(^([^:\s]+):(\d+):\s*(error|fatal error|warning|note):\s*(.+)$)",
    std::regex::ECMAScript | std::regex::optimize
);

bool ErrorInterceptor::parse_line(const std::string& line, CompilerDiagnostic& out_diag) {
    std::smatch match;
    if (std::regex_search(line, match, kDiagRegex)) {
        out_diag.file_path = match[1].str();
        out_diag.line = static_cast<uint32_t>(std::stoul(match[2].str()));
        out_diag.column = static_cast<uint32_t>(std::stoul(match[3].str()));
        out_diag.severity = match[4].str();
        out_diag.message = match[5].str();
        out_diag.raw_line = line;
        return true;
    } else if (std::regex_search(line, match, kDiagNoColRegex)) {
        out_diag.file_path = match[1].str();
        out_diag.line = static_cast<uint32_t>(std::stoul(match[2].str()));
        out_diag.column = 0;
        out_diag.severity = match[3].str();
        out_diag.message = match[4].str();
        out_diag.raw_line = line;
        return true;
    }
    return false;
}

std::string ErrorInterceptor::extract_source_context(
    const std::string& file_path,
    uint32_t target_line,
    uint32_t target_col,
    uint32_t context_radius,
    uint32_t& out_start_line,
    uint32_t& out_end_line
) {
    if (!fs::exists(file_path)) {
        out_start_line = 0;
        out_end_line = 0;
        return "[Source file not found on disk: " + file_path + "]";
    }

    std::ifstream file(file_path);
    if (!file.is_open()) {
        out_start_line = 0;
        out_end_line = 0;
        return "[Unable to open source file: " + file_path + "]";
    }

    std::vector<std::string> all_lines;
    std::string current_line;
    while (std::getline(file, current_line)) {
        all_lines.push_back(current_line);
    }

    if (all_lines.empty() || target_line == 0 || target_line > all_lines.size()) {
        out_start_line = 0;
        out_end_line = 0;
        return "[Target line out of range]";
    }

    uint32_t start_idx = (target_line > context_radius) ? (target_line - 1 - context_radius) : 0;
    uint32_t end_idx = std::min<uint32_t>(static_cast<uint32_t>(all_lines.size() - 1), target_line - 1 + context_radius);

    out_start_line = start_idx + 1;
    out_end_line = end_idx + 1;

    std::stringstream ss;
    for (uint32_t i = start_idx; i <= end_idx; ++i) {
        uint32_t lineno = i + 1;
        bool is_error_line = (lineno == target_line);
        ss << (is_error_line ? " >> " : "    ")
           << lineno << " | " << all_lines[i] << "\n";
        
        if (is_error_line && target_col > 0) {
            ss << "       | ";
            for (uint32_t c = 1; c < target_col; ++c) {
                ss << " ";
            }
            ss << "^\n";
        }
    }
    return ss.str();
}

KimiRepairPayload ErrorInterceptor::parse_compiler_output(const std::string& compiler_output, uint32_t context_lines) {
    KimiRepairPayload payload;
    payload.raw_compiler_output = compiler_output;

    std::istringstream stream(compiler_output);
    std::string line;

    while (std::getline(stream, line)) {
        CompilerDiagnostic diag;
        if (parse_line(line, diag)) {
            if (diag.severity == "error" || diag.severity == "fatal error") {
                payload.has_errors = true;
                payload.total_errors++;
            } else if (diag.severity == "warning") {
                payload.total_warnings++;
            }

            diag.code_snippet = extract_source_context(
                diag.file_path,
                diag.line,
                diag.column,
                context_lines,
                diag.context_start_line,
                diag.context_end_line
            );

            payload.diagnostics.push_back(diag);
        }
    }

    payload.structured_repair_prompt = generate_kimi_repair_json(payload);
    return payload;
}

static std::string escape_json(const std::string& s) {
    std::ostringstream o;
    for (char c : s) {
        switch (c) {
            case '"': o << "\\\""; break;
            case '\\': o << "\\\\"; break;
            case '\b': o << "\\b"; break;
            case '\f': o << "\\f"; break;
            case '\n': o << "\\n"; break;
            case '\r': o << "\\r"; break;
            case '\t': o << "\\t"; break;
            default:
                if ('\x00' <= c && c <= '\x1f') {
                    o << "\\u" << std::hex << std::setw(4) << std::setfill('0') << static_cast<int>(c);
                } else {
                    o << c;
                }
        }
    }
    return o.str();
}

std::string ErrorInterceptor::generate_kimi_repair_json(const KimiRepairPayload& payload) {
    std::stringstream ss;
    ss << "{\n";
    ss << "  \"target_model\": \"" << escape_json(payload.model_target) << "\",\n";
    ss << "  \"has_errors\": " << (payload.has_errors ? "true" : "false") << ",\n";
    ss << "  \"total_errors\": " << payload.total_errors << ",\n";
    ss << "  \"total_warnings\": " << payload.total_warnings << ",\n";
    ss << "  \"diagnostics\": [\n";

    for (size_t i = 0; i < payload.diagnostics.size(); ++i) {
        const auto& d = payload.diagnostics[i];
        ss << "    {\n";
        ss << "      \"file\": \"" << escape_json(d.file_path) << "\",\n";
        ss << "      \"line\": " << d.line << ",\n";
        ss << "      \"column\": " << d.column << ",\n";
        ss << "      \"severity\": \"" << escape_json(d.severity) << "\",\n";
        ss << "      \"message\": \"" << escape_json(d.message) << "\",\n";
        ss << "      \"context_range\": {\"start\": " << d.context_start_line << ", \"end\": " << d.context_end_line << "},\n";
        ss << "      \"code_context\": \"" << escape_json(d.code_snippet) << "\"\n";
        ss << "    }" << (i + 1 < payload.diagnostics.size() ? "," : "") << "\n";
    }
    ss << "  ],\n";
    ss << "  \"repair_instruction\": \"Please analyze the compiler diagnostics and provide the minimal targeted source fix to heal the build failure.\"\n";
    ss << "}\n";

    return ss.str();
}

} // namespace lucille
