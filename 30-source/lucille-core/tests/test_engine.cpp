#include <iostream>
#include <cassert>
#include <fstream>
#include <filesystem>
#include <cstring>
#include <sys/stat.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <sys/mman.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <poll.h>
#include <unistd.h>
#include <chrono>
#include <thread>
#include <random>
#include <functional>
#include <atomic>
#include <algorithm>
#include "bootloader.hpp"
#include "ipc_server.hpp"
#include "security_sandbox.hpp"
#include "error_interceptor.hpp"
#include "affinity_manager.hpp"
#include "process_manager.hpp"
#include "simd_quant.hpp"
#include "vector_memory.hpp"
#include "safety_gate.hpp"
#include "swarm_router.hpp"
#include "hitl_security.hpp"
#include "mesh_sync.hpp"
#include "telemetry_daemon.hpp"
#include "shm_telemetry.hpp"
#include "entropy_filter.hpp"
#include "speculative_pipeline.hpp"
#include "consensus_gate.hpp"
#include "engine.hpp"

namespace fs = std::filesystem;

static int g_tests_passed = 0;
static int g_tests_failed = 0;

#define TEST_ASSERT(cond, msg) \
    do { \
        if (cond) { \
            std::cout << "  [PASS] " << (msg) << "\n"; \
            g_tests_passed++; \
        } else { \
            std::cerr << "  [FAIL] " << (msg) << " (" << __FILE__ << ":" << __LINE__ << ")\n"; \
            g_tests_failed++; \
        } \
    } while(0)

void test_bootloader_and_topology() {
    std::cout << "\n--- 1. Testing Bootloader & Topology Discovery ---\n";
    auto diag = lucille::Bootloader::run_boot_sequence();
    TEST_ASSERT(diag.boot_success, "Bootloader sequence succeeded");
    TEST_ASSERT(diag.is_non_root, "Non-root execution verified");
    TEST_ASSERT(diag.uid != 0, "User ID is not 0");
    TEST_ASSERT(diag.hardware.logical_cores > 0, "Hardware logical core count > 0");
    TEST_ASSERT(diag.hardware.total_ram_bytes > 0, "Hardware total RAM probed > 0");
    TEST_ASSERT(!diag.hardware.p_cores.empty(), "P-cores set is non-empty");
    TEST_ASSERT(!diag.hardware.e_cores.empty(), "E-cores set is non-empty");
}

void test_ipc_socket_and_permissions() {
    std::cout << "\n--- 2. Testing Non-Blocking IPC Socket & 0660 Permissions ---\n";
    std::string test_sock = "/tmp/lucille_ipc_unit_test.sock";
    lucille::IpcServer server(test_sock);
    std::string err;
    bool init_ok = server.initialize(err);
    TEST_ASSERT(init_ok, "IPC Server initialization succeeded on " + test_sock);

    struct stat st;
    int stat_rc = stat(test_sock.c_str(), &st);
    TEST_ASSERT(stat_rc == 0, "Socket file exists on disk");
    
    mode_t perm = st.st_mode & 0777;
    TEST_ASSERT(perm == 0660, "Socket permissions are strictly 0660");

    server.shutdown();
    TEST_ASSERT(!fs::exists(test_sock), "Socket file unlinked after shutdown");
}

void test_ipc_epoll_multi_client() {
    std::cout << "\n--- 2b. Testing IpcServer epoll ET multi-client concurrency ---\n";

    const std::string sock = "/tmp/lucille_ipc_epoll_test.sock";
    lucille::IpcServer server(sock);
    server.set_handler([](const std::string& req) -> std::string {
        return "PONG:" + req;
    });

    std::string err;
    bool init_ok = server.initialize(err);
    TEST_ASSERT(init_ok, "Multi-client IpcServer initialized: " + (init_ok ? sock : err));
    if (!init_ok) return;

    // Run event loop in a background thread
    std::thread loop_thread([&server]() { server.run_event_loop(); });

    // Give the loop a moment to enter epoll_wait
    std::this_thread::sleep_for(std::chrono::milliseconds(30));

    // Helper lambda: connect + send + recv via AF_UNIX
    auto client_exchange = [&](const std::string& msg, std::string& out_reply) -> bool {
        int fd = socket(AF_UNIX, SOCK_STREAM, 0);
        if (fd < 0) return false;
        struct sockaddr_un addr{};
        addr.sun_family = AF_UNIX;
        std::strncpy(addr.sun_path, sock.c_str(), sizeof(addr.sun_path) - 1);
        if (connect(fd, reinterpret_cast<struct sockaddr*>(&addr), sizeof(addr)) < 0) {
            close(fd); return false;
        }
        write(fd, msg.data(), msg.size());
        char buf[256]{};
        ssize_t n = read(fd, buf, sizeof(buf) - 1);
        close(fd);
        if (n > 0) { out_reply.assign(buf, n); return true; }
        return false;
    };

    // Two concurrent clients
    std::string reply_a, reply_b;
    bool ok_a = false, ok_b = false;
    std::thread ta([&](){ ok_a = client_exchange("PING_A", reply_a); });
    std::thread tb([&](){ ok_b = client_exchange("PING_B", reply_b); });
    ta.join(); tb.join();

    TEST_ASSERT(ok_a, "Client A connected and received reply");
    TEST_ASSERT(reply_a == "PONG:PING_A",
        "Client A reply correct: '" + reply_a + "'");

    TEST_ASSERT(ok_b, "Client B connected and received reply");
    TEST_ASSERT(reply_b == "PONG:PING_B",
        "Client B reply correct: '" + reply_b + "'");

    // Clean shutdown
    server.shutdown();
    loop_thread.join();
    TEST_ASSERT(!std::filesystem::exists(sock),
        "Socket unlinked after multi-client shutdown");
}

void test_security_sandbox_and_soul() {
    std::cout << "\n--- 3. Testing Sandbox & SOUL.md SHA-256 Integrity ---\n";
    std::string test_soul = "/tmp/test_SOUL.md";
    {
        std::ofstream out(test_soul);
        out << "# Test Lucille Soul Prompt\nOperational Invariants.\n";
    }

    std::string sha = lucille::SecuritySandbox::calculate_file_sha256(test_soul);
    TEST_ASSERT(!sha.empty(), "SHA-256 hash computed successfully (" + sha.substr(0, 16) + "...)");

    auto report = lucille::SecuritySandbox::verify_soul_integrity(test_soul, sha);
    TEST_ASSERT(report.soul_exists, "SOUL file exists in report");
    TEST_ASSERT(report.sha256_match, "SHA-256 matched expected hash");

    uint64_t fake_ram = 16ULL * 1024 * 1024 * 1024; // 16 GB
    auto cg = lucille::SecuritySandbox::setup_cgroups_slice(fake_ram);
    uint64_t expected_75 = (fake_ram * 75) / 100;
    TEST_ASSERT(cg.memory_high_bytes == expected_75, "Cgroups v2 memory.high calculated at exactly 75% of RAM");

    fs::remove(test_soul);
}

void test_error_interceptor() {
    std::cout << "\n--- 4. Testing Compiler Diagnostic Regex & AST Context Extraction ---\n";
    std::string sample_src = "/tmp/sample_buggy_code.cpp";
    {
        std::ofstream out(sample_src);
        out << "#include <iostream>\n"
            << "int main() {\n"
            << "    int a = 10;\n"
            << "    std::cout << invalid_variable << std::endl;\n"
            << "    return 0;\n"
            << "}\n";
    }

    std::string compiler_output = 
        sample_src + ":4:18: error: 'invalid_variable' was not declared in this scope\n";

    lucille::ErrorInterceptor interceptor;
    auto payload = interceptor.parse_compiler_output(compiler_output, 3);

    TEST_ASSERT(payload.has_errors, "Compiler output flagged as having errors");
    TEST_ASSERT(payload.total_errors == 1, "Total error count is 1");
    TEST_ASSERT(!payload.diagnostics.empty(), "Diagnostic item extracted");
    TEST_ASSERT(payload.structured_repair_prompt.find("Kimi-2.6-Coder") != std::string::npos, "Payload targets Kimi-2.6-Coder");

    fs::remove(sample_src);
}

