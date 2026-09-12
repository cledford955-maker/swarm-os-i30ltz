#include "mesh_sync.hpp"
#include <openssl/evp.h>
#include <openssl/rand.h>
#include <iostream>
#include <sstream>
#include <iomanip>
#include <chrono>
#include <algorithm>
#include <unistd.h>
#include <sys/wait.h>

namespace lucille {

// Default 256-bit pre-shared mesh key (32 bytes) if none provided
static const std::string kDefaultMeshKeyHex = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef";

MeshSyncEngine::MeshSyncEngine(std::string pre_shared_key_hex)
    : mesh_key_hex_(pre_shared_key_hex.empty() ? kDefaultMeshKeyHex : std::move(pre_shared_key_hex)) {}

std::string MeshSyncEngine::to_hex(const unsigned char* data, size_t len) {
    std::stringstream ss;
    for (size_t i = 0; i < len; ++i) {
        ss << std::hex << std::setw(2) << std::setfill('0') << static_cast<int>(data[i]);
    }
    return ss.str();
}

std::vector<unsigned char> MeshSyncEngine::from_hex(const std::string& hex) {
    std::vector<unsigned char> bytes;
    for (size_t i = 0; i + 1 < hex.length(); i += 2) {
        std::string byteString = hex.substr(i, 2);
        unsigned char byte = static_cast<unsigned char>(std::strtol(byteString.c_str(), nullptr, 16));
        bytes.push_back(byte);
    }
    return bytes;
}

EncryptedClipboardPayload MeshSyncEngine::encrypt_clipboard(
    const std::string& plaintext,
    const std::string& device_id
) {
    EncryptedClipboardPayload payload;
    payload.sender_device_id = device_id;
    payload.timestamp = std::chrono::duration_cast<std::chrono::seconds>(
        std::chrono::system_clock::now().time_since_epoch()
    ).count();

    auto key_bytes = from_hex(mesh_key_hex_);
    if (key_bytes.size() < 32) {
        key_bytes.resize(32, 0xAA);
    }

    // 12-byte IV for AES-256-GCM
    unsigned char iv[12];
    RAND_bytes(iv, sizeof(iv));
    payload.iv_hex = to_hex(iv, sizeof(iv));

    EVP_CIPHER_CTX* ctx = EVP_CIPHER_CTX_new();
    if (!ctx) return payload;

    if (EVP_EncryptInit_ex(ctx, EVP_aes_256_gcm(), nullptr, nullptr, nullptr) != 1 ||
        EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_SET_IVLEN, sizeof(iv), nullptr) != 1 ||
        EVP_EncryptInit_ex(ctx, nullptr, nullptr, key_bytes.data(), iv) != 1) {
        EVP_CIPHER_CTX_free(ctx);
        return payload;
    }

    std::vector<unsigned char> ciphertext(plaintext.size() + 16);
    int out_len1 = 0;
    EVP_EncryptUpdate(ctx, ciphertext.data(), &out_len1,
                      reinterpret_cast<const unsigned char*>(plaintext.data()), static_cast<int>(plaintext.size()));

    int out_len2 = 0;
    EVP_EncryptFinal_ex(ctx, ciphertext.data() + out_len1, &out_len2);

    int total_ciphertext_len = out_len1 + out_len2;
    payload.ciphertext_hex = to_hex(ciphertext.data(), total_ciphertext_len);

    unsigned char tag[16];
    EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_GET_TAG, sizeof(tag), tag);
    payload.tag_hex = to_hex(tag, sizeof(tag));

    EVP_CIPHER_CTX_free(ctx);
    return payload;
}

bool MeshSyncEngine::decrypt_clipboard(
    const EncryptedClipboardPayload& payload,
    std::string& out_plaintext
) {
    out_plaintext.clear();
    auto key_bytes = from_hex(mesh_key_hex_);
    if (key_bytes.size() < 32) {
        key_bytes.resize(32, 0xAA);
    }

    auto iv = from_hex(payload.iv_hex);
    auto ciphertext = from_hex(payload.ciphertext_hex);
    auto tag = from_hex(payload.tag_hex);

    if (iv.size() != 12 || tag.size() != 16) {
        return false;
    }

    EVP_CIPHER_CTX* ctx = EVP_CIPHER_CTX_new();
    if (!ctx) return false;

    if (EVP_DecryptInit_ex(ctx, EVP_aes_256_gcm(), nullptr, nullptr, nullptr) != 1 ||
        EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_SET_IVLEN, static_cast<int>(iv.size()), nullptr) != 1 ||
        EVP_DecryptInit_ex(ctx, nullptr, nullptr, key_bytes.data(), iv.data()) != 1) {
        EVP_CIPHER_CTX_free(ctx);
        return false;
    }

    std::vector<unsigned char> plaintext(ciphertext.size());
    int out_len1 = 0;
    EVP_DecryptUpdate(ctx, plaintext.data(), &out_len1, ciphertext.data(), static_cast<int>(ciphertext.size()));

    EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_SET_TAG, static_cast<int>(tag.size()), const_cast<unsigned char*>(tag.data()));

    int out_len2 = 0;
    int ret = EVP_DecryptFinal_ex(ctx, plaintext.data() + out_len1, &out_len2);
    EVP_CIPHER_CTX_free(ctx);

    if (ret > 0) {
        int total_len = out_len1 + out_len2;
        out_plaintext.assign(reinterpret_cast<char*>(plaintext.data()), total_len);
        return true;
    }

    return false;
}

