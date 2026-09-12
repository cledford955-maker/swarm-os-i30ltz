package com.example.ui.screens

import android.content.Intent
import android.net.Uri
import android.os.Environment
import android.widget.Toast
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.example.data.config.SwarmConnection
import com.example.ui.coderdroid.*
import com.example.ui.theme.*
import kotlinx.coroutines.launch
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import okhttp3.WebSocket
import okhttp3.WebSocketListener
import java.io.File

/**
 * Coder Droid IDE screen — integrated into SWARM_OS Companion.
 * Full layout: sidebar file tree + Monaco editor + tab bar + status bar.
 */
@Composable
fun CoderDroidScreen(
    viewModel: CoderDroidViewModel = viewModel(),
    onNavigateBack: (() -> Unit)? = null
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val context = LocalContext.current

    // Intercept Android back so it doesn't pop out of the IDE unexpectedly.
    // If terminal or sidebar is open, close those first; otherwise go back to Dashboard.
    BackHandler(enabled = true) {
        when {
            state.terminalVisible -> viewModel.onEvent(CoderDroidEvent.ToggleTerminal)
            state.sidebarVisible  -> viewModel.onEvent(CoderDroidEvent.ToggleSidebar)
            else                  -> onNavigateBack?.invoke()
        }
    }

    // Folder picker — uses SAF with persistent URI permission
    val folderPicker = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.OpenDocumentTree()
    ) { uri: Uri? ->
        uri?.let { treeUri ->
            // Take persistent permission so the URI survives app restart
            val flags = Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
            try {
                context.contentResolver.takePersistableUriPermission(treeUri, flags)
            } catch (_: SecurityException) {}

            // Try to resolve the actual File path from the SAF tree URI
            val rawPath = treeUri.path ?: return@let
            val resolved: File? = when {
                rawPath.startsWith("/tree/primary:") -> {
                    val rel = rawPath.removePrefix("/tree/primary:")
                    File(Environment.getExternalStorageDirectory(), rel)
                }
                rawPath.startsWith("/tree/home:") -> {
                    val rel = rawPath.removePrefix("/tree/home:")
                    File(Environment.getExternalStorageDirectory(), rel)
                }
                else -> {
                    // Fall back: try to find the root segment after the last ':'
                    val rel = rawPath.substringAfterLast(':', "")
                    if (rel.isNotEmpty()) File(Environment.getExternalStorageDirectory(), rel) else null
                }
            }

            if (resolved != null && resolved.exists()) {
                viewModel.onEvent(CoderDroidEvent.OpenWorkspace(resolved))
            } else {
                // Direct File path didn't resolve — try common Syncthing path patterns
                // by extracting the last path segment from the SAF URI
                val lastSegment = rawPath.substringAfterLast('/').substringAfterLast(':')
                val syncPath = File(Environment.getExternalStorageDirectory(), "Syncthing/SWARM_OS/$lastSegment")
                val altPath  = File(Environment.getExternalStorageDirectory(), lastSegment)
                val fallback = when {
                    syncPath.exists() -> syncPath
                    altPath.exists()  -> altPath
                    else              -> null
                }
                if (fallback != null) {
                    viewModel.onEvent(CoderDroidEvent.OpenWorkspace(fallback))
                } else {
                    Toast.makeText(
                        context,
                        "Folder not accessible directly. Ensure Syncthing synced SWARM_OS to /storage/emulated/0/Syncthing/SWARM_OS/",
                        Toast.LENGTH_LONG
                    ).show()
                }
            }
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(CarbonBackground)
    ) {
        // ── Top bar ────────────────────────────────────────────────────────────
        CdrTopBar(
            workspaceName  = state.workspaceName,
            onOpenFolder   = { folderPicker.launch(null) },
            onToggleSidebar = { viewModel.onEvent(CoderDroidEvent.ToggleSidebar) },
            onToggleTerminal = { viewModel.onEvent(CoderDroidEvent.ToggleTerminal) },
            onOpenDrI30LTZ  = {
                // Open the DR. I30LTZ Recovery project from Syncthing-synced folder
                val candidates = listOf(
                    File(Environment.getExternalStorageDirectory(), "Syncthing/SWARM_OS/i30ltz-recovery"),
                    File(Environment.getExternalStorageDirectory(), "SWARM_OS/i30ltz-recovery"),
                    File(Environment.getExternalStorageDirectory(), "i30ltz-recovery")
                )
                val found = candidates.firstOrNull { it.exists() }
                if (found != null) {
                    viewModel.onEvent(CoderDroidEvent.OpenWorkspace(found))
                } else {
                    Toast.makeText(
                        context,
                        "DR. I30LTZ project not found. Ensure Syncthing is syncing SWARM_OS → phone.",
                        Toast.LENGTH_LONG
                    ).show()
                }
            }
        )

        // ── Main area ──────────────────────────────────────────────────────────
        Row(modifier = Modifier.weight(1f)) {

            if (state.sidebarVisible) {
                CdrFileTreePanel(
                    workspaceRoot = state.workspaceRoot,
                    workspaceName = state.workspaceName,
                    onFileClick   = { viewModel.onEvent(CoderDroidEvent.OpenFile(it)) },
                    modifier      = Modifier
                        .width(220.dp)
                        .fillMaxHeight()
                )
            }

            Column(modifier = Modifier.weight(1f).fillMaxHeight()) {

                CdrTabBar(
                    tabs        = state.tabs,
                    activeTabId = state.activeTabId,
                    onTabClick  = { viewModel.onEvent(CoderDroidEvent.SwitchTab(it)) },
                    onTabClose  = { viewModel.onEvent(CoderDroidEvent.CloseTab(it)) }
                )

                val activeTab = state.tabs.find { it.id == state.activeTabId }

                CdrMonacoEditorView(
                    tab              = activeTab,
                    onContentChanged = { viewModel.onEvent(CoderDroidEvent.MarkDirty(it, true)) },
                    onSaveRequested  = { tabId, content -> viewModel.onEvent(CoderDroidEvent.SaveTab(tabId, content)) },
                    modifier         = Modifier.weight(1f).fillMaxWidth()
                )

                if (state.terminalVisible) {
                    CdrInlineTerminal(
                        modifier = Modifier.height(200.dp).fillMaxWidth()
                    )
                }
            }
        }

        // ── Status bar ─────────────────────────────────────────────────────────
        CdrStatusBar(
            workspaceName   = state.workspaceName,
            activeTab       = state.tabs.find { it.id == state.activeTabId },
            terminalVisible = state.terminalVisible,
            onToggleTerminal = { viewModel.onEvent(CoderDroidEvent.ToggleTerminal) }
        )
    }
}

