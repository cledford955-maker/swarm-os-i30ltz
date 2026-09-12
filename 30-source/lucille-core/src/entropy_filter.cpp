#include "entropy_filter.hpp"

#include <sstream>
#include <unordered_map>
#include <cctype>
#include <cmath>
#include <algorithm>

namespace lucille {

// Strip ANSI/VT100 escape sequences: ESC [ ... m  and similar
std::string EntropyFilter::strip_ansi(const std::string& s, size_t& bytes_removed) {
    std::string out;
    out.reserve(s.size());
    bytes_removed = 0;
    size_t i = 0;
    while (i < s.size()) {
        if (s[i] == '\x1b' && i + 1 < s.size() && s[i + 1] == '[') {
            size_t start = i;
            i += 2;
            // Skip parameter bytes (0x30–0x3F) then intermediate (0x20–0x2F) then final (0x40–0x7E)
            while (i < s.size() && s[i] >= 0x30 && s[i] <= 0x3F) ++i;
            while (i < s.size() && s[i] >= 0x20 && s[i] <= 0x2F) ++i;
            if (i < s.size() && s[i] >= 0x40 && s[i] <= 0x7E) ++i;
            bytes_removed += i - start;
        } else if (s[i] == '\r') {
            // Bare CR (overwrite progress bars): skip to end of line or next LF
            while (i < s.size() && s[i] != '\n') ++i;
        } else {
            out += s[i++];
        }
    }
    return out;
}

// Returns true for lines like:  "[ 45%] Building CXX object ..."
//                               "[100%] Linking CXX executable"
//                               "-- Configuring done"
//                               "-- Build files have been written"
bool EntropyFilter::is_progress_line(const std::string& line) {
    if (line.empty()) return false;

    // CMake build progress: "[ NN%]" or "[NNN%]"
    if (line.size() >= 6 && line[0] == '[') {
        size_t close = line.find(']');
        if (close != std::string::npos && close <= 5) {
            // Check that interior is digits and %
            bool ok = true;
            for (size_t i = 1; i < close; ++i) {
                if (!std::isdigit(static_cast<unsigned char>(line[i])) && line[i] != '%' && line[i] != ' ') {
                    ok = false; break;
                }
            }
            if (ok) return true;
        }
    }

    // CMake status lines
    const char* cmake_prefixes[] = {
        "-- ", "-- Configuring", "-- Generating", "-- Build files",
        "Scanning dependencies", "make[", "Making ", nullptr
    };
    for (int k = 0; cmake_prefixes[k]; ++k) {
        if (line.rfind(cmake_prefixes[k], 0) == 0) return true;
    }

    // Unicode progress bars / spinners (UTF-8 multi-byte art)
    // Detect lines that are >60% non-ASCII printable (progress bar art)
    size_t non_ascii = 0;
    for (unsigned char c : line) {
        if (c > 127) ++non_ascii;
    }
    if (!line.empty() && non_ascii > line.size() * 60 / 100) return true;

    return false;
}

// True for lines that consist only of filesystem path characters with no words
bool EntropyFilter::is_path_only_line(const std::string& line) {
    if (line.size() < 4 || line.find('/') == std::string::npos) return false;
    size_t alpha = 0;
    for (char c : line) {
        if (std::isalpha(static_cast<unsigned char>(c))) ++alpha;
    }
    // If the line has letters but most chars are path separators/dots, skip it
    size_t path_chars = 0;
    for (char c : line) {
        if (c == '/' || c == '.' || c == '_' || c == '-' || std::isdigit((unsigned char)c)) ++path_chars;
    }
    return (!line.empty() && path_chars > line.size() * 75 / 100 && alpha < 6);
}

EntropyFilter::CleanResult EntropyFilter::clean(const std::string& raw, size_t max_chars) {
    CleanResult result;
    if (raw.empty()) return result;

    // 1. Strip ANSI escape codes and bare CR (progress bar rewrites)
    size_t ansi_removed = 0;
    std::string stripped = strip_ansi(raw, ansi_removed);
    result.ansi_bytes_removed = ansi_removed;

    // 2. Split into lines
    std::vector<std::string> lines;
    {
        std::istringstream ss(stripped);
        std::string line;
        while (std::getline(ss, line)) {
            // Strip trailing whitespace
            while (!line.empty() && (line.back() == ' ' || line.back() == '\t' || line.back() == '\r'))
                line.pop_back();
            lines.push_back(std::move(line));
        }
    }
    result.lines_in = lines.size();

    // 3. Filter: progress lines, path-only lines, deduplicate repeated lines
    std::unordered_map<std::string, size_t> seen; // line → occurrence count
    std::vector<std::string> kept;
    kept.reserve(lines.size());
    size_t consecutive_blank = 0;

    for (auto& line : lines) {
        if (is_progress_line(line)) {
            ++result.progress_removed;
            continue;
        }
        if (is_path_only_line(line)) {
            ++result.progress_removed; // counted together
            continue;
        }

        // Collapse runs of blank lines to at most one
        if (line.empty()) {
            ++consecutive_blank;
            if (consecutive_blank > 1) continue;
        } else {
            consecutive_blank = 0;
        }

        // Deduplicate: allow each unique line at most twice
        size_t& count = seen[line];
        ++count;
        if (count > 2) {
            ++result.dupes_removed;
            continue;
        }

        kept.push_back(std::move(line));
    }

    // 4. Reassemble
    std::string out;
    out.reserve(std::min(stripped.size(), max_chars > 0 ? max_chars : stripped.size()));
    for (size_t i = 0; i < kept.size(); ++i) {
        if (max_chars > 0 && out.size() + kept[i].size() + 1 > max_chars) break;
        out += kept[i];
        out += '\n';
    }

    // Trim trailing blank lines
    while (out.size() >= 2 && out[out.size()-1] == '\n' && out[out.size()-2] == '\n')
        out.pop_back();

    result.lines_out = kept.size();
    result.text = std::move(out);
    return result;
}

} // namespace lucille
