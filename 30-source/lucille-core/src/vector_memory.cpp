#include "vector_memory.hpp"
#include "entropy_filter.hpp"
#include <iostream>
#include <sstream>
#include <chrono>
#include <cmath>
#include <numeric>
#include <filesystem>
#include <cstdlib>
#include <cstring>

namespace fs = std::filesystem;

namespace lucille {

// --- SQLite Custom SIMD Vector Functions ---

static void sqlite_vec_cosine_distance(sqlite3_context* ctx, int argc, sqlite3_value** argv) {
    if (argc < 2 || sqlite3_value_type(argv[0]) == SQLITE_NULL || sqlite3_value_type(argv[1]) == SQLITE_NULL) {
        sqlite3_result_null(ctx);
        return;
    }

    const float* a = reinterpret_cast<const float*>(sqlite3_value_blob(argv[0]));
    int bytes_a = sqlite3_value_bytes(argv[0]);

    const float* b = reinterpret_cast<const float*>(sqlite3_value_blob(argv[1]));
    int bytes_b = sqlite3_value_bytes(argv[1]);

    if (!a || !b || bytes_a != bytes_b || bytes_a == 0) {
        sqlite3_result_null(ctx);
        return;
    }

    size_t dim = bytes_a / sizeof(float);
    float dist = SimdQuant::cosine_distance_f32(a, b, dim);
    sqlite3_result_double(ctx, static_cast<double>(dist));
}

static void sqlite_vec_dot_product(sqlite3_context* ctx, int argc, sqlite3_value** argv) {
    if (argc < 2 || sqlite3_value_type(argv[0]) == SQLITE_NULL || sqlite3_value_type(argv[1]) == SQLITE_NULL) {
        sqlite3_result_null(ctx);
        return;
    }

    const float* a = reinterpret_cast<const float*>(sqlite3_value_blob(argv[0]));
    int bytes_a = sqlite3_value_bytes(argv[0]);

    const float* b = reinterpret_cast<const float*>(sqlite3_value_blob(argv[1]));
    int bytes_b = sqlite3_value_bytes(argv[1]);

    if (!a || !b || bytes_a != bytes_b || bytes_a == 0) {
        sqlite3_result_null(ctx);
        return;
    }

    size_t dim = bytes_a / sizeof(float);
    float dot = SimdQuant::dot_product_f32(a, b, dim);
    sqlite3_result_double(ctx, static_cast<double>(dot));
}

static void sqlite_vec_hamming_distance(sqlite3_context* ctx, int argc, sqlite3_value** argv) {
    if (argc < 2 || sqlite3_value_type(argv[0]) == SQLITE_NULL || sqlite3_value_type(argv[1]) == SQLITE_NULL) {
        sqlite3_result_null(ctx);
        return;
    }

    const uint64_t* a = reinterpret_cast<const uint64_t*>(sqlite3_value_blob(argv[0]));
    int bytes_a = sqlite3_value_bytes(argv[0]);

    const uint64_t* b = reinterpret_cast<const uint64_t*>(sqlite3_value_blob(argv[1]));
    int bytes_b = sqlite3_value_bytes(argv[1]);

    if (!a || !b || bytes_a != bytes_b || bytes_a == 0) {
        sqlite3_result_null(ctx);
        return;
    }

    size_t words = bytes_a / sizeof(uint64_t);
    uint32_t dist = 0;
    for (size_t i = 0; i < words; ++i) {
        dist += static_cast<uint32_t>(__builtin_popcountll(a[i] ^ b[i]));
    }
    sqlite3_result_int64(ctx, static_cast<sqlite3_int64>(dist));
}

std::string VectorMemoryEngine::resolve_default_db_path() {
    const char* xdg_data = std::getenv("XDG_DATA_HOME");
    if (xdg_data && xdg_data[0] != '\0') {
        return std::string(xdg_data) + "/lucille/memory.db";
    }

    const char* home = std::getenv("HOME");
    if (home && home[0] != '\0') {
        return std::string(home) + "/.local/share/lucille/memory.db";
    }

    return "/tmp/lucille_memory.db";
}

VectorMemoryEngine::VectorMemoryEngine(std::string db_path)
    : db_path_(std::move(db_path)) {
    if (db_path_.empty()) {
        db_path_ = resolve_default_db_path();
    }
}

VectorMemoryEngine::~VectorMemoryEngine() {
    close();
}

void VectorMemoryEngine::close() {
    std::lock_guard<std::mutex> lock(db_mutex_);
    if (db_) {
        sqlite3_close(db_);
        db_ = nullptr;
    }
}

bool VectorMemoryEngine::initialize(std::string& err_msg) {
    std::lock_guard<std::mutex> lock(db_mutex_);

    // Ensure parent directories exist
    fs::path p(db_path_);
    if (p.has_parent_path()) {
        std::error_code ec;
        fs::create_directories(p.parent_path(), ec);
    }

    int rc = sqlite3_open_v2(
        db_path_.c_str(),
        &db_,
        SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX,
        nullptr
    );

    if (rc != SQLITE_OK) {
        err_msg = "Failed to open SQLite database at " + db_path_ + ": " + sqlite3_errmsg(db_);
        if (db_) {
            sqlite3_close(db_);
            db_ = nullptr;
        }
        return false;
    }

    // Enable WAL mode & performance PRAGMAs
    const char* pragma_sql =
        "PRAGMA journal_mode = WAL;\n"
        "PRAGMA synchronous = NORMAL;\n"
        "PRAGMA foreign_keys = ON;\n"
        "PRAGMA temp_store = MEMORY;\n"
        "PRAGMA mmap_size = 268435456;\n"; // 256MB memory mapped I/O

    char* errmsg_raw = nullptr;
    rc = sqlite3_exec(db_, pragma_sql, nullptr, nullptr, &errmsg_raw);
    if (rc != SQLITE_OK) {
        err_msg = "Failed to configure WAL mode PRAGMAs: " + std::string(errmsg_raw ? errmsg_raw : "");
        if (errmsg_raw) sqlite3_free(errmsg_raw);
        return false;
    }

    // Register custom high-speed SIMD SQL functions
    if (!register_simd_sql_functions()) {
        err_msg = "Failed to register custom SIMD SQL functions";
        return false;
    }

    // Create schema and virtual tables
    if (!create_schema()) {
        err_msg = "Failed to create database schema and virtual tables: " + std::string(sqlite3_errmsg(db_));
        return false;
    }

    return true;
}

bool VectorMemoryEngine::register_simd_sql_functions() {
    if (!db_) return false;

    sqlite3_create_function_v2(
        db_, "vec_cosine_distance", 2, SQLITE_UTF8 | SQLITE_DETERMINISTIC,
        nullptr, sqlite_vec_cosine_distance, nullptr, nullptr, nullptr
    );

    sqlite3_create_function_v2(
        db_, "vec_dot_product", 2, SQLITE_UTF8 | SQLITE_DETERMINISTIC,
        nullptr, sqlite_vec_dot_product, nullptr, nullptr, nullptr
    );

    sqlite3_create_function_v2(
        db_, "vec_hamming_distance", 2, SQLITE_UTF8 | SQLITE_DETERMINISTIC,
        nullptr, sqlite_vec_hamming_distance, nullptr, nullptr, nullptr
    );

    return true;
}

bool VectorMemoryEngine::create_schema() {
    if (!db_) return false;

    // 1. Relational tables: episodes, conversation_turns, memory_chunks, metadata_tags
    const char* schema_sql = R"(
        CREATE TABLE IF NOT EXISTS episodes (
            session_id TEXT PRIMARY KEY,
            title TEXT,
            metadata_json TEXT,
            created_at INTEGER NOT NULL
        );

        CREATE TABLE IF NOT EXISTS conversation_turns (
            turn_id INTEGER PRIMARY KEY AUTOINCREMENT,
            session_id TEXT NOT NULL,
            role TEXT NOT NULL,
            content TEXT NOT NULL,
            timestamp INTEGER NOT NULL,
            tokens INTEGER DEFAULT 0,
            FOREIGN KEY (session_id) REFERENCES episodes(session_id) ON DELETE CASCADE
        );

        CREATE TABLE IF NOT EXISTS memory_chunks (
            chunk_id INTEGER PRIMARY KEY AUTOINCREMENT,
            turn_id INTEGER,
            session_id TEXT,
            chunk_text TEXT NOT NULL,
            embedding_blob BLOB,
            quant_int8_blob BLOB,
            quant_int8_scale REAL DEFAULT 1.0,
            quant_binary_blob BLOB,
            is_ephemeral INTEGER DEFAULT 0,
            importance_score REAL DEFAULT 1.0,
            decay_factor REAL DEFAULT 0.05,
            access_count INTEGER DEFAULT 0,
            created_at INTEGER NOT NULL,
            last_accessed INTEGER NOT NULL,
            FOREIGN KEY (turn_id) REFERENCES conversation_turns(turn_id) ON DELETE CASCADE
        );

        CREATE TABLE IF NOT EXISTS metadata_tags (
            tag_id INTEGER PRIMARY KEY AUTOINCREMENT,
            chunk_id INTEGER NOT NULL,
            tag_name TEXT NOT NULL,
            tag_value TEXT NOT NULL,
            FOREIGN KEY (chunk_id) REFERENCES memory_chunks(chunk_id) ON DELETE CASCADE
        );

        CREATE INDEX IF NOT EXISTS idx_chunks_turn_id ON memory_chunks(turn_id);
        CREATE INDEX IF NOT EXISTS idx_chunks_session ON memory_chunks(session_id);
        CREATE INDEX IF NOT EXISTS idx_chunks_created ON memory_chunks(created_at);
        CREATE INDEX IF NOT EXISTS idx_chunks_ephemeral ON memory_chunks(is_ephemeral, created_at);
        CREATE INDEX IF NOT EXISTS idx_tags_chunk_id ON metadata_tags(chunk_id);
        CREATE INDEX IF NOT EXISTS idx_tags_name_value ON metadata_tags(tag_name, tag_value);

        -- FTS5 Virtual Table for Sparse BM25 Keyword Search
        CREATE VIRTUAL TABLE IF NOT EXISTS fts_chunks USING fts5(
            chunk_text,
            content='memory_chunks',
            content_rowid='chunk_id',
            tokenize='unicode61 remove_diacritics 2'
        );

        -- Triggers to synchronize FTS5 index automatically with memory_chunks
        CREATE TRIGGER IF NOT EXISTS trg_chunks_ai AFTER INSERT ON memory_chunks BEGIN
            INSERT INTO fts_chunks(rowid, chunk_text) VALUES (new.chunk_id, new.chunk_text);
        END;

        CREATE TRIGGER IF NOT EXISTS trg_chunks_ad AFTER DELETE ON memory_chunks BEGIN
            INSERT INTO fts_chunks(fts_chunks, rowid, chunk_text) VALUES('delete', old.chunk_id, old.chunk_text);
        END;

        CREATE TRIGGER IF NOT EXISTS trg_chunks_au AFTER UPDATE ON memory_chunks BEGIN
            INSERT INTO fts_chunks(fts_chunks, rowid, chunk_text) VALUES('delete', old.chunk_id, old.chunk_text);
            INSERT INTO fts_chunks(rowid, chunk_text) VALUES (new.chunk_id, new.chunk_text);
        END;
    )";

