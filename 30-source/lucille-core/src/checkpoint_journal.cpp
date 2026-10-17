#include "checkpoint_journal.hpp"
#include <vector>
#include <sstream>
#include <ctime>
#include <unistd.h>
#include <sys/wait.h>
#include <fcntl.h>
#include <cstring>
#include <cerrno>

namespace lucille {

std::string CheckpointJournal::run_git(
    const std::string& workspace_dir,
    const std::vector<std::string>& args,
    int& exit_code
) {
    int pipe_fd[2];
    if (pipe(pipe_fd) < 0) {
        exit_code = -1;
        return "";
    }

    pid_t pid = fork();
    if (pid < 0) {
        close(pipe_fd[0]);
        close(pipe_fd[1]);
        exit_code = -1;
        return "";
    }

    if (pid == 0) {
        close(pipe_fd[0]);
        dup2(pipe_fd[1], STDOUT_FILENO);
        dup2(pipe_fd[1], STDERR_FILENO);
        close(pipe_fd[1]);

        if (!workspace_dir.empty()) chdir(workspace_dir.c_str());

        std::vector<const char*> c_args;
        c_args.push_back("git");
        for (const auto& a : args) c_args.push_back(a.c_str());
        c_args.push_back(nullptr);

        execvp("git", const_cast<char* const*>(c_args.data()));
        _exit(127);
    }

    close(pipe_fd[1]);
    std::string output;
    char buf[1024];
    ssize_t n = 0;
    while ((n = read(pipe_fd[0], buf, sizeof(buf) - 1)) > 0) {
        buf[n] = '\0';
        output += buf;
    }
    close(pipe_fd[0]);

    int status = 0;
    waitpid(pid, &status, 0);
    exit_code = WIFEXITED(status) ? WEXITSTATUS(status) : -1;

    // Trim trailing newline
    while (!output.empty() && (output.back() == '\n' || output.back() == '\r'))
        output.pop_back();

    return output;
}

CheckpointResult CheckpointJournal::create_checkpoint(
    const std::string& workspace_dir,
    const std::string& label
) {
    CheckpointResult result;
    result.label = label;
    int rc = 0;

    // Ensure we're inside a git repo
    run_git(workspace_dir, {"rev-parse", "--git-dir"}, rc);
    if (rc != 0) {
        result.status_msg = "Not a git repository: " + workspace_dir;
        return result;
    }

    // Stage everything (new files, modifications, deletions)
    run_git(workspace_dir, {"add", "-A"}, rc);
    if (rc != 0) {
        result.status_msg = "git add -A failed";
        return result;
    }

    // Check if there's anything to commit
    std::string diff_stat = run_git(workspace_dir, {"diff", "--cached", "--stat"}, rc);
    if (diff_stat.empty()) {
        // Nothing staged — create an empty checkpoint anchored to HEAD
        std::string head_sha = run_git(workspace_dir, {"rev-parse", "HEAD"}, rc);
        if (rc != 0 || head_sha.empty()) {
            result.status_msg = "Nothing to checkpoint and no HEAD commit found";
            return result;
        }
        result.ok = true;
        result.checkpoint_id = head_sha;
        result.status_msg = "No changes — checkpoint anchored to HEAD " + head_sha.substr(0, 8);
        return result;
    }

    // Build commit message with ISO-8601 timestamp
    std::time_t now = std::time(nullptr);
    char ts[32];
    std::strftime(ts, sizeof(ts), "%Y-%m-%dT%H:%M:%S", std::gmtime(&now));
    std::string msg = "checkpoint: " + label + " [" + ts + "Z]";

    // Commit with a dedicated author so checkpoint commits are visually distinct
    run_git(workspace_dir,
        {"commit", "-m", msg,
         "--author=lucille-core <checkpoint@swarm.local>",
         "--no-verify"},
        rc);

    if (rc != 0) {
        result.status_msg = "git commit failed creating checkpoint '" + label + "'";
        return result;
    }

    // Capture the new commit SHA
    std::string sha = run_git(workspace_dir, {"rev-parse", "HEAD"}, rc);
    if (rc != 0 || sha.empty()) {
        result.status_msg = "Checkpoint committed but could not read SHA";
        return result;
    }

    result.ok = true;
    result.checkpoint_id = sha;
    result.status_msg = "Checkpoint " + sha.substr(0, 8) + " created: " + label;
    return result;
}

RollbackResult CheckpointJournal::rollback_to_checkpoint(
    const std::string& workspace_dir,
    const std::string& checkpoint_id
) {
    RollbackResult result;
    result.checkpoint_id = checkpoint_id;
    int rc = 0;

    if (checkpoint_id.empty()) {
        result.status_msg = "Empty checkpoint_id — rollback aborted";
        return result;
    }

    // Validate the SHA exists
    run_git(workspace_dir, {"cat-file", "-e", checkpoint_id + "^{commit}"}, rc);
    if (rc != 0) {
        result.status_msg = "Checkpoint SHA not found: " + checkpoint_id;
        return result;
    }

    // Hard reset to the checkpoint commit — discards all changes after it
    std::string out = run_git(workspace_dir,
        {"reset", "--hard", checkpoint_id}, rc);

    if (rc != 0) {
        result.status_msg = "git reset --hard failed: " + out;
        return result;
    }

    // Clean untracked files that appeared after the checkpoint
    run_git(workspace_dir, {"clean", "-fd"}, rc);

    result.ok = true;
    result.status_msg = "Rolled back to checkpoint " + checkpoint_id.substr(0, 8);
    return result;
}

bool CheckpointJournal::confirm_checkpoint(
    const std::string& workspace_dir,
    const std::string& checkpoint_id,
    std::string& err_msg
) {
    int rc = 0;

    // Verify we're still at the checkpoint commit
    std::string current = run_git(workspace_dir, {"rev-parse", "HEAD"}, rc);
    if (current != checkpoint_id) {
        // Subsequent commits landed on top — checkpoint is already part of history, nothing to do
        return true;
    }

    // Amend the commit message to mark it confirmed
    std::string orig_msg = run_git(workspace_dir,
        {"log", "-1", "--format=%s", checkpoint_id}, rc);

    std::string confirmed_msg = orig_msg + " [confirmed]";
    run_git(workspace_dir,
        {"commit", "--amend", "--no-edit", "-m", confirmed_msg,
         "--author=lucille-core <checkpoint@swarm.local>",
         "--no-verify"},
        rc);

    if (rc != 0) {
        err_msg = "Failed to amend checkpoint commit as confirmed";
        return false;
    }
    return true;
}

} // namespace lucille
