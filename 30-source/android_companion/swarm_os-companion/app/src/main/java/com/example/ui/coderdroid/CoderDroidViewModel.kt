package com.example.ui.coderdroid

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.io.File

data class CoderDroidState(
    val workspaceRoot: File? = null,
    val workspaceName: String = "No workspace",
    val tabs: List<CdrEditorTab> = emptyList(),
    val activeTabId: String? = null,
    val sidebarVisible: Boolean = true,
    val terminalVisible: Boolean = false
)

sealed class CoderDroidEvent {
    data class OpenFile(val node: CdrFileNode) : CoderDroidEvent()
    data class CloseTab(val tabId: String) : CoderDroidEvent()
    data class SwitchTab(val tabId: String) : CoderDroidEvent()
    data class MarkDirty(val tabId: String, val dirty: Boolean) : CoderDroidEvent()
    data class SaveTab(val tabId: String, val content: String) : CoderDroidEvent()
    data class OpenWorkspace(val root: File) : CoderDroidEvent()
    object ToggleSidebar : CoderDroidEvent()
    object ToggleTerminal : CoderDroidEvent()
}

class CoderDroidViewModel : ViewModel() {

    private val _state = MutableStateFlow(CoderDroidState())
    val state: StateFlow<CoderDroidState> = _state.asStateFlow()

    fun onEvent(event: CoderDroidEvent) {
        when (event) {
            is CoderDroidEvent.OpenFile      -> openFile(event.node)
            is CoderDroidEvent.CloseTab      -> closeTab(event.tabId)
            is CoderDroidEvent.SwitchTab     -> switchTab(event.tabId)
            is CoderDroidEvent.MarkDirty     -> markDirty(event.tabId, event.dirty)
            is CoderDroidEvent.SaveTab       -> saveTab(event.tabId, event.content)
            is CoderDroidEvent.OpenWorkspace -> openWorkspace(event.root)
            CoderDroidEvent.ToggleSidebar    -> toggleSidebar()
            CoderDroidEvent.ToggleTerminal   -> toggleTerminal()
        }
    }

    // ── Workspace boundary guard ───────────────────────────────────────────────
    // Resolves canonical paths so symlink tricks can't escape the project folder.
    // Returns true only if `file` is inside the current workspace root.
    private fun isWithinWorkspace(file: File): Boolean {
        val root = _state.value.workspaceRoot ?: return false
        return try {
            val canonical     = file.canonicalPath
            val rootCanonical = root.canonicalPath
            canonical == rootCanonical ||
                canonical.startsWith(rootCanonical + File.separator)
        } catch (_: Exception) {
            false
        }
    }

    private fun openFile(node: CdrFileNode) {
        if (!isWithinWorkspace(node.file)) return   // never open files outside the project
        val existing = _state.value.tabs.find { it.filePath == node.path }
        if (existing != null) { switchTab(existing.id); return }
        val tab = CdrEditorTab(fileNode = node)
        _state.update { s -> s.copy(tabs = s.tabs + tab, activeTabId = tab.id) }
    }

    private fun closeTab(tabId: String) {
        val tabs = _state.value.tabs.filter { it.id != tabId }
        val newActive = when {
            _state.value.activeTabId != tabId -> _state.value.activeTabId
            tabs.isEmpty()                    -> null
            else                              -> tabs.last().id
        }
        _state.update { it.copy(tabs = tabs, activeTabId = newActive) }
    }

    private fun switchTab(tabId: String) =
        _state.update { it.copy(activeTabId = tabId) }

    private fun markDirty(tabId: String, dirty: Boolean) =
        _state.update { s ->
            s.copy(tabs = s.tabs.map { t -> if (t.id == tabId) t.copy(isDirty = dirty) else t })
        }

    private fun saveTab(tabId: String, content: String) {
        val tab = _state.value.tabs.find { it.id == tabId } ?: return
        if (!isWithinWorkspace(tab.fileNode.file)) return   // never write outside the project
        viewModelScope.launch(Dispatchers.IO) {
            tab.fileNode.file.writeText(content)
            markDirty(tabId, false)
        }
    }

    private fun openWorkspace(root: File) =
        // Switching projects clears all open tabs — nothing from the old project leaks in
        _state.update { it.copy(workspaceRoot = root, workspaceName = root.name, tabs = emptyList(), activeTabId = null) }

    private fun toggleSidebar() = _state.update { it.copy(sidebarVisible = !it.sidebarVisible) }
    private fun toggleTerminal() = _state.update { it.copy(terminalVisible = !it.terminalVisible) }
}
