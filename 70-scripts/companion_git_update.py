from pathlib import Path
root=Path('/mnt/Lucy/30-source/android_companion/swarm_os-companion/app/src/main')
p=root/'java/com/example/ui/coderdroid/CdrGitService.kt';s=p.read_text();s=s.replace('import org.eclipse.jgit.transport.UsernamePasswordCredentialsProvider','import org.eclipse.jgit.transport.UsernamePasswordCredentialsProvider\nimport org.eclipse.jgit.transport.RemoteRefUpdate\nimport java.net.URI')
s=s.replace('''        cmd.call()
    }

    fun stageAll''','''        cmd.call()
        val deleted = git.add().setUpdate(true)
        paths.forEach { deleted.addFilepattern(it) }
        deleted.call()
    }

    fun stageAll''',1)
s=s.replace('''        git.add().addFilepattern(".").call()
    }''','''        git.add().addFilepattern(".").call()
        git.add().setUpdate(true).addFilepattern(".").call()
    }''',1)
s=s.replace('''        git.commit()
            .setMessage(message)
            .setAuthor(authorName.ifBlank { "CoderDroid" }, authorEmail.ifBlank { "coderdroid@swarm-os.local" })
            .call()''','''        require(message.isNotBlank()) { "Enter a commit message." }
        require(authorName.isNotBlank() && authorEmail.contains("@")) { "Set your commit name and email in Git settings." }
        require(git.status().call().conflicting.isEmpty()) { "Resolve merge conflicts before committing." }
        git.commit().setMessage(message.trim())
            .setAuthor(authorName.trim(), authorEmail.trim())
            .setCommitter(authorName.trim(), authorEmail.trim()).call()''')
start=s.index('    /**\n     * Clones');end=s.index('    private fun runGit',start)
s=s[:start]+'''    /** Existing user files are never erased on a failed clone. */
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

'''+s[end:];p.write_text(s)
p=root/'java/com/example/ui/coderdroid/CdrGitCredentials.kt';s=p.read_text().replace('    val hasCredentials: Boolean','''    var authorName: String
        get() = prefs.getString("author_name", "") ?: ""
        set(value) = prefs.edit().putString("author_name", value.trim()).apply()
    var authorEmail: String
        get() = prefs.getString("author_email", "") ?: ""
        set(value) = prefs.edit().putString("author_email", value.trim()).apply()

    val hasCredentials: Boolean''');p.write_text(s)
p=root/'java/com/example/ui/coderdroid/CoderDroidViewModel.kt';s=p.read_text().replace('    val cloneError: String? = null','''    val cloneError: String? = null,
    val gitAuthorName: String = "",
    val gitAuthorEmail: String = "",
    val gitUsername: String = "",
    val notice: String? = null,
    val savedSequence: Int = 0,
    val commitSequence: Int = 0''')
s=s.replace('    object ToggleGitPanel', '    object ShowGitPanel : CoderDroidEvent()\n    object DismissNotice : CoderDroidEvent()\n    object ToggleGitPanel')
s=s.replace('data class SetGitCredentials(val username: String, val token: String)', 'data class SetGitCredentials(val username: String, val token: String, val authorName: String, val authorEmail: String)')
s=s.replace('''        _state.update { it.copy(gitHasCredentials = gitCredentials.hasCredentials) }''','''        _state.update { it.copy(gitHasCredentials = gitCredentials.hasCredentials, gitUsername = gitCredentials.username,
            gitAuthorName = gitCredentials.authorName, gitAuthorEmail = gitCredentials.authorEmail) }
        val saved = getApplication<Application>().getSharedPreferences("cdr_workspace", 0).getString("root", null)
        saved?.let { File(it) }?.takeIf { it.isDirectory && it.canRead() }?.let { openWorkspace(it) }''',1)
s=s.replace('            CoderDroidEvent.ToggleGitPanel      -> toggleGitPanel()','''            CoderDroidEvent.ShowGitPanel -> { _state.update { it.copy(sidebarVisible = true, gitPanelVisible = true) }; refreshGit() }
            CoderDroidEvent.DismissNotice -> _state.update { it.copy(notice = null) }
            CoderDroidEvent.ToggleGitPanel      -> toggleGitPanel()''')
s=s.replace('setGitCredentials(event.username, event.token)','setGitCredentials(event.username, event.token, event.authorName, event.authorEmail)')
s=s.replace('''            tab.fileNode.file.writeText(content)
            markDirty(tabId, false)
            refreshGit()''','''            runCatching { tab.fileNode.file.writeText(content) }.fold(
                onSuccess = { markDirty(tabId, false); _state.update { it.copy(savedSequence = it.savedSequence + 1) }; refreshGit() },
                onFailure = { err -> _state.update { it.copy(notice = "Save failed: ${err.message}") } }
            )''')
