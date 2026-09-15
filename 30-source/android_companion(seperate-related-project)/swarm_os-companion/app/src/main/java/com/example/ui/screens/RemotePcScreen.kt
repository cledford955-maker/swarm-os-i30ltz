package com.example.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Send
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.KeyboardReturn
import androidx.compose.material.icons.filled.Terminal
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.data.config.SwarmConnection
import com.example.ui.theme.CarbonBorder
import com.example.ui.theme.CarbonSurface
import com.example.ui.theme.CarbonSurfaceVariant
import com.example.ui.theme.LightningYellow
import com.example.ui.theme.NvidiaGreen
import com.example.ui.theme.TextMuted
import com.example.ui.theme.TextPrimary
import kotlinx.coroutines.launch
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.RequestBody.Companion.toRequestBody

@Composable
fun RemotePcScreen(onBack: () -> Unit = {}) {
    val context = LocalContext.current
    val connection = remember { SwarmConnection(context) }

    var commandInput by remember { mutableStateOf("") }
    var targetIp by remember { mutableStateOf(connection.host) }
    var authTokenInput by remember { mutableStateOf(connection.authToken) }
    var isIpConfigExpanded by remember { mutableStateOf(false) }

    val terminalLog = remember {
        mutableStateListOf(
            "root@swarm-pc:~# SWARM_OS CYBER TERMINAL v3.6 ONLINE",
            "root@swarm-pc:~# Target Node: ${connection.host} (LucyServer .NET 8 / REST & WS)",
            "------------------------------------------------------------------------"
        )
    }
    val coroutineScope = rememberCoroutineScope()
    val listState = rememberLazyListState()

    fun executeTerminalCommand(rawInput: String) {
        val trimmed = rawInput.trim().removeSuffix("\n")
        if (trimmed.isEmpty()) return

        terminalLog.add("root@${connection.host}:~# $trimmed")

        coroutineScope.launch(kotlinx.coroutines.Dispatchers.IO) {
            try {
                val jsonMedia = "application/json".toMediaType()
                val isClipboard = trimmed.startsWith("clipboard ")

                val url = if (isClipboard) "${connection.httpBase()}/api/clipboard/set" else "${connection.httpBase()}/api/run_command"
                val bodyText = if (isClipboard) "{\"Text\":\"${trimmed.removePrefix("clipboard ")}\"}" else "{\"Command\":\"$trimmed\"}"
                val reqBody = bodyText.toRequestBody(jsonMedia)
                val request = okhttp3.Request.Builder()
                    .url(url)
                    .addHeader("X-Swarm-Auth", connection.authToken)
                    .post(reqBody)
                    .build()
                val client = okhttp3.OkHttpClient()
                val response = client.newCall(request).execute()
                val responseBody = response.body?.string() ?: ""

                kotlinx.coroutines.withContext(kotlinx.coroutines.Dispatchers.Main) {
                    if (response.isSuccessful) {
                        terminalLog.add(if (isClipboard) "Clipboard updated remotely." else responseBody)
                    } else {
                        terminalLog.add("Error: ${response.code} $responseBody")
                    }
                    listState.animateScrollToItem(terminalLog.size - 1)
                }
            } catch (e: Exception) {
                kotlinx.coroutines.withContext(kotlinx.coroutines.Dispatchers.Main) {
                    terminalLog.add("Network Error: ${e.message}")
                    listState.animateScrollToItem(terminalLog.size - 1)
                }
            }
        }
        commandInput = ""
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
            .padding(16.dp)
    ) {
        Column(modifier = Modifier.fillMaxSize()) {
            // Header Bar
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    IconButton(onClick = onBack) {
                        Icon(Icons.Default.ArrowBack, contentDescription = "Back", tint = NvidiaGreen)
                    }
                    Spacer(modifier = Modifier.width(4.dp))
                    Column {
                        Text(
                            text = "REMOTE PC CYBER TERMINAL",
                            color = NvidiaGreen,
                            fontSize = 16.sp,
                            fontWeight = FontWeight.Bold,
                            fontFamily = FontFamily.Monospace
                        )
                        Text(
                            text = "NODE: ${connection.host} • PORT ${connection.port}",
                            color = Color(0xFFE040FB),
                            fontSize = 10.sp,
                            fontWeight = FontWeight.Bold
                        )
                        if (!connection.isUsable) {
                            Text(
                                text = "⚠ host or auth token is blank — commands will fail",
                                color = Color.Red,
                                fontSize = 9.sp,
                                fontWeight = FontWeight.Bold
                            )
                        }
                    }
                }

                Surface(
                    color = NvidiaGreen.copy(alpha = 0.15f),
                    shape = RoundedCornerShape(8.dp),
                    border = androidx.compose.foundation.BorderStroke(1.dp, NvidiaGreen),
                    modifier = Modifier.clickable { isIpConfigExpanded = !isIpConfigExpanded }
                ) {
                    Text(
                        text = "CHANGE NODE",
                        color = NvidiaGreen,
                        fontSize = 10.sp,
                        fontWeight = FontWeight.Bold,
                        modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
                    )
                }
            }

            // Dynamic Tailscale Node Switcher
            if (isIpConfigExpanded) {
                Card(
                    colors = CardDefaults.cardColors(containerColor = CarbonSurfaceVariant),
                    shape = RoundedCornerShape(8.dp),
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(bottom = 8.dp)
                ) {
                    Column(modifier = Modifier.padding(8.dp)) {
                        Text("Dynamic Tailscale Node IP:", color = TextPrimary, fontSize = 11.sp, fontWeight = FontWeight.Bold)
                        Spacer(modifier = Modifier.height(4.dp))
                        OutlinedTextField(
                            value = targetIp,
                            onValueChange = { targetIp = it },
                            singleLine = true,
                            modifier = Modifier.fillMaxWidth(),
                            textStyle = androidx.compose.ui.text.TextStyle(fontSize = 12.sp, color = Color.White, fontFamily = FontFamily.Monospace)
                        )
                        Spacer(modifier = Modifier.height(8.dp))
                        Text("X-Swarm-Auth token:", color = TextPrimary, fontSize = 11.sp, fontWeight = FontWeight.Bold)
                        Spacer(modifier = Modifier.height(4.dp))
                        OutlinedTextField(
                            value = authTokenInput,
                            onValueChange = { authTokenInput = it },
                            singleLine = true,
                            modifier = Modifier.fillMaxWidth(),
                            textStyle = androidx.compose.ui.text.TextStyle(fontSize = 12.sp, color = Color.White, fontFamily = FontFamily.Monospace)
                        )
                        Spacer(modifier = Modifier.height(8.dp))
                        Button(
                            onClick = {
                                connection.host = targetIp
                                connection.authToken = authTokenInput
                                isIpConfigExpanded = false
                                terminalLog.add("⚡ Node switched to ${connection.host}")
                            },
                            colors = ButtonDefaults.buttonColors(containerColor = NvidiaGreen),
                            modifier = Modifier.align(Alignment.End)
                        ) {
                            Text("SAVE", color = Color.Black, fontSize = 11.sp, fontWeight = FontWeight.Bold)
                        }
                    }
                }
            }

            // Quick Desktop Command Launchers
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = 6.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                QuickCommandTile("tailscale status", "TAILSCALE", NvidiaGreen) { executeTerminalCommand("tailscale status") }
                QuickCommandTile("ping a17", "PING a17", LightningYellow) { executeTerminalCommand("ping a17") }
                QuickCommandTile("ping a16", "PING a16", Color.Cyan) { executeTerminalCommand("ping a16") }
                QuickCommandTile("lucille audit", "AUDIT", Color(0xFFE040FB)) { executeTerminalCommand("lucille audit") }
            }

            Spacer(modifier = Modifier.height(8.dp))

            // Live Terminal Log Screen Box
            Box(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(12.dp))
                    .background(Color(0xFF0A0C10))
                    .border(1.dp, NvidiaGreen.copy(alpha = 0.6f), RoundedCornerShape(12.dp))
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
                                logLine.startsWith("root@") -> NvidiaGreen
                                logLine.contains("⚡") -> Color(0xFFE040FB)
                                logLine.contains("PING") -> LightningYellow
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

            // Command Input Box with Enter Support
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                OutlinedTextField(
                    value = commandInput,
                    onValueChange = { newValue ->
                        if (newValue.contains("\n")) {
                            executeTerminalCommand(newValue)
                        } else {
                            commandInput = newValue
                        }
                    },
                    placeholder = { Text("Type command & press ENTER...", color = TextMuted, fontSize = 12.sp, fontFamily = FontFamily.Monospace) },
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(imeAction = ImeAction.Go),
                    keyboardActions = KeyboardActions(
                        onGo = { executeTerminalCommand(commandInput) },
                        onDone = { executeTerminalCommand(commandInput) },
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

                // Dedicated RUN / ENTER Button
                Button(
                    onClick = { executeTerminalCommand(commandInput) },
                    colors = ButtonDefaults.buttonColors(containerColor = NvidiaGreen, contentColor = Color.Black),
                    shape = RoundedCornerShape(10.dp),
                    modifier = Modifier.height(54.dp)
                ) {
                    Icon(Icons.Default.KeyboardReturn, contentDescription = "Enter", modifier = Modifier.size(18.dp))
                    Spacer(modifier = Modifier.width(4.dp))
                    Text("ENTER", fontWeight = FontWeight.Bold, fontSize = 12.sp)
                }
            }
        }
    }
}

@Composable
private fun QuickCommandTile(cmd: String, label: String, color: Color, onClick: () -> Unit) {
    Surface(
        color = CarbonSurface,
        shape = RoundedCornerShape(8.dp),
        border = androidx.compose.foundation.BorderStroke(1.dp, color.copy(alpha = 0.5f)),
        modifier = Modifier.clickable { onClick() }
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Box(modifier = Modifier.size(6.dp).clip(RoundedCornerShape(3.dp)).background(color))
            Spacer(modifier = Modifier.width(6.dp))
            Text(label, color = color, fontSize = 10.sp, fontWeight = FontWeight.Bold, fontFamily = FontFamily.Monospace)
        }
    }
}



