// SwarmScreen.kt — SWARM OS Status | AI Coach | Telemetry  v1.0.0  2026-09-24
// Enterprise dark-theme live telemetry + gaming coach + system status
package com.swarm.lucille.ui.screen

import androidx.compose.animation.*
import androidx.compose.animation.core.*
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.*
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.*
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.swarm.lucille.data.network.*
import com.swarm.lucille.ui.theme.*
import com.swarm.lucille.ui.viewmodel.MainViewModel

@Composable
fun SwarmScreen(vm: MainViewModel) {
    var tab by remember { mutableStateOf(0) }
    val tabs = listOf("STATUS", "AI COACH", "TELEMETRY")

    Column(modifier = Modifier.fillMaxSize().background(SwarmBg)) {
        // SWARM header
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .background(Brush.horizontalGradient(listOf(Color(0xFF0D0020), SwarmSurface2)))
                .padding(horizontal = 16.dp, vertical = 10.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text("🔥 SWARM OS", style = MaterialTheme.typography.displaySmall, color = SwarmCyan)
                Text("v1.2.0 · 2026-09-24", style = MaterialTheme.typography.labelSmall)
            }
        }

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
            0 -> SwarmStatusTab(vm)
            1 -> CoachTab(vm)
            2 -> TelemetryTab(vm)
        }
    }
}

// ─── SWARM Status ─────────────────────────────────────────────────────────────

@Composable
fun SwarmStatusTab(vm: MainViewModel) {
    val telState  by vm.telemetry.collectAsStateWithLifecycle()
    val briefState by vm.projectBrief.collectAsStateWithLifecycle()

    LaunchedEffect(Unit) {
        vm.loadTelemetryOnce()
        vm.loadProjectBrief()
    }

    LazyColumn(
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        // Quick telemetry snapshot
        item {
            val t = telState.data?.telemetry
            SwarmCard {
                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    StatusGaugeChip("CPU",  t?.cpu?.usagePct ?: 0.0, "${t?.cpu?.usagePct?.toInt() ?: "?"}%")
                    StatusGaugeChip("RAM",  t?.memory?.usagePct ?: 0.0, "${t?.memory?.usagePct?.toInt() ?: "?"}%")
                    StatusGaugeChip("GPU",  t?.gpu?.usagePct ?: 0.0, "${t?.gpu?.usagePct?.toInt() ?: "?"}%")
                    StatusGaugeChip("VRAM",
                        if ((t?.gpu?.memTotalMB ?: 0.0) > 0)
                            (t!!.gpu!!.memUsedMB / t.gpu!!.memTotalMB) * 100 else 0.0,
                        "${t?.gpu?.memUsedMB?.toInt() ?: "?"} MB")
                }
                Spacer(Modifier.height(8.dp))
                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    Text("↑ ${t?.uptime ?: "—"}", style = MaterialTheme.typography.labelSmall, color = SwarmGreen)
                    Text("Load: ${t?.loadAvg?.firstOrNull()?.let { String.format("%.2f", it) } ?: "—"}",
                        style = MaterialTheme.typography.labelSmall)
                    Text("Temp: ${t?.cpu?.tempC?.let { "${it.toInt()}°C" } ?: "—"}",
                        style = MaterialTheme.typography.labelSmall,
                        color = if ((t?.cpu?.tempC ?: 0.0) > 85) SwarmRed else TextSecondary)
                }
            }
        }

        // Project suggestions (from brief)
        val suggestions = briefState.data?.suggestions ?: emptyList()
        if (suggestions.isNotEmpty()) {
            item { SectionHeader("💡 LUCILLE'S ROADMAP") }
            items(suggestions.take(5)) { s -> SuggestionCard(s) }
        }

        // Go to full telemetry
        item {
            OutlinedButton(
                onClick = { /* navigate to telemetry tab — handled by tab index above */ },
                modifier = Modifier.fillMaxWidth(),
                colors = ButtonDefaults.outlinedButtonColors(contentColor = SwarmCyan),
                border = BorderStroke(1.dp, SwarmBorder)
            ) {
                Text("VIEW LIVE TELEMETRY →", style = MaterialTheme.typography.labelLarge)
            }
        }
    }
}

