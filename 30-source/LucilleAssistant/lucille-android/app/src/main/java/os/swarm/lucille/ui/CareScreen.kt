// CareScreen.kt — wellness tracking  v1.0.0 · 2026-09-26
package os.swarm.lucille.ui

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.*
import org.json.JSONObject
import os.swarm.lucille.api.LucilleApi

@Composable
fun CareScreen(api: LucilleApi) {
    var care    by remember { mutableStateOf<JSONObject?>(null) }
    var loading by remember { mutableStateOf(true) }
    var error   by remember { mutableStateOf("") }
    var snack   by remember { mutableStateOf("") }
    val scope   = rememberCoroutineScope()

    fun reload() {
        loading = true; error = ""
        scope.launch {
            try {
                val raw = withContext(Dispatchers.IO) { api.care() }
                care    = JSONObject(raw)
            } catch (e: Exception) { error = e.message ?: "Error" }
            finally { loading = false }
        }
    }

    LaunchedEffect(api) { reload() }

    fun act(block: suspend () -> Unit) {
        scope.launch {
            try { withContext(Dispatchers.IO) { block() }; reload() }
            catch (e: Exception) { snack = e.message ?: "Error" }
        }
    }

    if (loading) { LoadingPane("Loading care…"); return }
    if (error.isNotBlank()) { ErrorPane(error) { reload() }; return }

    val meds  = care?.optJSONArray("meds")
    val water = care?.optJSONObject("water")
    val meals = care?.optJSONArray("meals")
    val sleep = care?.optJSONObject("sleep")

    Column(
        Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        // ── Water ────────────────────────────────────────────────────────────
        SwarmCard {
            SectionLabel("Hydration")
            val ml    = water?.optInt("today_ml", 0) ?: 0
            val goal  = water?.optInt("goal_ml",  2000) ?: 2000
            val pct   = (ml.toFloat() / goal).coerceIn(0f, 1f)
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                Icon(Icons.Filled.WaterDrop, "water", tint = Arc)
                Column(Modifier.weight(1f)) {
                    Text("$ml / $goal ml", color = Filament)
                    Spacer(Modifier.height(4.dp))
                    LinearProgressIndicator(progress = { pct }, modifier = Modifier.fillMaxWidth(), color = Arc)
                }
            }
            Spacer(Modifier.height(10.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                listOf(250 to "250ml", 500 to "500ml", 750 to "750ml").forEach { (ml, lbl) ->
                    OutlinedButton(
                        onClick = { act { api.logWater(ml) } },
                        colors  = ButtonDefaults.outlinedButtonColors(contentColor = Arc),
                        border  = ButtonDefaults.outlinedButtonBorder.copy(brush = androidx.compose.ui.graphics.SolidColor(Arc.copy(alpha = 0.4f)))
                    ) { Text(lbl, color = Arc) }
                }
            }
        }

        // ── Meds ─────────────────────────────────────────────────────────────
        SwarmCard {
            SectionLabel("Medications")
            if (meds == null || meds.length() == 0) {
                Text("No meds configured", color = SmokeDim)
            } else {
                (0 until meds.length()).forEach { i ->
                    val med   = meds.getJSONObject(i)
                    val name  = med.optString("name", "Unknown")
                    val taken = med.optBoolean("taken", false)
                    Row(
                        Modifier.fillMaxWidth().padding(vertical = 4.dp),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                            Icon(
                                if (taken) Icons.Filled.CheckCircle else Icons.Filled.RadioButtonUnchecked,
                                "med",
                                tint = if (taken) Ok else SmokeDim
                            )
                            Text(name, color = Filament)
                        }
                        if (!taken) {
                            TextButton(onClick = { act { api.logMed(name) } }) {
                                Text("Log", color = Plasma)
                            }
                        }
                    }
                }
            }
        }

        // ── Meals ────────────────────────────────────────────────────────────
        SwarmCard {
            SectionLabel("Meals")
            var mealInput by remember { mutableStateOf("") }
            if (meals != null && meals.length() > 0) {
                (0 until meals.length()).forEach { i ->
                    val m = meals.getJSONObject(i)
                    Text("• ${m.optString("name","?")}  ${m.optString("time","")}", color = Smoke, style = MaterialTheme.typography.bodySmall)
                }
                Spacer(Modifier.height(8.dp))
            }
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                OutlinedTextField(
                    value         = mealInput,
                    onValueChange = { mealInput = it },
                    placeholder   = { Text("What did you eat?", color = SmokeDim) },
                    modifier      = Modifier.weight(1f),
                    colors        = OutlinedTextFieldDefaults.colors(
                        focusedBorderColor   = Plasma,
                        unfocusedBorderColor = SmokeDim,
                        focusedTextColor     = Filament,
                        unfocusedTextColor   = Filament
                    ),
                    singleLine    = true
                )
                PlasmaButton("Log") { if (mealInput.isNotBlank()) { act { api.logMeal(mealInput) }; mealInput = "" } }
            }
        }

        // ── Sleep ────────────────────────────────────────────────────────────
        SwarmCard {
            SectionLabel("Sleep")
            val slept = sleep?.optInt("hours", 0) ?: 0
            Text("${slept}h logged today", color = if (slept >= 7) Ok else Warn)
            Spacer(Modifier.height(8.dp))
            PlasmaButton("Log Sleep Now", onClick = { act { api.logSleep() } })
        }
    }

    if (snack.isNotBlank()) {
        LaunchedEffect(snack) { delay(3000); snack = "" }
        Snackbar(Modifier.padding(16.dp)) { Text(snack) }
    }
}
