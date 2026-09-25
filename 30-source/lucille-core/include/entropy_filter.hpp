#pragma once

#include <string>
#include <vector>
#include <cstddef>
#include <cmath>
#include <algorithm>
#include <type_traits>

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

    // Dynamic context pruning via score dropoff, applied after hybrid_search().
    // Sorts the prunable results' cosine distances, finds the largest jump
    // between neighbours, and cuts there when that jump is a real outlier:
    //     gap > mean_gap + std_dev_mult × std_dev_gap
    // Evenly spread results (no dropoff) are all kept. Surviving results keep
    // their original (e.g. RRF) order. Always keeps at least min_keep of the
    // closest prunable results. Results where is_prunable(r) is false (e.g.
    // keyword-only hits with no embedding distance) are never dropped.
    struct DistancePruneResult {
        size_t kept{0};
        size_t dropped{0};
        float  threshold{1.0f};   // largest cosine_distance still kept
        float  largest_gap{0.0f}; // biggest jump between sorted neighbours
        float  mean{0.0f};        // mean gap between sorted neighbours
        float  std_dev{0.0f};     // std-dev of those gaps
    };

    template<typename T, typename Prunable,
             typename = std::enable_if_t<std::is_invocable_r_v<bool, Prunable, const T&>>>
    static DistancePruneResult prune_by_distance_dropoff(
        std::vector<T>& results,
        Prunable is_prunable,
        float std_dev_mult = 1.5f,
        size_t min_keep    = 1
    );

    template<typename T>
    static DistancePruneResult prune_by_distance_dropoff(
        std::vector<T>& results,
        float std_dev_mult = 1.5f,
        size_t min_keep    = 1
    ) {
        return prune_by_distance_dropoff(
            results, [](const T&) { return true; }, std_dev_mult, min_keep);
    }

private:
    static std::string strip_ansi(const std::string& s, size_t& bytes_removed);
    static bool is_progress_line(const std::string& line);
    static bool is_path_only_line(const std::string& line);
};

// --- template implementation ---

template<typename T, typename Prunable, typename>
EntropyFilter::DistancePruneResult EntropyFilter::prune_by_distance_dropoff(
    std::vector<T>& results,
    Prunable is_prunable,
    float std_dev_mult,
    size_t min_keep
) {
    DistancePruneResult pr;
    pr.kept = results.size();

    std::vector<float> dists;
    for (const auto& r : results) {
        if (is_prunable(r)) dists.push_back(r.cosine_distance);
    }
    if (min_keep < 1) min_keep = 1;
    if (dists.size() <= min_keep) {
        if (!dists.empty()) pr.threshold = *std::max_element(dists.begin(), dists.end());
        return pr;
    }
    std::sort(dists.begin(), dists.end());

    // Gap statistics between sorted neighbours
    std::vector<float> gaps(dists.size() - 1);
    double sum = 0.0;
    for (size_t i = 0; i + 1 < dists.size(); ++i) {
        gaps[i] = dists[i + 1] - dists[i];
        sum += gaps[i];
    }
    pr.mean = static_cast<float>(sum / gaps.size());
    double var = 0.0;
    for (float g : gaps) var += (g - pr.mean) * (g - pr.mean);
    pr.std_dev = static_cast<float>(std::sqrt(var / gaps.size()));

    // Largest dropoff that still leaves at least min_keep results above it
    size_t cut = gaps.size(); // index of the gap to cut at; gaps.size() = no cut
    for (size_t i = min_keep - 1; i < gaps.size(); ++i) {
        if (gaps[i] > pr.largest_gap) {
            pr.largest_gap = gaps[i];
            cut = i;
        }
    }

    const bool significant = cut < gaps.size() &&
        pr.largest_gap > pr.mean + std_dev_mult * pr.std_dev;
    pr.threshold = significant ? dists[cut] : dists.back();
    if (!significant) return pr;

    // Drop prunable results beyond the dropoff, preserving original order
    const float threshold = pr.threshold;
    auto new_end = std::remove_if(results.begin(), results.end(),
        [&](const T& r) { return is_prunable(r) && r.cosine_distance > threshold; });
    pr.dropped = static_cast<size_t>(results.end() - new_end);
    results.erase(new_end, results.end());
    pr.kept = results.size();
    return pr;
}

} // namespace lucille
