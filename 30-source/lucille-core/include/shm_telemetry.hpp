#pragma once

#include <string>
#include <cstdint>
#include <atomic>
#include <optional>

namespace lucille {

static constexpr uint64_t kShmMagic     = 0x5357524D54454C4DUL; // "SWRMTELM"
static constexpr uint32_t kShmVersion   = 1;
static constexpr uint32_t kShmCapacity  = 256; // must be power of 2
static constexpr const char* kShmName   = "/swarm_telemetry_shm"; // → /dev/shm/swarm_telemetry_shm

// Plain-data telemetry snapshot — no pointers, safe across process boundaries.
struct alignas(128) ShmTelemetrySlot {
    std::atomic<uint64_t> sequence;  // seqlock: odd = write in progress, even = committed
    uint64_t  timestamp_ns;
    float     cpu_load;
    uint32_t  active_agents;
    uint64_t  ram_total_mb;
    uint64_t  ram_free_mb;
    uint64_t  vram_total_mb;
    uint64_t  vram_used_mb;
    char      quant_mode[16];
    uint8_t   _pad[56];
};
static_assert(sizeof(ShmTelemetrySlot) == 128, "ShmTelemetrySlot must be exactly 128 bytes");

struct alignas(64) ShmTelemetryHeader {
    uint64_t              magic;        // kShmMagic
    uint32_t              version;      // kShmVersion
    uint32_t              capacity;     // number of slots
    std::atomic<uint64_t> write_pos;    // monotonic counter; slot = write_pos % capacity
    uint64_t              created_at_ns;
    uint8_t               _pad[32];
};
static_assert(sizeof(ShmTelemetryHeader) == 64, "ShmTelemetryHeader must be exactly 64 bytes");

// Total shm region size
static constexpr size_t kShmSize = sizeof(ShmTelemetryHeader) + kShmCapacity * sizeof(ShmTelemetrySlot);

struct ShmSnapshot {
    uint64_t timestamp_ns;
    float    cpu_load;
    uint32_t active_agents;
    uint64_t ram_total_mb;
    uint64_t ram_free_mb;
    uint64_t vram_total_mb;
    uint64_t vram_used_mb;
    char     quant_mode[16];
};

// Lock-free seqlock ring buffer over POSIX shared memory.
// Single-writer safe; multiple readers safe.
class ShmTelemetryBuffer {
public:
    ShmTelemetryBuffer() = default;
    ~ShmTelemetryBuffer();

    ShmTelemetryBuffer(const ShmTelemetryBuffer&) = delete;
    ShmTelemetryBuffer& operator=(const ShmTelemetryBuffer&) = delete;

    // Writer: create or re-open the shm region. Returns false on failure.
    bool open_writer(std::string& err_msg);

    // Reader: open an existing shm region (read-only). Returns false if not yet created.
    bool open_reader(std::string& err_msg);

    // Write a new snapshot. Thread-safe for a single concurrent writer.
    void write(float cpu_load, uint32_t active_agents,
               uint64_t ram_total_mb, uint64_t ram_free_mb,
               uint64_t vram_total_mb, uint64_t vram_used_mb,
               const char* quant_mode);

    // Read the most recently committed snapshot. Returns nullopt if buffer is empty.
    std::optional<ShmSnapshot> read_latest() const;

    void close();
    bool is_open() const { return mapped_ != nullptr; }

private:
    void*              mapped_{nullptr};
    size_t             mapped_size_{0};
    int                shm_fd_{-1};
    bool               is_writer_{false};

    ShmTelemetryHeader* header() const;
    ShmTelemetrySlot*   slots()  const;

    static uint64_t now_ns();
};

} // namespace lucille