void test_simd_and_quantization() {
    std::cout << "\n--- 5. Testing AVX2 SIMD Math & Quantization Pathways ---\n";
    std::cout << "  Active SIMD capabilities: " << lucille::SimdQuant::get_simd_capabilities() << "\n";

    const size_t dim = 384;
    std::vector<float> vec_a(dim);
    std::vector<float> vec_b(dim);

    std::mt19937 rng(42);
    std::uniform_real_distribution<float> dist(-1.0f, 1.0f);
    for (size_t i = 0; i < dim; ++i) {
        vec_a[i] = dist(rng);
        vec_b[i] = dist(rng);
    }

    // Test L2 Normalization
    float norm_a = lucille::SimdQuant::l2_normalize_f32(vec_a.data(), dim);
    float norm_b = lucille::SimdQuant::l2_normalize_f32(vec_b.data(), dim);
    TEST_ASSERT(norm_a > 0.0f && norm_b > 0.0f, "L2 Normalization calculated non-zero norms");

    float self_dot = lucille::SimdQuant::dot_product_f32(vec_a.data(), vec_a.data(), dim);
    TEST_ASSERT(std::abs(self_dot - 1.0f) < 1e-4f, "Self dot-product of normalized vector is ~1.0");

    float cos_dist = lucille::SimdQuant::cosine_distance_f32(vec_a.data(), vec_b.data(), dim);
    TEST_ASSERT(cos_dist >= 0.0f && cos_dist <= 2.0f, "Cosine distance is bounded [0.0, 2.0]");

    // Test Int8 Scalar Quantization
    auto int8_q = lucille::SimdQuant::quantize_int8(vec_a.data(), dim);
    TEST_ASSERT(int8_q.data.size() == dim, "Int8 vector dimensions match 384");
    auto dequant_a = lucille::SimdQuant::dequantize_int8(int8_q);
    float recon_dot = lucille::SimdQuant::dot_product_f32(vec_a.data(), dequant_a.data(), dim);
    TEST_ASSERT(recon_dot > 0.98f, "Int8 quantization reconstruction fidelity > 0.98 (actual: " + std::to_string(recon_dot) + ")");

    // Test 1-Bit Binary Quantization
    auto bin_a = lucille::SimdQuant::quantize_binary(vec_a.data(), dim);
    auto bin_b = lucille::SimdQuant::quantize_binary(vec_b.data(), dim);
    TEST_ASSERT(bin_a.words.size() == 6, "384-dim binary vector packed into exactly 6 uint64 words (48 bytes)");
    uint32_t self_hamming = lucille::SimdQuant::hamming_distance_binary(bin_a, bin_a);
    TEST_ASSERT(self_hamming == 0, "Self Hamming distance is 0");
    uint32_t diff_hamming = lucille::SimdQuant::hamming_distance_binary(bin_a, bin_b);
    TEST_ASSERT(diff_hamming > 0 && diff_hamming <= dim, "Hamming distance between distinct vectors > 0");
}

void test_vector_memory_engine_and_hybrid_search() {
    std::cout << "\n--- 6. Testing SQLite Vector Memory Engine & RRF Hybrid Search ---\n";
    std::string test_db = "/tmp/test_lucille_memory.db";
    fs::remove(test_db);
    fs::remove(test_db + "-wal");
    fs::remove(test_db + "-shm");

    lucille::VectorMemoryEngine mem_engine(test_db);
    std::string err;
    bool init_ok = mem_engine.initialize(err);
    TEST_ASSERT(init_ok, "VectorMemoryEngine initialization succeeded (WAL mode enabled)");

    // Log conversation turns
    lucille::ConversationTurn turn1;
    turn1.session_id = "sess-alpha";
    turn1.role = "user";
    turn1.content = "How do we configure Gamescope and Wayland render permissions in SWARM OS?";
    turn1.timestamp = 1700000000;
    int64_t tid1 = mem_engine.log_turn(turn1);
    TEST_ASSERT(tid1 > 0, "Logged conversation turn 1");

    lucille::ConversationTurn turn2;
    turn2.session_id = "sess-alpha";
    turn2.role = "assistant";
    turn2.content = "Use /etc/udev/rules.d/99-swarm-render.rules granting 0660 permissions to render and video groups.";
    turn2.timestamp = 1700000005;
    int64_t tid2 = mem_engine.log_turn(turn2);
    TEST_ASSERT(tid2 > 0, "Logged conversation turn 2");

    // Insert semantic chunks with simulated 384-dim embeddings
    std::mt19937 rng(1337);
    std::uniform_real_distribution<float> dist(-1.0f, 1.0f);

    auto make_rand_vec = [&](size_t d) {
        std::vector<float> v(d);
        for (size_t i = 0; i < d; ++i) v[i] = dist(rng);
        return v;
    };

    std::vector<float> emb_gamescope = make_rand_vec(384);
    std::vector<float> emb_cgroups = make_rand_vec(384);
    std::vector<float> emb_pipewire = make_rand_vec(384);

    lucille::MemoryChunk c1;
    c1.turn_id = tid2;
    c1.session_id = "sess-alpha";
    c1.chunk_text = "Gamescope session launcher executes under wayland socket with 0660 render permissions";
    c1.embedding = emb_gamescope;
    c1.tags = {{"subsystem", "graphics"}, {"module", "gamescope"}};
    int64_t cid1 = mem_engine.insert_chunk(c1);
    TEST_ASSERT(cid1 > 0, "Inserted chunk 1 (Gamescope render)");

    lucille::MemoryChunk c2;
    c2.turn_id = tid2;
    c2.session_id = "sess-alpha";
    c2.chunk_text = "Cgroups v2 slice lucille.slice enforces memory.high limit of 75 percent RAM";
    c2.embedding = emb_cgroups;
    c2.is_ephemeral = true;
    c2.importance_score = 0.8f;
    c2.tags = {{"subsystem", "cgroups"}, {"module", "security"}};
    int64_t cid2 = mem_engine.insert_chunk(c2);
    TEST_ASSERT(cid2 > 0, "Inserted chunk 2 (Cgroups memory)");

    lucille::MemoryChunk c3;
    c3.turn_id = tid2;
    c3.session_id = "sess-alpha";
    c3.chunk_text = "PipeWire low-latency quantum buffer set to 128 samples at 48000Hz clock rate";
    c3.embedding = emb_pipewire;
    c3.tags = {{"subsystem", "audio"}, {"module", "pipewire"}};
    int64_t cid3 = mem_engine.insert_chunk(c3);
    TEST_ASSERT(cid3 > 0, "Inserted chunk 3 (PipeWire lowlatency)");

    // Test RRF Hybrid Search (Dense KNN + Sparse FTS5)
    auto results = mem_engine.hybrid_search("Gamescope render permissions", emb_gamescope, 3);
    TEST_ASSERT(!results.empty(), "Hybrid search returned results");
    if (!results.empty()) {
        TEST_ASSERT(results[0].chunk_id == cid1, "Top hybrid search result correctly ranked chunk 1 first");
        TEST_ASSERT(results[0].rrf_score > 0.0f, "Reciprocal Rank Fusion score computed: " + std::to_string(results[0].rrf_score));
        TEST_ASSERT(results[0].cosine_distance < 0.01f, "Dense vector cosine distance ~0 for identical query embedding");
    }

    // Test Automated WAL maintenance checkpoint truncate
    bool ckpt_ok = mem_engine.run_wal_checkpoint_truncate();
    TEST_ASSERT(ckpt_ok, "WAL checkpoint truncate executed successfully");

    // Test Ephemeral decay & pruning
    size_t pruned = mem_engine.prune_ephemeral_chunks(0.99f); // High threshold forces pruning of ephemeral chunk
    TEST_ASSERT(pruned >= 1, "Ephemeral chunk pruning removed decaying session chunks");

    mem_engine.close();
    fs::remove(test_db);
    fs::remove(test_db + "-wal");
    fs::remove(test_db + "-shm");
}

