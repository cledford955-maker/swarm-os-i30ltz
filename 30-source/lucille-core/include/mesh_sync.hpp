#pragma once

#include <string>
#include <vector>
#include <memory>
#include <mutex>
#include <cstdint>

namespace lucille {

struct EncryptedClipboardPayload {
    std::string iv_hex;
    std::string tag_hex;
    std::string ciphertext_hex;
    int64_t timestamp{0};
    std::string sender_device_id;
};

struct SyncJobResult {
    bool success{false};
    std::string source_dir;
    std::string target_dir;
    std::string rsync_command_used;
    std::string log_output;
    uint32_t files_transferred{0};
    uint64_t bytes_transferred{0};
};

class MeshSyncEngine {
public:
    explicit MeshSyncEngine(std::string pre_shared_key_hex = "");
    ~MeshSyncEngine() = default;

    // --- 1. E2E Encrypted Clipboard Synchronization ---
    
    // Encrypt clipboard content using AES-256-GCM
    EncryptedClipboardPayload encrypt_clipboard(
        const std::string& plaintext,
        const std::string& device_id = "swarm_workstation"
    );

    // Decrypt clipboard content using AES-256-GCM
    bool decrypt_clipboard(
        const EncryptedClipboardPayload& payload,
        std::string& out_plaintext
    );

    // Format payload as JSON string for WebSocket transmission
    static std::string serialize_clipboard_json(const EncryptedClipboardPayload& payload);
    static bool deserialize_clipboard_json(const std::string& json_str, EncryptedClipboardPayload& out_payload);

    // --- 2. Non-Destructive Rsync Synchronization (SYNC-OPTIONS.md) ---
    
    // Execute non-destructive rsync according to SYNC-OPTIONS.md
    SyncJobResult execute_non_destructive_sync(
        const std::string& source_path,
        const std::string& destination_path,
        bool dry_run = false
    );

    // Validate rsync flags against no-delete safety policy
    static bool validate_sync_safety(const std::vector<std::string>& rsync_flags, std::string& out_reason);

    void set_mesh_key(const std::string& key_hex) { mesh_key_hex_ = key_hex; }
    const std::string& get_mesh_key() const { return mesh_key_hex_; }

private:
    std::string mesh_key_hex_;
    std::mutex sync_mutex_;

    static std::string to_hex(const unsigned char* data, size_t len);
    static std::vector<unsigned char> from_hex(const std::string& hex);
};

} // namespace lucille
