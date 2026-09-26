// SettingsScreen.kt — host profiles: SWARM / CachyOS / Debian  v1.0.0 · 2026-09-26
package os.swarm.lucille.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import os.swarm.lucille.data.HostProfile
import os.swarm.lucille.data.Prefs

@Composable
fun SettingsScreen(prefs: Prefs, onActiveChanged: () -> Unit) {
    var profiles  by remember { mutableStateOf(prefs.profiles) }
    var activeId  by remember { mutableStateOf(prefs.activeId) }
    var editIdx   by remember { mutableStateOf(-1) }   // -1 = none editing

    Column(
        Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Text("HOST PROFILES", color = SmokeDim, fontSize = 10.sp, letterSpacing = 1.5.sp, fontWeight = FontWeight.Medium)

        profiles.forEachIndexed { idx, profile ->
            val isActive  = profile.id == activeId
            val tint      = Color(profile.color)
            val isEditing = editIdx == idx

            SwarmCard(
                modifier = Modifier
                    .border(
                        width = if (isActive) 1.5.dp else 0.5.dp,
                        color = if (isActive) tint else SmokeDim.copy(alpha = 0.3f),
                        shape = RoundedCornerShape(12.dp)
                    )
                    .clickable(enabled = !isEditing) {
                        if (!isActive) {
                            prefs.activeId = profile.id
                            activeId = profile.id
                            onActiveChanged()
                        }
                    }
            ) {
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                    Column {
                        Text(profile.label, color = tint, fontWeight = FontWeight.Bold)
                        Text(profile.host,  color = Smoke, style = MaterialTheme.typography.bodySmall)
                    }
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                        if (isActive) Icon(Icons.Filled.CheckCircle, "active", tint = tint, modifier = Modifier.size(16.dp))
                        TextButton(onClick = { editIdx = if (isEditing) -1 else idx }) {
                            Text(if (isEditing) "Done" else "Edit", color = SmokeDim, fontSize = 12.sp)
                        }
                    }
                }

                if (isEditing) {
                    var host   by remember { mutableStateOf(profile.host)  }
                    var token  by remember { mutableStateOf(profile.token) }
                    var showTk by remember { mutableStateOf(false) }

                    Spacer(Modifier.height(12.dp))
                    SwarmDivider()

                    OutlinedTextField(
                        value         = host,
                        onValueChange = { host = it },
                        label         = { Text("Host URL", color = SmokeDim) },
                        modifier      = Modifier.fillMaxWidth(),
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Uri),
                        colors        = OutlinedTextFieldDefaults.colors(focusedBorderColor = tint, unfocusedBorderColor = SmokeDim, focusedTextColor = Filament, unfocusedTextColor = Filament),
                        singleLine    = true
                    )
                    Spacer(Modifier.height(8.dp))
                    OutlinedTextField(
                        value         = token,
                        onValueChange = { token = it },
                        label         = { Text("SWARM_AUTH_TOKEN", color = SmokeDim) },
                        modifier      = Modifier.fillMaxWidth(),
                        visualTransformation = if (showTk) VisualTransformation.None else PasswordVisualTransformation(),
                        trailingIcon  = { TextButton(onClick = { showTk = !showTk }) { Text(if (showTk) "Hide" else "Show", color = SmokeDim, fontSize = 11.sp) } },
                        colors        = OutlinedTextFieldDefaults.colors(focusedBorderColor = tint, unfocusedBorderColor = SmokeDim, focusedTextColor = Filament, unfocusedTextColor = Filament),
                        singleLine    = true
                    )
                    Spacer(Modifier.height(12.dp))
                    Button(
                        onClick = {
                            val updated = profile.copy(host = host.trimEnd('/'), token = token)
                            prefs.upsertProfile(updated)
                            profiles = prefs.profiles
                            editIdx  = -1
                            if (isActive) onActiveChanged()
                        },
                        colors  = ButtonDefaults.buttonColors(containerColor = tint),
                        modifier = Modifier.fillMaxWidth()
                    ) { Text("Save", color = Filament) }
                }
            }
        }

        Spacer(Modifier.height(8.dp))
        Text(
            "Tap a profile to switch · tap Edit to set the token",
            color = SmokeDim, fontSize = 11.sp
        )
    }
}