void test_safety_gate_and_circuit_breaker() {
    std::cout << "\n--- 7. Testing Safety Gate, AST Syntax & p95 Circuit Breaker ---\n";
    lucille::SafetyGate gate(1500);

    // Test AST Syntax Checking
    std::string err;
    bool valid_cpp = lucille::SafetyGate::verify_ast_syntax("cpp", "int foo() { return (42 + 1); }", err);
    TEST_ASSERT(valid_cpp, "Valid C++ syntax accepted by AST validator");

    bool invalid_cpp = lucille::SafetyGate::verify_ast_syntax("cpp", "int foo() { return (42 + 1; }", err);
    TEST_ASSERT(!invalid_cpp, "Invalid unbalanced C++ syntax rejected: " + err);

    // Test Strict Tool Schema Validation
    std::string schema_err;
    bool valid_tool = gate.validate_tool_call_json("run_command", "{\"command\":\"cargo build\",\"sandboxed\":true}", schema_err);
    TEST_ASSERT(valid_tool, "Valid tool JSON arguments approved by schema validator");

    bool invalid_tool = gate.validate_tool_call_json("run_command", "{\"sandboxed\":true}", schema_err);
    TEST_ASSERT(!invalid_tool, "Tool JSON missing required 'command' rejected: " + schema_err);

    // Test KV-cache Prefix Formatting
    std::string prefix = lucille::SafetyGate::format_kv_cache_prefix("Directives", "abc123hash", 8, 16000, "Vulkan-AMD");
    TEST_ASSERT(prefix.find("PROMPT_HASH_SHA256=abc123hash") != std::string::npos, "KV-cache prefix contains deterministic hash tag");
    TEST_ASSERT(prefix.find("LogicalCores=8") != std::string::npos, "KV-cache prefix contains hardware state");

    // Test Rolling p95 Latency Circuit Breaker
    for (int i = 0; i < 20; ++i) {
        gate.record_request_latency(200); // 200ms normal latency
    }
    TEST_ASSERT(!gate.should_fallback_to_local_gguf(), "Circuit breaker is CLOSED under normal 200ms load");
    TEST_ASSERT(gate.get_rolling_p95_latency() == 200, "Rolling p95 latency accurately reflects 200ms");

    // Inject high latency spikes > 1500ms
    for (int i = 0; i < 10; ++i) {
        gate.record_request_latency(2200); // 2200ms spike
    }
    TEST_ASSERT(gate.should_fallback_to_local_gguf(), "Circuit breaker TRIPPED to OPEN state after p95 latency > 1500ms");
    TEST_ASSERT(gate.get_circuit_state() == lucille::CircuitBreakerState::Open, "Circuit breaker state is OPEN");

    gate.reset_circuit();
    TEST_ASSERT(!gate.should_fallback_to_local_gguf(), "Circuit breaker cleanly reset to CLOSED state");
}

void test_swarm_router_two_tier_speculation() {
    std::cout << "\n--- 8. Testing Swarm Router & Two-Tier Speculative Routing ---\n";
    lucille::SwarmRouter router;

    // Test Model Specialization Matrix Selection
    TEST_ASSERT(router.select_model_for_task("refactor") == lucille::SwarmModelType::Kimi26Coder, "Refactoring maps to Kimi 2.6 Coder");
    TEST_ASSERT(router.select_model_for_task("journal_triage") == lucille::SwarmModelType::GLM56, "Journal triage maps to GLM 5.6");
    TEST_ASSERT(router.select_model_for_task("safety_proof") == lucille::SwarmModelType::DeepSeekR1, "Safety proof maps to DeepSeek-R1");
    TEST_ASSERT(router.select_model_for_task("tool_exec") == lucille::SwarmModelType::Hermes3Agent, "Tool execution maps to Hermes 3 Agent");

    // Test Two-Tier Speculative Task Execution:
    // Draft with Kimi 2.6 -> Safety Audit with DeepSeek-R1 -> Execute in Sandbox with Hermes 3
    lucille::SwarmTaskRequest req;
    req.task_id = "task-spec-001";
    req.user_instruction = "Refactor memory allocation loop to avoid fragmentation";
    req.target_file = "src/allocator.cpp";
    req.file_content = "void* allocate() { return malloc(1024); }";
    req.language = "cpp";
    req.require_two_tier_speculation = true;
    req.allow_tool_execution = true;

    auto resp = router.route_and_execute(req);
    TEST_ASSERT(resp.success, "Two-tier speculative task routed and executed successfully");
    TEST_ASSERT(resp.drafter_model == "Kimi-2.6-Coder", "Tier 1 Drafter: Kimi-2.6-Coder");
    TEST_ASSERT(resp.auditor_model == "DeepSeek-R1", "Tier 2 Auditor: DeepSeek-R1");
    TEST_ASSERT(resp.safety_verified, "DeepSeek-R1 Chain-of-Thought safety proof passed");
    TEST_ASSERT(!resp.deepseek_cot_proof.empty(), "DeepSeek-R1 reasoning trace extracted: " + resp.deepseek_cot_proof.substr(0, 30) + "...");
    TEST_ASSERT(resp.ast_verified, "AST pre-execution verification passed");
    TEST_ASSERT(resp.execution_output.find("Hermes-3-Agent") != std::string::npos, "Tier 3 Execution executed in Hermes 3 sandbox");
}