    char* err_msg = nullptr;
    int rc = sqlite3_exec(db_, schema_sql, nullptr, nullptr, &err_msg);
    if (rc != SQLITE_OK) {
        if (err_msg) sqlite3_free(err_msg);
        return false;
    }

    // Try loading sqlite-vec extension if available (optional extension loader)
    sqlite3_enable_load_extension(db_, 1);
    const char* vec_ext_names[] = {"sqlite_vec", "vec0", "libsqlite_vec", "libvec0"};
    for (const char* ext : vec_ext_names) {
        char* ext_err = nullptr;
        if (sqlite3_load_extension(db_, ext, nullptr, &ext_err) == SQLITE_OK) {
            is_vec0_extension_loaded_ = true;
            break;
        }
        if (ext_err) sqlite3_free(ext_err);
    }
    sqlite3_enable_load_extension(db_, 0);

    if (is_vec0_extension_loaded_) {
        const char* vec0_sql = R"(
            CREATE VIRTUAL TABLE IF NOT EXISTS vec_chunks USING vec0(
                chunk_id INTEGER PRIMARY KEY,
                embedding float[384] distance_metric=cosine
            );
        )";
        sqlite3_exec(db_, vec0_sql, nullptr, nullptr, nullptr);
    }

    return true;
}

int64_t VectorMemoryEngine::log_turn(const ConversationTurn& turn) {
    std::lock_guard<std::mutex> lock(db_mutex_);
    if (!db_) return -1;

    // Ensure session episode exists
    const char* ep_sql = "INSERT OR IGNORE INTO episodes (session_id, title, metadata_json, created_at) VALUES (?1, ?2, '{}', ?3);";
    sqlite3_stmt* ep_stmt = nullptr;
    if (sqlite3_prepare_v2(db_, ep_sql, -1, &ep_stmt, nullptr) == SQLITE_OK) {
        sqlite3_bind_text(ep_stmt, 1, turn.session_id.c_str(), -1, SQLITE_TRANSIENT);
        sqlite3_bind_text(ep_stmt, 2, ("Session " + turn.session_id).c_str(), -1, SQLITE_TRANSIENT);
        sqlite3_bind_int64(ep_stmt, 3, turn.timestamp);
        sqlite3_step(ep_stmt);
        sqlite3_finalize(ep_stmt);
    }

    const char* sql = "INSERT INTO conversation_turns (session_id, role, content, timestamp, tokens) VALUES (?1, ?2, ?3, ?4, ?5);";
    sqlite3_stmt* stmt = nullptr;
    if (sqlite3_prepare_v2(db_, sql, -1, &stmt, nullptr) != SQLITE_OK) {
        return -1;
    }

    sqlite3_bind_text(stmt, 1, turn.session_id.c_str(), -1, SQLITE_TRANSIENT);
    sqlite3_bind_text(stmt, 2, turn.role.c_str(), -1, SQLITE_TRANSIENT);
    sqlite3_bind_text(stmt, 3, turn.content.c_str(), -1, SQLITE_TRANSIENT);
    sqlite3_bind_int64(stmt, 4, turn.timestamp);
    sqlite3_bind_int(stmt, 5, turn.tokens);

    int rc = sqlite3_step(stmt);
    sqlite3_finalize(stmt);

    if (rc == SQLITE_DONE) {
        return sqlite3_last_insert_rowid(db_);
    }
    return -1;
}

