#pragma once

#include <string>
#include <vector>
#include <cstdint>

namespace lucille {

struct CheckpointResult {
    bool ok{false};
    std::string checkpoint_id;  // git commit SHA or "stash@{N}"
    std::string label;
    std::string status_msg;
};

struct RollbackResult {
    bool ok{false};
    std::string checkpoint_id;
    std::string status_msg;
};

// Atomic git-diff checkpoint journaling.
// Call create_checkpoint() before any mutating shell command or code patch.
// On success: call discard_checkpoint() to keep the commit as a clean journal entry.
// On test/compile failure: call rollback_to_checkpoint() for instant revert.
class CheckpointJournal {
public:
    // Stage all changes and create a lightweight commit tagged with label.
    // Returns the commit SHA as checkpoint_id. No-ops cleanly if nothing is staged.
    static CheckpointResult create_checkpoint(
        const std::string& workspace_dir,
        const std::string& label
    );

    // Hard-reset HEAD to checkpoint_id, discarding everything after it.
    // Safe to call from the regression-test-failure path.
    static RollbackResult rollback_to_checkpoint(
        const std::string& workspace_dir,
        const std::string& checkpoint_id
    );

    // Reword the checkpoint commit message to mark it as confirmed (keeps journal clean).
    // Call after a mutating operation succeeds and tests pass.
    static bool confirm_checkpoint(
        const std::string& workspace_dir,
        const std::string& checkpoint_id,
        std::string& err_msg
    );

private:
    static std::string run_git(
        const std::string& workspace_dir,
        const std::vector<std::string>& args,
        int& exit_code
    );
};

} // namespace lucille
