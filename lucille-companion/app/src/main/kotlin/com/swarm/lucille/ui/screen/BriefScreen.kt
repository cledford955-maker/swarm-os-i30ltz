// BriefScreen.kt — Daily + Project brief tabs  v1.0.0  2026-09-24
package com.swarm.lucille.ui.screen

import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.material3.TabRowDefaults.tabIndicatorOffset
import androidx.compose.runtime.*
import androidx.compose.ui.*
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.*
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.swarm.lucille.data.network.*
import com.swarm.lucille.ui.theme.*
import com.swarm.lucille.ui.viewmodel.MainViewModel

@Composable
fun BriefScreen(vm: MainViewModel) {
    var tab by remember { mutableStateOf(0) }
    val tabs = listOf("DAILY", "PROJECT", "BRIEFINGS")

    Column(modifier = Modifier.fillMaxSize().background(SwarmBg)) {
        // Sub-tab bar
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
                    text     = { Text(label, style = MaterialTheme.typography.labelLarge,
                        color = if (tab == i) SwarmCyan else TextDisabled) }
                )
            }
        }

        when (tab) {
            0 -> DailyTab(vm)
            1 -> ProjectTab(vm)
            2 -> BriefingsTab(vm)
        }
    }
}

// ─── Daily Brief ──────────────────────────────────────────────────────────────

@Composable
fun DailyTab(vm: MainViewModel) {
    val state by vm.dailyBrief.collectAsStateWithLifecycle()

    LaunchedEffect(Unit) { vm.loadDailyBrief() }

    when {
        state.loading -> SwarmLoading("Loading daily brief…")
        state.error  != null -> SwarmError(state.error!!) { vm.loadDailyBrief(true) }
        state.data   != null -> DailyContent(state.data!!, onRefresh = { vm.loadDailyBrief(true) })
        else -> SwarmEmpty("No brief yet") { vm.loadDailyBrief() }
    }
}

@Composable
fun DailyContent(brief: DailyBriefResponse, onRefresh: () -> Unit) {
    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        // Headline card
        item {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(16.dp))
                    .background(Brush.horizontalGradient(listOf(SwarmPurple.copy(0.6f), SwarmCyan.copy(0.3f))))
                    .padding(20.dp)
            ) {
                Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text("⚡ DAILY BRIEF", style = MaterialTheme.typography.labelLarge)
                    Text(brief.headline ?: "Good morning, broken.",
                        style = MaterialTheme.typography.displaySmall,
                        color = TextPrimary
                    )
                    Text(brief.generatedAt?.take(16) ?: "", style = MaterialTheme.typography.labelSmall)
                }
            }
        }

        // Nudges
        if (!brief.nudges.isNullOrEmpty()) {
            item { SectionHeader("🔔 NUDGES") }
            items(brief.nudges) { nudge -> NudgeCard(nudge) }
        }

        // Sessions today
        brief.sessions?.todayMin?.let { todayMin ->
            if (todayMin.isNotEmpty()) {
                item { SectionHeader("⏱ TODAY'S SESSIONS") }
                item {
                    SwarmCard {
                        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                            todayMin.entries.sortedByDescending { it.value }.forEach { (proj, mins) ->
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.SpaceBetween
                                ) {
                                    Text(proj, style = MaterialTheme.typography.bodyMedium)
                                    Text("${mins.toInt()} min", style = MaterialTheme.typography.labelLarge, color = SwarmCyan)
                                }
                            }
                        }
                    }
                }
            }
        }

        // Drive usage
        if (!brief.drives.isNullOrEmpty()) {
            item { SectionHeader("💾 STORAGE") }
            items(brief.drives.filter { it.mounted }) { drive -> DriveUsageCard(drive) }
        }

        // Refresh
        item {
            TextButton(onClick = onRefresh, modifier = Modifier.fillMaxWidth()) {
                Text("↺ REFRESH BRIEF", color = SwarmCyan, style = MaterialTheme.typography.labelLarge)
            }
        }
    }
}

// ─── Project Brief ────────────────────────────────────────────────────────────

@Composable
fun ProjectTab(vm: MainViewModel) {
    val state by vm.projectBrief.collectAsStateWithLifecycle()

    LaunchedEffect(Unit) { vm.loadProjectBrief() }

    when {
        state.loading -> SwarmLoading("Loading project brief…")
        state.error  != null -> SwarmError(state.error!!) { vm.loadProjectBrief(true) }
        state.data   != null -> ProjectContent(state.data!!, onRefresh = { vm.loadProjectBrief(true) })
        else -> SwarmEmpty("No project brief yet") { vm.loadProjectBrief() }
    }
}