int64_t VectorMemoryEngine::insert_chunk(const MemoryChunk& chunk) {
    std::lock_guard<std::mutex> lock(db_mutex_);
    if (!db_) return -1;

    // Prepare normalized embedding copy and quantizations
    std::vector<float> norm_emb = chunk.embedding;
    if (!norm_emb.empty()) {
        SimdQuant::l2_normalize_f32(norm_emb.data(), norm_emb.size());
    }

    SimdQuant::Int8QuantizedVector int8_q;
    SimdQuant::BinaryQuantizedVector bin_q;

    if (!norm_emb.empty()) {
        int8_q = SimdQuant::quantize_int8(norm_emb.data(), norm_emb.size());
        bin_q = SimdQuant::quantize_binary(norm_emb.data(), norm_emb.size());
    }

    int64_t now = chunk.created_at;
    if (now == 0) {
        now = std::chrono::duration_cast<std::chrono::seconds>(
            std::chrono::system_clock::now().time_since_epoch()
        ).count();
    }

    const char* sql = R"(
        INSERT INTO memory_chunks (
            turn_id, session_id, chunk_text, embedding_blob,
            quant_int8_blob, quant_int8_scale, quant_binary_blob,
            is_ephemeral, importance_score, decay_factor,
            access_count, created_at, last_accessed
        ) VALUES (
            ?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, 0, ?11, ?12
        );
    )";

    sqlite3_stmt* stmt = nullptr;
    if (sqlite3_prepare_v2(db_, sql, -1, &stmt, nullptr) != SQLITE_OK) {
        return -1;
    }

    if (chunk.turn_id > 0) sqlite3_bind_int64(stmt, 1, chunk.turn_id);
    else sqlite3_bind_null(stmt, 1);

    sqlite3_bind_text(stmt, 2, chunk.session_id.c_str(), -1, SQLITE_TRANSIENT);
    sqlite3_bind_text(stmt, 3, chunk.chunk_text.c_str(), -1, SQLITE_TRANSIENT);

    // Float32 Embedding Blob
    if (!norm_emb.empty()) {
        sqlite3_bind_blob(stmt, 4, norm_emb.data(), static_cast<int>(norm_emb.size() * sizeof(float)), SQLITE_TRANSIENT);
    } else {
        sqlite3_bind_null(stmt, 4);
    }

    // Int8 Quantized Blob
    if (!int8_q.data.empty()) {
        sqlite3_bind_blob(stmt, 5, int8_q.data.data(), static_cast<int>(int8_q.data.size()), SQLITE_TRANSIENT);
        sqlite3_bind_double(stmt, 6, int8_q.scale);
    } else {
        sqlite3_bind_null(stmt, 5);
        sqlite3_bind_double(stmt, 6, 1.0);
    }

    // Binary Quantized Blob
    if (!bin_q.words.empty()) {
        sqlite3_bind_blob(stmt, 7, bin_q.words.data(), static_cast<int>(bin_q.words.size() * sizeof(uint64_t)), SQLITE_TRANSIENT);
    } else {
        sqlite3_bind_null(stmt, 7);
    }

    sqlite3_bind_int(stmt, 8, chunk.is_ephemeral ? 1 : 0);
    sqlite3_bind_double(stmt, 9, chunk.importance_score);
    sqlite3_bind_double(stmt, 10, chunk.decay_factor);
    sqlite3_bind_int64(stmt, 11, now);
    sqlite3_bind_int64(stmt, 12, now);

    int rc = sqlite3_step(stmt);
    sqlite3_finalize(stmt);

    if (rc != SQLITE_DONE) {
        return -1;
    }

    int64_t chunk_id = sqlite3_last_insert_rowid(db_);

    // Insert metadata tags
    if (!chunk.tags.empty()) {
        const char* tag_sql = "INSERT INTO metadata_tags (chunk_id, tag_name, tag_value) VALUES (?1, ?2, ?3);";
        sqlite3_stmt* tstmt = nullptr;
        if (sqlite3_prepare_v2(db_, tag_sql, -1, &tstmt, nullptr) == SQLITE_OK) {
            for (const auto& [name, val] : chunk.tags) {
                sqlite3_reset(tstmt);
                sqlite3_bind_int64(tstmt, 1, chunk_id);
                sqlite3_bind_text(tstmt, 2, name.c_str(), -1, SQLITE_TRANSIENT);
                sqlite3_bind_text(tstmt, 3, val.c_str(), -1, SQLITE_TRANSIENT);
                sqlite3_step(tstmt);
            }
            sqlite3_finalize(tstmt);
        }
    }

    // If vec0 virtual table is active, sync embedding
    if (is_vec0_extension_loaded_ && !norm_emb.empty()) {
        const char* v0_sql = "INSERT INTO vec_chunks (chunk_id, embedding) VALUES (?1, ?2);";
        sqlite3_stmt* vstmt = nullptr;
        if (sqlite3_prepare_v2(db_, v0_sql, -1, &vstmt, nullptr) == SQLITE_OK) {
            sqlite3_bind_int64(vstmt, 1, chunk_id);
            sqlite3_bind_blob(vstmt, 2, norm_emb.data(), static_cast<int>(norm_emb.size() * sizeof(float)), SQLITE_TRANSIENT);
            sqlite3_step(vstmt);
            sqlite3_finalize(vstmt);
        }
    }

    insertion_count_++;
    check_wal_maintenance();

    return chunk_id;
}