@Composable
fun RowScope.StatusGaugeChip(label: String, pct: Double, value: String) {
    val color = gaugeColor(pct)
    Column(
        modifier = Modifier
            .weight(1f)
            .clip(RoundedCornerShape(10.dp))
            .background(color.copy(0.12f))
            .padding(8.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        Text(label, style = MaterialTheme.typography.labelSmall, color = TextSecondary)
        Text(value, style = MaterialTheme.typography.labelLarge, color = color, fontWeight = FontWeight.Bold)
        LinearProgressIndicator(
            progress = { (pct.coerceIn(0.0, 100.0) / 100).toFloat() },
            modifier = Modifier.fillMaxWidth().height(4.dp).clip(RoundedCornerShape(2.dp)),
            color = color, trackColor = SwarmBorder
        )
    }
}

// ─── AI Coach ─────────────────────────────────────────────────────────────────

@Composable
fun CoachTab(vm: MainViewModel) {
    val state    by vm.coach.collectAsStateWithLifecycle()
    val game     by vm.coachGame.collectAsStateWithLifecycle("")
    var editGame by remember { mutableStateOf(false) }
    var newGame  by remember { mutableStateOf("") }

    LaunchedEffect(Unit) { vm.loadCoachTips(game) }

    LazyColumn(
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        // Coach header card
        item {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(16.dp))
                    .background(Brush.horizontalGradient(listOf(SwarmPurple.copy(0.7f), SwarmCyan.copy(0.2f))))
                    .padding(20.dp)
            ) {
                Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text("🎮 AI GAMING COACH", style = MaterialTheme.typography.labelLarge)
                    if (game.isNotBlank()) {
                        Text(game, style = MaterialTheme.typography.displaySmall, color = TextPrimary)
                    } else {
                        Text("All Games / SWARM OS", style = MaterialTheme.typography.displaySmall, color = TextSecondary)
                    }
                    TextButton(onClick = { editGame = true; newGame = game }) {
                        Text(if (game.isBlank()) "Set current game →" else "Change game →",
                            color = SwarmCyan, style = MaterialTheme.typography.labelLarge)
                    }
                }
            }
        }

        // Game picker dialog
        if (editGame) {
            item {
                SwarmCard {
                    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text("CURRENT GAME", style = MaterialTheme.typography.labelLarge)
                        OutlinedTextField(
                            value = newGame,
                            onValueChange = { newGame = it },
                            modifier = Modifier.fillMaxWidth(),
                            placeholder = { Text("e.g. Cyberpunk 2077") },
                            singleLine = true,
                            colors = OutlinedTextFieldDefaults.colors(
                                focusedBorderColor   = SwarmPurple,
                                unfocusedBorderColor = SwarmBorder,
                                cursorColor          = SwarmCyan
                            )
                        )
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            OutlinedButton(onClick = { editGame = false }, modifier = Modifier.weight(1f)) {
                                Text("CANCEL")
                            }
                            Button(
                                onClick = {
                                    vm.setCoachGame(newGame.trim())
                                    editGame = false
                                },
                                modifier = Modifier.weight(1f),
                                colors = ButtonDefaults.buttonColors(containerColor = SwarmPurple)
                            ) {
                                Text("SET GAME")
                            }
                        }
                    }
                }
            }
        }

        // Refresh button
        item {
            TextButton(onClick = { vm.loadCoachTips(game) }, modifier = Modifier.fillMaxWidth()) {
                Text("↺ REFRESH TIPS", color = SwarmCyan, style = MaterialTheme.typography.labelLarge)
            }
        }

        // Tips
        when {
            state.loading -> item { SwarmLoading("Loading tips…") }
            state.error != null -> item { SwarmError(state.error!!) { vm.loadCoachTips(game) } }
            else -> {
                val tips = state.data?.tips ?: emptyList()
                if (tips.isEmpty()) {
                    item { SwarmEmpty("No tips yet") { vm.loadCoachTips(game) } }
                } else {
                    // Group by category
                    val groups = tips.groupBy { it.category }
                    val order = listOf("performance", "gaming", "health", "swarm", "shortcut")
                    val sorted = order.mapNotNull { cat -> groups[cat]?.let { cat to it } } +
                        groups.filter { it.key !in order }.entries.map { it.key to it.value }

                    sorted.forEach { (cat, catTips) ->
                        item { CoachCategoryHeader(cat) }
                        items(catTips) { tip -> CoachTipCard(tip) }
                    }
                }
            }
        }
    }
}