s=s.replace('''        // Switching projects clears all open tabs''','''        if (_state.value.tabs.any { it.isDirty }) {
            _state.update { it.copy(notice = "Save changed files before switching projects.") }; return
        }
        getApplication<Application>().getSharedPreferences("cdr_workspace", 0).edit().putString("root", root.absolutePath).apply()
        // Switching projects clears all open tabs''')
s=s.replace('''        val tabs = _state.value.tabs.filter''','''        if (_state.value.tabs.any { it.id == tabId && it.isDirty }) {
            _state.update { it.copy(notice = "Save this file before closing it.") }; return
        }
        val tabs = _state.value.tabs.filter''',1)
s=s.replace('''        if (message.isBlank()) return
        withGitRoot { root ->
            CdrGitService.commit(root, message, authorName = "CoderDroid", authorEmail = "coderdroid@swarm-os.local")
        }''','''        if (message.isBlank()) return
        if (_state.value.tabs.any { it.isDirty }) {
            _state.update { it.copy(notice = "Save changed files before committing.") }; return
        }
        withGitRoot { root ->
            CdrGitService.commit(root, message, gitCredentials.authorName, gitCredentials.authorEmail).onSuccess {
                _state.update { it.copy(commitSequence = it.commitSequence + 1, notice = "Commit saved locally. Use Push to send it to GitHub.") }
            }
        }''')
s=s.replace('''            val result = CdrGitService.status(root)
            _state.update { it.copy(gitState = result) }''','''            val result = CdrGitService.status(root)
            _state.update { if (it.workspaceRoot == root && !it.gitState.isBusy) it.copy(gitState = result) else it }''')
s=s.replace('''        val trimmed = url.trim()
        if (trimmed.isBlank()) return''','''        val trimmed = url.trim()
        if (trimmed.isBlank() || _state.value.cloneInProgress) return
        if (_state.value.tabs.any { it.isDirty }) { _state.update { it.copy(notice = "Save changed files before cloning another project.") }; return }''')
s=s.replace('''        val dest = File(getApplication<Application>().filesDir, "projects/$repoName")''','''        if (!repoName.matches(Regex("[A-Za-z0-9][A-Za-z0-9._-]{0,100}"))) {
            _state.update { it.copy(cloneError = "Repository name is not a valid project folder.") }; return
        }
        val dest = File(getApplication<Application>().filesDir, "projects/$repoName")''')
s=s.replace('''private fun setGitCredentials(username: String, token: String)''','''private fun setGitCredentials(username: String, token: String, authorName: String, authorEmail: String)''')
s=s.replace('''        gitCredentials.token = token
        _state.update { it.copy(gitHasCredentials = gitCredentials.hasCredentials) }''','''        if (token.isNotBlank()) gitCredentials.token = token
        gitCredentials.authorName = authorName
        gitCredentials.authorEmail = authorEmail
        _state.update { it.copy(gitHasCredentials = gitCredentials.hasCredentials, gitUsername = username,
            gitAuthorName = authorName, gitAuthorEmail = authorEmail, notice = "Git settings saved on this phone.") }''')
s=s.replace('''        val root = _state.value.workspaceRoot ?: return
        _state.update { it.copy(gitState = it.gitState.copy(isBusy = true''','''        val root = _state.value.workspaceRoot ?: return
        if (_state.value.gitState.isBusy) return
        _state.update { it.copy(gitState = it.gitState.copy(isBusy = true''')
s=s.replace('''            val result = block(root)''','''            val result = runCatching { block(root).getOrThrow() }
            if (_state.value.workspaceRoot != root) return@launch''')
p.write_text(s)
# Exclude Keystore-encrypted secrets from backup: the encryption key cannot be restored.
(root/'res/xml/backup_rules.xml').write_text('''<?xml version="1.0" encoding="utf-8"?>
<full-backup-content><exclude domain="sharedpref" path="cdr_git_credentials.xml" /></full-backup-content>
''')
(root/'res/xml/data_extraction_rules.xml').write_text('''<?xml version="1.0" encoding="utf-8"?>
<data-extraction-rules>
<cloud-backup><exclude domain="sharedpref" path="cdr_git_credentials.xml" /></cloud-backup>
<device-transfer><exclude domain="sharedpref" path="cdr_git_credentials.xml" /></device-transfer>
</data-extraction-rules>
''')