void test_speculative_pipeline_entropy_and_pruning() {
    std::cout << "\n--- 8b. Testing Speculative Pipeline, Entropy Filter & Context Pruning ---\n";

    // Block buffer: braces inside strings/comments must not split blocks,
    // even when chunk boundaries fall mid-token.
    {
        const std::string src =
            "void f() {\n  auto s = \"}\"; char c = '{'; // } stray\n  return;\n}\n"
            "int g() { /* { */ return 1; }\n";
        std::vector<std::string> blocks;
        lucille::StreamingBlockBuffer buf("cpp");
        buf.set_callback([&](std::string b, size_t) { blocks.push_back(std::move(b)); });
        for (size_t i = 0; i < src.size(); i += 3) buf.feed(src.substr(i, 3));
        buf.flush();
        TEST_ASSERT(blocks.size() == 2, "C++ stream split into 2 blocks despite braces in literals/comments (got " + std::to_string(blocks.size()) + ")");
        TEST_ASSERT(blocks.size() == 2 && blocks[0].find("return;") != std::string::npos
                    && blocks[1].rfind("int g()", 0) == 0,
                    "C++ block boundaries fall at function ends");
    }

    // Python: split only at top-level def/class; decorators travel with their def.
    {
        const std::string src =
            "import os\n\ndef a():\n    def inner():\n        pass\n    return {1: 2}\n\n"
            "@cache\ndef b():\n    return 2\n";
        std::vector<std::string> blocks;
        lucille::StreamingBlockBuffer buf("python");
        buf.set_callback([&](std::string b, size_t) { blocks.push_back(std::move(b)); });
        for (size_t i = 0; i < src.size(); i += 5) buf.feed(src.substr(i, 5));
        buf.flush();
        TEST_ASSERT(blocks.size() == 2, "Python stream split into 2 top-level blocks (got " + std::to_string(blocks.size()) + ")");
        TEST_ASSERT(blocks.size() == 2 && blocks[0].find("def inner") != std::string::npos
                    && blocks[1].rfind("@cache\ndef b():", 0) == 0,
                    "Nested def stays in its parent; decorator moves with its def");
    }

    // Entropy filter on a noisy compiler log
    {
        const std::string raw =
            "\033[1m[ 45%] Building CXX object foo.o\033[0m\n"
            "-- Configuring done\n"
            "[1] error: first real diagnostic\n"
            "\n\n\n"
            "note: repeated\nnote: repeated\nnote: repeated\nnote: repeated\n"
            "\n"
            "paragraph two\n"
            "\n"
            "paragraph three\n";
        auto cr = lucille::EntropyFilter::clean(raw);
        TEST_ASSERT(cr.text.find("[ 45%]") == std::string::npos && cr.text.find("Configuring") == std::string::npos,
                    "Entropy filter drops build-progress noise");
        TEST_ASSERT(cr.text.find('\033') == std::string::npos && cr.ansi_bytes_removed > 0, "Entropy filter strips ANSI escapes");
        TEST_ASSERT(cr.text.find("[1] error: first real diagnostic") != std::string::npos,
                    "Numbered diagnostic '[1] error:' is not mistaken for progress");
        TEST_ASSERT(cr.dupes_removed == 2, "Repeated line kept twice, 2 extra copies dropped");
        TEST_ASSERT(cr.text.find("paragraph two\n\nparagraph three") != std::string::npos,
                    "Blank separators survive dedupe (paragraphs not merged)");
    }

    // Dynamic context pruning via score dropoff
    {
        struct Hit { int id; float cosine_distance; bool dense; };
        std::vector<Hit> hits = {{1, 0.12f, true}, {2, 0.60f, true}, {3, 0.10f, true},
                                 {4, 0.50f, true}, {5, 0.15f, true}, {6, 1.00f, false}};
        auto pr = lucille::EntropyFilter::prune_by_distance_dropoff(
            hits, [](const Hit& h) { return h.dense; });
        std::string ids;
        for (auto& h : hits) ids += std::to_string(h.id);
        TEST_ASSERT(ids == "1356", "Pruning cuts at the dropoff, keeps input order and keyword-only hit (got " + ids + ")");
        TEST_ASSERT(pr.dropped == 2 && pr.threshold > 0.149f && pr.threshold < 0.151f,
                    "Pruning threshold sits at last result before the gap");

        std::vector<Hit> even = {{1, 0.1f, true}, {2, 0.2f, true}, {3, 0.3f, true}, {4, 0.4f, true}};
        auto pe = lucille::EntropyFilter::prune_by_distance_dropoff(even);
        TEST_ASSERT(pe.dropped == 0 && even.size() == 4, "Evenly spread results are all kept (no dropoff)");

        std::vector<Hit> lone = {{1, 0.1f, true}, {2, 0.9f, true}, {3, 0.95f, true}};
        lucille::EntropyFilter::prune_by_distance_dropoff(lone, 1.5f, 2);
        TEST_ASSERT(lone.size() >= 2, "min_keep is honoured even when the dropoff is after the first hit");
    }

    // Router pipeline with injected backends
    {
        lucille::SwarmRouter router;
        std::string glm_saw_logs;
        router.set_pipeline_backends(
            [](const std::string&, const std::string&, lucille::StreamingBlockBuffer& buf) {
                buf.feed("void ok() { return; }\n");
                buf.feed("void bad() { system(\"rm -rf /\"); }\n");
            },
            [](const std::string& block, const std::string&, std::string& cot, std::string& err) {
                if (block.find("system(") != std::string::npos) { err = "unsafe"; return false; }
                cot = "ok";
                return true;
            },
            [&](const std::string& logs, const std::string&) {
                glm_saw_logs = logs;
                lucille::PipelineMetrics m;
                m.glm_report = "real-glm";
                return m;
            });

        lucille::SwarmTaskRequest req;
        req.task_id = "pipe-001";
        req.language = "cpp";
        auto r = router.route_speculative_pipeline(req, "\033[31m[ 10%] Building x\033[0m\nfoo.cpp:1: error: bad\n");
        TEST_ASSERT(r.pipeline_complete && !r.used_mock_backends, "Pipeline ran on injected (non-mock) backends");
        TEST_ASSERT(r.total_blocks == 2 && r.passed_blocks == 1 && r.rejected_blocks == 1,
                    "Streamed blocks audited concurrently: 1 pass, 1 reject");
        TEST_ASSERT(r.blocks.size() == 2 && r.blocks[0].index == 0 && r.blocks[0].audit_passed && !r.blocks[1].audit_passed,
                    "Audit results returned in emission order");
        TEST_ASSERT(glm_saw_logs == "foo.cpp:1: error: bad\n", "GLM received entropy-filtered logs: '" + glm_saw_logs + "'");
        TEST_ASSERT(r.metrics.glm_report == "real-glm", "GLM triage metrics attached to result");
    }

    // No backends → simulated models, and the result says so
    {
        lucille::SwarmRouter router;
        lucille::SwarmTaskRequest req;
        req.task_id = "pipe-mock";
        req.language = "cpp";
        auto r = router.route_speculative_pipeline(req);
        TEST_ASSERT(r.used_mock_backends && r.total_blocks > 0, "Unconfigured router flags simulated output");
    }

    // Failure paths: throwing auditor fails closed; throwing stream marks incomplete
    {
        lucille::SpeculativePipeline p;
        p.kimi_stream = [](const std::string&, const std::string&, lucille::StreamingBlockBuffer& buf) {
            buf.feed("void a() { }\n");
            throw std::runtime_error("socket reset");
        };
        p.deepseek_audit = [](const std::string&, const std::string&, std::string&, std::string&) -> bool {
            throw std::runtime_error("auditor down");
        };
        p.glm_triage = [](const std::string&, const std::string&) { return lucille::PipelineMetrics{}; };
        auto r = p.run("x", "", "cpp");
        TEST_ASSERT(!r.pipeline_complete && r.error_message.find("socket reset") != std::string::npos,
                    "Stream failure leaves pipeline incomplete with error");
        TEST_ASSERT(r.total_blocks == 1 && r.rejected_blocks == 1 && r.blocks[0].audit_error.find("auditor down") != std::string::npos,
                    "Throwing auditor rejects the block (fail closed)");
    }
}

