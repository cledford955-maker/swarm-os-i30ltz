// VoiceScreen.kt — Google Voice: SMS / Calls / Voicemail  v1.0.0  2026-09-24
package com.swarm.lucille.ui.screen

import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.material3.TabRowDefaults.tabIndicatorOffset
import androidx.compose.runtime.*
import androidx.compose.ui.*
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.*
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.swarm.lucille.data.network.MailMessage
import com.swarm.lucille.ui.theme.*
import com.swarm.lucille.ui.viewmodel.MainViewModel

@Composable
fun VoiceScreen(vm: MainViewModel) {
    var tab by remember { mutableStateOf(0) }
    val tabs = listOf("SMS", "CALLS", "VOICEMAIL")

    Column(modifier = Modifier.fillMaxSize().background(SwarmBg)) {
        TabRow(
            selectedTabIndex = tab,
            containerColor   = SwarmSurface,
            contentColor     = SwarmCyan,
            indicator = { pos ->
                TabRowDefaults.SecondaryIndicator(
                    modifier = Modifier.tabIndicatorOffset(pos[tab]),
                    color    = SwarmCyan
                )
            }
        ) {
            tabs.forEachIndexed { i, label ->
                Tab(
                    selected = tab == i,
                    onClick  = { tab = i },
                    text = {
                        Text(label, style = MaterialTheme.typography.labelLarge,
                            color = if (tab == i) SwarmCyan else TextDisabled)
                    }
                )
            }
        }

        when (tab) {
            0 -> VoiceSMSTab(vm)
            1 -> VoiceCallsTab(vm)
            2 -> VoiceVoicemailTab(vm)
        }
    }
}

// ─── SMS ──────────────────────────────────────────────────────────────────────

@Composable
fun VoiceSMSTab(vm: MainViewModel) {
    val state by vm.voiceSMS.collectAsStateWithLifecycle()
    var showReply by remember { mutableStateOf<String?>(null) }   // threadId
    var replyBody by remember { mutableStateOf("") }
    var sending   by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) { vm.loadVoiceSMS() }

    Column(modifier = Modifier.fillMaxSize()) {
        when {
            state.loading    -> SwarmLoading("Loading SMS…")
            state.error != null -> SwarmError(state.error!!) { vm.loadVoiceSMS(true) }
            else -> {
                val msgs = state.data?.messages ?: emptyList()
                if (msgs.isEmpty()) {
                    SwarmEmpty("No SMS messages") { vm.loadVoiceSMS(true) }
                } else {
                    LazyColumn(
                        modifier = Modifier.weight(1f),
                        contentPadding = PaddingValues(bottom = 8.dp)
                    ) {
                        item {
                            Row(
                                modifier = Modifier.fillMaxWidth().padding(16.dp, 8.dp),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Text("${msgs.size} messages", style = MaterialTheme.typography.labelMedium)
                                TextButton(onClick = { vm.loadVoiceSMS(true) }) {
                                    Text("↺", color = SwarmCyan)
                                }
                            }
                        }
                        items(msgs, key = { it.id }) { msg ->
                            VoiceMessageRow(
                                msg   = msg,
                                icon  = "💬",
                                onClick = { showReply = msg.threadId }
                            )
                        }
                    }
                }
            }
        }

        // Reply sheet
        if (showReply != null) {
            Surface(
                color = SwarmSurface,
                tonalElevation = 4.dp,
                modifier = Modifier.fillMaxWidth()
            ) {
                Column(modifier = Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text("Reply via Google Voice", style = MaterialTheme.typography.headlineSmall, modifier = Modifier.weight(1f))
                        TextButton(onClick = { showReply = null; replyBody = "" }) {
                            Text("✕", color = TextSecondary)
                        }
                    }
                    OutlinedTextField(
                        value         = replyBody,
                        onValueChange = { replyBody = it },
                        modifier      = Modifier.fillMaxWidth(),
                        placeholder   = { Text("Type a message…") },
                        colors = OutlinedTextFieldDefaults.colors(
                            focusedBorderColor   = SwarmPurple,
                            unfocusedBorderColor = SwarmBorder,
                            cursorColor          = SwarmCyan
                        )
                    )
                    Button(
                        onClick = {
                            val tid = showReply ?: return@Button
                            sending = true
                            vm.sendVoiceSMS(tid, replyBody) { ok ->
                                sending = false
                                if (ok) { showReply = null; replyBody = "" }
                            }
                        },
                        enabled  = replyBody.isNotBlank() && !sending,
                        modifier = Modifier.fillMaxWidth(),
                        colors   = ButtonDefaults.buttonColors(containerColor = SwarmPurple)
                    ) {
                        if (sending) CircularProgressIndicator(color = TextPrimary, strokeWidth = 2.dp, modifier = Modifier.size(18.dp))
                        else Text("SEND SMS")
                    }
                }
            }
        }
    }
}

