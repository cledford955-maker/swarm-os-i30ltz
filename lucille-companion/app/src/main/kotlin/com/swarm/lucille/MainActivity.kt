// MainActivity.kt — Root activity, connect screen + bottom-nav scaffold  v1.0.0  2026-09-24
// SWARM OS dark purple-lightning theme — always dark, never light
package com.swarm.lucille

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.animation.*
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.*
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.*
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.swarm.lucille.ui.screen.*
import com.swarm.lucille.ui.theme.*
import com.swarm.lucille.ui.viewmodel.MainViewModel

class MainActivity : ComponentActivity() {

    private lateinit var vm: MainViewModel

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()

        val app = application as LucilleApp
        vm = ViewModelProvider(this, MainViewModel.Factory(app.prefs, app.repository))
            .get(MainViewModel::class.java)

        setContent {
            LucilleTheme {
                LucilleRoot(vm)
            }
        }
    }
}

// ─── Bottom Nav Destinations ──────────────────────────────────────────────────

enum class Tab(val label: String, val icon: String) {
    BRIEF    ("BRIEF",     "⚡"),
    INBOX    ("INBOX",     "✉"),
    VOICE    ("VOICE",     "📞"),
    WORKSPACE("WORKSPACE", "🗂"),
    SWARM    ("SWARM",     "🔥")
}

// ─── Root Composable ──────────────────────────────────────────────────────────

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LucilleRoot(vm: MainViewModel) {
    val connected by vm.connected.collectAsStateWithLifecycle()
    val serverUrl by vm.serverUrl.collectAsStateWithLifecycle("")

    // First-run: show connect screen if never configured
    if (connected == null || (!connected!! && serverUrl.isBlank())) {
        ConnectScreen(vm)
        return
    }

    // Not yet determined — show splash
    if (connected == null) {
        SwarmSplash()
        return
    }

    MainScaffold(vm)
}

// ─── Splash / Loading ─────────────────────────────────────────────────────────

@Composable
fun SwarmSplash() {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(SwarmBg),
        contentAlignment = Alignment.Center
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(16.dp)) {
            Text("⚡ LUCILLE", style = MaterialTheme.typography.displayLarge, color = SwarmCyan)
            CircularProgressIndicator(color = SwarmPurple, strokeWidth = 2.dp, modifier = Modifier.size(28.dp))
            Text("connecting to SWARM...", style = MaterialTheme.typography.labelMedium)
        }
    }
}

// ─── Connect / Setup Screen ───────────────────────────────────────────────────

@Composable
fun ConnectScreen(vm: MainViewModel) {
    var url   by remember { mutableStateOf("http://100.x.x.x:8403") }
    var token by remember { mutableStateOf("") }
    var busy  by remember { mutableStateOf(false) }
    val connected by vm.connected.collectAsStateWithLifecycle()

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(
                Brush.verticalGradient(listOf(SwarmBg, SwarmSurface2))
            ),
        contentAlignment = Alignment.Center
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth(0.9f)
                .clip(RoundedCornerShape(20.dp))
                .background(SwarmSurface)
                .padding(28.dp),
            verticalArrangement = Arrangement.spacedBy(20.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            // Header
            Text("⚡ LUCILLE", style = MaterialTheme.typography.displayLarge, color = SwarmCyan)
            Text("SWARM OS Companion", style = MaterialTheme.typography.bodyLarge, color = TextSecondary)
            Text("v1.0.0 · 2026-09-24", style = MaterialTheme.typography.labelSmall)

            HorizontalDivider(color = SwarmBorder)

            // Server URL
            OutlinedTextField(
                value = url,
                onValueChange = { url = it },
                label = { Text("Lucille Server URL") },
                placeholder = { Text("http://100.x.x.x:8403") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
                colors = OutlinedTextFieldDefaults.colors(
                    focusedBorderColor   = SwarmPurple,
                    unfocusedBorderColor = SwarmBorder,
                    focusedLabelColor    = SwarmCyan,
                    cursorColor          = SwarmCyan,
                )
            )

            // Token
            OutlinedTextField(
                value = token,
                onValueChange = { token = it },
                label = { Text("Auth Token") },
                placeholder = { Text("SWARM_AUTH_TOKEN value") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
                colors = OutlinedTextFieldDefaults.colors(
                    focusedBorderColor   = SwarmPurple,
                    unfocusedBorderColor = SwarmBorder,
                    focusedLabelColor    = SwarmCyan,
                    cursorColor          = SwarmCyan,
                )
            )

            // Status
            if (connected == false && !busy) {
                Text(
                    "⚠ Could not connect — check URL and token",
                    style = MaterialTheme.typography.bodySmall,
                    color = SwarmRed,
                    textAlign = TextAlign.Center
                )
            }

            // Connect button
            Button(
                onClick = {
                    busy = true
                    vm.configure(url.trim(), token.trim())
                },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(52.dp),
                shape = RoundedCornerShape(12.dp),
                colors = ButtonDefaults.buttonColors(containerColor = SwarmPurple),
                enabled = url.isNotBlank() && token.isNotBlank() && !busy
            ) {
                if (busy) {
                    CircularProgressIndicator(color = TextPrimary, strokeWidth = 2.dp, modifier = Modifier.size(18.dp))
                } else {
                    Text("CONNECT TO SWARM OS", fontWeight = FontWeight.Bold, letterSpacing = 1.sp)
                }
            }

            LaunchedEffect(connected) {
                if (connected != null) busy = false
            }

            Text(
                "Reach Lucille via Tailscale across all your devices",
                style = MaterialTheme.typography.labelSmall,
                textAlign = TextAlign.Center,
                modifier = Modifier.padding(top = 4.dp)
            )
        }
    }
}

// ─── Main Scaffold + Bottom Nav ───────────────────────────────────────────────

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MainScaffold(vm: MainViewModel) {
    var currentTab by remember { mutableStateOf(Tab.BRIEF) }

    Scaffold(
        containerColor = SwarmBg,
        bottomBar = {
            SwarmBottomNav(
                currentTab = currentTab,
                onTabSelected = { currentTab = it }
            )
        }
    ) { padding ->
        Box(modifier = Modifier.padding(padding)) {
            when (currentTab) {
                Tab.BRIEF     -> BriefScreen(vm)
                Tab.INBOX     -> InboxScreen(vm)
                Tab.VOICE     -> VoiceScreen(vm)
                Tab.WORKSPACE -> WorkspaceScreen(vm)
                Tab.SWARM     -> SwarmScreen(vm)
            }
        }
    }
}

// ─── Bottom Navigation Bar ────────────────────────────────────────────────────

@Composable
fun SwarmBottomNav(currentTab: Tab, onTabSelected: (Tab) -> Unit) {
    NavigationBar(
        containerColor = SwarmSurface,
        tonalElevation = 0.dp
    ) {
        Tab.values().forEach { tab ->
            val selected = tab == currentTab
            NavigationBarItem(
                selected = selected,
                onClick  = { onTabSelected(tab) },
                icon = {
                    Text(
                        text  = tab.icon,
                        fontSize = if (selected) 22.sp else 18.sp
                    )
                },
                label = {
                    Text(
                        text  = tab.label,
                        style = MaterialTheme.typography.labelSmall,
                        color = if (selected) SwarmCyan else TextDisabled
                    )
                },
                colors = NavigationBarItemDefaults.colors(
                    selectedIconColor   = SwarmCyan,
                    indicatorColor      = SwarmSurface2,
                    unselectedIconColor = TextDisabled,
                )
            )
        }
    }
}
