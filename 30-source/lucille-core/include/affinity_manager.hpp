#pragma once

#include <vector>
#include <cstdint>
#include <pthread.h>
#include <sched.h>
#include "bootloader.hpp"

namespace lucille {

enum class WorkerThreadRole {
    InferencePillar,    // P-cores
    BackgroundIO,       // E-cores
    EpollMultiplexer,   // E-cores
    SelfHealingWorker   // P-cores
};

class AffinityManager {
public:
    explicit AffinityManager(const HardwareTopology& topology);
    ~AffinityManager() = default;

    // Pin a specific thread according to its role
    bool pin_thread_by_role(pthread_t thread, WorkerThreadRole role);

    // Pin current calling thread
    bool pin_current_thread(WorkerThreadRole role);

    // Explicit core pinning
    static bool pin_thread_to_cpu_set(pthread_t thread, const std::vector<uint32_t>& cores);
    static bool pin_thread_to_single_core(pthread_t thread, uint32_t core_id);

    const std::vector<uint32_t>& get_p_cores() const { return p_cores_; }
    const std::vector<uint32_t>& get_e_cores() const { return e_cores_; }

private:
    std::vector<uint32_t> p_cores_;
    std::vector<uint32_t> e_cores_;
    uint32_t total_logical_cores_{1};
};

} // namespace lucille