@Composable
fun ProjectContent(brief: ProjectBriefResponse, onRefresh: () -> Unit) {
    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        // Project headline
        item {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(16.dp))
                    .background(Brush.horizontalGradient(listOf(Color(0xFF4B0082), SwarmPurple)))
                    .padding(20.dp)
            ) {
                Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text("🛠 PROJECT STATUS", style = MaterialTheme.typography.labelLarge)
                    Text(brief.projectHeadline ?: "SWARM OS Suite in progress.",
                        style = MaterialTheme.typography.displaySmall,
                        color = TextPrimary
                    )
                }
            }
        }

        // Lucille suggestions — ranked by priority
        if (!brief.suggestions.isNullOrEmpty()) {
            item { SectionHeader("💡 LUCILLE SUGGESTS") }
            items(brief.suggestions) { s -> SuggestionCard(s) }
        }

        // Git status
        if (!brief.git.isNullOrEmpty()) {
            item { SectionHeader("🔀 GIT STATUS") }
            items(brief.git) { repo -> GitRepoCard(repo) }
        }

        // Refresh
        item {
            TextButton(onClick = onRefresh, modifier = Modifier.fillMaxWidth()) {
                Text("↺ REFRESH PROJECT", color = SwarmCyan, style = MaterialTheme.typography.labelLarge)
            }
        }
    }
}

// ─── Shared Card Composables ──────────────────────────────────────────────────

@Composable
fun NudgeCard(nudge: Nudge) {
    val (bg, icon) = when (nudge.severity) {
        "critical" -> SwarmRed.copy(0.15f) to "🚨"
        "warn"     -> SwarmGold.copy(0.15f) to "⚠️"
        else       -> SwarmCyan.copy(0.08f) to "💧"
    }
    val accent = when (nudge.severity) {
        "critical" -> SwarmRed
        "warn"     -> SwarmGold
        else       -> SwarmCyan
    }
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(bg)
            .padding(14.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(icon, fontSize = 22.sp)
        Text(nudge.text, style = MaterialTheme.typography.bodyMedium, color = accent, modifier = Modifier.weight(1f))
    }
}

@Composable
fun SuggestionCard(s: ProjectSuggestion) {
    val (icon, color) = when (s.priority) {
        "critical" -> "🚨" to SwarmRed
        "high"     -> "⚡" to SwarmOrange
        "medium"   -> "🔧" to SwarmCyan
        else       -> "💡" to SwarmGold
    }
    val tagColor = when (s.tag) {
        "code"      -> SwarmPurple
        "build"     -> SwarmCyan
        "hardware"  -> SwarmGold
        "companion" -> SwarmGreen
        "recovery"  -> SwarmOrange
        else        -> TextSecondary
    }
    SwarmCard {
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Text(icon, fontSize = 20.sp)
            Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                    Text(s.title, style = MaterialTheme.typography.headlineSmall, color = color)
                    SwarmBadge(s.tag.uppercase(), tagColor)
                }
                Text(s.detail, style = MaterialTheme.typography.bodySmall)
            }
        }
    }
}

@Composable
fun GitRepoCard(repo: RepoStatus) {
    SwarmCard {
        Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Text(repo.path.split("/").takeLast(2).joinToString("/"),
                    style = MaterialTheme.typography.headlineSmall, color = SwarmCyan)
                Text(repo.branch, style = MaterialTheme.typography.labelLarge)
            }
            if (repo.dirty > 0 || repo.untracked > 0) {
                Text("${repo.dirty} modified · ${repo.untracked} untracked",
                    style = MaterialTheme.typography.bodySmall, color = SwarmOrange)
            }
            if (repo.ahead > 0) {
                Text("↑ ${repo.ahead} ahead of remote", style = MaterialTheme.typography.bodySmall, color = SwarmGold)
            }
            repo.lastCommit?.let {
                Text("Last: $it", style = MaterialTheme.typography.labelSmall, color = TextDisabled)
            }
            repo.error?.let {
                Text("⚠ $it", style = MaterialTheme.typography.labelSmall, color = SwarmRed)
            }
        }
    }
}

// ─── Project Briefings (separate Lucille Assistant service) ──────────────────

