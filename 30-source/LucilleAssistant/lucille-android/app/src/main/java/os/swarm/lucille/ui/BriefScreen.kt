// BriefScreen.kt — daily brief + nudges  v1.0.0 · 2026-09-26
package os.swarm.lucille.ui

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.*
import os.swarm.lucille.api.LucilleApi
import org.json.JSONObject

@Composable
fun BriefScreen(api: LucilleApi) {
    var brief   by remember { mutableStateOf<JSONObject?>(null) }
    var nudges  by remember { mutableStateOf<List<String>>(emptyList()) }
    var loading by remember { mutableStateOf(true) }
    var error   by remember { mutableStateOf("") }

    LaunchedEffect(api) {
        loading = true; error = ""
        try {
            withContext(Dispatchers.IO) {
                val b = JSONObject(api.brief())
                val n = JSONObject(api.nudges())
                withContext(Dispatchers.Main) {
                    brief = b
                    val arr = n.optJSONArray("nudges")
                    nudges = if (arr != null) (0 until arr.length()).map { arr.getString(it) } else emptyList()
                    loading = false
                }
            }
        } catch (e: Exception) {
            error   = e.message ?: "Unknown error"
            loading = false
        }
    }

    when {
        loading      -> LoadingPane("Loading brief…")
        error.isNotBlank() -> ErrorPane(error) {
            loading = true; error = ""
            // re-trigger by recreating the key would be cleaner — for now the user retaps
        }
        else -> {
            Column(
                Modifier
                    .fillMaxSize()
                    .verticalScroll(rememberScrollState())
                    .padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                // Headline
                brief?.optString("headline")?.takeIf { it.isNotBlank() }?.let {
                    SwarmCard {
                        SectionLabel("Headline")
                        Text(it, style = MaterialTheme.typography.bodyLarge, color = Filament)
                    }
                }

                // Nudges
                if (nudges.isNotEmpty()) {
                    SwarmCard {
                        SectionLabel("Nudges")
                        nudges.forEach { n ->
                            Row(
                                Modifier.padding(vertical = 4.dp),
                                horizontalArrangement = Arrangement.spacedBy(8.dp)
                            ) {
                                Text("›", color = Warn)
                                Text(n, color = Filament, style = MaterialTheme.typography.bodyLarge)
                            }
                        }
                    }
                }

                // Raw brief sections
                brief?.let { b ->
                    listOf("git", "drives", "care", "sessions").forEach { key ->
                        b.optJSONObject(key)?.let { obj ->
                            SwarmCard {
                                SectionLabel(key)
                                Text(
                                    obj.toString(2),
                                    style  = MaterialTheme.typography.labelMedium,
                                    color  = Smoke,
                                    fontFamily = androidx.compose.ui.text.font.FontFamily.Monospace
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}