int64_t VectorMemoryEngine::insert_chunk_filtered(
    const MemoryChunk& chunk,
    EntropyFilter::CleanResult* filter_result
) {
    EntropyFilter::CleanResult cr = EntropyFilter::clean(chunk.chunk_text);
    if (filter_result) *filter_result = cr;

    if (cr.text.empty()) return -1; // nothing left after filtering

    MemoryChunk filtered = chunk;
    filtered.chunk_text = std::move(cr.text);

    if (cr.dupes_removed > 0 || cr.progress_removed > 0 || cr.ansi_bytes_removed > 0) {
        std::cout << "[VectorMemory] Entropy filter: "
                  << cr.lines_in << "→" << cr.lines_out << " lines, "
                  << cr.dupes_removed << " dupes, "
                  << cr.progress_removed << " noise lines, "
                  << cr.ansi_bytes_removed << " ANSI bytes removed\n";
    }

    return insert_chunk(filtered);
}

std::vector<HybridSearchResult> VectorMemoryEngine::hybrid_search(
    const std::string& query_text,
    const std::vector<float>& query_embedding,
    size_t limit,
    float rrf_k,
    bool prune_by_distance,
    float std_dev_mult
) {
    std::lock_guard<std::mutex> lock(db_mutex_);
    std::vector<HybridSearchResult> results;
    if (!db_) return results;

    std::vector<float> norm_query = query_embedding;
    if (!norm_query.empty()) {
        SimdQuant::l2_normalize_f32(norm_query.data(), norm_query.size());
    }

    // Unified Hybrid Search SQL using Common Table Expressions (CTEs) and Reciprocal Rank Fusion (RRF)
    const char* rrf_sql = R"(
        WITH dense_matches AS (
            SELECT chunk_id, vec_cosine_distance(embedding_blob, ?1) AS distance,
                   ROW_NUMBER() OVER (ORDER BY vec_cosine_distance(embedding_blob, ?1) ASC) AS dense_rank
            FROM memory_chunks
            WHERE embedding_blob IS NOT NULL
            LIMIT ?3 * 4
        ),
        sparse_matches AS (
            SELECT rowid AS chunk_id, rank,
                   ROW_NUMBER() OVER (ORDER BY rank ASC) AS sparse_rank
            FROM fts_chunks
            WHERE fts_chunks MATCH ?2
            LIMIT ?3 * 4
        ),
        rrf_fused AS (
            SELECT
                COALESCE(d.chunk_id, s.chunk_id) AS chunk_id,
                (COALESCE(1.0 / (?4 + d.dense_rank), 0.0) +
                 COALESCE(1.0 / (?4 + s.sparse_rank), 0.0)) AS rrf_score,
                d.dense_rank,
                s.sparse_rank,
                COALESCE(d.distance, 1.0) AS cosine_dist
            FROM dense_matches d
            FULL OUTER JOIN sparse_matches s ON d.chunk_id = s.chunk_id
        )
        SELECT m.chunk_id, m.turn_id, m.session_id, m.chunk_text, m.importance_score,
               m.is_ephemeral, f.rrf_score, f.cosine_dist, f.dense_rank, f.sparse_rank
        FROM rrf_fused f
        JOIN memory_chunks m ON m.chunk_id = f.chunk_id
        ORDER BY f.rrf_score DESC
        LIMIT ?3;
    )";

    sqlite3_stmt* stmt = nullptr;
    if (sqlite3_prepare_v2(db_, rrf_sql, -1, &stmt, nullptr) != SQLITE_OK) {
        return results;
    }

    // Bind parameter 1: Query embedding blob
    if (!norm_query.empty()) {
        sqlite3_bind_blob(stmt, 1, norm_query.data(), static_cast<int>(norm_query.size() * sizeof(float)), SQLITE_TRANSIENT);
    } else {
        sqlite3_bind_null(stmt, 1);
    }

    // Bind parameter 2: Clean query text for FTS5 (surround with quotes or word tokens)
    std::string clean_fts_query;
    std::istringstream ss(query_text);
    std::string token;
    while (ss >> token) {
        // Strip non-alphanumeric punctuation for safe FTS5 query token
        std::string filtered;
        for (char c : token) {
            if (isalnum(static_cast<unsigned char>(c))) filtered += c;
        }
        if (!filtered.empty()) {
            if (!clean_fts_query.empty()) clean_fts_query += " OR ";
            clean_fts_query += filtered + "*";
        }
    }
    if (clean_fts_query.empty()) clean_fts_query = "\"*\"";

    sqlite3_bind_text(stmt, 2, clean_fts_query.c_str(), -1, SQLITE_TRANSIENT);
    sqlite3_bind_int64(stmt, 3, static_cast<sqlite3_int64>(limit));
    sqlite3_bind_double(stmt, 4, static_cast<double>(rrf_k));

    while (sqlite3_step(stmt) == SQLITE_ROW) {
        HybridSearchResult res;
        res.chunk_id = sqlite3_column_int64(stmt, 0);
        res.turn_id = sqlite3_column_int64(stmt, 1);
        res.session_id = reinterpret_cast<const char*>(sqlite3_column_text(stmt, 2));
        res.chunk_text = reinterpret_cast<const char*>(sqlite3_column_text(stmt, 3));
        res.importance_score = static_cast<float>(sqlite3_column_double(stmt, 4));
        res.is_ephemeral = (sqlite3_column_int(stmt, 5) != 0);
        res.rrf_score = static_cast<float>(sqlite3_column_double(stmt, 6));
        res.cosine_distance = static_cast<float>(sqlite3_column_double(stmt, 7));
        res.dense_rank = sqlite3_column_type(stmt, 8) != SQLITE_NULL ? sqlite3_column_int64(stmt, 8) : -1;
        res.sparse_rank = sqlite3_column_type(stmt, 9) != SQLITE_NULL ? sqlite3_column_int64(stmt, 9) : -1;

        results.push_back(res);
    }
    sqlite3_finalize(stmt);

    // Dynamic context pruning: cut dense hits past the largest score dropoff.
    // Keyword-only hits (no dense rank, placeholder distance 1.0) are exempt so
    // RRF's sparse recall isn't discarded, and RRF ordering is preserved.
    if (prune_by_distance && results.size() > 1) {
        auto pr = EntropyFilter::prune_by_distance_dropoff(
            results,
            [](const HybridSearchResult& r) { return r.dense_rank >= 0; },
            std_dev_mult);
        if (pr.dropped > 0) {
            std::cout << "[VectorMemory] Distance pruning: kept=" << pr.kept
                      << " dropped=" << pr.dropped
                      << " threshold=" << pr.threshold
                      << " (gap=" << pr.largest_gap << " mean_gap=" << pr.mean
                      << " σ=" << pr.std_dev << ")\n";
        }
    }

    // Update access count and last_accessed timestamp for returned chunks
    if (!results.empty()) {
        int64_t now = std::chrono::duration_cast<std::chrono::seconds>(
            std::chrono::system_clock::now().time_since_epoch()
        ).count();

        const char* touch_sql = "UPDATE memory_chunks SET access_count = access_count + 1, last_accessed = ?1 WHERE chunk_id = ?2;";
        sqlite3_stmt* tstmt = nullptr;
        if (sqlite3_prepare_v2(db_, touch_sql, -1, &tstmt, nullptr) == SQLITE_OK) {
            for (const auto& r : results) {
                sqlite3_reset(tstmt);
                sqlite3_bind_int64(tstmt, 1, now);
                sqlite3_bind_int64(tstmt, 2, r.chunk_id);
                sqlite3_step(tstmt);
            }
            sqlite3_finalize(tstmt);
        }
    }

    return results;
}