@Composable
fun BriefingsTab(vm: MainViewModel) {
    val paired by vm.assistantPaired.collectAsStateWithLifecycle(initialValue = false)

    if (!paired) {
        AssistantPairingCard(vm)
        return
    }

    val state by vm.briefings.collectAsStateWithLifecycle()
    LaunchedEffect(Unit) { vm.loadBriefings() }

    when {
        state.loading -> SwarmLoading("Loading briefings…")
        state.error  != null -> SwarmError(state.error!!) { vm.loadBriefings(true) }
        state.data   != null -> BriefingsContent(state.data!!.briefings.orEmpty(), onRefresh = { vm.loadBriefings(true) })
        else -> SwarmEmpty("No briefings yet") { vm.loadBriefings() }
    }
}

@Composable
fun BriefingsContent(items: List<Briefing>, onRefresh: () -> Unit) {
    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        item { SectionHeader("📋 PROJECT BRIEFINGS") }
        items(items.sortedBy { it.order }) { b -> BriefingCard(b) }
        item {
            TextButton(onClick = onRefresh, modifier = Modifier.fillMaxWidth()) {
                Text("↺ REFRESH BRIEFINGS", color = SwarmCyan, style = MaterialTheme.typography.labelLarge)
            }
        }
    }
}

@Composable
fun BriefingCard(b: Briefing) {
    var expanded by remember { mutableStateOf(false) }
    SwarmCard(modifier = Modifier.clickable { expanded = !expanded }) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(b.title, style = MaterialTheme.typography.headlineSmall, color = SwarmCyan)
                SwarmBadge(b.project.uppercase(), SwarmPurple)
            }
            Text(if (expanded) "▲" else "▼", color = TextDisabled)
        }
        if (b.summary.isNotBlank()) {
            Text(b.summary, style = MaterialTheme.typography.bodyMedium, modifier = Modifier.padding(top = 8.dp))
        }
        if (expanded) {
            if (!b.readFirst.isNullOrEmpty()) {
                Column(modifier = Modifier.padding(top = 10.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text("READ FIRST", style = MaterialTheme.typography.labelSmall, color = SwarmGold)
                    b.readFirst.forEach { line ->
                        Text("• $line", style = MaterialTheme.typography.bodySmall)
                    }
                }
            }
            if (b.body.isNotBlank()) {
                Text(
                    b.body,
                    style = MaterialTheme.typography.bodySmall,
                    color = TextSecondary,
                    modifier = Modifier.padding(top = 10.dp)
                )
            }
        }
    }
}

@Composable
fun AssistantPairingCard(vm: MainViewModel) {
    var code by remember { mutableStateOf("") }
    val pairState by vm.pairing.collectAsStateWithLifecycle()

    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        SwarmCard(modifier = Modifier.padding(24.dp)) {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text("🔐 PAIR WITH LUCILLE ASSISTANT", style = MaterialTheme.typography.labelLarge, color = SwarmCyan)
                Text(
                    "Run `lucille-assistant pair` on the PC — it prints a 6-digit code good for 10 minutes. Enter it below.",
                    style = MaterialTheme.typography.bodySmall
                )
                OutlinedTextField(
                    value = code,
                    onValueChange = { if (it.length <= 6 && it.all(Char::isDigit)) code = it },
                    label = { Text("6-digit code") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth()
                )
                if (pairState.error != null) {
                    Text(pairState.error!!, style = MaterialTheme.typography.bodySmall, color = SwarmRed)
                }
                Button(
                    onClick = { vm.redeemAssistantPairCode(code) },
                    enabled = code.length == 6 && !pairState.loading,
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Text(if (pairState.loading) "PAIRING…" else "PAIR THIS PHONE")
                }
            }
        }
    }
}

@Composable
fun DriveUsageCard(d: DriveUsage) {
    val pct   = d.usedPct.coerceIn(0.0, 100.0)
    val color = when {
        pct >= 90 -> SwarmRed
        pct >= 75 -> SwarmGold
        else      -> SwarmGreen
    }
    SwarmCard {
        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Text(d.mount, style = MaterialTheme.typography.headlineSmall)
                Text("${String.format("%.0f", pct)}%", style = MaterialTheme.typography.labelLarge, color = color)
            }
            LinearProgressIndicator(
                progress = { (pct / 100).toFloat() },
                modifier = Modifier.fillMaxWidth().height(6.dp).clip(RoundedCornerShape(3.dp)),
                color = color,
                trackColor = SwarmBorder
            )
            Text("${String.format("%.1f", d.usedGB)} / ${String.format("%.1f", d.totalGB)} GB",
                style = MaterialTheme.typography.labelSmall)
        }
    }
}