// ─── Calls ────────────────────────────────────────────────────────────────────

@Composable
fun VoiceCallsTab(vm: MainViewModel) {
    val state by vm.voiceCalls.collectAsStateWithLifecycle()

    LaunchedEffect(Unit) { vm.loadVoiceCalls() }

    when {
        state.loading    -> SwarmLoading("Loading call log…")
        state.error != null -> SwarmError(state.error!!) { vm.loadVoiceCalls(true) }
        else -> {
            val msgs = state.data?.messages ?: emptyList()
            if (msgs.isEmpty()) SwarmEmpty("No recent calls") { vm.loadVoiceCalls(true) }
            else {
                LazyColumn(contentPadding = PaddingValues(bottom = 8.dp)) {
                    item {
                        Row(
                            modifier = Modifier.fillMaxWidth().padding(16.dp, 8.dp),
                            horizontalArrangement = Arrangement.SpaceBetween
                        ) {
                            Text("${msgs.size} calls", style = MaterialTheme.typography.labelMedium)
                            TextButton(onClick = { vm.loadVoiceCalls(true) }) { Text("↺", color = SwarmCyan) }
                        }
                    }
                    items(msgs, key = { it.id }) { msg ->
                        val icon = when {
                            msg.subject?.contains("Missed", ignoreCase = true) == true -> "📵"
                            msg.subject?.contains("Placed", ignoreCase = true) == true -> "📤"
                            else -> "📥"
                        }
                        VoiceMessageRow(msg = msg, icon = icon, onClick = {})
                    }
                }
            }
        }
    }
}

// ─── Voicemail ────────────────────────────────────────────────────────────────

@Composable
fun VoiceVoicemailTab(vm: MainViewModel) {
    val state by vm.voiceVoicemail.collectAsStateWithLifecycle()

    LaunchedEffect(Unit) { vm.loadVoiceVoicemail() }

    when {
        state.loading    -> SwarmLoading("Loading voicemail…")
        state.error != null -> SwarmError(state.error!!) { vm.loadVoiceVoicemail(true) }
        else -> {
            val msgs = state.data?.messages ?: emptyList()
            if (msgs.isEmpty()) SwarmEmpty("No voicemails") { vm.loadVoiceVoicemail(true) }
            else {
                LazyColumn(contentPadding = PaddingValues(bottom = 8.dp)) {
                    item {
                        Row(
                            modifier = Modifier.fillMaxWidth().padding(16.dp, 8.dp),
                            horizontalArrangement = Arrangement.SpaceBetween
                        ) {
                            Text("${msgs.size} voicemails", style = MaterialTheme.typography.labelMedium)
                            TextButton(onClick = { vm.loadVoiceVoicemail(true) }) { Text("↺", color = SwarmCyan) }
                        }
                    }
                    items(msgs, key = { it.id }) { msg ->
                        VoiceMessageRow(msg = msg, icon = "🎙️", onClick = {})
                    }
                }
            }
        }
    }
}

// ─── Shared row ───────────────────────────────────────────────────────────────

@Composable
fun VoiceMessageRow(msg: MailMessage, icon: String, onClick: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 12.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(icon, fontSize = 24.sp)
        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Text(
                    msg.from?.split("<")?.firstOrNull()?.trim() ?: "Unknown",
                    style = MaterialTheme.typography.headlineSmall,
                    maxLines = 1, overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.weight(1f)
                )
                Text(msg.date?.take(10) ?: "", style = MaterialTheme.typography.labelSmall)
            }
            Text(
                msg.subject ?: "(no subject)",
                style = MaterialTheme.typography.bodySmall,
                maxLines = 1, overflow = TextOverflow.Ellipsis,
                color = TextSecondary
            )
            if (!msg.snippet.isNullOrBlank()) {
                Text(
                    msg.snippet,
                    style = MaterialTheme.typography.labelSmall,
                    maxLines = 1, overflow = TextOverflow.Ellipsis
                )
            }
        }
    }
    HorizontalDivider(color = SwarmBorder, thickness = 0.5.dp)
}
