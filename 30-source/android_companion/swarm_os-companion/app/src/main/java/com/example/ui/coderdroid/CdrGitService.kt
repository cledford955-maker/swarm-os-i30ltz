package com.example.ui.coderdroid

import org.eclipse.jgit.api.Git
import org.eclipse.jgit.api.errors.GitAPIException
import org.eclipse.jgit.lib.BranchTrackingStatus
import org.eclipse.jgit.transport.UsernamePasswordCredentialsProvider
import java.io.File

/**
 * Thin wrapper over JGit for CoderDroid's Git panel. Every call opens the repo
 * fresh (JGit repos are cheap to open, and the panel is not a hot path) so
 * there's no lifecycle to manage across workspace switches. Callers are
 * expected to run these on Dispatchers.IO — none of this is safe to call from
 * the main thread.
 */
object CdrGitService {

    fun isGitRepo(root: File): Boolean =
        File(root, ".git").exists()

    fun status(root: File): CdrGitState {
        if (!isGitRepo(root)) return CdrGitState(isRepo = false)
        return try {
            Git.open(root).use { git ->
                val st = git.status().call()
                val branch = git.repository.branch ?: ""
                val tracking = try { BranchTrackingStatus.of(git.repository, branch) } catch (_: Exception) { null }

                val staged = mutableListOf<CdrGitFileStatus>()
                st.added.forEach { staged += CdrGitFileStatus(it, CdrGitFileStatus.Kind.ADDED, staged = true) }
                st.changed.forEach { staged += CdrGitFileStatus(it, CdrGitFileStatus.Kind.MODIFIED, staged = true) }
                st.removed.forEach { staged += CdrGitFileStatus(it, CdrGitFileStatus.Kind.DELETED, staged = true) }

                val unstaged = mutableListOf<CdrGitFileStatus>()
                st.modified.forEach { unstaged += CdrGitFileStatus(it, CdrGitFileStatus.Kind.MODIFIED, staged = false) }
                st.missing.forEach { unstaged += CdrGitFileStatus(it, CdrGitFileStatus.Kind.MISSING, staged = false) }
                st.untracked.forEach { unstaged += CdrGitFileStatus(it, CdrGitFileStatus.Kind.UNTRACKED, staged = false) }
                st.conflicting.forEach { unstaged += CdrGitFileStatus(it, CdrGitFileStatus.Kind.CONFLICTING, staged = false) }

                CdrGitState(
                    isRepo = true,
                    branch = branch,
                    ahead = tracking?.aheadCount ?: 0,
                    behind = tracking?.behindCount ?: 0,
                    staged = staged,
                    unstaged = unstaged
                )
            }
        } catch (e: Exception) {
            CdrGitState(isRepo = true, lastError = e.message ?: "git status failed")
        }
    }

    fun stage(root: File, paths: List<String>): Result<Unit> = runGit(root) { git ->
        val cmd = git.add()
        paths.forEach { cmd.addFilepattern(it) }
        cmd.call()
    }

    fun stageAll(root: File): Result<Unit> = runGit(root) { git ->
        git.add().addFilepattern(".").call()
    }

    fun unstage(root: File, paths: List<String>): Result<Unit> = runGit(root) { git ->
        val cmd = git.reset()
        paths.forEach { cmd.addPath(it) }
        cmd.call()
    }

    fun commit(root: File, message: String, authorName: String, authorEmail: String): Result<Unit> = runGit(root) { git ->
        git.commit()
            .setMessage(message)
            .setAuthor(authorName.ifBlank { "CoderDroid" }, authorEmail.ifBlank { "coderdroid@swarm-os.local" })
            .call()
    }

    /**
     * Clones [url] into [dest]. [dest] lives under the app's private storage
     * (filesDir/projects/<name>) — no file manager or SAF picker can ever
     * see into it, so if a user goes looking for "the folder" outside the
     * app they will always find nothing there; that's expected, not a bug.
     *
     * If [dest] already holds a valid clone (e.g. this repo was already
     * fetched, or the caller is retrying after opening it once), returns it
     * as-is rather than failing. If [dest] exists but ISN'T a real repo, it's
     * leftover debris from a previous clone that got interrupted (app
     * killed, network dropped) before this function's own catch-block
     * cleanup ran — found 2026-09-19: the old code treated that leftover
     * debris the same as a real repo and refused forever with "already
     * exists and isn't empty", with no way for the user to recover short of
     * clearing app storage. Now it's wiped and retried automatically.
     */
    fun clone(dest: File, url: String, username: String, token: String): Result<File> =
        try {
            val hasContent = dest.exists() && dest.listFiles()?.isNotEmpty() == true
            if (hasContent && isGitRepo(dest)) {
                Result.success(dest)
            } else {
                if (hasContent) dest.deleteRecursively()
                dest.parentFile?.mkdirs()
                val cmd = Git.cloneRepository().setURI(url).setDirectory(dest)
                if (token.isNotBlank()) {
                    cmd.setCredentialsProvider(UsernamePasswordCredentialsProvider(username.ifBlank { token }, token))
                }
                cmd.call().close()
                Result.success(dest)
            }
        } catch (e: Exception) {
            dest.deleteRecursively()
            Result.failure(e)
        }

    fun push(root: File, username: String, token: String): Result<Unit> = runGit(root) { git ->
        git.push()
            .setCredentialsProvider(UsernamePasswordCredentialsProvider(username.ifBlank { token }, token))
            .call()
    }

    fun pull(root: File, username: String, token: String): Result<Unit> = runGit(root) { git ->
        git.pull()
            .setCredentialsProvider(UsernamePasswordCredentialsProvider(username.ifBlank { token }, token))
            .call()
    }

    private fun runGit(root: File, block: (Git) -> Unit): Result<Unit> =
        try {
            Git.open(root).use { git -> block(git) }
            Result.success(Unit)
        } catch (e: GitAPIException) {
            Result.failure(e)
        } catch (e: Exception) {
            Result.failure(e)
        }
}
