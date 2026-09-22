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
    var portInput by remember { mutableStateOf(connection.port.toString()) }
    var isIpConfigExpanded by remember { mutableStateOf(false) }

    val terminalLog = remember {
        mutableStateListOf(
            "I30LTZ Companion — remote terminal (connection not tested)",
            "Target node: ${connection.host} (LucyServer · REST & WS)",
            "------------------------------------------------------------------------"
        )
    }
    val coroutineScope = rememberCoroutineScope()
    val listState = rememberLazyListState()

    var connectionStatus by remember { mutableStateOf("Not tested") }
    var checking by remember { mutableStateOf(false) }
    fun checkConnection() {
        if(checking) return
        checking = true
        coroutineScope.launch {
            connectionStatus = kotlinx.coroutines.withContext(kotlinx.coroutines.Dispatchers.IO) {
                try {
                    val client = okhttp3.OkHttpClient.Builder().connectTimeout(8, java.util.concurrent.TimeUnit.SECONDS).readTimeout(10, java.util.concurrent.TimeUnit.SECONDS).build()
                    val request = okhttp3.Request.Builder().url("${connection.httpBase()}/api/system/stats").header("X-Swarm-Auth",connection.authToken).build()
                    client.newCall(request).execute().use { response ->
                        if(response.isSuccessful) "Connected and authenticated: ${connection.host}:${connection.port}"
                        else connection.explain(null,response.code)
                    }
                } catch(e: Exception) { connection.explain(e) }
            }
            checking = false
        }
    }

    fun executeTerminalCommand(rawInput: String) {
        val trimmed = rawInput.trim().removeSuffix("\n")
        if (trimmed.isEmpty()) return

        terminalLog.add("${connection.host} $ $trimmed")

        coroutineScope.launch(kotlinx.coroutines.Dispatchers.IO) {
            try {
                val jsonMedia = "application/json".toMediaType()
                val isClipboard = trimmed.startsWith("clipboard ")

                val url = if (isClipboard) "${connection.httpBase()}/api/clipboard/set" else "${connection.httpBase()}/api/run_command"
                // JSONObject escapes quotes and backslashes; the old hand-built
                // string turned any command containing " into invalid JSON (HTTP 400).
                val bodyText = if (isClipboard) {
                    org.json.JSONObject().put("text", trimmed.removePrefix("clipboard ")).toString()
                } else {
                    org.json.JSONObject().put("command", trimmed).toString()
                }
                val request = okhttp3.Request.Builder()
                    .url(url)
                    .addHeader("X-Swarm-Auth", connection.authToken)
                    .post(bodyText.toRequestBody(jsonMedia))
                    .build()
                val client = okhttp3.OkHttpClient.Builder()
                    .connectTimeout(8, java.util.concurrent.TimeUnit.SECONDS)
                    .readTimeout(120, java.util.concurrent.TimeUnit.SECONDS)
                    .build()
                val lines = client.newCall(request).execute().use { response ->
                    val responseBody = response.body?.string() ?: ""
                    when {
                        !response.isSuccessful -> listOf("Error: ${connection.explain(null, response.code)}")
                        isClipboard -> listOf("Clipboard updated remotely.")
                        else -> {
                            val result = runCatching { org.json.JSONObject(responseBody) }.getOrNull()
                            if (result == null) listOf(responseBody) else buildList {
                                result.optString("standardOutput").trimEnd().takeIf { it.isNotEmpty() }?.let { addAll(it.split("\n")) }
                                result.optString("standardError").trimEnd().takeIf { it.isNotEmpty() }?.let { addAll(it.split("\n")) }
                                val code = result.optInt("exitCode", 0)
                                if (code != 0) add("[exit $code]")
                                if (isEmpty()) add("(no output)")
                            }
                        }
                    }
                }

                kotlinx.coroutines.withContext(kotlinx.coroutines.Dispatchers.Main) {
                    terminalLog.addAll(lines)
                    listState.animateScrollToItem(terminalLog.size - 1)
                }
            } catch (e: Exception) {
                kotlinx.coroutines.withContext(kotlinx.coroutines.Dispatchers.Main) {
                    terminalLog.add("Network Error: ${connection.explain(e)}")
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

            Text(connectionStatus, color = TextPrimary, fontSize = 12.sp)
            Row {
                TextButton(onClick = { checkConnection() }, enabled = !checking) { Text(if(checking) "Testing…" else "Test connection") }
                TextButton(onClick = {
                    val intent = context.packageManager.getLaunchIntentForPackage("com.tailscale.ipn")
                    if(intent != null) context.startActivity(intent) else connectionStatus = "Tailscale is not installed on this phone."
                }) { Text("Open Tailscale") }
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
                        Text("Port (LucyServer, default 5000):", color = TextPrimary, fontSize = 11.sp, fontWeight = FontWeight.Bold)
                        Spacer(modifier = Modifier.height(4.dp))
                        OutlinedTextField(
                            value = portInput,
                            onValueChange = { v -> portInput = v.filter { it.isDigit() }.take(5) },
                            singleLine = true,
                            modifier = Modifier.fillMaxWidth(),
                            textStyle = androidx.compose.ui.text.TextStyle(fontSize = 12.sp, color = Color.White, fontFamily = FontFamily.Monospace)
                        )
                        Spacer(modifier = Modifier.height(8.dp))
                        Text("X-Swarm-Auth token:", color = TextPrimary, fontSize = 11.sp, fontWeight = FontWeight.Bold)
                        Spacer(modifier = Modifier.height(4.dp))
                        OutlinedTextField(
                            visualTransformation = androidx.compose.ui.text.input.PasswordVisualTransformation(),
                            value = authTokenInput,
                            onValueChange = { authTokenInput = it },
                            singleLine = true,
                            modifier = Modifier.fillMaxWidth(),
                            textStyle = androidx.compose.ui.text.TextStyle(fontSize = 12.sp, color = Color.White, fontFamily = FontFamily.Monospace)
                        )
                        Spacer(modifier = Modifier.height(8.dp))
                        Button(
                            onClick = {
                                val host = targetIp.trim().removePrefix("http://").removePrefix("https://").trimEnd('/')
                                if(!host.matches(Regex("[A-Za-z0-9.-]+")) || portInput.toIntOrNull() !in 1..65535) {
                                    connectionStatus = "Use a hostname or IPv4 address without a port/path, and a port from 1 to 65535."
                                    return@Button
                                }
                                connection.host = host
                                connection.authToken = authTokenInput
                                portInput.toIntOrNull()?.takeIf { it in 1..65535 }?.let { connection.port = it }
                                com.example.data.memory.MemorySyncEngine.connectionChanged()
                                isIpConfigExpanded = false
                                terminalLog.add("Node saved: ${connection.host}:${connection.port}")
                                checkConnection()
                            },
                            colors = ButtonDefaults.buttonColors(containerColor = NvidiaGreen),
                            modifier = Modifier.align(Alignment.End)
                        ) {
                            Text("SAVE & TEST", color = Color.Black, fontSize = 11.sp, fontWeight = FontWeight.Bold)
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
                QuickCommandTile("ping A17", "PING A17", LightningYellow) { executeTerminalCommand("ping -c 3 -W 3 100.82.1.17") }
                QuickCommandTile("ping A16", "PING A16", Color.Cyan) { executeTerminalCommand("ping -c 3 -W 3 100.82.1.16") }
                QuickCommandTile("i30ltz audit", "AUDIT", Color(0xFFE040FB)) { executeTerminalCommand("i30ltz audit") }
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



