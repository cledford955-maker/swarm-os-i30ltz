// MainActivity.kt — Lucille SWARM OS companion  v1.0.0 · 2026-09-26
package os.swarm.lucille

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import os.swarm.lucille.api.LucilleApi
import os.swarm.lucille.data.Prefs
import os.swarm.lucille.ui.*

// ─── Nav destination ──────────────────────────────────────────────────────────
data class NavItem(val route: String, val label: String, val icon: ImageVector)

val NAV_ITEMS = listOf(
    NavItem("brief",    "Brief",   Icons.Filled.Home),
    NavItem("care",     "Care",    Icons.Filled.Favorite),
    NavItem("work",     "Code",    Icons.Filled.Code),
    NavItem("games",    "Gaming",  Icons.Filled.SportsEsports),
    NavItem("ideas",    "Ideas",   Icons.Filled.Lightbulb),
    NavItem("settings", "Config",  Icons.Filled.Settings),
)

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        val prefs = Prefs(this)

        setContent {
            LucilleTheme {
                LucilleApp(prefs)
            }
        }
    }
}

@Composable
fun LucilleApp(prefs: Prefs) {
    // Setup flow ──────────────────────────────────────────────────────────────
    var configured by remember { mutableStateOf(prefs.isConfigured) }
    if (!configured) {
        SetupScreen { host, token ->
            val profile = prefs.profiles.firstOrNull { it.id == prefs.activeId }
                ?: prefs.profiles.firstOrNull()
            if (profile != null) {
                prefs.upsertProfile(profile.copy(host = host, token = token))
            }
            prefs.activeId = prefs.activeId
            configured = true
        }
        return
    }

    // Active host ─────────────────────────────────────────────────────────────
    var activeProfile by remember { mutableStateOf(prefs.activeProfile) }
    var api           by remember { mutableStateOf(buildApi(prefs)) }
    var activeTab     by remember { mutableStateOf(prefs.lastTab) }

    fun switchHost() {
        activeProfile = prefs.activeProfile
        api           = buildApi(prefs)
    }

    // Shell ───────────────────────────────────────────────────────────────────
    val profile = activeProfile
    Scaffold(
        containerColor = Void,
        bottomBar = {
            SwarmBottomBar(
                items     = NAV_ITEMS,
                current   = activeTab,
                tint      = if (profile != null) Color(profile.color) else Plasma,
                onSelect  = { activeTab = it; prefs.lastTab = it }
            )
        },
        topBar = {
            SwarmTopBar(
                profileLabel = profile?.label ?: "LUCILLE",
                tint         = if (profile != null) Color(profile.color) else Plasma
            )
        }
    ) { innerPadding ->
        Box(
            Modifier
                .fillMaxSize()
                .background(Void)
                .padding(innerPadding)
        ) {
            when (activeTab) {
                "brief"    -> BriefScreen(api)
                "care"     -> CareScreen(api)
                "work"     -> WorkScreen(api)
                "games"    -> GamesScreen(api)
                "ideas"    -> IdeasScreen(api)
                "settings" -> SettingsScreen(prefs) { switchHost() }
                else       -> BriefScreen(api)
            }
        }
    }
}

// ─── Helper: rebuild API from current prefs ───────────────────────────────────
private fun buildApi(prefs: Prefs): LucilleApi {
    val p = prefs.activeProfile ?: return LucilleApi("", "")
    return LucilleApi(p.host, p.token)
}

// ─── Top bar ─────────────────────────────────────────────────────────────────
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SwarmTopBar(profileLabel: String, tint: Color) {
    TopAppBar(
        title = {
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Text("LUCILLE", color = tint, fontWeight = androidx.compose.ui.text.font.FontWeight.Bold, letterSpacing = 2.sp)
                Text("·", color = SmokeDim)
                Text(profileLabel, color = Smoke, fontSize = 13.sp)
            }
        },
        colors = TopAppBarDefaults.topAppBarColors(containerColor = Void2)
    )
}

// ─── Bottom navigation ────────────────────────────────────────────────────────
@Composable
fun SwarmBottomBar(items: List<NavItem>, current: String, tint: Color, onSelect: (String) -> Unit) {
    NavigationBar(containerColor = Void2, tonalElevation = 0.dp) {
        items.forEach { item ->
            NavigationBarItem(
                selected = current == item.route,
                onClick  = { onSelect(item.route) },
                icon     = { Icon(item.icon, item.label, modifier = Modifier.size(22.dp)) },
                label    = { Text(item.label, fontSize = 10.sp) },
                colors   = NavigationBarItemDefaults.colors(
                    selectedIconColor   = tint,
                    selectedTextColor   = tint,
                    unselectedIconColor = SmokeDim,
                    unselectedTextColor = SmokeDim,
                    indicatorColor      = tint.copy(alpha = 0.15f)
                )
            )
        }
    }
}
