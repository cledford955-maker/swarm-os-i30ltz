#pragma once

#include <string>
#include <vector>
#include <functional>
#include <mutex>
#include <atomic>
#include <condition_variable>
#include <thread>
#include <cstdint>

namespace lucille {

using IpcMessageHandler = std::function<std::string(const std::string& request)>;

class IpcServer {
public:
    explicit IpcServer(std::string socket_path = "/tmp/lucille_ipc.sock");
    ~IpcServer();

    IpcServer(const IpcServer&) = delete;
    IpcServer& operator=(const IpcServer&) = delete;

    bool initialize(std::string& err_msg);
    void shutdown();

    // Block the calling thread, running an edge-triggered epoll loop until
    // shutdown() is called from another thread. initialize() must succeed first.
    // The loop owns the fds while it runs and closes them on exit; shutdown()
    // only signals it and waits, so no fd is closed while the loop uses it.
    void run_event_loop();

    int get_server_fd() const { return server_fd_; }
    const std::string& get_socket_path() const { return socket_path_; }

    int accept_connection();
    bool read_message(int client_fd, std::string& out_msg);
    bool send_message(int client_fd, const std::string& msg);
    void broadcast(const std::string& msg);

    void register_client(int client_fd);
    void unregister_client(int client_fd);

    void set_handler(IpcMessageHandler handler) { handler_ = std::move(handler); }
    void process_client(int client_fd);

private:
    std::string socket_path_;
    int server_fd_{-1};
    int epoll_fd_{-1};   // epoll instance
    int wake_fd_{-1};    // eventfd — written by shutdown() to break epoll_wait
    std::atomic<bool> is_running_{false};
    std::mutex clients_mutex_;
    std::vector<int> client_fds_;
    IpcMessageHandler handler_;

    // Loop lifecycle — guards the handoff of fd ownership in shutdown()
    std::mutex              lifecycle_mutex_;
    std::condition_variable loop_exited_cv_;
    bool                    loop_active_{false};
    std::thread::id         loop_thread_id_;

    void release_resources();        // close all fds + unlink; idempotent

    void epoll_add(int fd, uint32_t events);
    void epoll_del(int fd);
    void drain_accept_queue();       // loop accept4 until EAGAIN (ET mode)
    void drain_client(int client_fd);// loop read until EAGAIN, close on EOF
    void close_client(int client_fd);
};

} // namespace lucille
