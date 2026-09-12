#include "shm_telemetry.hpp"

#include <fcntl.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <unistd.h>
#include <time.h>
#include <cerrno>
#include <cstring>
#include <cstdio>
#include <atomic>

namespace lucille {

uint64_t ShmTelemetryBuffer::now_ns() {
    struct timespec ts;
    clock_gettime(CLOCK_REALTIME, &ts);
    return static_cast<uint64_t>(ts.tv_sec) * 1'000'000'000ULL + static_cast<uint64_t>(ts.tv_nsec);
}

ShmTelemetryHeader* ShmTelemetryBuffer::header() const {
    return static_cast<ShmTelemetryHeader*>(mapped_);
}

ShmTelemetrySlot* ShmTelemetryBuffer::slots() const {
    return reinterpret_cast<ShmTelemetrySlot*>(
        static_cast<char*>(mapped_) + sizeof(ShmTelemetryHeader));
}

bool ShmTelemetryBuffer::open_writer(std::string& err_msg) {
    int fd = shm_open(kShmName, O_CREAT | O_RDWR, 0660);
    if (fd < 0) {
        err_msg = std::string("shm_open(writer) failed: ") + strerror(errno);
        return false;
    }

    if (ftruncate(fd, static_cast<off_t>(kShmSize)) < 0) {
        err_msg = std::string("ftruncate failed: ") + strerror(errno);
        ::close(fd);
        return false;
    }

    void* ptr = mmap(nullptr, kShmSize, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
    if (ptr == MAP_FAILED) {
        err_msg = std::string("mmap(writer) failed: ") + strerror(errno);
        ::close(fd);
        return false;
    }

    shm_fd_     = fd;
    mapped_     = ptr;
    mapped_size_= kShmSize;
    is_writer_  = true;

    // Initialize header if magic doesn't match
    auto* hdr = header();
    if (hdr->magic != kShmMagic) {
        memset(ptr, 0, kShmSize);
        hdr->magic        = kShmMagic;
        hdr->version      = kShmVersion;
        hdr->capacity     = kShmCapacity;
        hdr->write_pos.store(0, std::memory_order_release);
        hdr->created_at_ns= now_ns();
    }

    return true;
}

bool ShmTelemetryBuffer::open_reader(std::string& err_msg) {
    int fd = shm_open(kShmName, O_RDONLY, 0);
    if (fd < 0) {
        err_msg = std::string("shm_open(reader) failed: ") + strerror(errno);
        return false;
    }

    void* ptr = mmap(nullptr, kShmSize, PROT_READ, MAP_SHARED, fd, 0);
    if (ptr == MAP_FAILED) {
        err_msg = std::string("mmap(reader) failed: ") + strerror(errno);
        ::close(fd);
        return false;
    }

    shm_fd_     = fd;
    mapped_     = ptr;
    mapped_size_= kShmSize;
    is_writer_  = false;

    auto* hdr = header();
    if (hdr->magic != kShmMagic) {
        munmap(ptr, kShmSize);
        ::close(fd);
        mapped_ = nullptr;
        err_msg = "Shared memory region not yet initialized by writer";
        return false;
    }

    return true;
}

void ShmTelemetryBuffer::write(float cpu_load, uint32_t active_agents,
                                uint64_t ram_total_mb, uint64_t ram_free_mb,
                                uint64_t vram_total_mb, uint64_t vram_used_mb,
                                const char* quant_mode) {
    if (!mapped_ || !is_writer_) return;

    auto* hdr = header();
    // Claim a position with fetch_add; wrap via modulo with power-of-2 capacity
    uint64_t pos = hdr->write_pos.fetch_add(1, std::memory_order_relaxed);
    uint32_t idx = static_cast<uint32_t>(pos % kShmCapacity);
    ShmTelemetrySlot& slot = slots()[idx];

    // Seqlock: mark write in progress (odd sequence)
    uint64_t seq = slot.sequence.load(std::memory_order_relaxed);
    slot.sequence.store(seq + 1, std::memory_order_release); // now odd → readers spin
    std::atomic_thread_fence(std::memory_order_release);

    slot.timestamp_ns   = now_ns();
    slot.cpu_load       = cpu_load;
    slot.active_agents  = active_agents;
    slot.ram_total_mb   = ram_total_mb;
    slot.ram_free_mb    = ram_free_mb;
    slot.vram_total_mb  = vram_total_mb;
    slot.vram_used_mb   = vram_used_mb;
    if (quant_mode) {
        strncpy(slot.quant_mode, quant_mode, sizeof(slot.quant_mode) - 1);
        slot.quant_mode[sizeof(slot.quant_mode) - 1] = '\0';
    } else {
        slot.quant_mode[0] = '\0';
    }

    std::atomic_thread_fence(std::memory_order_release);
    // Commit: bump sequence to even → readers see a stable snapshot
    slot.sequence.store(seq + 2, std::memory_order_release);
}

std::optional<ShmSnapshot> ShmTelemetryBuffer::read_latest() const {
    if (!mapped_) return std::nullopt;

    auto* hdr = header();
    uint64_t wp = hdr->write_pos.load(std::memory_order_acquire);
    if (wp == 0) return std::nullopt;

    // Most recent slot = (write_pos - 1) % capacity
    uint32_t idx = static_cast<uint32_t>((wp - 1) % kShmCapacity);
    const ShmTelemetrySlot& slot = slots()[idx];

    // Seqlock read loop: retry if sequence is odd (write in progress) or changed
    for (int retry = 0; retry < 16; ++retry) {
        uint64_t seq_before = slot.sequence.load(std::memory_order_acquire);
        if (seq_before & 1u) continue; // write in progress

        std::atomic_thread_fence(std::memory_order_acquire);
        ShmSnapshot snap;
        snap.timestamp_ns  = slot.timestamp_ns;
        snap.cpu_load      = slot.cpu_load;
        snap.active_agents = slot.active_agents;
        snap.ram_total_mb  = slot.ram_total_mb;
        snap.ram_free_mb   = slot.ram_free_mb;
        snap.vram_total_mb = slot.vram_total_mb;
        snap.vram_used_mb  = slot.vram_used_mb;
        memcpy(snap.quant_mode, slot.quant_mode, sizeof(snap.quant_mode));
        std::atomic_thread_fence(std::memory_order_acquire);

        uint64_t seq_after = slot.sequence.load(std::memory_order_acquire);
        if (seq_before == seq_after) return snap;
        // Sequence changed mid-read — retry
    }

    return std::nullopt; // could not get a clean read in 16 tries
}

void ShmTelemetryBuffer::close() {
    if (mapped_) {
        munmap(mapped_, mapped_size_);
        mapped_ = nullptr;
    }
    if (shm_fd_ >= 0) {
        ::close(shm_fd_);
        shm_fd_ = -1;
    }
}

ShmTelemetryBuffer::~ShmTelemetryBuffer() {
    close();
}

} // namespace lucille
