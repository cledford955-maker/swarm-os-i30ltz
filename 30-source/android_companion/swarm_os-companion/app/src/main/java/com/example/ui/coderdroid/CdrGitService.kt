package com.example.ui.coderdroid

import org.eclipse.jgit.api.Git
import org.eclipse.jgit.api.errors.GitAPIException
import org.eclipse.jgit.lib.BranchTrackingStatus
import org.eclipse.jgit.transport.UsernamePasswordCredentialsProvider
import org.eclipse.jgit.transport.RemoteRefUpdate
import java.net.URI
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
        val deleted = git.add().setUpdate(true)
        paths.forEach { deleted.addFilepattern(it) }
        deleted.call()
    }

    fun stageAll(root: File): Result<Unit> = runGit(root) { git ->
        git.add().addFilepattern(".").call()
        git.add().setUpdate(true).addFilepattern(".").call()
    }

    fun unstage(root: File, paths: List<String>): Result<Unit> = runGit(root) { git ->
        val cmd = git.reset()
        paths.forEach { cmd.addPath(it) }
        cmd.call()
    }

    fun commit(root: File, message: String, authorName: String, authorEmail: String): Result<Unit> = runGit(root) { git ->
        require(message.isNotBlank()) { "Enter a commit message." }
        require(authorName.isNotBlank() && authorEmail.contains("@")) { "Set your commit name and email in Git settings." }
        require(git.status().call().conflicting.isEmpty()) { "Resolve merge conflicts before committing." }
        git.commit().setMessage(message.trim())
            .setAuthor(authorName.trim(), authorEmail.trim())
            .setCommitter(authorName.trim(), authorEmail.trim()).call()
    }

    /** Existing user files are never erased on a failed clone. */
    fun clone(dest: File, url: String, username: String, token: String): Result<File> = runCatching {
        val uri = URI(url.trim())
        require(uri.scheme == "https" && !uri.host.isNullOrBlank() && uri.userInfo == null) {
            "Use an HTTPS repository URL without embedded credentials."
        }
        if (isGitRepo(dest)) {
            Git.open(dest).use { git ->
                require(git.repository.config.getString("remote", "origin", "url")?.trimEnd('/') == url.trim().trimEnd('/')) {
                    "That project folder belongs to another repository. Choose a different project name."
                }
            }
            return@runCatching dest
        }
        require(!dest.exists()) { "A non-Git folder already exists at this path. Its files have been preserved." }
        dest.parentFile?.mkdirs()
        val temp = File(dest.parentFile, ".clone-" + java.util.UUID.randomUUID())
        try {
            val cmd = Git.cloneRepository().setURI(url.trim()).setDirectory(temp).setTimeout(120)
            if (token.isNotBlank()) cmd.setCredentialsProvider(credentials(username, token, uri.host))
            cmd.call().close()
            check(temp.renameTo(dest)) { "Could not save the cloned project." }
            dest
        } finally { if (temp.exists()) temp.deleteRecursively() }
    }

    private fun credentials(username: String, token: String, host: String?): UsernamePasswordCredentialsProvider {
        require(host.equals("github.com", ignoreCase = true)) { "Saved GitHub credentials are used only with github.com HTTPS remotes." }
        return UsernamePasswordCredentialsProvider(username.ifBlank { "x-access-token" }, token)
    }

    private fun remoteCredentials(git: Git, username: String, token: String): UsernamePasswordCredentialsProvider {
        val remote = git.repository.config.getString("remote", "origin", "url") ?: error("No origin remote configured.")
        val uri = URI(remote)
        require(uri.scheme == "https" && uri.userInfo == null) { "Use an HTTPS origin without embedded credentials." }
        return credentials(username, token, uri.host)
    }

    fun push(root: File, username: String, token: String): Result<Unit> = runGit(root) { git ->
        val results = git.push().setRemote("origin").setTimeout(120)
            .setCredentialsProvider(remoteCredentials(git, username, token)).call().toList()
        val updates = results.flatMap { it.remoteUpdates }
        require(updates.isNotEmpty()) { "No remote branch was updated; check your branch and origin." }
        val rejected = updates.filter { it.status != RemoteRefUpdate.Status.OK && it.status != RemoteRefUpdate.Status.UP_TO_DATE }
        require(rejected.isEmpty()) { rejected.joinToString("; ") { "${it.remoteName}: ${it.status} ${it.message.orEmpty()}" } }
    }

    fun pull(root: File, username: String, token: String): Result<Unit> = runGit(root) { git ->
        require(git.status().call().isClean) { "Commit or resolve local changes before pulling." }
        val result = git.pull().setRemote("origin").setTimeout(120)
            .setCredentialsProvider(remoteCredentials(git, username, token)).call()
        require(result.isSuccessful) { "Pull needs attention: ${result.mergeResult ?: result.rebaseResult}. Resolve conflicts before pushing." }
    }

    fun setOrigin(root: File, url: String): Result<Unit> = runGit(root) { git ->
        val uri = URI(url.trim())
        require(uri.scheme == "https" && uri.host == "github.com" && uri.userInfo == null && uri.path.count { it == '/' } >= 2) { "Use an HTTPS GitHub repository URL without credentials." }
        git.repository.config.apply {
            setString("remote", "origin", "url", url.trim())
            setString("remote", "origin", "fetch", "+refs/heads/*:refs/remotes/origin/*")
            val branch = git.repository.branch
            setString("branch", branch, "remote", "origin")
            setString("branch", branch, "merge", "refs/heads/$branch")
            save()
        }
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
