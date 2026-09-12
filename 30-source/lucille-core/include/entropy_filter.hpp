#pragma once

#include <string>
#include <vector>
#include <cstddef>
#include <cmath>
#include <algorithm>

namespace lucille {

// Cleans raw terminal / compiler output before it is embedded and stored in
// sqlite-vec. Removes noise patterns that carry no semantic signal:
//   - ANSI escape codes
//   - CMake / compiler build-progress lines  ([ 45%] Building...)
//   - Repeated identical lines (keeps first 2 occurrences, drops the rest)
//   - Lines that are purely file-path noise (no words, just slashes/dots)
//   - Trailing whitespace and blank-line runs (collapses to single blank)
//
// Also provides the dynamic context-pruning threshold used after hybrid_search().
class EntropyFilter {
public:
    struct CleanResult {
        std::string text;        // cleaned text ready for embedding
        size_t  lines_in{0};
        size_t  lines_out{0};
        size_t  dupes_removed{0};
        size_t  progress_removed{0};
        size_t  ansi_bytes_removed{0};
    };

    // Strip all noise from a raw terminal capture / compiler log.
    // max_chars: hard cap on output size (0 = no cap).
    static CleanResult clean(const std::string& raw, size_t max_chars = 8192);

    // After hybrid_search() returns results with cosine_distance populated,
    // discard any result where  cosine_distance > mean − std_dev_mult × std_dev.
    // Always keeps at least min_keep results (the lowest-distance ones).
    struct DistancePruneResult {
        size_t kept{0};
        size_t dropped{0};
        float  threshold{1.0f};
        float  mean{0.0f};
        float  std_dev{0.0f};
    };

    template<typename T>
    static DistancePruneResult prune_by_distance_dropoff(
        std::vector<T>& results,
        float std_dev_mult = 1.5f,
        size_t min_keep    = 1
    );

private:
    static std::string strip_ansi(const std::string& s, size_t& bytes_removed);
    static bool is_progress_line(const std::string& line);
    static bool is_path_only_line(const std::string& line);
};

// --- template implementation ---

template<typename T>
EntropyFilter::DistancePruneResult EntropyFilter::prune_by_distance_dropoff(
    std::vector<T>& results,
    float std_dev_mult,
    size_t min_keep
) {
    DistancePruneResult pr;
    if (results.size() <= min_keep) {
        pr.kept = results.size();
        return pr;
    }

    // Compute mean cosine distance across the result set
    double sum = 0.0;
    for (const auto& r : results) sum += r.cosine_distance;
    pr.mean = static_cast<float>(sum / results.size());

    // Compute standard deviation
    double var = 0.0;
    for (const auto& r : results) {
        double d = r.cosine_distance - pr.mean;
        var += d * d;
    }
    pr.std_dev = static_cast<float>(std::sqrt(var / results.size()));

    // Threshold: keep only results tighter than mean − std_dev_mult * std_dev
    // (i.e. the high-similarity cluster; outlier-far results are dropped)
    pr.threshold = pr.mean - std_dev_mult * pr.std_dev;

    // Sort ascending by cosine_distance so we keep the best min_keep
    std::sort(results.begin(), results.end(), [](const T& a, const T& b) {
        return a.cosine_distance < b.cosine_distance;
    });

    size_t keep_count = 0;
    for (size_t i = 0; i < results.size(); ++i) {
        if (i < min_keep || results[i].cosine_distance <= pr.threshold) {
            ++keep_count;
        } else {
            break; // sorted, so everything after this is also above threshold
        }
    }

    pr.dropped = results.size() - keep_count;
    results.resize(keep_count);
    pr.kept = keep_count;
    return pr;
}

} // namespace lucille