@Composable
fun CoachCategoryHeader(cat: String) {
    val (icon, color) = when (cat) {
        "performance" -> "⚡" to SwarmOrange
        "gaming"      -> "🎮" to SwarmGreen
        "health"      -> "💙" to Color(0xFF60A5FA)
        "swarm"       -> "🔥" to SwarmPurple
        "shortcut"    -> "⌨" to SwarmCyan
        else          -> "💡" to SwarmGold
    }
    Row(
        modifier = Modifier.padding(top = 4.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(icon, fontSize = 16.sp)
        Text(cat.uppercase(), style = MaterialTheme.typography.labelLarge, color = color)
    }
}

@Composable
fun CoachTipCard(tip: CoachTip) {
    val isLive = tip.source == "live"
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(10.dp))
            .background(if (isLive) SwarmRed.copy(0.08f) else SwarmSurface2)
            .padding(14.dp),
        horizontalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        Text(if (isLive) "🔴" else "▸", fontSize = 14.sp, modifier = Modifier.padding(top = 2.dp))
        Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(tip.tip, style = MaterialTheme.typography.bodyMedium, color = if (isLive) SwarmRed else TextPrimary)
            if (isLive) {
                Text("LIVE DATA", style = MaterialTheme.typography.labelSmall, color = SwarmRed)
            }
        }
    }
}

// ─── Live Telemetry ───────────────────────────────────────────────────────────