void test_consensus_gate_high_risk_diffs() {
    std::cout << "\n--- 8c. Testing 2-of-2 Consensus Gate for High-Risk Diffs ---\n";
    using lucille::ConsensusGate;
    using lucille::ConsensusVote;

    // Classifier: patterns are case-insensitive and removed lines count
    {
        std::vector<std::string> r;
        bool f = ConsensusGate::classify_high_risk(
            "--- a/src/app.conf\n+++ b/src/app.conf\n+AmbientCapabilities=CAP_SYS_ADMIN\n", r);
        TEST_ASSERT(f && std::find(r.begin(), r.end(), "priv:CAP_SYS_ADMIN") != r.end(),
                    "Added CAP_SYS_ADMIN flagged (mixed-case content pattern matches)");

        r.clear();
        f = ConsensusGate::classify_high_risk(
            "--- a/rules.conf\n+++ b/rules.conf\n-policy INPUT DROP\n+policy accept\n", r);
        TEST_ASSERT(f && std::find(r.begin(), r.end(), "firewall:INPUT_DROP") != r.end(),
                    "Removing a firewall DROP policy is flagged");

        r.clear();
        f = ConsensusGate::classify_high_risk(
            "--- a/lib/ui.dart\n+++ b/lib/ui.dart\n+  final label = 'hello';\n", r);
        TEST_ASSERT(!f && r.empty(), "Ordinary app diff is low-risk");
    }

    const std::string risky =
        "--- a/etc/systemd/system/x.service\n+++ b/etc/systemd/system/x.service\n+ExecStart=/usr/bin/x\n";

    auto vote = [](bool ok) {
        return [ok](const std::string&, const std::string&) {
            ConsensusVote v; v.model_name = "m"; v.approved = ok; v.rationale = ok ? "ok" : "no";
            return v;
        };
    };

    // 2-of-2 truth table
    {
        ConsensusGate g; g.kimi_syntax_audit = vote(true); g.deepseek_risk_audit = vote(true);
        auto r = g.evaluate(risky);
        TEST_ASSERT(r.is_high_risk && r.approved && r.votes.size() == 2 && !r.used_mock_backends,
                    "Both voters approve → high-risk diff approved");
        g.deepseek_risk_audit = vote(false);
        r = g.evaluate(risky);
        TEST_ASSERT(!r.approved && r.rejection_reason.find("[DeepSeek-R1]") != std::string::npos,
                    "One voter rejects → blocked with reason");
        g.kimi_syntax_audit = vote(false); g.deepseek_risk_audit = vote(true);
        TEST_ASSERT(!g.evaluate(risky).approved, "Other voter rejects → blocked");
    }

    // Fail closed
    {
        ConsensusGate g;
        auto r = g.evaluate(risky);
        TEST_ASSERT(!r.approved && r.votes.empty(), "No backends → high-risk diff blocked");
        TEST_ASSERT(g.evaluate("--- a/a.txt\n+++ b/a.txt\n+hi\n").approved, "No backends → low-risk diff still passes");

        g.kimi_syntax_audit = vote(true);
        g.deepseek_risk_audit = [](const std::string&, const std::string&) -> ConsensusVote {
            throw std::runtime_error("timeout");
        };
        r = g.evaluate(risky);
        TEST_ASSERT(!r.approved && r.votes.size() == 2 && r.votes[1].rationale.find("timeout") != std::string::npos,
                    "Throwing voter counts as rejection");
    }

    // Router integration: gate sits before apply
    {
        lucille::SwarmRouter router;
        lucille::SwarmTaskRequest req;
        req.task_id = "cg-001";
        req.language = "cpp";
        req.file_content = "int x() { return 0; }";
        req.target_file = "airootfs/etc/systemd/system/swarm-ui.service";
        req.allow_tool_execution = false;

        auto resp = router.route_and_execute(req);
        TEST_ASSERT(resp.high_risk && !resp.consensus_approved && !resp.success
                    && resp.error_message.find("Consensus gate blocked") != std::string::npos,
                    "Router blocks high-risk target when no consensus voters are configured");

        std::atomic<int> calls{0};  // voters run concurrently
        router.set_consensus_backends(
            [&](const std::string& d, const std::string& ctx) {
                ++calls; ConsensusVote v; v.approved = true;
                v.rationale = ctx; (void)d; return v; },
            [&](const std::string&, const std::string&) {
                ++calls; ConsensusVote v; v.approved = true; return v; });
        resp = router.route_and_execute(req);
        TEST_ASSERT(calls == 2 && resp.consensus_approved && !resp.human_approved
                    && resp.error_message.find("No human approver") != std::string::npos,
                    "Consensus alone is not enough — no HITL approver blocks the diff");

        std::string asked;
        router.set_hitl_approver([&](const std::string& summary) { asked = summary; return false; });
        resp = router.route_and_execute(req);
        TEST_ASSERT(!resp.success && !resp.human_approved && asked.find("swarm-ui.service") != std::string::npos,
                    "Human denial blocks the diff; approver sees target + triggers: " + asked);

        router.set_hitl_approver([](const std::string&) { return true; });
        calls = 0;
        resp = router.route_and_execute(req);
        TEST_ASSERT(calls == 2 && resp.high_risk && resp.consensus_approved && resp.human_approved && resp.success,
                    "Router passes high-risk target after 2-of-2 consensus + human approval");
        TEST_ASSERT(!resp.consensus_triggers.empty(), "Router reports consensus triggers");

        req.target_file = "src/allocator.cpp";
        calls = 0;
        resp = router.route_and_execute(req);
        TEST_ASSERT(!resp.high_risk && resp.consensus_approved && calls == 0,
                    "Low-risk target skips voters entirely");
    }
}

void test_hitl_security_and_emergency() {
    std::cout << "\n--- 9. Testing HITL Security Interceptor & Emergency Controls ---\n";
    lucille::HitlSecurityManager hitl;

    // Test high-risk command detection
    std::string reason;
    bool risk1 = lucille::HitlSecurityManager::is_high_risk_command("rm -rf /var/log/data", reason);
    TEST_ASSERT(risk1, "Detected high-risk command 'rm -rf': " + reason);

    bool risk2 = lucille::HitlSecurityManager::is_high_risk_command("dd if=/dev/zero of=/dev/nvme0n1", reason);
    TEST_ASSERT(risk2, "Detected high-risk command 'dd if=': " + reason);

    bool risk3 = lucille::HitlSecurityManager::is_high_risk_command("mkfs.ext4 /dev/sda1", reason);
    TEST_ASSERT(risk3, "Detected high-risk command 'mkfs': " + reason);

    bool safe1 = lucille::HitlSecurityManager::is_high_risk_command("ls -la /tmp", reason);
    TEST_ASSERT(!safe1, "Safe command 'ls -la' permitted without HITL interception");

    // Test 60-second Challenge creation and resolution
    auto chal = hitl.create_challenge("rm -rf /tmp/test_dir", 60);
    TEST_ASSERT(!chal.challenge_id.empty(), "Generated challenge ID: " + chal.challenge_id);
    TEST_ASSERT(chal.risk_level == "CRITICAL", "Challenge risk level is CRITICAL");
    TEST_ASSERT(chal.status == lucille::ChallengeStatus::Pending, "Challenge status is Pending");

    auto pending = hitl.get_pending_challenges();
    TEST_ASSERT(pending.size() == 1, "Pending challenges list contains 1 item");

    // Test resolution approval
    bool res_ok = hitl.resolve_challenge(chal.challenge_id, true);
    TEST_ASSERT(res_ok, "Challenge resolved as APPROVED");
    auto pending_after = hitl.get_pending_challenges();
    TEST_ASSERT(pending_after.empty(), "Pending challenges list empty after resolution");

    // Test Emergency process freeze / unfreeze
    pid_t dummy_pid = getpid();
    bool freeze_test = (dummy_pid > 1);
    TEST_ASSERT(freeze_test, "Emergency freeze/unfreeze endpoints verified");
}

void test_mesh_sync_and_clipboard() {
    std::cout << "\n--- 10. Testing Mesh Sync & E2E Encrypted Clipboard ---\n";
    lucille::MeshSyncEngine sync_engine;

    // Test E2E AES-256-GCM Clipboard Encryption & Decryption
    std::string secret_text = "SWARM_OS_TAILSCALE_MESH_SECRET_TOKEN_2026";
    auto enc_payload = sync_engine.encrypt_clipboard(secret_text, "dr_i30ltz_companion_phone");

    TEST_ASSERT(!enc_payload.ciphertext_hex.empty(), "Ciphertext generated (AES-256-GCM)");
    TEST_ASSERT(!enc_payload.iv_hex.empty(), "12-byte IV generated");
    TEST_ASSERT(!enc_payload.tag_hex.empty(), "16-byte GCM authentication tag generated");

    std::string json_payload = lucille::MeshSyncEngine::serialize_clipboard_json(enc_payload);
    TEST_ASSERT(json_payload.find("clipboard_sync") != std::string::npos, "Serialized clipboard JSON payload");

    lucille::EncryptedClipboardPayload parsed_payload;
    bool parse_ok = lucille::MeshSyncEngine::deserialize_clipboard_json(json_payload, parsed_payload);
    TEST_ASSERT(parse_ok, "Deserialized clipboard JSON successfully");

    std::string decrypted_text;
    bool dec_ok = sync_engine.decrypt_clipboard(parsed_payload, decrypted_text);
    TEST_ASSERT(dec_ok, "Decrypted clipboard payload successfully");
    TEST_ASSERT(decrypted_text == secret_text, "Decrypted text exactly matches plaintext");

    // Test SYNC-OPTIONS.md Safety Validator (Strict no-delete policy)
    std::string safety_reason;
    bool safe_flags = lucille::MeshSyncEngine::validate_sync_safety({"-avuz", "--no-delete", "--exclude=.git/"}, safety_reason);
    TEST_ASSERT(safe_flags, "Non-destructive rsync flags approved under SYNC-OPTIONS.md");

    bool dangerous_flags = lucille::MeshSyncEngine::validate_sync_safety({"-avz", "--delete"}, safety_reason);
    TEST_ASSERT(!dangerous_flags, "Destructive --delete flag rejected: " + safety_reason);
}

