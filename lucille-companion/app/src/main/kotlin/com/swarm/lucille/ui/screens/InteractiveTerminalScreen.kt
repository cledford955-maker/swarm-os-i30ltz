package com.swarm.lucille.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Send
import androidx.compose.material.icons.filled.Terminal
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.swarm.lucille.data.config.SwarmConnection
import com.swarm.lucille.ui.theme.*
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import okhttp3.*
import okio.ByteString

@Composable
fun InteractiveTerminalScreen(
    onNavigateBack: () -> Unit = {},
    onNavigateToCheatSheet: () -> Unit = {}
) {
    val context = LocalContext.current
    val connection = remember { SwarmConnection(context) }

    var commandInput by remember { mutableStateOf("") }
    val targetIp = connection.host
    var isIpConfigExpanded by remember { mutableStateOf(false) }

    val terminalLog = remember { mutableStateListOf<String>("Connecting to DR. I30LTZ Terminal ($targetIp)...") }
    val coroutineScope = rememberCoroutineScope()
    val listState = rememberLazyListState()

    var webSocket by remember { mutableStateOf<WebSocket?>(null) }
    var connected by remember { mutableStateOf(false) }
    var attempt by remember { mutableIntStateOf(0) }

    // OkHttp calls back on its own threads; Compose state must change on the main thread.
    fun log(vararg lines: String) {
        coroutineScope.launch(Dispatchers.Main) {
            lines.forEach { text -> text.split("\n").filter { it.isNotEmpty() }.forEach { terminalLog.add(it) } }
            if (terminalLog.size > 1000) repeat(terminalLog.size - 1000) { terminalLog.removeAt(0) }
            if (terminalLog.isNotEmpty()) listState.animateScrollToItem(terminalLog.size - 1)
        }
    }

    DisposableEffect(targetIp, attempt) {
        if (attempt > 0) log("Reconnecting to ${connection.host}:${connection.port}…")
        val request = Request.Builder()
            .url("${connection.wsBase()}/api/terminal/ws")
            .addHeader("X-Swarm-Auth", connection.authToken)
            .build()

        val ws = connection.terminalClient().newWebSocket(request, object : WebSocketListener() {
            override fun onOpen(webSocket: WebSocket, response: Response) {
                coroutineScope.launch(Dispatchers.Main) { connected = true }
                log("⚡ SWARM_OS DR. I30LTZ CYBER TERMINAL ONLINE ($targetIp)")
            }

            override fun onMessage(webSocket: WebSocket, text: String) = log(text)

            override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
                coroutineScope.launch(Dispatchers.Main) { connected = false }
                log("[TERMINAL DISCONNECTED${if (reason.isNotBlank()) ": $reason" else ""}] Tap RECONNECT.")
            }

            override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
                coroutineScope.launch(Dispatchers.Main) { connected = false }
                log("[TERMINAL CONNECTION ERROR] ${connection.explain(t, response?.code)}")
            }
        })
        webSocket = ws

        onDispose {
            ws.close(1000, "Screen disposed")
        }
    }

    fun executeTerminalCommand(cmd: String) {
        val trimmed = cmd.trim()
        if (trimmed.isEmpty()) return
        commandInput = ""
        if (!connected || webSocket?.send(trimmed + "\n") != true) {
            log("[TERMINAL CONNECTION ERROR] Not connected — tap RECONNECT.")
            return
        }
        log("$ $trimmed")
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
            .padding(16.dp)
    ) {
        // Terminal Header
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                imageVector = Icons.Default.Terminal,
                contentDescription = null,
                tint = NvidiaGreen,
                modifier = Modifier.size(24.dp)
            )
            Spacer(modifier = Modifier.width(8.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = "DR. I30LTZ • INTERACTIVE CYBER TERMINAL",
                    color = NvidiaGreen,
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Bold,
                    fontFamily = FontFamily.Monospace
                )
                Text(
                    text = "DR. i3OLTZ Shell Interface • Live WebSocket Session",
                    color = TextMuted,
                    fontSize = 10.sp
                )
            }
            
            IconButton(
                onClick = onNavigateToCheatSheet,
                modifier = Modifier
                    .clip(RoundedCornerShape(8.dp))
                    .background(CarbonSurfaceVariant)
            ) {
                Icon(
                    imageVector = Icons.Default.Warning,
                    contentDescription = "Cheat Sheet",
                    tint = LightningYellow
                )
            }
        }

        // Terminal Output Screen
        Box(
            modifier = Modifier
                .weight(1f)
                .fillMaxWidth()
                .clip(RoundedCornerShape(12.dp))
                .background(Color(0xFF0A0C10))
                .border(1.dp, NvidiaGreen.copy(alpha = 0.5f), RoundedCornerShape(12.dp))
                .padding(12.dp)
        ) {
            LazyColumn(
                state = listState,
                modifier = Modifier.fillMaxSize(),
                verticalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                items(terminalLog) { logLine ->
                    Text(
                        text = logLine,
                        color = when {
                            logLine.contains("⚡") -> NvidiaGreen
                            logLine.contains("ERROR") -> Color.Red
                            else -> TextPrimary
                        },
                        fontSize = 12.sp,
                        fontFamily = FontFamily.Monospace,
                        lineHeight = 16.sp
                    )
                }
            }
        }

        Spacer(modifier = Modifier.height(10.dp))

        // Quick Command Chips
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            TerminalChip(if (connected) "ONLINE" else "RECONNECT") { if (!connected) attempt++ }
            TerminalChip("CLEAR") { terminalLog.clear() }
            TerminalChip("TOP") { executeTerminalCommand("top -b -n 1") }
            TerminalChip("LSBLK") { executeTerminalCommand("lsblk") }
            TerminalChip("HELP") { executeTerminalCommand("help") }
        }

        Spacer(modifier = Modifier.height(8.dp))

        // Command Input Bar
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(bottom = 80.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            OutlinedTextField(
                value = commandInput,
                onValueChange = { newValue ->
                    if (newValue.contains("\n")) {
                        executeTerminalCommand(newValue.replace("\n", ""))
                    } else {
                        commandInput = newValue
                    }
                },
                placeholder = { Text("Enter command...", color = TextMuted, fontSize = 12.sp, fontFamily = FontFamily.Monospace) },
                singleLine = true,
                keyboardOptions = androidx.compose.foundation.text.KeyboardOptions(imeAction = androidx.compose.ui.text.input.ImeAction.Send),
                keyboardActions = androidx.compose.foundation.text.KeyboardActions(
                    onSend = { executeTerminalCommand(commandInput) }
                ),
                colors = OutlinedTextFieldDefaults.colors(
                    focusedBorderColor = NvidiaGreen,
                    unfocusedBorderColor = CarbonBorder,
                    focusedTextColor = NvidiaGreen,
                    unfocusedTextColor = NvidiaGreen,
                    focusedContainerColor = CarbonSurface,
                    unfocusedContainerColor = CarbonSurface
                ),
                shape = RoundedCornerShape(10.dp),
                modifier = Modifier.weight(1f)
            )

            Spacer(modifier = Modifier.width(8.dp))

            IconButton(
                onClick = { executeTerminalCommand(commandInput) },
                modifier = Modifier
                    .size(48.dp)
                    .clip(RoundedCornerShape(10.dp))
                    .background(NvidiaGreen)
            ) {
                Icon(
                    imageVector = Icons.AutoMirrored.Filled.Send,
                    contentDescription = "Send",
                    tint = Color.Black
                )
            }
        }
    }
}

@Composable
fun TerminalChip(label: String, onClick: () -> Unit) {
    Surface(
        color = CarbonSurfaceVariant,
        shape = RoundedCornerShape(8.dp),
        border = androidx.compose.foundation.BorderStroke(1.dp, CarbonBorder),
        modifier = Modifier.clickable { onClick() }
    ) {
        Text(
            text = label,
            color = NvidiaGreen,
            fontSize = 9.sp,
            fontWeight = FontWeight.Bold,
            fontFamily = FontFamily.Monospace,
            modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
        )
    }
}