// ── Top bar ────────────────────────────────────────────────────────────────────

@Composable
private fun CdrTopBar(
    workspaceName: String,
    onOpenFolder: () -> Unit,
    onToggleSidebar: () -> Unit,
    onToggleTerminal: () -> Unit,
    onOpenDrI30LTZ: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(CarbonSurface)
            .border(1.dp, CarbonBorder)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .height(44.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Row(
                modifier = Modifier.padding(start = 10.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                // SWARM electric bolt badge
                Box(
                    modifier = Modifier
                        .clip(RoundedCornerShape(4.dp))
                        .background(ElectricPurple.copy(alpha = 0.2f))
                        .border(1.dp, ElectricPurple.copy(alpha = 0.5f), RoundedCornerShape(4.dp))
                        .padding(horizontal = 6.dp, vertical = 2.dp)
                ) {
                    Text(
                        text = "⚡ CODER DROID",
                        color = ElectricPurple,
                        fontSize = 10.sp,
                        fontWeight = FontWeight.ExtraBold,
                        letterSpacing = 1.sp
                    )
                }

                Text(
                    text = workspaceName,
                    color = TextSecondary,
                    fontSize = 11.sp,
                    fontFamily = FontFamily.Monospace
                )
            }

            Row(
                modifier = Modifier.padding(end = 8.dp),
                horizontalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                CdrIconButton(Icons.Default.FolderOpen, "Open folder", ElectricCyan) { onOpenFolder() }
                CdrIconButton(Icons.Default.ViewSidebar, "Toggle sidebar", TextSecondary) { onToggleSidebar() }
                CdrIconButton(Icons.Default.Terminal, "Toggle terminal", TextSecondary) { onToggleTerminal() }
            }
        }

        // Quick-open row for DR. I30LTZ Recovery project
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .height(28.dp)
                .background(CarbonSurfaceVariant)
                .clickable { onOpenDrI30LTZ() }
                .padding(horizontal = 10.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            Icon(Icons.Default.Bolt, null, tint = LightningYellow, modifier = Modifier.size(11.dp))
            Text(
                text = "DR. I30LTZ Recovery",
                color = LightningYellow,
                fontSize = 10.sp,
                fontWeight = FontWeight.Bold,
                letterSpacing = 0.5.sp
            )
            Text(
                text = "· tap to open project",
                color = TextMuted,
                fontSize = 10.sp
            )
        }
    }
}

// ── Status bar ─────────────────────────────────────────────────────────────────

