package com.swarm.lucille.ui.coderdroid

/** One file's git status, relative to the workspace root. */
data class CdrGitFileStatus(
    val path: String,
    val kind: Kind,
    val staged: Boolean
) {
    enum class Kind { MODIFIED, ADDED, DELETED, UNTRACKED, CONFLICTING, RENAMED, MISSING }
}

/** Snapshot of the open workspace's git state, or the "not a repo" state. */
data class CdrGitState(
    val isRepo: Boolean = false,
    val branch: String = "",
    val ahead: Int = 0,
    val behind: Int = 0,
    val staged: List<CdrGitFileStatus> = emptyList(),
    val unstaged: List<CdrGitFileStatus> = emptyList(),
    val isBusy: Boolean = false,
    val lastError: String? = null,
    val lastMessage: String? = null
) {
    val hasChanges: Boolean get() = staged.isNotEmpty() || unstaged.isNotEmpty()
}
