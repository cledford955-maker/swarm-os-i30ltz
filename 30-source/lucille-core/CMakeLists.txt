cmake_minimum_required(VERSION 3.20)
project(lucille_core LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# AVX2, FMA & Optimization Compiler Flags
add_compile_options(-Wall -Wextra -Wpedantic -Wno-unused-parameter -pthread -O3 -mavx2 -mfma)

find_package(OpenSSL REQUIRED)
find_package(SQLite3 REQUIRED)
find_package(Threads REQUIRED)
find_package(CURL REQUIRED)

include_directories(
    ${CMAKE_CURRENT_SOURCE_DIR}/include
    ${OPENSSL_INCLUDE_DIR}
    ${SQLITE3_INCLUDE_DIRS}
    ${CURL_INCLUDE_DIRS}
)

# Core engine library
add_library(lucille_engine_lib STATIC
    src/bootloader.cpp
    src/ipc_server.cpp
    src/security_sandbox.cpp
    src/error_interceptor.cpp
    src/affinity_manager.cpp
    src/process_manager.cpp
    src/simd_quant.cpp
    src/vector_memory.cpp
    src/safety_gate.cpp
    src/checkpoint_journal.cpp
    src/swarm_router.cpp
    src/hitl_security.cpp
    src/mesh_sync.cpp
    src/telemetry_daemon.cpp
    src/shm_telemetry.cpp
    src/entropy_filter.cpp
    src/speculative_pipeline.cpp
    src/consensus_gate.cpp
    src/http_client.cpp
    src/openrouter_backends.cpp
    src/engine.cpp
)

target_link_libraries(lucille_engine_lib PUBLIC
    OpenSSL::Crypto
    SQLite3::SQLite3
    Threads::Threads
    CURL::libcurl
    stdc++fs
    m
    rt
)

# Daemon executable
add_executable(lucille-core
    src/main.cpp
)

target_link_libraries(lucille-core PRIVATE
    lucille_engine_lib
)

# Test executable
enable_testing()
add_executable(test_engine
    tests/test_engine.cpp
)

target_link_libraries(test_engine PRIVATE
    lucille_engine_lib
)

add_test(NAME EngineTestSuite COMMAND test_engine)