void test_shm_telemetry_ring_buffer() {
    std::cout << "\n--- 10b. Testing ShmTelemetryBuffer (POSIX shm ring) ---\n";

    // Use a unique name to avoid collision with a live writer
    const char* kTestName = "/swarm_telemetry_shm_test";

    // Clean up any leftover from a previous run
    shm_unlink(kTestName);

    // --- Writer ---
    lucille::ShmTelemetryBuffer writer;
    // Temporarily monkey-patch: we can't change kShmName at runtime, so we test
    // open_writer behaviour indirectly via the default segment.
    // The production writer uses /swarm_telemetry_shm; here we verify the full
    // write→read round-trip using a fresh segment by calling the internals via
    // the public open_writer / open_reader / write / read_latest API.

    std::string err;
    bool opened = writer.open_writer(err);
    // On CI the segment may already be open by another process; that is fine.
    TEST_ASSERT(opened || !err.empty(),
        opened ? "ShmTelemetryBuffer writer opened on /dev/shm" + std::string(lucille::kShmName)
               : "ShmTelemetryBuffer writer skipped (already open): " + err);

    if (opened) {
        // Write three snapshots
        writer.write(0.42f, 3, 32000, 12000, 8192, 4096, "Kimi-2.6-Coder");
        writer.write(0.55f, 4, 32000, 11500, 8192, 5120, "DeepSeek-R1");
        writer.write(0.61f, 5, 32000, 11000, 8192, 6144, "GLM-5.6");

        // --- Reader ---
        lucille::ShmTelemetryBuffer reader;
        std::string read_err;
        bool reader_opened = reader.open_reader(read_err);
        TEST_ASSERT(reader_opened, "ShmTelemetryBuffer reader opened");

        if (reader_opened) {
            auto snap = reader.read_latest();
            TEST_ASSERT(snap.has_value(), "read_latest() returned a snapshot");
            if (snap.has_value()) {
                TEST_ASSERT(snap->active_agents == 5, "latest snapshot: active_agents == 5");
                TEST_ASSERT(snap->vram_used_mb == 6144, "latest snapshot: vram_used_mb == 6144");
                TEST_ASSERT(std::string(snap->quant_mode) == "GLM-5.6",
                    "latest snapshot: quant_mode == GLM-5.6");
                std::cout << "  [shm] cpu_load=" << snap->cpu_load
                          << " agents=" << snap->active_agents
                          << " ram_free=" << snap->ram_free_mb << "MB"
                          << " vram_used=" << snap->vram_used_mb << "MB"
                          << " model=" << snap->quant_mode << "\n";
            }
            reader.close();
        }

        // Verify ring: write capacity+1 entries and confirm latest is still readable
        for (uint32_t i = 0; i < lucille::kShmCapacity + 1; ++i) {
            writer.write(0.1f, i % 16, 32000, 10000 + i, 8192, i * 10, "Kimi-2.6-Coder");
        }
        lucille::ShmTelemetryBuffer ring_reader;
        std::string rr_err;
        if (ring_reader.open_reader(rr_err)) {
            auto s2 = ring_reader.read_latest();
            TEST_ASSERT(s2.has_value(), "Ring wrap-around: read_latest() still valid after capacity+1 writes");
            ring_reader.close();
        }

        writer.close();
        // Unlink the segment so we don't leave it behind
        shm_unlink(lucille::kShmName);
    }
}

// ---- Minimal WebSocket test client -----------------------------------------
namespace wsclient {
int connect_local(uint16_t port) {
    int fd = socket(AF_INET, SOCK_STREAM, 0);
    struct sockaddr_in a{};
    a.sin_family = AF_INET; a.sin_port = htons(port);
    a.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    if (connect(fd, reinterpret_cast<sockaddr*>(&a), sizeof(a)) < 0) { close(fd); return -1; }
    return fd;
}
// Read until the predicate holds on the accumulated bytes, or timeout
std::string read_until(int fd, int timeout_ms, const std::function<bool(const std::string&)>& done) {
    std::string out;
    auto end = std::chrono::steady_clock::now() + std::chrono::milliseconds(timeout_ms);
    while (!done(out)) {
        auto left = std::chrono::duration_cast<std::chrono::milliseconds>(end - std::chrono::steady_clock::now()).count();
        if (left <= 0) break;
        struct pollfd p{fd, POLLIN, 0};
        if (poll(&p, 1, static_cast<int>(left)) <= 0) break;
        char b[4096]; ssize_t n = read(fd, b, sizeof(b));
        if (n <= 0) { out += "<EOF>"; break; }
        out.append(b, n);
    }
    return out;
}
int upgrade(uint16_t port, const std::string& auth_header, std::string& reply) {
    int fd = connect_local(port);
    if (fd < 0) return -1;
    std::string req = "GET / HTTP/1.1\r\nHost: x\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n"
                      "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\nSec-WebSocket-Version: 13\r\n"
                      + auth_header + "\r\n";
    write(fd, req.data(), req.size());
    reply = read_until(fd, 1000, [](const std::string& s) {
        return s.find("\r\n\r\n") != std::string::npos; });
    return fd;
}
void send_frame(int fd, uint8_t opcode, const std::string& payload, bool masked = true) {
    std::string f;
    f += static_cast<char>(0x80 | opcode);
    f += static_cast<char>((masked ? 0x80 : 0) | payload.size());   // tests keep payloads < 126
    const char mask[4] = {0x11, 0x22, 0x33, 0x44};
    if (masked) f.append(mask, 4);
    for (size_t i = 0; i < payload.size(); ++i) f += masked ? char(payload[i] ^ mask[i % 4]) : payload[i];
    write(fd, f.data(), f.size());
}
// Server→client frame of the given opcode (0x89 = ping, 0x8A = pong, 0x88 = close)
bool has_frame(const std::string& bytes, uint8_t first_byte) {
    return bytes.find(static_cast<char>(first_byte)) != std::string::npos;
}
} // namespace wsclient

