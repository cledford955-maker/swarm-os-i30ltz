package com.swarm.lucille.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Sync
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.swarm.lucille.data.memory.MemoryEntryEntity
import com.swarm.lucille.data.memory.MemorySyncEngine
import com.swarm.lucille.ui.theme.*
import kotlinx.coroutines.launch
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter

private val kindFilters = listOf("" to "All", "note" to "Notes", "fact" to "Facts", "decision" to "Decisions", "claude_memory" to "Claude", "chatgpt_memory" to "ChatGPT memories", "chatgpt_conversation" to "ChatGPT chats", "doc" to "Core docs")
private val writableKinds = listOf("note" to "Note", "fact" to "Fact", "decision" to "Decision")

private fun kindColor(kind: String): Color = when (kind) {
    "decision" -> LightningYellow
    "fact" -> NeonGreen
    "claude_memory" -> ElectricCyan
    "doc" -> ElectricPurple
    else -> TextSecondary
}

private val timeFmt = DateTimeFormatter.ofPattern("MMM d · HH:mm").withZone(ZoneId.systemDefault())
private fun shortTime(ts: String) = runCatching { timeFmt.format(Instant.parse(ts)) }.getOrDefault(ts.take(16))

/**
 * Shared memory — the same log 13E457-THUNDERI30LT keeps at /mnt/brains/swarm-memory,
 * including Claude's memory files and Lucille's core docs.
 */
@Composable
fun MemoryScreen() {
    val engine = MemorySyncEngine
    val scope = rememberCoroutineScope()

    DisposableEffect(Unit) {
        engine.requestSync()
        engine.startLive()
        onDispose { engine.stopLive() }
    }

    var kind by remember { mutableStateOf("") }
    var query by remember { mutableStateOf("") }
    val entries by remember(kind, query) { engine.entries(kind, query) }.collectAsStateWithLifecycle(emptyList())
    val total by engine.count().collectAsStateWithLifecycle(0)
    val pending by engine.pending.collectAsStateWithLifecycle()
    val status by engine.status.collectAsStateWithLifecycle()
    val syncing by engine.syncing.collectAsStateWithLifecycle()
    val peers by engine.peers.collectAsStateWithLifecycle()
    val lease by engine.lease.collectAsStateWithLifecycle()
    val live by engine.live.collectAsStateWithLifecycle()
    val meshEnabled by engine.meshEnabled.collectAsStateWithLifecycle()
    LaunchedEffect(Unit) { engine.startMeshIfSecure() } // picks up a token saved in Remote PC
    var message by remember { mutableStateOf<String?>(null) }

    LazyColumn(
        modifier = Modifier.fillMaxSize().padding(horizontal = 14.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
        contentPadding = PaddingValues(top = 30.dp, bottom = 24.dp)
    ) {
        item {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) {
                    Text("SHARED MEMORY", color = ElectricCyan, fontSize = 11.sp, fontWeight = FontWeight.Bold, letterSpacing = 2.sp)
                    Text("$total entries · ${engine.deviceId}", color = TextSecondary, fontSize = 12.sp, fontFamily = FontFamily.Monospace)
                }
                Box(Modifier.size(8.dp).clip(CircleShape).background(if (live) NeonGreen else TextMuted))
                Spacer(Modifier.width(6.dp))
                Text(if (live) "LIVE" else "OFFLINE", color = if (live) NeonGreen else TextMuted, fontSize = 10.sp, fontWeight = FontWeight.Bold)
                Spacer(Modifier.width(10.dp))
                FilledTonalButton(onClick = { engine.requestSync() }, enabled = !syncing, contentPadding = PaddingValues(horizontal = 12.dp)) {
                    Icon(Icons.Default.Sync, contentDescription = null, modifier = Modifier.size(16.dp))
                    Spacer(Modifier.width(4.dp))
                    Text(if (syncing) "Syncing…" else "Sync now", fontSize = 12.sp)
                }
            }
        }

        item {
            Panel {
                Text(status, color = TextPrimary, fontSize = 13.sp)
                if (pending > 0) Text("$pending waiting to reach 13E457-THUNDERI30LT", color = LightningYellow, fontSize = 12.sp)
                if (!meshEnabled) Text(
                    "Phone-to-phone sync is off: this phone still uses the default SWARM token. Enter your real token in Remote PC to turn it on.",
                    color = LightningYellow, fontSize = 12.sp
                )
                peers.forEach { p ->
                    Row(Modifier.padding(top = 4.dp), verticalAlignment = Alignment.CenterVertically) {
                        Box(Modifier.size(6.dp).clip(CircleShape).background(if (p.lastError == null) NeonGreen else ElectricRed))
                        Spacer(Modifier.width(6.dp))
                        Text(p.name, color = TextPrimary, fontSize = 12.sp, modifier = Modifier.weight(1f))
                        Text(
                            p.lastError ?: "↓${p.pulled} ↑${p.pushed}",
                            color = if (p.lastError == null) TextSecondary else ElectricRed,
                            fontSize = 11.sp, maxLines = 1, overflow = TextOverflow.Ellipsis,
                            modifier = Modifier.widthIn(max = 200.dp)
                        )
                    }
                }
            }
        }

        item {
            Panel {
                val mine = lease.holder == engine.deviceId
                Text("MAIN DEVICE (LIVE EDITING)", color = TextMuted, fontSize = 10.sp, fontWeight = FontWeight.Bold, letterSpacing = 1.5.sp)
                Text(
                    when {
                        !lease.known -> "Unknown until 13E457-THUNDERI30LT is reachable"
                        lease.isFree -> "Nobody — any device can write"
                        mine -> "This phone"
                        else -> lease.holder
                    },
                    color = if (mine) NeonGreen else TextPrimary, fontSize = 14.sp, fontWeight = FontWeight.SemiBold
                )
                Row(Modifier.padding(top = 6.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    when {
                        mine -> OutlinedButton(onClick = { scope.launch { engine.releaseLease() } }) { Text("Release") }
                        lease.isFree -> Button(onClick = {
                            scope.launch { engine.acquireLease(false).onFailure { message = it.message } }
                        }) { Text("Make this phone main") }
                        else -> Button(
                            onClick = { scope.launch { engine.acquireLease(true).onFailure { message = it.message } } },
                            colors = ButtonDefaults.buttonColors(containerColor = ElectricRedDark)
                        ) { Text("Take over") }
                    }
                }
            }
        }

        item { Composer(onSave = { k, key, text ->
            scope.launch {
                message = when (val r = engine.add(k, key, text)) {
                    is MemorySyncEngine.WriteResult.Saved -> null
                    is MemorySyncEngine.WriteResult.Blocked -> "${r.holder} is main right now. Take over to write."
                }
            }
        }) }

        message?.let { m -> item { Text(m, color = ElectricRed, fontSize = 12.sp) } }

        item {
            OutlinedTextField(
                value = query, onValueChange = { query = it }, singleLine = true,
                leadingIcon = { Icon(Icons.Default.Search, contentDescription = null) },
                placeholder = { Text("Search memory") },
                modifier = Modifier.fillMaxWidth()
            )
            Row(Modifier.padding(top = 8.dp).fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                kindFilters.take(3).forEach { (k, label) -> FilterChip(selected = kind == k, onClick = { kind = k }, label = { Text(label, fontSize = 11.sp) }) }
            }
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                kindFilters.drop(3).forEach { (k, label) -> FilterChip(selected = kind == k, onClick = { kind = k }, label = { Text(label, fontSize = 11.sp) }) }
            }
        }

        if (entries.isEmpty()) {
            item {
                Text(
                    if (total == 0) "No memories on this phone yet. Sync with 13E457-THUNDERI30LT to pull the shared log." else "Nothing matches.",
                    color = TextMuted, fontSize = 13.sp, modifier = Modifier.padding(vertical = 24.dp)
                )
            }
        }
        items(entries, key = { it.id }) { EntryRow(it) }
    }
}

