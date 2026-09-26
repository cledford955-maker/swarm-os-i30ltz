// GamesScreen.kt — Steam hours · deals · news  v1.0.0 · 2026-09-26
package os.swarm.lucille.ui

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.*
import org.json.JSONArray
import org.json.JSONObject
import os.swarm.lucille.api.LucilleApi

@Composable
fun GamesScreen(api: LucilleApi) {
    var gaming  by remember { mutableStateOf<JSONObject?>(null) }
    var deals   by remember { mutableStateOf<JSONArray?>(null) }
    var news    by remember { mutableStateOf<JSONArray?>(null) }
    var loading by remember { mutableStateOf(true) }
    var error   by remember { mutableStateOf("") }
    var tab     by remember { mutableStateOf(0) }  // 0=Stats 1=Deals 2=News

    fun reload() {
        loading = true; error = ""
    }

    LaunchedEffect(api) {
        reload()
        try {
            withContext(Dispatchers.IO) {
                val g = JSONObject(api.gaming())
                val d = JSONObject(api.deals())
                val n = JSONObject(api.news())
                withContext(Dispatchers.Main) {
                    gaming  = g
                    deals   = d.optJSONArray("deals")
                    news    = n.optJSONArray("items")
                    loading = false
                }
            }
        } catch (e: Exception) {
            error   = e.message ?: "Error"
            loading = false
        }
    }

    if (loading) { LoadingPane("Loading gaming…"); return }
    if (error.isNotBlank()) { ErrorPane(error) { /* would re-trigger */ }; return }

    Column(Modifier.fillMaxSize()) {

        // Sub-tabs
        TabRow(
            selectedTabIndex = tab,
            containerColor   = Void2,
            contentColor     = Plasma
        ) {
            listOf("STATS", "DEALS", "NEWS").forEachIndexed { i, lbl ->
                Tab(selected = tab == i, onClick = { tab = i }) {
                    Text(lbl, fontSize = 11.sp, modifier = Modifier.padding(vertical = 12.dp))
                }
            }
        }

        Column(
            Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            when (tab) {

                // ── Stats ────────────────────────────────────────────────────
                0 -> {
                    val games = gaming?.optJSONArray("games")
                    val total = gaming?.optInt("total_hours", 0) ?: 0
                    SwarmCard {
                        SectionLabel("Steam playtime")
                        Text("Total: ${total}h", color = Filament)
                        Spacer(Modifier.height(8.dp))
                        if (games == null || games.length() == 0) {
                            Text("No game data — set STEAM_API_KEY + STEAM_ID64", color = SmokeDim, style = MaterialTheme.typography.bodySmall)
                        } else {
                            (0 until minOf(games.length(), 10)).forEach { i ->
                                val g    = games.getJSONObject(i)
                                val name = g.optString("name", "?")
                                val hrs  = g.optInt("hours", 0)
                                Row(Modifier.fillMaxWidth().padding(vertical = 3.dp), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                                    Text(name, color = Filament, modifier = Modifier.weight(1f), maxLines = 1)
                                    MonoChip("${hrs}h")
                                }
                            }
                        }
                    }

                    // Today's session hours from sessions
                    SwarmCard {
                        SectionLabel("Gaming sessions today")
                        val todayMin = gaming?.optInt("today_minutes", 0) ?: 0
                        val todayH   = todayMin / 60
                        val todayM   = todayMin % 60
                        Text(if (todayMin == 0) "No sessions logged" else "${todayH}h ${todayM}m", color = if (todayMin == 0) SmokeDim else Ok)
                    }
                }

                // ── Deals ────────────────────────────────────────────────────
                1 -> {
                    if (deals == null || deals!!.length() == 0) {
                        SwarmCard { Text("No deals available right now", color = SmokeDim) }
                    } else {
                        SwarmCard {
                            SectionLabel("Steam + CD-key deals")
                            (0 until deals!!.length()).forEach { i ->
                                val d     = deals!!.getJSONObject(i)
                                val title = d.optString("title","?")
                                val sale  = d.optString("salePrice","?")
                                val norm  = d.optString("normalPrice","")
                                val pct   = d.optInt("savings", 0)
                                Row(
                                    Modifier.fillMaxWidth().padding(vertical = 5.dp),
                                    horizontalArrangement = Arrangement.SpaceBetween,
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Column(Modifier.weight(1f)) {
                                        Text(title, color = Filament, maxLines = 1)
                                        if (norm.isNotBlank()) Text("was $norm", color = SmokeDim, style = MaterialTheme.typography.bodySmall)
                                    }
                                    Row(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.CenterVertically) {
                                        MonoChip("$$sale", Ok)
                                        if (pct > 0) MonoChip("-$pct%", Warn)
                                    }
                                }
                                SwarmDivider()
                            }
                        }
                    }
                }

                // ── News ─────────────────────────────────────────────────────
                2 -> {
                    if (news == null || news!!.length() == 0) {
                        SwarmCard { Text("No news", color = SmokeDim) }
                    } else {
                        (0 until news!!.length()).forEach { i ->
                            val n   = news!!.getJSONObject(i)
                            val ttl = n.optString("title","")
                            val src = n.optString("source","")
                            val ago = n.optString("ago","")
                            SwarmCard {
                                Text(ttl, color = Filament, style = MaterialTheme.typography.bodyLarge)
                                Spacer(Modifier.height(4.dp))
                                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                    MonoChip(src)
                                    if (ago.isNotBlank()) Text(ago, color = SmokeDim, style = MaterialTheme.typography.bodySmall)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