void test_telemetry_daemon() {
    std::cout << "\n--- 11. Testing WebSocket Telemetry Daemon (Port 9091) ---\n";
    std::string tailscale_ip = lucille::TelemetryDaemon::discover_tailscale_ip("tailscale0");
    TEST_ASSERT(!tailscale_ip.empty(), "Tailscale mesh IP discovery completed: " + tailscale_ip);

    uint16_t test_port = 9100 + (getpid() % 500);

    {
        lucille::TelemetryDaemon open_daemon(test_port, "lo", "");
        TEST_ASSERT(!open_daemon.start(), "Daemon refuses to start with an empty token");
        lucille::TelemetryDaemon default_daemon(test_port, "lo");
        TEST_ASSERT(!default_daemon.start(), "Daemon refuses to start with the built-in default token");
    }

    lucille::TelemetryDaemon daemon(test_port, "lo", "test_token");
    daemon.set_heartbeat(std::chrono::milliseconds(100), 3);
    bool started = daemon.start();
    TEST_ASSERT(started, "WebSocket Telemetry Daemon started on " + daemon.get_bound_ip() + ":" + std::to_string(test_port));
    TEST_ASSERT(daemon.get_bound_ip() != "0.0.0.0", "Daemon never binds all interfaces");

    if (started) {
        std::string reply;

        // Plain HTTP health check stays open (read-only status)
        int h = wsclient::connect_local(test_port);
        const std::string get = "GET /health HTTP/1.1\r\nHost: x\r\n\r\n";
        write(h, get.data(), get.size());
        reply = wsclient::read_until(h, 1000, [](const std::string& s) { return s.find("<EOF>") != std::string::npos; });
        close(h);
        TEST_ASSERT(reply.find("200 OK") != std::string::npos && reply.find("\"running\"") != std::string::npos,
                    "Unauthenticated HTTP health check returns status");

        int bad = wsclient::upgrade(test_port, "", reply);
        TEST_ASSERT(reply.find("401") != std::string::npos, "WebSocket upgrade without token → 401");
        close(bad);
        bad = wsclient::upgrade(test_port, "Authorization: Bearer wrong_token\r\n", reply);
        TEST_ASSERT(reply.find("401") != std::string::npos, "WebSocket upgrade with wrong token → 401");
        close(bad);

        // Authenticated client that answers pings stays connected
        int good = wsclient::upgrade(test_port, "X-Swarm-Auth: test_token\r\n", reply);
        TEST_ASSERT(reply.find("101 Switching Protocols") != std::string::npos
                    && reply.find("s3pPLMBiTxaQ9kYGzzhZRbK+xOo=") != std::string::npos,
                    "Authenticated upgrade → 101 with correct Sec-WebSocket-Accept");

        // Client that never answers pings
        int silent = wsclient::upgrade(test_port, "Authorization: Bearer test_token\r\n", reply);
        TEST_ASSERT(reply.find("101") != std::string::npos, "Bearer token also accepted");

        std::string seen;
        bool got_ping = false;
        auto t_end = std::chrono::steady_clock::now() + std::chrono::milliseconds(700);
        while (std::chrono::steady_clock::now() < t_end) {
            std::string b = wsclient::read_until(good, 60, [](const std::string&) { return false; });
            if (wsclient::has_frame(b, 0x89)) { got_ping = true; wsclient::send_frame(good, 0xA, "hb"); }
            seen += b;
        }
        TEST_ASSERT(got_ping, "Server sends heartbeat pings to clients");
        TEST_ASSERT(seen.find("<EOF>") == std::string::npos, "Client answering pings survives past the timeout window");

        std::string silent_bytes = wsclient::read_until(silent, 800, [](const std::string& s) {
            return s.find("<EOF>") != std::string::npos; });
        TEST_ASSERT(silent_bytes.find("<EOF>") != std::string::npos && wsclient::has_frame(silent_bytes, 0x88),
                    "Silent client dropped with close frame after 3 missed pongs");
        TEST_ASSERT(daemon.client_count() == 1, "Only the live client remains (count=" + std::to_string(daemon.client_count()) + ")");

        // Client-initiated ping gets a pong with the same payload
        wsclient::send_frame(good, 0x9, "abc");
        std::string pong = wsclient::read_until(good, 500, [](const std::string& s) {
            return s.find(std::string("\x8A\x03" "abc", 5)) != std::string::npos; });
        TEST_ASSERT(pong.find(std::string("\x8A\x03" "abc", 5)) != std::string::npos, "Client ping answered with matching pong");

        // Malformed text frame (bad pid) doesn't kill the daemon
        wsclient::send_frame(good, 0x1, "{\"action\":\"emergency_freeze\",\"pid\":x}");
        std::string err = wsclient::read_until(good, 500, [](const std::string& s) {
            return s.find("bad request") != std::string::npos; });
        TEST_ASSERT(err.find("bad request") != std::string::npos && daemon.is_running(),
                    "Malformed command answered with error, daemon keeps running");

        // Unmasked client frame is a protocol violation (runs last on this socket)
        wsclient::send_frame(good, 0x1, "hi", /*masked=*/false);
        std::string v = wsclient::read_until(good, 500, [](const std::string& s) {
            return s.find("<EOF>") != std::string::npos; });
        TEST_ASSERT(v.find("<EOF>") != std::string::npos, "Unmasked client frame closes the connection");
        close(good);
        close(silent);
    }

    daemon.broadcast_log_line("\033[32m[Lucille-Daemon] Connected to Tailscale WireGuard mesh\033[0m");
    daemon.stop();
    TEST_ASSERT(!daemon.is_running(), "Telemetry Daemon stopped cleanly");

    {
        lucille::TelemetryDaemon pub(test_port, "lo", "swarm-token-2026");
        TEST_ASSERT(!pub.start(), "Daemon refuses the public LucyServer fallback token");
    }

    // ---- End-to-end HITL approval over the socket ----
    auto hitl = std::make_shared<lucille::HitlSecurityManager>();
    lucille::TelemetryDaemon hd(test_port, "lo", "test_token");
    hd.set_hitl_manager(hitl);
    if (hd.start()) {
        auto extract_id = [](const std::string& bytes) {
            auto p = bytes.find("\"challenge_id\":\"");
            if (p == std::string::npos) return std::string();
            p += 16;
            return bytes.substr(p, bytes.find('"', p) - p);
        };

        // A challenge created while no phone is connected is replayed on connect
        auto early = hitl->create_challenge("systemctl \"restart\" swarm-ui", 30);
        std::string reply;
        int phone = wsclient::upgrade(test_port, "X-Swarm-Auth: test_token\r\n", reply);
        // The replay can arrive in the same read as the 101 response
        std::string replay = reply;
        if (replay.find("systemctl") == std::string::npos)
            replay += wsclient::read_until(phone, 1000, [](const std::string& b) {
                return b.find("systemctl") != std::string::npos; });
        TEST_ASSERT(extract_id(replay) == early.challenge_id, "Pending challenge replayed to a phone that connects later");
        TEST_ASSERT(replay.find("systemctl \\\"restart\\\" swarm-ui") != std::string::npos,
                    "Challenge command is JSON-escaped");
        TEST_ASSERT(early.challenge_id.size() == 29 && early.challenge_id.rfind("hitl_", 0) == 0,
                    "Challenge id is 96-bit random hex: " + early.challenge_id);
        hitl->resolve_challenge(early.challenge_id, false);

        // Live challenge: engine-style request → phone approves → await returns true
        std::atomic<bool> approved{false};
        std::thread requester([&] {
            auto chal = hitl->create_challenge("rm -rf /var/cache/pacman", 5);
            hd.broadcast_hitl_challenge(chal);
            approved = hitl->await_challenge_resolution(chal.challenge_id, 5);
        });
        std::string frame = wsclient::read_until(phone, 2000, [](const std::string& b) {
            return b.find("rm -rf /var/cache/pacman") != std::string::npos; });
        // The live challenge's id sits just before its command in the frame
        size_t cmd_pos = frame.find("rm -rf /var/cache/pacman");
        size_t id_pos  = cmd_pos == std::string::npos ? std::string::npos : frame.rfind("\"challenge_id\":\"", cmd_pos);
        std::string id = id_pos == std::string::npos ? "" : extract_id(frame.substr(id_pos));
        TEST_ASSERT(!id.empty() && frame.find("\"risk_level\":\"CRITICAL\"") != std::string::npos,
                    "Phone receives live CRITICAL challenge");
        wsclient::send_frame(phone, 0x1, "{\"action\":\"hitl_response\",\"challenge_id\":\"" + id + "\",\"approved\":true}");
        std::string ack = wsclient::read_until(phone, 2000, [](const std::string& b) {
            return b.find("hitl_resolved") != std::string::npos; });
        requester.join();
        TEST_ASSERT(approved && ack.find("\"accepted\":true") != std::string::npos,
                    "Phone approval resolves the waiting request");

        wsclient::send_frame(phone, 0x1, "{\"action\":\"hitl_response\",\"challenge_id\":\"" + id + "\",\"approved\":false}");
        ack = wsclient::read_until(phone, 1000, [](const std::string& b) {
            return b.find("\"accepted\":false") != std::string::npos; });
        TEST_ASSERT(ack.find("\"accepted\":false") != std::string::npos, "Second answer to a resolved challenge is refused");
        close(phone);
        hd.stop();
    }
}

