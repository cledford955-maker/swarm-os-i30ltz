#include "ipc_server.hpp"

#include <sys/socket.h>
#include <sys/un.h>
#include <sys/stat.h>
#include <sys/epoll.h>
#include <sys/eventfd.h>
#include <unistd.h>
#include <fcntl.h>
#include <cstring>
#include <cerrno>
#include <iostream>
#include <algorithm>

namespace lucille {

static constexpr int kMaxEvents = 64;

IpcServer::IpcServer(std::string socket_path)
    : socket_path_(std::move(socket_path)) {}

IpcServer::~IpcServer() {
    shutdown();
}

bool IpcServer::initialize(std::string& err_msg) {
    unlink(socket_path_.c_str());

    server_fd_ = socket(AF_UNIX, SOCK_STREAM | SOCK_NONBLOCK | SOCK_CLOEXEC, 0);
    if (server_fd_ < 0) {
        err_msg = "socket(): " + std::string(strerror(errno));
        return false;
    }

    struct sockaddr_un addr;
    std::memset(&addr, 0, sizeof(addr));
    addr.sun_family = AF_UNIX;
    if (socket_path_.length() >= sizeof(addr.sun_path)) {
        err_msg = "Socket path exceeds AF_UNIX max length";
        close(server_fd_); server_fd_ = -1;
        return false;
    }
    std::strncpy(addr.sun_path, socket_path_.c_str(), sizeof(addr.sun_path) - 1);

    if (bind(server_fd_, reinterpret_cast<struct sockaddr*>(&addr), sizeof(addr)) < 0) {
        err_msg = "bind(" + socket_path_ + "): " + std::string(strerror(errno));
        close(server_fd_); server_fd_ = -1;
        return false;
    }
    chmod(socket_path_.c_str(), 0660);

    if (listen(server_fd_, SOMAXCONN) < 0) {
        err_msg = "listen(): " + std::string(strerror(errno));
        close(server_fd_); server_fd_ = -1;
        return false;
    }

    // epoll instance
    epoll_fd_ = epoll_create1(EPOLL_CLOEXEC);
    if (epoll_fd_ < 0) {
        err_msg = "epoll_create1(): " + std::string(strerror(errno));
        close(server_fd_); server_fd_ = -1;
        return false;
    }

    // eventfd for clean wakeup on shutdown()
    wake_fd_ = eventfd(0, EFD_CLOEXEC | EFD_NONBLOCK);
    if (wake_fd_ < 0) {
        err_msg = "eventfd(): " + std::string(strerror(errno));
        close(epoll_fd_); epoll_fd_ = -1;
        close(server_fd_); server_fd_ = -1;
        return false;
    }

    epoll_add(server_fd_, EPOLLIN | EPOLLET);
    epoll_add(wake_fd_,   EPOLLIN);

    is_running_ = true;
    std::cout << "[IpcServer] Listening on " << socket_path_ << " (epoll ET)\n";
    return true;
}

void IpcServer::epoll_add(int fd, uint32_t events) {
    struct epoll_event ev;
    ev.events   = events;
    ev.data.fd  = fd;
    epoll_ctl(epoll_fd_, EPOLL_CTL_ADD, fd, &ev);
}

void IpcServer::epoll_del(int fd) {
    epoll_ctl(epoll_fd_, EPOLL_CTL_DEL, fd, nullptr);
}

// ---- Event loop ---------------------------------------------------------

void IpcServer::run_event_loop() {
    {
        std::lock_guard<std::mutex> lk(lifecycle_mutex_);
        if (!is_running_ || epoll_fd_ < 0) return;   // already shut down
        loop_active_    = true;
        loop_thread_id_ = std::this_thread::get_id();
    }

    struct epoll_event events[kMaxEvents];

    while (is_running_) {
        int n = epoll_wait(epoll_fd_, events, kMaxEvents, /*timeout_ms=*/500);
        if (n < 0) {
            if (errno == EINTR) continue;
            std::cerr << "[IpcServer] epoll_wait error: " << strerror(errno) << "\n";
            break;
        }

        for (int i = 0; i < n; ++i) {
            int fd = events[i].data.fd;

            if (fd == wake_fd_) {
                // shutdown() fired — drain and exit
                uint64_t val;
                while (read(wake_fd_, &val, sizeof(val)) > 0) {}
                goto done;
            }

            if (fd == server_fd_) {
                drain_accept_queue();
                continue;
            }

            if (events[i].events & (EPOLLERR | EPOLLHUP)) {
                close_client(fd);
                continue;
            }

            if (events[i].events & EPOLLIN) {
                drain_client(fd);
            }
        }
    }
done:
    // Hand fd ownership back: after loop_active_ is cleared under the lock,
    // shutdown() can no longer write to wake_fd_, so closing is safe.
    {
        std::lock_guard<std::mutex> lk(lifecycle_mutex_);
        loop_active_ = false;
        release_resources();
    }
    loop_exited_cv_.notify_all();
    std::cout << "[IpcServer] Event loop exited.\n";
}

// ---- Accept in a loop until EAGAIN (required for EPOLLET) ---------------

void IpcServer::drain_accept_queue() {
    for (;;) {
        int cfd = accept4(server_fd_, nullptr, nullptr, SOCK_NONBLOCK | SOCK_CLOEXEC);
        if (cfd < 0) {
            if (errno == EAGAIN || errno == EWOULDBLOCK) break;
            if (errno == EINTR) continue;
            std::cerr << "[IpcServer] accept4(): " << strerror(errno) << "\n";
            break;
        }
        epoll_add(cfd, EPOLLIN | EPOLLET | EPOLLRDHUP);
        register_client(cfd);
        std::cout << "[IpcServer] Client connected fd=" << cfd << "\n";
    }
}

// ---- Read all available data from one client (required for EPOLLET) ------

void IpcServer::drain_client(int client_fd) {
    std::string accumulated;
    char buf[4096];

    for (;;) {
        ssize_t n = read(client_fd, buf, sizeof(buf));
        if (n > 0) {
            accumulated.append(buf, n);
            continue;
        }
        if (n == 0) {
            // EOF — peer closed
            close_client(client_fd);
            return;
        }
        // n < 0
        if (errno == EAGAIN || errno == EWOULDBLOCK) break;
        if (errno == EINTR) continue;
        close_client(client_fd);
        return;
    }

    if (!accumulated.empty() && handler_) {
        std::string response = handler_(accumulated);
        if (!response.empty()) {
            send_message(client_fd, response);
        }
    }
}

void IpcServer::close_client(int client_fd) {
    epoll_del(client_fd);
    unregister_client(client_fd);
    std::cout << "[IpcServer] Client disconnected fd=" << client_fd << "\n";
}

// ---- Shutdown ------------------------------------------------------------

void IpcServer::shutdown() {
    std::unique_lock<std::mutex> lk(lifecycle_mutex_);
    if (!is_running_.exchange(false)) return;

    if (!loop_active_) {
        // No loop running (never started, or already exited): clean up here
        release_resources();
        return;
    }

    // Loop is running and owns the fds — wake it; it releases them on exit
    uint64_t val = 1;
    while (write(wake_fd_, &val, sizeof(val)) < 0 && errno == EINTR) {}

    // Wait for the loop to finish (unless shutdown() came from a handler
    // running on the loop thread itself — it exits after this returns)
    if (std::this_thread::get_id() != loop_thread_id_) {
        loop_exited_cv_.wait(lk, [this] { return !loop_active_; });
    }
}

void IpcServer::release_resources() {
    if (epoll_fd_  >= 0) { close(epoll_fd_);  epoll_fd_  = -1; }
    if (wake_fd_   >= 0) { close(wake_fd_);   wake_fd_   = -1; }
    if (server_fd_ >= 0) {
        close(server_fd_); server_fd_ = -1;
        unlink(socket_path_.c_str());
    }

    std::lock_guard<std::mutex> lock(clients_mutex_);
    for (int cfd : client_fds_) {
        if (cfd >= 0) close(cfd);
    }
    client_fds_.clear();
}

// ---- Remaining helpers ---------------------------------------------------

int IpcServer::accept_connection() {
    if (server_fd_ < 0) return -1;
    int cfd = accept4(server_fd_, nullptr, nullptr, SOCK_NONBLOCK | SOCK_CLOEXEC);
    if (cfd >= 0) register_client(cfd);
    return cfd;
}

void IpcServer::register_client(int client_fd) {
    std::lock_guard<std::mutex> lock(clients_mutex_);
    client_fds_.push_back(client_fd);
}

void IpcServer::unregister_client(int client_fd) {
    std::lock_guard<std::mutex> lock(clients_mutex_);
    auto it = std::find(client_fds_.begin(), client_fds_.end(), client_fd);
    if (it != client_fds_.end()) {
        close(*it);
        client_fds_.erase(it);
    }
}

bool IpcServer::read_message(int client_fd, std::string& out_msg) {
    char buf[4096];
    out_msg.clear();
    ssize_t n = read(client_fd, buf, sizeof(buf) - 1);
    if (n > 0) {
        buf[n] = '\0';
        out_msg.assign(buf, n);
        return true;
    }
    return false;
}

bool IpcServer::send_message(int client_fd, const std::string& msg) {
    size_t sent = 0;
    while (sent < msg.size()) {
        ssize_t n = write(client_fd, msg.data() + sent, msg.size() - sent);
        if (n < 0) {
            if (errno == EAGAIN || errno == EWOULDBLOCK || errno == EINTR) continue;
            return false;
        }
        sent += static_cast<size_t>(n);
    }
    return true;
}

void IpcServer::broadcast(const std::string& msg) {
    std::lock_guard<std::mutex> lock(clients_mutex_);
    for (int cfd : client_fds_) {
        send_message(cfd, msg);
    }
}

void IpcServer::process_client(int client_fd) {
    std::string request;
    if (read_message(client_fd, request) && handler_) {
        std::string response = handler_(request);
        if (!response.empty()) {
            send_message(client_fd, response);
        }
    }
}

} // namespace lucille
