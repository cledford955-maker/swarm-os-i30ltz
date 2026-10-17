package com.swarm.lucille.ui.screens

import android.content.Intent
import android.provider.Settings
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp

@Composable
fun AntivirusScreen(threatScore: Int, isScanning: Boolean, onRunScan: () -> Unit, report: String = "No audit run yet.") {
    val context = LocalContext.current
    Column(Modifier.fillMaxSize().padding(16.dp).verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(16.dp)) {
        Text("Device security review", style = MaterialTheme.typography.headlineSmall)
        Text("Inspect Android's reported security patch, screen lock and USB debugging setting. This app does not include a malware scanner or certify that the phone or PC is secure.")
        Button(onClick=onRunScan, enabled=!isScanning, modifier=Modifier.fillMaxWidth().testTag("run_antivirus_scan_button")) { Text(if(isScanning) "Reading device configuration…" else "Run device audit") }
        SelectionContainer { Text(report) }
        OutlinedButton(onClick={context.startActivity(Intent(Settings.ACTION_SECURITY_SETTINGS))}) { Text("Open Android security settings") }
        OutlinedButton(onClick={context.startActivity(Intent(Settings.ACTION_PRIVACY_SETTINGS))}) { Text("Open privacy settings") }
        Text("Authorize ADB only for computers you trust. Remote PC currently uses HTTP/WebSocket with an access token; protect it with your private Tailscale network. The app does not verify tunnel encryption and its Room database is not application-encrypted.")
    }
}