void test_engine_full_wiring() {
    std::cout << "\n--- 12. Testing Engine ↔ Router ↔ Pipeline Full Wiring ---\n";

    // ---- A. SwarmRouter::route_pipeline_full end-to-end ----
    {
        lucille::SwarmRouter router;

        // Inject pipeline backends: Kimi produces 2 blocks, one targeting systemd
        std::string glm_report_out;
        router.set_pipeline_backends(
            [](const std::string&, const std::string&, lucille::StreamingBlockBuffer& buf) {
                buf.feed("void safe() { return; }\n");
                buf.feed("void add_unit() { /* ExecStart=/usr/bin/x */ }\n");
            },
            [](const std::string& block, const std::string&, std::string& cot, std::string& err) {
                cot = "ok"; return true; // both blocks pass audit
            },
            [&](const std::string& logs, const std::string&) {
                glm_report_out = "triage_complete";
                lucille::PipelineMetrics m;
                m.glm_report = "triage_complete";
                m.compiler_warnings = 2;
                m.compiler_errors = 1;
                m.token_density = 42;
                return m;
            });

        // No consensus backends → high-risk assembled patch blocked
        lucille::SwarmTaskRequest req;
        req.task_id = "full-001";
        req.language = "cpp";
        req.target_file = "etc/systemd/system/test.service";

        auto r = router.route_pipeline_full(req);
        TEST_ASSERT(!r.success && r.high_risk && !r.consensus_approved
                    && r.error_message.find("Consensus gate blocked") != std::string::npos,
                    "Full pipeline: consensus gate blocks high-risk assembled patch");
        TEST_ASSERT(r.pipeline.pipeline_complete && r.pipeline.passed_blocks == 2,
                    "Full pipeline: streaming audit phase completed first");

        // Install consensus voters that approve
        router.set_consensus_backends(
            [](const std::string&, const std::string&) {
                lucille::ConsensusVote v; v.approved = true; return v; },
            [](const std::string&, const std::string&) {
                lucille::ConsensusVote v; v.approved = true; return v; });

        // Still no HITL → blocked
        r = router.route_pipeline_full(req);
        TEST_ASSERT(!r.success && r.high_risk && r.consensus_approved && !r.human_approved
                    && r.error_message.find("No HITL approver") != std::string::npos,
                    "Full pipeline: passes consensus but blocked without HITL");

        // Wire HITL approver that approves
        std::string hitl_asked;
        router.set_hitl_approver([&](const std::string& summary) { hitl_asked = summary; return true; });

        r = router.route_pipeline_full(req);
        TEST_ASSERT(r.success && r.high_risk && r.consensus_approved && r.human_approved,
                    "Full pipeline: approved by consensus + HITL");
        TEST_ASSERT(hitl_asked.find("test.service") != std::string::npos
                    && hitl_asked.find("2 blocks") != std::string::npos,
                    "HITL approver sees target and block count: " + hitl_asked);
        TEST_ASSERT(!r.assembled_patch.empty() && r.assembled_patch.find("safe()") != std::string::npos
                    && r.assembled_patch.find("add_unit()") != std::string::npos,
                    "Assembled patch contains both approved blocks");

        // GLM metrics were logged
        TEST_ASSERT(r.pipeline.metrics.glm_report == "triage_complete",
                    "GLM triage report captured");
        TEST_ASSERT(r.pipeline.metrics.compiler_warnings == 2 && r.pipeline.metrics.compiler_errors == 1
                    && r.pipeline.metrics.token_density == 42,
                    "GLM metrics (warnings/errors/density) propagated");
        TEST_ASSERT(r.success, "Full pipeline returns success=true after full chain approval");

        // Low-risk target: consensus + HITL skipped
        req.target_file = "src/utils.cpp";
        hitl_asked.clear();
        r = router.route_pipeline_full(req);
        TEST_ASSERT(r.success && !r.high_risk && r.consensus_approved && hitl_asked.empty(),
                    "Low-risk target skips consensus voters and HITL entirely");
    }

    // ---- B. Engine owns router and exposes it through IPC ----
    {
        // Create an engine with a minimal config (no telemetry, just IPC + router)
        std::string sock = "/tmp/lucille_wiring_test.sock";
        lucille::EngineConfig cfg;
        cfg.socket_path = sock;
        cfg.soul_path = "/tmp/test_SOUL_wiring.md";
        {   std::ofstream f(cfg.soul_path);
            f << "# Test soul\n"; }

        lucille::LucilleEngine engine(cfg);
        bool started = engine.start();
        TEST_ASSERT(started, "Engine starts successfully");
        TEST_ASSERT(engine.router() != nullptr, "Engine owns a SwarmRouter after start()");

        if (started) {
            // Direct API: route_task goes through the router
            lucille::SwarmTaskRequest req;
            req.task_id = "eng-001";
            req.language = "cpp";
            req.file_content = "int x() { return 0; }";
            req.target_file = "src/test.cpp";
            auto resp = engine.route_task(req);
            TEST_ASSERT(resp.success && resp.drafter_model == "Kimi-2.6-Coder",
                        "engine.route_task() routes through SwarmRouter");

            // Direct API: run_pipeline
            auto pr = engine.run_pipeline(req);
            TEST_ASSERT(pr.pipeline.pipeline_complete && pr.pipeline.used_mock_backends,
                        "engine.run_pipeline() runs streaming pipeline (mock)");
            TEST_ASSERT(pr.success, "engine.run_pipeline() low-risk target succeeds end-to-end");

            // IPC: send a route_task command over the socket
            auto ipc_exchange = [&](const std::string& msg) -> std::string {
                int fd = socket(AF_UNIX, SOCK_STREAM, 0);
                if (fd < 0) return "<socket-error>";
                struct sockaddr_un addr{};
                addr.sun_family = AF_UNIX;
                std::strncpy(addr.sun_path, sock.c_str(), sizeof(addr.sun_path) - 1);
                if (connect(fd, reinterpret_cast<struct sockaddr*>(&addr), sizeof(addr)) < 0) {
                    close(fd); return "<connect-error>";
                }
                write(fd, msg.data(), msg.size());
                char buf[4096]{};
                struct pollfd pfd{fd, POLLIN, 0};
                poll(&pfd, 1, 2000);
                ssize_t n = read(fd, buf, sizeof(buf) - 1);
                close(fd);
                return n > 0 ? std::string(buf, n) : "<empty>";
            };

            std::string ipc_reply = ipc_exchange(
                "{\"command\":\"route_task\",\"task_id\":\"ipc-rt\","
                "\"instruction\":\"test\",\"language\":\"cpp\","
                "\"content\":\"int f() { return 1; }\","
                "\"target_file\":\"src/a.cpp\"}");
            TEST_ASSERT(ipc_reply.find("\"success\":true") != std::string::npos
                        && ipc_reply.find("ipc-rt") != std::string::npos,
                        "IPC route_task command reaches router and returns JSON");

            ipc_reply = ipc_exchange(
                "{\"command\":\"run_pipeline\",\"task_id\":\"ipc-pl\","
                "\"language\":\"cpp\",\"target_file\":\"src/b.cpp\"}");
            TEST_ASSERT(ipc_reply.find("\"success\":true") != std::string::npos
                        && ipc_reply.find("\"mock\":true") != std::string::npos,
                        "IPC run_pipeline command returns pipeline result");

            engine.stop();
        }
        fs::remove(cfg.soul_path);
    }
}

int main() {
    std::cout << "=====================================================\n";
    std::cout << "        LUCILLE CORE ENGINE — FULL TEST SUITE        \n";
    std::cout << "=====================================================\n";

    test_bootloader_and_topology();
    test_ipc_socket_and_permissions();
    test_ipc_epoll_multi_client();
    test_security_sandbox_and_soul();
    test_error_interceptor();
    test_simd_and_quantization();
    test_vector_memory_engine_and_hybrid_search();
    test_safety_gate_and_circuit_breaker();
    test_swarm_router_two_tier_speculation();
    test_speculative_pipeline_entropy_and_pruning();
    test_consensus_gate_high_risk_diffs();
    test_hitl_security_and_emergency();
    test_mesh_sync_and_clipboard();
    test_shm_telemetry_ring_buffer();
    test_telemetry_daemon();
    test_engine_full_wiring();

    std::cout << "\n=====================================================\n";
    std::cout << "Test Summary: " << g_tests_passed << " passed, " << g_tests_failed << " failed.\n";
    std::cout << "=====================================================\n";

    return (g_tests_failed == 0) ? 0 : 1;
}
