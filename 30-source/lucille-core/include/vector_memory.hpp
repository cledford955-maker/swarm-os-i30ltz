#pragma once

#include <string>
#include <vector>
#include <memory>
#include <mutex>
#include <cstdint>
#include <sqlite3.h>
#include "simd_quant.hpp"
#include "entropy_filter.hpp"

namespace lucille {

struct ConversationTurn {
    int64_t turn_id{-1};
    std::string session_id;
    std::string role; // "user", "assistant", "system", "tool"
    std::string content;
    int64_t timestamp{0};
    int32_t tokens{0};
};

struct MemoryChunk {
    int64_t chunk_id{-1};
    int64_t turn_id{-1};
    std::string session_id;
    std::string chunk_text;
    std::vector<float> embedding; // 384-dim
    bool is_ephemeral{false};
    float importance_score{1.0f};
    float decay_factor{0.05f};
    int64_t created_at{0};
    int64_t last_accessed{0};
    int32_t access_count{0};
    std::vector<std::pair<std::string, std::string>> tags; // key-value metadata
};

struct HybridSearchResult {
    int64_t chunk_id{-1};
    int64_t turn_id{-1};
    std::string session_id;
    std::string chunk_text;
    float rrf_score{0.0f};
    float cosine_distance{1.0f};
    int64_t dense_rank{-1};
    int64_t sparse_rank{-1};
    float importance_score{1.0f};
    bool is_ephemeral{false};
};

class VectorMemoryEngine {
public:
    explicit VectorMemoryEngine(std::string db_path = "");
    ~VectorMemoryEngine();

    // Disable copy
    VectorMemoryEngine(const VectorMemoryEngine&) = delete;
    VectorMemoryEngine& operator=(const VectorMemoryEngine&) = delete;

    // Initialize database, tables, triggers, and SIMD SQL functions
    bool initialize(std::string& err_msg);
    void close();

    // Conversation Turn logging
    int64_t log_turn(const ConversationTurn& turn);

    // Insert semantic chunk with embedding and quantization
    int64_t insert_chunk(const MemoryChunk& chunk);

    // Hybrid Search: Dense KNN + Sparse BM25 + Reciprocal Rank Fusion.
    // If prune_by_distance is true, applies dynamic score-dropoff after retrieval:
    // drops results where cosine_distance > mean − std_dev_mult × std_dev.
    std::vector<HybridSearchResult> hybrid_search(
        const std::string& query_text,
        const std::vector<float>& query_embedding,
        size_t limit = 5,
        float rrf_k = 60.0f,
        bool prune_by_distance = true,
        float std_dev_mult = 1.5f
    );

    // Insert a chunk after running semantic entropy filtering on chunk_text.
    // Returns chunk_id, or -1 on failure. Sets filter_result for diagnostics.
    int64_t insert_chunk_filtered(
        const MemoryChunk& chunk,
        EntropyFilter::CleanResult* filter_result = nullptr
    );

    // Automated WAL maintenance & ephemeral pruning
    bool run_wal_checkpoint_truncate();
    size_t prune_ephemeral_chunks(float decay_threshold = 0.2f);

    const std::string& get_db_path() const { return db_path_; }
    size_t get_insertion_count() const { return insertion_count_; }

    static std::string resolve_default_db_path();

private:
    std::string db_path_;
    sqlite3* db_{nullptr};
    std::mutex db_mutex_;
    size_t insertion_count_{0};
    bool is_vec0_extension_loaded_{false};

    bool create_schema();
    bool register_simd_sql_functions();
    void check_wal_maintenance();
};

} // namespace lucille
