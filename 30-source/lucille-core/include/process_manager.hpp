#pragma once

#include <string>
#include <vector>
#include <map>
#include <memory>
#include <functional>
#include <thread>
#include <atomic>
#include <mutex>
#include <sys/epoll.h>
#include <sys/types.h>
#include "security_sandbox.hpp"

namespace lucille {

enum class ProcessStreamType {
    Stdout,
    Stderr
};

using OutputCallback = std::function<void(pid_t pid, ProcessStreamType stream_type, const std::string& data)>;
using ProcessExitCallback = std::function<void(pid_t pid, int exit_code)>;

struct SubAgentProcess {
    pid_t pid{-1};
    std::string command;
    std::string agent_name; // "Hermes Agent", "OpenClaw", "Kimi Coder", etc.
    int stdout_fd{-1};
    int stderr_fd{-1};
    bool is_sandboxed{true};
    std::string accumulated_stdout;
    std::string accumulated_stderr;
    int exit_code{-1};
    bool is_finished{false};
};

class ProcessManager {
public:
    ProcessManager(std::string cgroup_slice = "/sys/fs/cgroup/lucille.slice");
    ~ProcessManager();

    // Disable copy
    ProcessManager(const ProcessManager&) = delete;
    ProcessManager& operator=(const ProcessManager&) = delete;

    bool initialize(std::string& err_msg);
    void shutdown();

    // Spawn sub-agent process with no_new_privs, cgroup attachment, and non-blocking pipes
    pid_t spawn_agent(
        const std::string& agent_name,
        const std::vector<std::string>& argv,
        const std::string& working_dir = ".",
        bool enforce_sandbox = true,
        const std::map<std::string, std::string>& env_vars = {}
    );

    // Epoll event loop runner
    void run_epoll_loop();
    void stop_epoll_loop();

    // Callbacks
    void set_output_callback(OutputCallback cb) { output_callback_ = cb; }
    void set_exit_callback(ProcessExitCallback cb) { exit_callback_ = cb; }

    int get_epoll_fd() const { return epoll_fd_; }
    size_t get_active_process_count();

private:
    int epoll_fd_{-1};
    std::string cgroup_slice_;
    std::atomic<bool> is_running_{false};
    std::thread event_loop_thread_;
    std::mutex processes_mutex_;
    std::map<int, std::pair<pid_t, ProcessStreamType>> fd_to_process_;
    std::map<pid_t, std::shared_ptr<SubAgentProcess>> active_processes_;

    OutputCallback output_callback_;
    ProcessExitCallback exit_callback_;

    void handle_pipe_read(int fd);
    void check_child_termination();
};

} // namespace lucille
