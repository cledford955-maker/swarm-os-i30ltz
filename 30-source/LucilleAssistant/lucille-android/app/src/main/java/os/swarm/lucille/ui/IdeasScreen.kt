// IdeasScreen.kt — AI build ideas from Nemotron  v1.0.0 · 2026-09-26
package os.swarm.lucille.ui

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.*
import org.json.JSONObject
import os.swarm.lucille.api.LucilleApi

@Composable
fun IdeasScreen(api: LucilleApi) {
    var ideas   by remember { mutableStateOf<List<String>>(emptyList()) }
    var loading by remember { mutableStateOf(true) }
    var error   by remember { mutableStateOf("") }
    val scope   = rememberCoroutineScope()

    fun reload() {
        loading = true; error = ""
        scope.launch {
            try {
                val raw  = withContext(Dispatchers.IO) { api.ideas() }
                val obj  = JSONObject(raw)
                val arr  = obj.optJSONArray("ideas")
                ideas    = if (arr != null) (0 until arr.length()).map { arr.getString(it) } else emptyList()
            } catch (e: Exception) { error = e.message ?: "Error" }
            finally { loading = false }
        }
    }

    LaunchedEffect(api) { reload() }

    when {
        loading -> LoadingPane("Asking Nemotron for ideas…")
        error.isNotBlank() -> ErrorPane(error) { reload() }
        else -> Column(
            Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            if (ideas.isEmpty()) {
                SwarmCard { Text("No ideas returned — check NVIDIA_API_KEY", color = SmokeDim) }
            } else {
                ideas.forEachIndexed { i, idea ->
                    SwarmCard {
                        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                            MonoChip("#${i + 1}")
                            Text(idea, color = Filament, style = MaterialTheme.typography.bodyLarge)
                        }
                    }
                }
            }
            Spacer(Modifier.height(8.dp))
            PlasmaButton("Refresh ideas", onClick = { reload() }, modifier = Modifier.fillMaxWidth())
        }
    }
}