@Composable
private fun CdrStatusBar(
    workspaceName: String,
    activeTab: CdrEditorTab?,
    terminalVisible: Boolean,
    onToggleTerminal: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(22.dp)
            .background(ElectricPurple.copy(alpha = 0.85f)),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        Row(
            modifier = Modifier.padding(start = 8.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(Icons.Default.Bolt, null, tint = Color.White, modifier = Modifier.size(12.dp))
            Text(workspaceName, color = Color.White, fontSize = 10.sp)
        }

        Row(
            modifier = Modifier.padding(end = 8.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            activeTab?.let {
                Text(it.languageId, color = Color.White, fontSize = 10.sp)
                Text("Ln ${it.cursorLine + 1}  Col ${it.cursorColumn + 1}", color = Color.White, fontSize = 10.sp)
            }
            Icon(
                Icons.Default.Terminal, "Terminal",
                tint = if (terminalVisible) LightningYellow else Color.White,
                modifier = Modifier.size(12.dp)
            )
        }
    }
}

// ── Inline terminal ────────────────────────────────────────────────────────────

/**
 * Live shell inside the IDE, over LucyServer's /api/terminal/ws. Replaces the
 * previous placeholder that only printed "coming soon". Host, port and the
 * X-Swarm-Auth token come from [SwarmConnection], so configuring the node in
 * Remote PC also configures this.
 */
@Composable
private fun CdrInlineTerminal(modifier: Modifier = Modifier) {
    val context = LocalContext.current
    val connection = remember { SwarmConnection(context) }
    val scope = rememberCoroutineScope()
    val listState = rememberLazyListState()

    var commandInput by remember { mutableStateOf("") }
    var connected by remember { mutableStateOf(false) }
    val lines = remember { mutableStateListOf("Connecting to ${connection.host}:${connection.port}…") }
    var socket by remember { mutableStateOf<WebSocket?>(null) }

    fun append(text: String) {
        text.split("\n").filter { it.isNotEmpty() }.forEach { lines.add(it) }
        if (lines.size > 500) repeat(lines.size - 500) { lines.removeAt(0) }
        scope.launch { if (lines.isNotEmpty()) listState.animateScrollToItem(lines.size - 1) }
    }

    DisposableEffect(connection.host, connection.port) {
        val client = OkHttpClient()
        val request = Request.Builder()
            .url("${connection.wsBase()}/api/terminal/ws")
            .addHeader("X-Swarm-Auth", connection.authToken)
            .build()

        val ws = client.newWebSocket(request, object : WebSocketListener() {
            override fun onOpen(webSocket: WebSocket, response: Response) {
                connected = true
                append("⚡ connected to ${connection.host}")
            }

            override fun onMessage(webSocket: WebSocket, text: String) = append(text)

            override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
                connected = false
                append("[disconnected: $reason]")
            }

            override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
                connected = false
                append("[connection error: ${t.message}]")
            }
        })
        socket = ws
        onDispose { ws.close(1000, "terminal closed") }
    }

    Column(
        modifier = modifier
            .background(CarbonSurface)
            .border(1.dp, CarbonBorder)
            .padding(8.dp)
    ) {
        LazyColumn(state = listState, modifier = Modifier.weight(1f).fillMaxWidth()) {
            items(lines) { line ->
                Text(
                    text = line,
                    color = if (line.startsWith("[")) Color(0xFFFF6B6B) else NeonGreen,
                    fontSize = 11.sp,
                    fontFamily = FontFamily.Monospace,
                    lineHeight = 14.sp
                )
            }
        }

        Row(modifier = Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            Text(
                text = if (connected) "$ " else "× ",
                color = if (connected) NeonGreen else Color(0xFFFF6B6B),
                fontSize = 12.sp,
                fontFamily = FontFamily.Monospace
            )
            BasicTextField(
                value = commandInput,
                onValueChange = { newValue ->
                    if (newValue.contains("\n")) {
                        val cmd = newValue.replace("\n", "").trim()
                        if (cmd.isNotEmpty()) {
                            socket?.send(cmd + "\n")
                            append("$ $cmd")
                        }
                        commandInput = ""
                    } else {
                        commandInput = newValue
                    }
                },
                singleLine = true,
                enabled = connected,
                textStyle = TextStyle(color = NeonGreen, fontSize = 12.sp, fontFamily = FontFamily.Monospace),
                cursorBrush = SolidColor(NeonGreen),
                keyboardOptions = KeyboardOptions(imeAction = ImeAction.Send),
                keyboardActions = KeyboardActions(onSend = {
                    val cmd = commandInput.trim()
                    if (cmd.isNotEmpty() && connected) {
                        socket?.send(cmd + "\n")
                        append("$ $cmd")
                    }
                    commandInput = ""
                }),
                modifier = Modifier.weight(1f)
            )
        }
    }
}

// ── Reusable icon button ───────────────────────────────────────────────────────

@Composable
private fun CdrIconButton(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    desc: String,
    tint: Color,
    onClick: () -> Unit
) {
    IconButton(onClick = onClick, modifier = Modifier.size(32.dp)) {
        Icon(icon, desc, tint = tint, modifier = Modifier.size(18.dp))
    }
}