@Composable
private fun Panel(content: @Composable ColumnScope.() -> Unit) {
    Column(
        Modifier.fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(CarbonSurface.copy(alpha = 0.92f))
            .border(1.dp, CarbonBorder, RoundedCornerShape(12.dp))
            .padding(12.dp),
        content = content
    )
}

@Composable
private fun Composer(onSave: (kind: String, key: String, text: String) -> Unit) {
    var kind by remember { mutableStateOf("note") }
    var key by remember { mutableStateOf("") }
    var text by remember { mutableStateOf("") }
    Panel {
        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            writableKinds.forEach { (k, label) -> FilterChip(selected = kind == k, onClick = { kind = k }, label = { Text(label, fontSize = 11.sp) }) }
        }
        if (kind != "note") {
            OutlinedTextField(
                value = key, onValueChange = { key = it }, singleLine = true,
                label = { Text("Key (a newer ${kind} with the same key replaces it)") },
                modifier = Modifier.fillMaxWidth()
            )
        }
        OutlinedTextField(
            value = text, onValueChange = { text = it }, minLines = 2,
            placeholder = { Text("Something every OS, phone and AI should remember") },
            modifier = Modifier.fillMaxWidth().padding(top = 6.dp)
        )
        Button(
            onClick = { onSave(kind, if (kind == "note") "" else key, text); text = ""; key = "" },
            enabled = text.isNotBlank(),
            modifier = Modifier.padding(top = 6.dp).align(Alignment.End)
        ) { Text("Save to memory") }
    }
}

@Composable
private fun EntryRow(e: MemoryEntryEntity) {
    var expanded by remember { mutableStateOf(false) }
    Column(
        Modifier.fillMaxWidth()
            .clip(RoundedCornerShape(10.dp))
            .background(CarbonSurface.copy(alpha = 0.85f))
            .clickable { expanded = !expanded }
            .padding(10.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(e.kind.replace('_', ' ').uppercase(), color = kindColor(e.kind), fontSize = 10.sp, fontWeight = FontWeight.Bold, letterSpacing = 1.sp)
            if (e.key.isNotEmpty()) {
                Spacer(Modifier.width(6.dp))
                Text(e.key, color = TextPrimary, fontSize = 12.sp, fontFamily = FontFamily.Monospace, maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f, fill = false))
            }
            Spacer(Modifier.weight(1f))
            Text(shortTime(e.ts), color = TextMuted, fontSize = 10.sp)
        }
        Text(
            if (e.deleted) "(deleted)" else e.content,
            color = if (e.deleted) TextMuted else TextSecondary,
            fontSize = 13.sp,
            maxLines = if (expanded) Int.MAX_VALUE else 3,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.padding(top = 4.dp)
        )
        if (e.kind.startsWith("chatgpt_")) {
            val metadata = runCatching { org.json.JSONObject(e.metaJson) }.getOrNull()
            Text("ChatGPT export snapshot · source date ${metadata?.optString("source_modified").orEmpty().ifBlank { "unknown" }} · not live cloud sync", color = TextMuted, fontSize = 10.sp)
        }
        Text(e.device, color = TextMuted, fontSize = 10.sp, fontFamily = FontFamily.Monospace, modifier = Modifier.padding(top = 4.dp))
    }
}