std::string MeshSyncEngine::serialize_clipboard_json(const EncryptedClipboardPayload& payload) {
    std::stringstream ss;
    ss << "{\"event\":\"clipboard_sync\","
       << "\"sender\":\"" << payload.sender_device_id << "\","
       << "\"timestamp\":" << payload.timestamp << ","
       << "\"iv\":\"" << payload.iv_hex << "\","
       << "\"tag\":\"" << payload.tag_hex << "\","
       << "\"ciphertext\":\"" << payload.ciphertext_hex << "\"}";
    return ss.str();
}

bool MeshSyncEngine::deserialize_clipboard_json(const std::string& json_str, EncryptedClipboardPayload& out_payload) {
    auto extract = [&](const std::string& key) -> std::string {
        std::string pattern = "\"" + key + "\":\"";
        auto pos = json_str.find(pattern);
        if (pos == std::string::npos) return "";
        pos += pattern.length();
        auto end_pos = json_str.find("\"", pos);
        if (end_pos == std::string::npos) return "";
        return json_str.substr(pos, end_pos - pos);
    };

    out_payload.iv_hex = extract("iv");
    out_payload.tag_hex = extract("tag");
    out_payload.ciphertext_hex = extract("ciphertext");
    out_payload.sender_device_id = extract("sender");

    return (!out_payload.iv_hex.empty() && !out_payload.tag_hex.empty() && !out_payload.ciphertext_hex.empty());
}

bool MeshSyncEngine::validate_sync_safety(const std::vector<std::string>& rsync_flags, std::string& out_reason) {
    for (const auto& flag : rsync_flags) {
        if (flag == "--delete" || flag == "--delete-before" || flag == "--delete-after" || flag == "--delete-during" || flag == "--delete-excluded") {
            out_reason = "FATAL: SYNC-OPTIONS.md strictly forbids destructive --delete flags";
            return false;
        }
    }
    return true;
}

SyncJobResult MeshSyncEngine::execute_non_destructive_sync(
    const std::string& source_path,
    const std::string& destination_path,
    bool dry_run
) {
    std::lock_guard<std::mutex> lock(sync_mutex_);
    SyncJobResult res;
    res.source_dir = source_path;
    res.target_dir = destination_path;

    // Build rsync command enforcing SYNC-OPTIONS.md:
    // rsync -avuz --no-delete --exclude='.git/' --exclude='build/' --exclude='*.iso' <src> <dest>
    std::vector<std::string> args = {
        "rsync",
        "-avuz",
        "--no-delete",
        "--exclude=.git/",
        "--exclude=build/",
        "--exclude=*.iso",
        "--exclude=*.tmp"
    };

    if (dry_run) {
        args.push_back("--dry-run");
    }

    args.push_back(source_path);
    args.push_back(destination_path);

    std::stringstream cmd_ss;
    for (const auto& a : args) cmd_ss << a << " ";
    res.rsync_command_used = cmd_ss.str();

    std::string safety_err;
    if (!validate_sync_safety(args, safety_err)) {
        res.success = false;
        res.log_output = safety_err;
        return res;
    }

    int pipe_fd[2];
    if (pipe(pipe_fd) < 0) {
        res.success = false;
        res.log_output = "Failed to create rsync execution pipe";
        return res;
    }

    pid_t pid = fork();
    if (pid < 0) {
        close(pipe_fd[0]);
        close(pipe_fd[1]);
        res.success = false;
        res.log_output = "Failed to fork rsync child process";
        return res;
    }

    if (pid == 0) {
        close(pipe_fd[0]);
        dup2(pipe_fd[1], STDOUT_FILENO);
        dup2(pipe_fd[1], STDERR_FILENO);
        close(pipe_fd[1]);

        std::vector<char*> c_args;
        for (const auto& a : args) c_args.push_back(const_cast<char*>(a.c_str()));
        c_args.push_back(nullptr);

        execvp("rsync", c_args.data());
        _exit(127);
    }

    close(pipe_fd[1]);
    char buffer[1024];
    ssize_t bytes = 0;
    while ((bytes = read(pipe_fd[0], buffer, sizeof(buffer) - 1)) > 0) {
        buffer[bytes] = '\0';
        res.log_output += buffer;
    }
    close(pipe_fd[0]);

    int status = 0;
    waitpid(pid, &status, 0);
    res.success = (WIFEXITED(status) && WEXITSTATUS(status) == 0);

    return res;
}

} // namespace lucille
