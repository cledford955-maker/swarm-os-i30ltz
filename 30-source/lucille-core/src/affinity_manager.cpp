#include "affinity_manager.hpp"
#include <iostream>
#include <cstring>
#include <cerrno>

namespace lucille {

AffinityManager::AffinityManager(const HardwareTopology& topology)
    : p_cores_(topology.p_cores),
      e_cores_(topology.e_cores),
      total_logical_cores_(topology.logical_cores) {
    
    // Safety check: ensure we have at least 1 core in each set
    if (p_cores_.empty()) {
        p_cores_.push_back(0);
    }
    if (e_cores_.empty()) {
        e_cores_.push_back(total_logical_cores_ > 1 ? (total_logical_cores_ - 1) : 0);
    }
}

bool AffinityManager::pin_thread_to_cpu_set(pthread_t thread, const std::vector<uint32_t>& cores) {
    if (cores.empty()) return false;

    cpu_set_t cpuset;
    CPU_ZERO(&cpuset);

    for (uint32_t core_id : cores) {
        CPU_SET(core_id, &cpuset);
    }

    int rc = pthread_setaffinity_np(thread, sizeof(cpu_set_t), &cpuset);
    if (rc != 0) {
        std::cerr << "[AffinityManager] Warning: pthread_setaffinity_np failed: "
                  << strerror(rc) << "\n";
        return false;
    }
    return true;
}

bool AffinityManager::pin_thread_to_single_core(pthread_t thread, uint32_t core_id) {
    cpu_set_t cpuset;
    CPU_ZERO(&cpuset);
    CPU_SET(core_id, &cpuset);

    int rc = pthread_setaffinity_np(thread, sizeof(cpu_set_t), &cpuset);
    return (rc == 0);
}

bool AffinityManager::pin_thread_by_role(pthread_t thread, WorkerThreadRole role) {
    switch (role) {
        case WorkerThreadRole::InferencePillar:
        case WorkerThreadRole::SelfHealingWorker:
            return pin_thread_to_cpu_set(thread, p_cores_);
        case WorkerThreadRole::BackgroundIO:
        case WorkerThreadRole::EpollMultiplexer:
            return pin_thread_to_cpu_set(thread, e_cores_);
    }
    return false;
}

bool AffinityManager::pin_current_thread(WorkerThreadRole role) {
    return pin_thread_by_role(pthread_self(), role);
}

} // namespace lucille