void VectorMemoryEngine::check_wal_maintenance() {
    if (insertion_count_ > 0 && (insertion_count_ % 500 == 0)) {
        run_wal_checkpoint_truncate();
    }
}

bool VectorMemoryEngine::run_wal_checkpoint_truncate() {
    if (!db_) return false;
    int log = 0, ckpt = 0;
    int rc = sqlite3_wal_checkpoint_v2(db_, nullptr, SQLITE_CHECKPOINT_TRUNCATE, &log, &ckpt);
    return (rc == SQLITE_OK);
}

size_t VectorMemoryEngine::prune_ephemeral_chunks(float decay_threshold) {
    std::lock_guard<std::mutex> lock(db_mutex_);
    if (!db_) return 0;

    int64_t now = std::chrono::duration_cast<std::chrono::seconds>(
        std::chrono::system_clock::now().time_since_epoch()
    ).count();

    // Decay model: importance * exp(-decay_factor * (now - created_at) / 3600.0) < threshold
    // Using SQL math approximation
    const char* prune_sql = R"(
        DELETE FROM memory_chunks
        WHERE is_ephemeral = 1
          AND (importance_score * (1.0 / (1.0 + (decay_factor * (?1 - created_at) / 3600.0)))) < ?2;
    )";

    sqlite3_stmt* stmt = nullptr;
    if (sqlite3_prepare_v2(db_, prune_sql, -1, &stmt, nullptr) != SQLITE_OK) {
        return 0;
    }

    sqlite3_bind_int64(stmt, 1, now);
    sqlite3_bind_double(stmt, 2, static_cast<double>(decay_threshold));

    sqlite3_step(stmt);
    sqlite3_finalize(stmt);

    return static_cast<size_t>(sqlite3_changes(db_));
}

} // namespace lucille
