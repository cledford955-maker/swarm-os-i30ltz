// WorkScreen.kt — git · drives · sessions · memory  v1.0.0 · 2026-09-26
package os.swarm.lucille.ui

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.Alignment
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.*
import org.json.JSONObject
import org.json.JSONArray
import os.swarm.lucille.api.LucilleApi

@Composable
fun WorkScreen(api: LucilleApi) {
    var git      by remember { mutableStateOf<JSONArray?>(null) }
    var drives   by remember { mutableStateOf<JSONArray?>(null) }
    var sessions by remember { mutableStateOf<JSONObject?>(null) }
    var memory   by remember { mutableStateOf<List<String>>(emptyList()) }
    var loading  by remember { mutableStateOf(true) }
    var error    by remember { mutableStateOf("") }
    var memInput by remember { mutableStateOf("") }
    var snack    by remember { mutableStateOf("") }
    val scope    = rememberCoroutineScope()

    fun reload() {
        loading = true; error = ""
        scope.launch {
            try {
                withContext(Dispatchers.IO) {
                    val g = JSONObject(api.git())
                    val d = JSONObject(api.drives())
                    val s = JSONObject(api.sessions())
                    val m = JSONObject(api.memory())
                    withContext(Dispatchers.Main) {
                        git      = g.optJSONArray("repos")
                        drives   = d.optJSONArray("drives")
                        sessions = s
                        val arr  = m.optJSONArray("entries")
                        memory   = if (arr != null) (0 until arr.length()).map { arr.getString(it) }.reversed() else emptyList()
                    }
                }
            } catch (e: Exception) { error = e.message ?: "Error" }
            finally { loading = false }
        }
    }

    LaunchedEffect(api) { reload() }
    if (loading) { LoadingPane(); return }
    if (error.isNotBlank()) { ErrorPane(error) { reload() }; return }

    Column(
        Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        // ── Sessions ─────────────────────────────────────────────────────────
        SwarmCard {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                SectionLabel("Sessions")
                val active = sessions?.optBoolean("active", false) ?: false
                StatusDot(ok = active)
            }
            val proj = sessions?.optString("project", "")?.takeIf { it.isNotBlank() }
            if (proj != null) {
                Text("Active: $proj", color = Ok)
                Spacer(Modifier.height(8.dp))
                PlasmaButton("Stop Session") {
                    scope.launch { try { withContext(Dispatchers.IO) { api.sessionStop() }; reload() } catch (e: Exception) { snack = e.message ?: "Error" } }
                }
            } else {
                var projInput by remember { mutableStateOf("") }
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                    OutlinedTextField(
                        value         = projInput,
                        onValueChange = { projInput = it },
                        placeholder   = { Text("Project name…", color = SmokeDim) },
                        modifier      = Modifier.weight(1f),
                        colors        = OutlinedTextFieldDefaults.colors(focusedBorderColor = Plasma, unfocusedBorderColor = SmokeDim, focusedTextColor = Filament, unfocusedTextColor = Filament),
                        singleLine    = true
                    )
                    PlasmaButton("Start") {
                        if (projInput.isNotBlank()) {
                            scope.launch {
                                try { withContext(Dispatchers.IO) { api.sessionStart(projInput) }; reload() }
                                catch (e: Exception) { snack = e.message ?: "Error" }
                            }
                        }
                    }
                }
            }
        }

        // ── Git ──────────────────────────────────────────────────────────────
        SwarmCard {
            SectionLabel("Git repos")
            if (git == null || git!!.length() == 0) {
                Text("No repos configured", color = SmokeDim)
            } else {
                (0 until git!!.length()).forEach { i ->
                    val r     = git!!.getJSONObject(i)
                    val name  = r.optString("name", "repo")
                    val clean = r.optBoolean("clean", true)
                    val branch = r.optString("branch", "main")
                    Row(Modifier.fillMaxWidth().padding(vertical = 4.dp), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                            Icon(Icons.Filled.Code, "git", tint = if (clean) Ok else Warn, modifier = Modifier.size(16.dp))
                            Text(name, color = Filament)
                            MonoChip(branch)
                        }
                        if (!clean) MonoChip("dirty", Warn)
                    }
                }
            }
        }

        // ── Drives ───────────────────────────────────────────────────────────
        SwarmCard {
            SectionLabel("Drives")
            if (drives == null || drives!!.length() == 0) {
                Text("No mounts", color = SmokeDim)
            } else {
                (0 until drives!!.length()).forEach { i ->
                    val d    = drives!!.getJSONObject(i)
                    val mnt  = d.optString("mount", "?")
                    val usedPct = d.optInt("used_pct", 0)
                    val free = d.optString("free", "?")
                    Row(Modifier.fillMaxWidth().padding(vertical = 4.dp), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                        Text(mnt, color = Filament, modifier = Modifier.weight(1f))
                        Row(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.CenterVertically) {
                            Text("free: $free", color = Smoke, style = MaterialTheme.typography.bodySmall)
                            MonoChip("$usedPct%", if (usedPct > 85) Crit else if (usedPct > 70) Warn else Ok)
                        }
                    }
                }
            }
        }

        // ── Memory ───────────────────────────────────────────────────────────
        SwarmCard {
            SectionLabel("SWARM Memory")
            if (memory.isEmpty()) {
                Text("No entries", color = SmokeDim)
            } else {
                memory.take(8).forEach { entry ->
                    Text("• $entry", color = Smoke, style = MaterialTheme.typography.bodySmall, modifier = Modifier.padding(vertical = 2.dp))
                }
            }
            Spacer(Modifier.height(10.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                OutlinedTextField(
                    value         = memInput,
                    onValueChange = { memInput = it },
                    placeholder   = { Text("Add memory note…", color = SmokeDim) },
                    modifier      = Modifier.weight(1f),
                    colors        = OutlinedTextFieldDefaults.colors(focusedBorderColor = Plasma, unfocusedBorderColor = SmokeDim, focusedTextColor = Filament, unfocusedTextColor = Filament),
                    singleLine    = true
                )
                PlasmaButton("Add") {
                    if (memInput.isNotBlank()) {
                        val note = memInput; memInput = ""
                        scope.launch {
                            try { withContext(Dispatchers.IO) { api.memoryAdd(note) }; reload() }
                            catch (e: Exception) { snack = e.message ?: "Error" }
                        }
                    }
                }
            }
        }
    }
}
