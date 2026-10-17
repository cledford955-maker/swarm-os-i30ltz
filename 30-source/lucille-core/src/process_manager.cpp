#include "process_manager.hpp"
#include <unistd.h>
#include <fcntl.h>
#include <sys/wait.h>
#include <sys/prctl.h>
#include <cstring>
#include <cerrno>
#include <iostream>
#include <algorithm>

namespace lucille {

ProcessManager::ProcessManager(std::string cgroup_slice)
    : cgroup_slice_(std::move(cgroup_slice)) {}

ProcessManager::~ProcessManager() {
    shutdown();
}

bool ProcessManager::initialize(std::string& err_msg) {
    epoll_fd_ = epoll_create1(EPOLL_CLOEXEC);
    if (epoll_fd_ < 0) {
        err_msg = "Failed to create epoll fd: " + std::string(strerror(errno));
        return false;
    }
    is_running_ = true;
    return true;
}

void ProcessManager::shutdown() {
    is_running_ = false;
    if (event_loop_thread_.joinable()) {
        event_loop_thread_.join();
    }

    std::lock_guard<std::mutex> lock(processes_mutex_);
    for (auto& [pid, proc] : active_processes_) {
        if (!proc->is_finished && proc->pid > 0) {
            kill(proc->pid, SIGTERM);
        }
        if (proc->stdout_fd >= 0) close(proc->stdout_fd);
        if (proc->stderr_fd >= 0) close(proc->stderr_fd);
    }
    active_processes_.clear();
    fd_to_process_.clear();

    if (epoll_fd_ >= 0) {
        close(epoll_fd_);
        epoll_fd_ = -1;
    }
}

pid_t ProcessManager::spawn_agent(
    const std::string& agent_name,
    const std::vector<std::string>& argv,
    const std::string& working_dir,
    bool enforce_sandbox,
    const std::map<std::string, std::string>& env_vars
) {
    if (argv.empty() || epoll_fd_ < 0) {
        return -1;
    }

    int stdout_pipe[2];
    int stderr_pipe[2];

    if (pipe2(stdout_pipe, O_CLOEXEC) < 0) {
        return -1;
    }
    if (pipe2(stderr_pipe, O_CLOEXEC) < 0) {
        close(stdout_pipe[0]);
        close(stdout_pipe[1]);
        return -1;
    }

    pid_t pid = fork();
    if (pid < 0) {
        close(stdout_pipe[0]);
        close(stdout_pipe[1]);
        close(stderr_pipe[0]);
        close(stderr_pipe[1]);
        return -1;
    }

    if (pid == 0) {
        // Child Process
        close(stdout_pipe[0]);
        close(stderr_pipe[0]);

        // Duplicate pipes to STDOUT_FILENO and STDERR_FILENO
        dup2(stdout_pipe[1], STDOUT_FILENO);
        dup2(stderr_pipe[1], STDERR_FILENO);
        close(stdout_pipe[1]);
        close(stderr_pipe[1]);

        // Change working directory if provided
        if (!working_dir.empty()) {
            if (chdir(working_dir.c_str()) < 0) {
                // Ignore error and proceed
            }
        }

        // Apply Sandbox: Landlock LSM (read-only on /, read-write in working_dir)
        // Landlock internally sets PR_SET_NO_NEW_PRIVS; no separate call needed.
        if (enforce_sandbox) {
            auto ll = SecuritySandbox::apply_landlock_sandbox(working_dir);
            if (!ll.applied) {
                // Landlock unsupported — fall back to prctl-only sandbox
                std::string err;
                if (!SecuritySandbox::apply_no_new_privs(err)) {
                    std::cerr << "[SubAgent:" << agent_name << "] Fatal: could not enforce NO_NEW_PRIVS: " << err << "\n";
                    _exit(127);
                }
                std::cerr << "[SubAgent:" << agent_name << "] Landlock unavailable (" << ll.status_msg << "), prctl-only sandbox active\n";
            } else {
                std::cerr << "[SubAgent:" << agent_name << "] " << ll.status_msg << "\n";
            }
        }

        // Set custom environment variables
        for (const auto& [k, v] : env_vars) {
            setenv(k.c_str(), v.c_str(), 1);
        }

        // Prepare exec arguments
        std::vector<char*> c_argv;
        for (const auto& arg : argv) {
            c_argv.push_back(const_cast<char*>(arg.c_str()));
        }
        c_argv.push_back(nullptr);

        execvp(c_argv[0], c_argv.data());

        // If execvp fails
        std::cerr << "[SubAgent:" << agent_name << "] Failed to execute " << argv[0] << ": " << strerror(errno) << "\n";
        _exit(127);
    }

    // Parent Process
    close(stdout_pipe[1]);
    close(stderr_pipe[1]);

    // Attach to Cgroup v2
    if (!cgroup_slice_.empty()) {
        SecuritySandbox::attach_process_to_cgroup(cgroup_slice_, pid);
    }

    // Set non-blocking on read ends
    fcntl(stdout_pipe[0], F_SETFL, fcntl(stdout_pipe[0], F_GETFL, 0) | O_NONBLOCK);
    fcntl(stderr_pipe[0], F_SETFL, fcntl(stderr_pipe[0], F_GETFL, 0) | O_NONBLOCK);

    auto proc = std::make_shared<SubAgentProcess>();
    proc->pid = pid;
    proc->agent_name = agent_name;
    proc->command = argv[0];
    proc->stdout_fd = stdout_pipe[0];
    proc->stderr_fd = stderr_pipe[0];
    proc->is_sandboxed = enforce_sandbox;

    {
        std::lock_guard<std::mutex> lock(processes_mutex_);
        active_processes_[pid] = proc;
        fd_to_process_[stdout_pipe[0]] = {pid, ProcessStreamType::Stdout};
        fd_to_process_[stderr_pipe[0]] = {pid, ProcessStreamType::Stderr};
    }

    // Add read ends to epoll
    struct epoll_event ev_out;
    std::memset(&ev_out, 0, sizeof(ev_out));
    ev_out.events = EPOLLIN | EPOLLHUP | EPOLLERR;
    ev_out.data.fd = stdout_pipe[0];
    epoll_ctl(epoll_fd_, EPOLL_CTL_ADD, stdout_pipe[0], &ev_out);

    struct epoll_event ev_err;
    std::memset(&ev_err, 0, sizeof(ev_err));
    ev_err.events = EPOLLIN | EPOLLHUP | EPOLLERR;
    ev_err.data.fd = stderr_pipe[0];
    epoll_ctl(epoll_fd_, EPOLL_CTL_ADD, stderr_pipe[0], &ev_err);

    return pid;
}

void ProcessManager::handle_pipe_read(int fd) {
    char buffer[4096];
    ssize_t bytes = 0;

    pid_t pid = -1;
    ProcessStreamType stream_type = ProcessStreamType::Stdout;
    std::shared_ptr<SubAgentProcess> proc;

    {
        std::lock_guard<std::mutex> lock(processes_mutex_);
        auto it = fd_to_process_.find(fd);
        if (it != fd_to_process_.end()) {
            pid = it->second.first;
            stream_type = it->second.second;
            auto pit = active_processes_.find(pid);
            if (pit != active_processes_.end()) {
                proc = pit->second;
            }
        }
    }

    if (!proc) return;

    while ((bytes = read(fd, buffer, sizeof(buffer) - 1)) > 0) {
        buffer[bytes] = '\0';
        std::string chunk(buffer, bytes);

        if (stream_type == ProcessStreamType::Stdout) {
            proc->accumulated_stdout += chunk;
        } else {
            proc->accumulated_stderr += chunk;
        }

        if (output_callback_) {
            output_callback_(pid, stream_type, chunk);
        }
    }

    if (bytes == 0 || (bytes < 0 && errno != EAGAIN && errno != EWOULDBLOCK)) {
        // EOF or error: Remove from epoll
        epoll_ctl(epoll_fd_, EPOLL_CTL_DEL, fd, nullptr);
    }
}

void ProcessManager::check_child_termination() {
    int status = 0;
    pid_t finished_pid = 0;

    while ((finished_pid = waitpid(-1, &status, WNOHANG)) > 0) {
        int exit_code = WIFEXITED(status) ? WEXITSTATUS(status) : -1;

        std::lock_guard<std::mutex> lock(processes_mutex_);
        auto it = active_processes_.find(finished_pid);
        if (it != active_processes_.end()) {
            it->second->is_finished = true;
            it->second->exit_code = exit_code;
        }

        if (exit_callback_) {
            exit_callback_(finished_pid, exit_code);
        }
    }
}

void ProcessManager::run_epoll_loop() {
    struct epoll_event events[64];

    while (is_running_) {
        int nfds = epoll_wait(epoll_fd_, events, 64, 50); // 50ms timeout
        if (nfds < 0) {
            if (errno == EINTR) continue;
            break;
        }

        for (int i = 0; i < nfds; ++i) {
            handle_pipe_read(events[i].data.fd);
        }

        check_child_termination();
    }
}

void ProcessManager::stop_epoll_loop() {
    is_running_ = false;
}

size_t ProcessManager::get_active_process_count() {
    std::lock_guard<std::mutex> lock(processes_mutex_);
    size_t count = 0;
    for (const auto& [pid, proc] : active_processes_) {
        if (!proc->is_finished) count++;
    }
    return count;
}

} // namespace lucille