@Composable
fun TelemetryTab(vm: MainViewModel) {
    val state by vm.telemetry.collectAsStateWithLifecycle()

    // Auto-poll every 3 seconds while screen is visible
    DisposableEffect(Unit) {
        vm.startTelemetryPolling()
        onDispose { vm.stopTelemetryPolling() }
    }

    val t = state.data?.telemetry

    LazyColumn(
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        // Header: live / loading indicator
        item {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text("📊 LIVE TELEMETRY", style = MaterialTheme.typography.labelLarge, color = SwarmCyan)
                if (state.loading) {
                    CircularProgressIndicator(color = SwarmCyan, strokeWidth = 2.dp, modifier = Modifier.size(14.dp))
                } else {
                    val ts = t?.timestamp?.take(19) ?: ""
                    Text(ts, style = MaterialTheme.typography.labelSmall)
                }
            }
        }

        // CPU
        item {
            TelemetrySection("🖥 CPU") {
                t?.cpu?.let { cpu ->
                    Text("${cpu.model ?: "CPU"} (${cpu.cores} cores)",
                        style = MaterialTheme.typography.bodySmall, color = TextSecondary)
                    Spacer(Modifier.height(8.dp))
                    GaugeBar("Usage", cpu.usagePct)
                    GaugeBar("Temp", cpu.tempC, "${cpu.tempC.toInt()}°C",
                        color = if (cpu.tempC > 85) SwarmRed else if (cpu.tempC > 70) SwarmGold else SwarmGreen)
                    MonoRow("Freq", "${String.format("%.0f", cpu.freqMHz)} MHz")
                } ?: Text("No CPU data", style = MaterialTheme.typography.bodySmall)
            }
        }

        // Memory
        item {
            TelemetrySection("💾 MEMORY") {
                t?.memory?.let { mem ->
                    GaugeBar("RAM", mem.usagePct,
                        "${mem.usedMB / 1024}/${mem.totalMB / 1024} GB")
                    if (mem.swapTotalMB > 0) {
                        val swapPct = if (mem.swapTotalMB > 0)
                            (mem.swapUsedMB.toDouble() / mem.swapTotalMB * 100) else 0.0
                        GaugeBar("SWAP", swapPct,
                            "${mem.swapUsedMB}/${mem.swapTotalMB} MB")
                    }
                    MonoRow("Available", "${mem.availMB} MB")
                } ?: Text("No memory data", style = MaterialTheme.typography.bodySmall)
            }
        }

        // GPU
        item {
            TelemetrySection("🎮 GPU") {
                t?.gpu?.let { gpu ->
                    Text("${gpu.vendor ?: "GPU"}: ${gpu.name ?: ""}",
                        style = MaterialTheme.typography.bodySmall, color = TextSecondary)
                    Spacer(Modifier.height(8.dp))
                    GaugeBar("GPU Usage", gpu.usagePct)
                    if (gpu.memTotalMB > 0) {
                        val vramPct = (gpu.memUsedMB / gpu.memTotalMB) * 100
                        GaugeBar("VRAM", vramPct,
                            "${gpu.memUsedMB.toInt()}/${gpu.memTotalMB.toInt()} MB")
                    }
                    GaugeBar("Temp", gpu.tempC, "${gpu.tempC.toInt()}°C",
                        color = if (gpu.tempC > 88) SwarmRed else if (gpu.tempC > 75) SwarmGold else SwarmGreen)
                    if (gpu.powerW > 0) MonoRow("Power", "${gpu.powerW.toInt()} W")
                    if (gpu.fanPct > 0) MonoRow("Fan",   "${gpu.fanPct.toInt()}%")
                } ?: Text("No GPU detected", style = MaterialTheme.typography.bodySmall, color = TextSecondary)
            }
        }

        // Network
        val nets = t?.network?.filter { it.name != "lo" } ?: emptyList()
        if (nets.isNotEmpty()) {
            item {
                TelemetrySection("🌐 NETWORK") {
                    nets.forEach { iface ->
                        Row(
                            modifier = Modifier.fillMaxWidth().padding(vertical = 3.dp),
                            horizontalArrangement = Arrangement.SpaceBetween
                        ) {
                            Text(iface.name, style = MaterialTheme.typography.labelLarge, color = SwarmCyan)
                            Text("↓ ${String.format("%.2f", iface.rxMbps)} MB/s  ↑ ${String.format("%.2f", iface.txMbps)} MB/s",
                                style = MaterialTheme.typography.labelMedium)
                        }
                    }
                }
            }
        }

        // Top processes
        val procs = t?.topProcs ?: emptyList()
        if (procs.isNotEmpty()) {
            item {
                TelemetrySection("⚙ TOP PROCESSES") {
                    // Header
                    Row(modifier = Modifier.fillMaxWidth()) {
                        Text("PID", style = MaterialTheme.typography.labelSmall,
                            modifier = Modifier.width(48.dp))
                        Text("NAME", style = MaterialTheme.typography.labelSmall, modifier = Modifier.weight(1f))
                        Text("CPU%", style = MaterialTheme.typography.labelSmall, modifier = Modifier.width(44.dp), textAlign = TextAlign.End)
                        Text("MEM", style = MaterialTheme.typography.labelSmall, modifier = Modifier.width(52.dp), textAlign = TextAlign.End)
                    }
                    HorizontalDivider(color = SwarmBorder, thickness = 0.5.dp, modifier = Modifier.padding(vertical = 4.dp))
                    procs.forEach { proc ->
                        Row(
                            modifier = Modifier.fillMaxWidth().padding(vertical = 3.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text("${proc.pid}", style = MaterialTheme.typography.labelSmall,
                                color = TextDisabled, modifier = Modifier.width(48.dp), fontFamily = FontFamily.Monospace)
                            Text(proc.name, style = MaterialTheme.typography.bodySmall,
                                modifier = Modifier.weight(1f))
                            Text("${String.format("%.1f", proc.cpuPct)}",
                                style = MaterialTheme.typography.labelLarge,
                                color = gaugeColor(proc.cpuPct),
                                modifier = Modifier.width(44.dp), textAlign = TextAlign.End)
                            Text("${proc.memMB.toInt()} MB",
                                style = MaterialTheme.typography.labelSmall,
                                modifier = Modifier.width(52.dp), textAlign = TextAlign.End)
                        }
                    }
                }
            }
        }

        // Load avg + uptime
        item {
            TelemetrySection("ℹ SYSTEM") {
                t?.loadAvg?.let { la ->
                    MonoRow("Load Avg", la.joinToString("  ") { String.format("%.2f", it) })
                }
                MonoRow("Uptime", t?.uptime ?: "—")
            }
        }
    }
}

// ─── Telemetry UI helpers ─────────────────────────────────────────────────────

@Composable
fun TelemetrySection(title: String, content: @Composable ColumnScope.() -> Unit) {
    SwarmCard {
        Text(title, style = MaterialTheme.typography.labelLarge, color = SwarmCyan)
        Spacer(Modifier.height(8.dp))
        content()
    }
}

@Composable
fun MonoRow(label: String, value: String) {
    Row(
        modifier = Modifier.fillMaxWidth().padding(vertical = 2.dp),
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        Text(label, style = MaterialTheme.typography.labelMedium, color = TextSecondary)
        Text(value,  style = MaterialTheme.typography.labelLarge,  color = TextPrimary, fontFamily = FontFamily.Monospace)
    }
}
