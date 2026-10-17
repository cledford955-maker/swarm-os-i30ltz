package com.swarm.lucille.ui.screens

import androidx.compose.animation.core.*
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.platform.LocalContext
import kotlinx.coroutines.launch
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.swarm.lucille.R
import com.swarm.lucille.data.db.DeviceSyncEntity
import com.swarm.lucille.data.service.SystemStats
import com.swarm.lucille.ui.NavigationTab
import com.swarm.lucille.ui.theme.*

private const val PHONE_ID_AVATAR = -1L

@Composable
fun DrI3oltzFullAvatarScreen(
    speechText: String?,
    isSpeaking: Boolean,
    isMuted: Boolean,
    stats: SystemStats,
    devices: List<DeviceSyncEntity>,
    onAvatarClick: () -> Unit,
    onMuteToggle: () -> Unit,
    onNavigateToTab: (NavigationTab) -> Unit,
    onOptimizeDevice: (Long) -> Unit,
    onMalwareScanDevice: (Long) -> Unit
) {
    var selectedId by remember { mutableStateOf(PHONE_ID_AVATAR) }
    var killedProcs by remember { mutableStateOf(setOf<String>()) }
    var lastKilled by remember { mutableStateOf<String?>(null) }

    val selectedDevice = if (selectedId == PHONE_ID_AVATAR) null else devices.find { it.id == selectedId }

    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val measured = selectedDevice?.takeIf { it.isConnected && System.currentTimeMillis() - it.lastSyncTime < 60_000 }
    val cpuPct = measured?.cpuLoadPercent ?: -1
    val ramPct = if (selectedId == PHONE_ID_AVATAR) stats.ramPercentage else measured?.ramLoadPercent ?: -1
    val pingMs = measured?.pingMs
    val processState = rememberDeviceProcesses(selectedDevice)
    val avatarProcesses = processState.entries

    LaunchedEffect(lastKilled) {
        if (lastKilled != null) {
            kotlinx.coroutines.delay(2500)
            lastKilled = null
        }
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
            .padding(horizontal = 16.dp)
    ) {
        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(top = 8.dp, bottom = 100.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            // ── Header ─────────────────────────────────────────────────────────────
            item {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        Box(
                            modifier = Modifier
                                .size(48.dp)
                                .clip(CircleShape)
                                .background(ElectricPurple.copy(alpha = 0.2f))
                                .border(1.5.dp, ElectricPurple, CircleShape)
                                .clickable { onAvatarClick() },
                            contentAlignment = Alignment.Center
                        ) {
                            Image(
                                painter = painterResource(id = R.drawable.dr_i3oltz_3d_avatar),
                                contentDescription = "DR. I30LTZ",
                                contentScale = ContentScale.Crop,
                                modifier = Modifier.fillMaxSize().clip(CircleShape)
                            )
                        }
                        Column {
                            Text(
                                text = "DR. i3OLTZ • FIELD CMD",
                                color = Color(0xFFE040FB),
                                fontSize = 15.sp,
                                fontWeight = FontWeight.Black,
                                letterSpacing = 1.sp
                            )
                            Text("Powered by SWARM CORE", color = TextSecondary, fontSize = 10.sp)
                        }
                    }
                    IconButton(
                        onClick = onMuteToggle,
                        modifier = Modifier.clip(CircleShape).background(CarbonSurfaceVariant).border(1.dp, CarbonBorder, CircleShape)
                    ) {
                        Icon(
                            imageVector = if (isMuted) Icons.Default.VolumeOff else Icons.Default.VolumeUp,
                            contentDescription = "Mute",
                            tint = if (isMuted) TextMuted else LightningYellow
                        )
                    }
                }
            }

            // ── Speech Bubble ───────────────────────────────────────────────────────
            item {
                Card(
                    colors = CardDefaults.cardColors(containerColor = CarbonSurface),
                    shape = RoundedCornerShape(16.dp),
                    modifier = Modifier
                        .fillMaxWidth()
                        .border(
                            1.5.dp,
                            Brush.horizontalGradient(listOf(ElectricPurple, Color(0xFFE040FB), LightningYellow)),
                            RoundedCornerShape(16.dp)
                        )
                ) {
                    Row(modifier = Modifier.padding(12.dp), verticalAlignment = Alignment.CenterVertically) {
                        Box(modifier = Modifier.size(10.dp).clip(CircleShape).background(if (isSpeaking) LightningYellow else NeonGreen))
                        Spacer(modifier = Modifier.width(8.dp))
                        Text(
                            text = speechText ?: "⚕ DR. i3OLTZ online. 14-step first-boot protocol loaded — expand the cheatsheet below. Services, Tailscale, TOTP 2FA, Claude Code, AppArmor, Nemotron. Tap any device to inspect live diagnostics.",
                            color = TextPrimary,
                            fontSize = 12.sp,
                            lineHeight = 17.sp,
                            fontStyle = FontStyle.Italic
                        )
                    }
                }
            }

            // ── First Boot Cheatsheet ────────────────────────────────────────────────
            item { I3oltzCheatsheet() }

            // ── Phone Body Diagram ───────────────────────────────────────────────────
            item {
                Card(
                    colors = CardDefaults.cardColors(containerColor = Color(0xFF0A0A12)),
                    shape = RoundedCornerShape(18.dp),
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(220.dp)
                        .border(1.dp, ElectricPurple.copy(alpha = 0.4f), RoundedCornerShape(18.dp))
                ) {
                    Box(modifier = Modifier.fillMaxSize()) {
                        PhoneBodyDiagram(
                            stats = stats,
                            modifier = Modifier.fillMaxSize()
                        )
                        // Stat labels overlay
                        Row(
                            modifier = Modifier
                                .align(Alignment.BottomCenter)
                                .padding(bottom = 10.dp)
                                .fillMaxWidth()
                                .padding(horizontal = 16.dp),
                            horizontalArrangement = Arrangement.SpaceEvenly
                        ) {
                            PhoneStatBadge("RAM", "${stats.ramPercentage}%", ElectricPurple)
                            PhoneStatBadge("STORAGE", "${stats.storagePercentage}%", ElectricCyan)
                            PhoneStatBadge("BATTERY", "${stats.batteryLevel}%",
                                if (stats.batteryLevel > 20) NeonGreen else ElectricRed)
                        }
                    }
                }
            }

            // ── Device Selector ───────────────────────────────────────────────────────
            item {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .horizontalScroll(rememberScrollState()),
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    AvatarDeviceChip(
                        label = "📱 This Phone",
                        selected = selectedId == PHONE_ID_AVATAR,
                        isOnline = true,
                        onClick = { selectedId = PHONE_ID_AVATAR; killedProcs = emptySet() }
                    )
                    devices.forEach { dev ->
                        val icon = when {
                            dev.deviceType.contains("PC") || dev.deviceType.contains("Windows") -> "💻"
                            dev.deviceType.contains("Tailscale") -> "🔵"
                            else -> "📡"
                        }
                        AvatarDeviceChip(
                            label = "$icon ${dev.deviceName.take(16)}",
                            selected = selectedId == dev.id,
                            isOnline = dev.isConnected,
                            onClick = { selectedId = dev.id; killedProcs = emptySet() }
                        )
                    }
                }
            }

            // ── Telemetry Mini-Grid ───────────────────────────────────────────────────
            item {
                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    MiniTelemetryTile("CPU", if (cpuPct < 0) "Unavailable" else "$cpuPct%", NvidiaGreen, cpuPct.coerceAtLeast(0) / 100f, modifier = Modifier.weight(1f))
                    MiniTelemetryTile("RAM", if (ramPct < 0) "Unavailable" else "$ramPct%", ElectricPurple, ramPct.coerceAtLeast(0) / 100f, modifier = Modifier.weight(1f))
                    if (selectedId == PHONE_ID_AVATAR) {
                        MiniTelemetryTile("BATT", "${stats.batteryLevel}%",
                            if (stats.batteryLevel > 20) NeonGreen else ElectricRed,
                            stats.batteryLevel / 100f, modifier = Modifier.weight(1f))
                    } else {
                        MiniTelemetryTile("PING", "${selectedDevice?.pingMs ?: 0}ms", ElectricCyan, 0f, modifier = Modifier.weight(1f))
                    }
                    MiniTelemetryTile("PROCS", "${avatarProcesses.size}", LightningYellow, avatarProcesses.size / 20f, modifier = Modifier.weight(1f))
                }
            }

            // ── Action Buttons ─────────────────────────────────────────────────────────
            item {
                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    Button(
                        onClick = { onOptimizeDevice(selectedId) },
                        modifier = Modifier.weight(1f),
                        colors = ButtonDefaults.buttonColors(containerColor = NvidiaGreen),
                        shape = RoundedCornerShape(10.dp)
                    ) {
                        Icon(Icons.Default.Bolt, contentDescription = null, modifier = Modifier.size(15.dp))
                        Spacer(modifier = Modifier.width(4.dp))
                        Text("OPTIMIZE", fontSize = 10.sp, fontWeight = FontWeight.Bold)
                    }
                    Button(
                        onClick = { onMalwareScanDevice(selectedId) },
                        modifier = Modifier.weight(1f),
                        colors = ButtonDefaults.buttonColors(containerColor = ElectricRed),
                        shape = RoundedCornerShape(10.dp)
                    ) {
                        Icon(Icons.Default.BugReport, contentDescription = null, modifier = Modifier.size(15.dp))
                        Spacer(modifier = Modifier.width(4.dp))
                        Text("AUDIT", fontSize = 10.sp, fontWeight = FontWeight.Bold)
                    }
                }
            }

            // ── Kill notification ──────────────────────────────────────────────────────
            if (lastKilled != null) {
                item {
                    Surface(
                        color = ElectricRed.copy(alpha = 0.15f),
                        shape = RoundedCornerShape(10.dp),
                        modifier = Modifier.fillMaxWidth().border(1.dp, ElectricRed.copy(alpha = 0.4f), RoundedCornerShape(10.dp))
                    ) {
                        Row(
                            modifier = Modifier.padding(12.dp),
                            horizontalArrangement = Arrangement.spacedBy(8.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Icon(Icons.Default.Close, contentDescription = null, tint = ElectricRed, modifier = Modifier.size(14.dp))
                            Text("$lastKilled", color = ElectricRed, fontSize = 11.sp, fontWeight = FontWeight.Bold)
                        }
                    }
                }
            }

            // ── Process Killer ───────────────────────────────────────────────────────
            item {
                Card(
                    colors = CardDefaults.cardColors(containerColor = CarbonSurface),
                    shape = RoundedCornerShape(16.dp),
                    modifier = Modifier.fillMaxWidth().border(1.dp, CarbonBorder, RoundedCornerShape(16.dp))
                ) {
                    Column(modifier = Modifier.padding(14.dp)) {
                        Text("PROCESS MONITOR", color = TextPrimary, fontWeight = FontWeight.Bold, fontSize = 13.sp)
                        Text(processState.status, color = TextSecondary, fontSize = 10.sp)
                        Spacer(modifier = Modifier.height(10.dp))
                        avatarProcesses.forEach { proc ->
                            Row(
                                modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Column(modifier = Modifier.weight(1f)) {
                                    Text(proc.label, color = if (proc.isSystem) TextSecondary else TextPrimary, fontSize = 11.sp, fontWeight = FontWeight.Medium)
                                }
                                Text(if (proc.memMb < 0) "RAM unavailable" else "${proc.memMb} MB", color = TextMuted, fontSize = 10.sp)
                                Spacer(modifier = Modifier.width(8.dp))
                                if (!proc.isSystem) {
                                    Box(
                                        modifier = Modifier
                                            .clip(RoundedCornerShape(5.dp))
                                            .background(ElectricRed.copy(alpha = 0.15f))
                                            .border(1.dp, ElectricRed.copy(alpha = 0.5f), RoundedCornerShape(5.dp))
                                            .clickable { scope.launch { lastKilled = terminateMeasuredProcess(context, selectedDevice, proc) } }
                                            .padding(horizontal = 7.dp, vertical = 3.dp)
                                    ) {
                                        Text("KILL", color = ElectricRed, fontSize = 8.sp, fontWeight = FontWeight.Bold)
                                    }
                                }
                            }
                            Divider(color = CarbonBorder, thickness = 0.5.dp)
                        }
                    }
                }
            }

            // ── Nav shortcuts ─────────────────────────────────────────────────────────
            item {
                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    Button(
                        onClick = { onNavigateToTab(NavigationTab.TASKS_SYNC) },
                        modifier = Modifier.weight(1f),
                        colors = ButtonDefaults.buttonColors(containerColor = ElectricPurple),
                        shape = RoundedCornerShape(12.dp)
                    ) {
                        Icon(Icons.Default.Devices, contentDescription = null, modifier = Modifier.size(14.dp))
                        Spacer(modifier = Modifier.width(4.dp))
                        Text("FLEET", fontSize = 10.sp, fontWeight = FontWeight.Bold)
                    }
                    Button(
                        onClick = { onNavigateToTab(NavigationTab.TERMINAL) },
                        modifier = Modifier.weight(1f),
                        colors = ButtonDefaults.buttonColors(containerColor = CarbonSurfaceVariant),
                        shape = RoundedCornerShape(12.dp)
                    ) {
                        Icon(Icons.Default.Terminal, contentDescription = null, tint = NvidiaGreen, modifier = Modifier.size(14.dp))
                        Spacer(modifier = Modifier.width(4.dp))
                        Text("TERMINAL", fontSize = 10.sp, color = NvidiaGreen, fontWeight = FontWeight.Bold)
                    }
                }
            }
        }
    }
}

@Composable
private fun PhoneBodyDiagram(stats: SystemStats, modifier: Modifier = Modifier) {
    val textMeasurer = rememberTextMeasurer()
    val infiniteTransition = rememberInfiniteTransition(label = "phone_glow")
    val glow by infiniteTransition.animateFloat(
        initialValue = 0.5f, targetValue = 1f,
        animationSpec = infiniteRepeatable(tween(1800, easing = FastOutSlowInEasing), RepeatMode.Reverse),
        label = "glow"
    )

    Canvas(modifier = modifier) {
        val w = size.width
        val h = size.height

        val phoneW = w * 0.38f
        val phoneH = h * 0.78f
        val left = (w - phoneW) / 2f
        val top = (h - phoneH) / 2f

        // Ambient glow
        drawCircle(
            brush = Brush.radialGradient(
                listOf(ElectricPurple.copy(alpha = 0.25f * glow), Color.Transparent),
                center = Offset(w / 2f, h / 2f),
                radius = phoneW * 1.4f
            ),
            radius = phoneW * 1.4f,
            center = Offset(w / 2f, h / 2f)
        )

        // Phone body fill
        drawRoundRect(
            color = Color(0xFF12121E),
            topLeft = Offset(left, top),
            size = Size(phoneW, phoneH),
            cornerRadius = CornerRadius(phoneW * 0.12f)
        )
        // Phone border
        drawRoundRect(
            color = ElectricPurple.copy(alpha = 0.8f * glow),
            topLeft = Offset(left, top),
            size = Size(phoneW, phoneH),
            cornerRadius = CornerRadius(phoneW * 0.12f),
            style = Stroke(width = 2f)
        )

        // Screen area
        val scrL = left + phoneW * 0.08f
        val scrT = top + phoneH * 0.12f
        val scrW = phoneW * 0.84f
        val scrH = phoneH * 0.68f
        drawRoundRect(
            color = Color(0xFF080810),
            topLeft = Offset(scrL, scrT),
            size = Size(scrW, scrH),
            cornerRadius = CornerRadius(phoneW * 0.05f)
        )

        // Camera pill
        drawRoundRect(
            color = Color(0xFF1E1E2E),
            topLeft = Offset(left + phoneW * 0.35f, top + phoneH * 0.04f),
            size = Size(phoneW * 0.3f, phoneH * 0.04f),
            cornerRadius = CornerRadius(phoneH * 0.02f)
        )
        // Camera lens dot
        drawCircle(
            color = Color(0xFF2A2A3A),
            radius = phoneH * 0.015f,
            center = Offset(left + phoneW * 0.5f, top + phoneH * 0.06f)
        )

        // Home bar
        drawRoundRect(
            color = ElectricPurple.copy(alpha = 0.5f),
            topLeft = Offset(left + phoneW * 0.3f, top + phoneH * 0.91f),
            size = Size(phoneW * 0.4f, 2.5f),
            cornerRadius = CornerRadius(1.5f)
        )

        // Volume buttons (left side)
        drawRoundRect(color = Color(0xFF2A2A3E), topLeft = Offset(left - 3f, top + phoneH * 0.28f), size = Size(3f, phoneH * 0.09f), cornerRadius = CornerRadius(2f))
        drawRoundRect(color = Color(0xFF2A2A3E), topLeft = Offset(left - 3f, top + phoneH * 0.39f), size = Size(3f, phoneH * 0.09f), cornerRadius = CornerRadius(2f))
        // Power button (right side)
        drawRoundRect(color = Color(0xFF2A2A3E), topLeft = Offset(left + phoneW, top + phoneH * 0.33f), size = Size(3f, phoneH * 0.11f), cornerRadius = CornerRadius(2f))

        // Bars inside screen
        val barL = scrL + scrW * 0.1f
        val barW = scrW * 0.8f
        val barH = scrH * 0.055f
        val barY1 = scrT + scrH * 0.25f   // RAM
        val barY2 = scrT + scrH * 0.47f   // Storage
        val barY3 = scrT + scrH * 0.69f   // Battery

        // RAM
        drawRoundRect(color = Color(0xFF2A2A3A), topLeft = Offset(barL, barY1), size = Size(barW, barH), cornerRadius = CornerRadius(barH / 2))
        drawRoundRect(color = ElectricPurple, topLeft = Offset(barL, barY1), size = Size(barW * (stats.ramPercentage / 100f).coerceIn(0f, 1f), barH), cornerRadius = CornerRadius(barH / 2))

        // Storage
        drawRoundRect(color = Color(0xFF2A2A3A), topLeft = Offset(barL, barY2), size = Size(barW, barH), cornerRadius = CornerRadius(barH / 2))
        drawRoundRect(color = ElectricCyan, topLeft = Offset(barL, barY2), size = Size(barW * (stats.storagePercentage / 100f).coerceIn(0f, 1f), barH), cornerRadius = CornerRadius(barH / 2))

        // Battery
        val battColor = if (stats.batteryLevel > 20) NeonGreen else ElectricRed
        drawRoundRect(color = Color(0xFF2A2A3A), topLeft = Offset(barL, barY3), size = Size(barW, barH), cornerRadius = CornerRadius(barH / 2))
        drawRoundRect(color = battColor, topLeft = Offset(barL, barY3), size = Size(barW * (stats.batteryLevel / 100f).coerceIn(0f, 1f), barH), cornerRadius = CornerRadius(barH / 2))

        // Text labels
        val labelStyle = TextStyle(color = TextMuted, fontSize = 8.sp)
        drawText(textMeasurer, "RAM", topLeft = Offset(barL, barY1 - 18f), style = labelStyle)
        drawText(textMeasurer, "STORAGE", topLeft = Offset(barL, barY2 - 18f), style = labelStyle)
        drawText(textMeasurer, "BATTERY", topLeft = Offset(barL, barY3 - 18f), style = labelStyle)

        // Right-side percentages
        val valStyle = TextStyle(color = Color.White, fontSize = 8.sp, fontWeight = FontWeight.Bold)
        drawText(textMeasurer, "${stats.ramPercentage}%", topLeft = Offset(barL + barW + 4f, barY1), style = valStyle)
        drawText(textMeasurer, "${stats.storagePercentage}%", topLeft = Offset(barL + barW + 4f, barY2), style = valStyle)
        drawText(textMeasurer, "${stats.batteryLevel}%", topLeft = Offset(barL + barW + 4f, barY3), style = valStyle)
    }
}

@Composable
private fun PhoneStatBadge(label: String, value: String, color: Color) {
    Surface(
        color = color.copy(alpha = 0.12f),
        shape = RoundedCornerShape(8.dp),
        modifier = Modifier.border(1.dp, color.copy(alpha = 0.4f), RoundedCornerShape(8.dp))
    ) {
        Column(
            modifier = Modifier.padding(horizontal = 10.dp, vertical = 4.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text(value, color = color, fontSize = 12.sp, fontWeight = FontWeight.ExtraBold)
            Text(label, color = TextMuted, fontSize = 8.sp)
        }
    }
}

@Composable
private fun AvatarDeviceChip(label: String, selected: Boolean, isOnline: Boolean, onClick: () -> Unit) {
    val bgColor = if (selected) ElectricPurple else CarbonSurfaceVariant
    Box(
        modifier = Modifier
            .clip(RoundedCornerShape(18.dp))
            .background(bgColor.copy(alpha = if (selected) 1f else 0.3f))
            .border(1.dp, if (selected) ElectricPurple else if (isOnline) NeonGreen.copy(alpha = 0.4f) else CarbonBorder, RoundedCornerShape(18.dp))
            .clickable(onClick = onClick)
            .padding(horizontal = 12.dp, vertical = 7.dp)
    ) {
        Text(label, color = if (selected) Color.White else TextPrimary, fontSize = 11.sp, fontWeight = if (selected) FontWeight.Bold else FontWeight.Normal)
    }
}

@Composable
private fun MiniTelemetryTile(label: String, value: String, color: Color, progress: Float, modifier: Modifier = Modifier) {
    Card(
        colors = CardDefaults.cardColors(containerColor = CarbonSurface),
        shape = RoundedCornerShape(12.dp),
        modifier = modifier.border(1.dp, color.copy(alpha = 0.3f), RoundedCornerShape(12.dp))
    ) {
        Column(modifier = Modifier.padding(10.dp), horizontalAlignment = Alignment.CenterHorizontally) {
            Text(value, color = color, fontSize = 16.sp, fontWeight = FontWeight.ExtraBold)
            Text(label, color = TextMuted, fontSize = 9.sp)
            if (progress > 0f) {
                Spacer(modifier = Modifier.height(4.dp))
                LinearProgressIndicator(
                    progress = { progress.coerceIn(0f, 1f) },
                    modifier = Modifier.fillMaxWidth().height(3.dp).clip(CircleShape),
                    color = color,
                    trackColor = CarbonSurfaceVariant
                )
            }
        }
    }
}

// Shared process list function (also used by SystemMonitorScreen)

internal data class ProcessEntryAvatar(val pkg: String, val label: String, val memMb: Int, val isSystem: Boolean)

// ── DR. I30LTZ Memory ────────────────────────────────────────────────────────
// Everything DR. I30LTZ knows about the system. Update this when the OS changes.

internal data class I3oltzMemoryEntry(val step: Int, val title: String, val command: String, val note: String)

internal val I3OLTZ_FIRST_BOOT_MEMORY: List<I3oltzMemoryEntry> = listOf(
    I3oltzMemoryEntry(1,  "Check Services",       "systemctl status swarm-ui gaming-agent lucy-server",   "All 3 must be active (running)"),
    I3oltzMemoryEntry(2,  "LUCILLE Drive",         "ls /mnt/Lucy/SWARM_AI_FEATURES.md",                   "UUID: 62f0e009-43c2-4760-8d6c-d7c445f5f3df"),
    I3oltzMemoryEntry(3,  "Install Tailscale",     "curl -fsSL https://tailscale.com/install.sh | sh",    "Then: sudo tailscale up --accept-routes --ssh"),
    I3oltzMemoryEntry(4,  "Set Lock Password",     "POST http://127.0.0.1:5000/api/settings/login_password", "{\"password\":\"YOUR_PASSWORD\"}"),
    I3oltzMemoryEntry(5,  "TOTP 2FA Setup",        "POST http://127.0.0.1:5000/api/settings/totp/setup",  "Scan URI on all 3 phones, then confirm with first code"),
    I3oltzMemoryEntry(6,  "Install Claude Code",   "npm install -g @anthropic-ai/claude-code",            "API key already in /etc/swarm_os.env"),
    I3oltzMemoryEntry(7,  "Verify Firewall",       "nft list ruleset",                                    "Default-drop. SSH tailscale-only. Tailscale0 fully trusted."),
    I3oltzMemoryEntry(8,  "AppArmor Status",       "aa-status | grep gaming-agent",                       "gaming-agent=enforce, lucy-server=complain"),
    I3oltzMemoryEntry(9,  "Test GamingAgent",      "curl http://127.0.0.1:8401/api/gfn/catalog",          "12h cache, warns on first call"),
    I3oltzMemoryEntry(10, "Install Ollama",        "curl -fsSL https://ollama.ai/install.sh | sh",        "Then: ollama pull nomic-embed-text (for RAG)"),
    I3oltzMemoryEntry(11, "Verify Vulkan/GPU",     "vulkaninfo --summary",                                "Intel/AMD GPU should appear"),
    I3oltzMemoryEntry(12, "Syncthing",             "systemctl status syncthing@swarm",                    "Web UI at localhost:8384 to pair phone"),
    I3oltzMemoryEntry(13, "Auth Token",            "echo SWARM_AUTH_TOKEN=... >> /etc/swarm_os.env",      "Default: swarm-token-2026. Change + update companion app."),
    I3oltzMemoryEntry(14, "Health Check",          "curl 127.0.0.1:5000/health && curl 127.0.0.1:8401/health", "Both should return {status:ok}"),
)

internal val BOLTZ_VOICE_MEMORY = "DR. I30LTZ voice: OpenRouter → OpenAI tts-1-hd, voice=onyx (deep authoritative male). " +
    "Lucille voice: ElevenLabs Bella (EXAVITQu4vr4xnSDxMaL) — velvet intelligent female. " +
    "Both configurable via BOLTZ_TTS_VOICE / LUCILLE_TTS_VOICE env vars. " +
    "OS agents reuse same /api/tts/generate endpoint with voice name 'boltz' or 'lucille'."

// ── First Boot Cheatsheet Card ────────────────────────────────────────────────

@Composable
private fun I3oltzCheatsheet() {
    var expanded by remember { mutableStateOf(false) }
    val accentColor = Color(0xFF00E5FF)
    val warnColor  = Color(0xFFFFAB00)

    Card(
        colors = CardDefaults.cardColors(containerColor = Color(0xFF060D14)),
        shape = RoundedCornerShape(16.dp),
        modifier = Modifier
            .fillMaxWidth()
            .border(1.dp, accentColor.copy(alpha = 0.5f), RoundedCornerShape(16.dp))
    ) {
        Column(modifier = Modifier.padding(14.dp)) {
            // Header row — tap to expand/collapse
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable { expanded = !expanded },
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Box(modifier = Modifier.size(8.dp).clip(androidx.compose.foundation.shape.CircleShape).background(warnColor))
                    Text("⚕ DR. I30LTZ — FIRST BOOT PROTOCOL", color = accentColor, fontSize = 11.sp, fontWeight = FontWeight.ExtraBold, letterSpacing = 0.5.sp)
                }
                Icon(
                    imageVector = if (expanded) Icons.Default.ExpandLess else Icons.Default.ExpandMore,
                    contentDescription = if (expanded) "Collapse" else "Expand",
                    tint = accentColor.copy(alpha = 0.7f),
                    modifier = Modifier.size(18.dp)
                )
            }

            if (!expanded) {
                Spacer(modifier = Modifier.height(6.dp))
                Text(
                    "14-step boot sequence • Tap to expand",
                    color = Color(0xFF6B7280),
                    fontSize = 10.sp,
                    fontStyle = FontStyle.Italic
                )
            } else {
                Spacer(modifier = Modifier.height(10.dp))
                I3OLTZ_FIRST_BOOT_MEMORY.forEach { entry ->
                    I3oltzCheatsheetRow(entry)
                    Spacer(modifier = Modifier.height(8.dp))
                }
                Divider(color = accentColor.copy(alpha = 0.2f), thickness = 0.5.dp)
                Spacer(modifier = Modifier.height(8.dp))
                // Voice info
                Text("🎙 VOICES", color = warnColor, fontSize = 10.sp, fontWeight = FontWeight.Bold)
                Spacer(modifier = Modifier.height(4.dp))
                Text(
                    "DR. I30LTZ → OpenRouter/onyx (deep male)\nLucille → ElevenLabs Bella (velvet female)\nBoth reusable by OS agents via voice='boltz'/'lucille'",
                    color = Color(0xFF9AA5B4),
                    fontSize = 10.sp,
                    lineHeight = 15.sp
                )
            }
        }
    }
}

@Composable
private fun I3oltzCheatsheetRow(entry: I3oltzMemoryEntry) {
    val stepColor = Color(0xFF00E5FF)
    Row(verticalAlignment = Alignment.Top, modifier = Modifier.fillMaxWidth()) {
        // Step badge
        Box(
            modifier = Modifier
                .size(22.dp)
                .clip(RoundedCornerShape(4.dp))
                .background(stepColor.copy(alpha = 0.15f))
                .border(0.5.dp, stepColor.copy(alpha = 0.4f), RoundedCornerShape(4.dp)),
            contentAlignment = Alignment.Center
        ) {
            Text("${entry.step}", color = stepColor, fontSize = 9.sp, fontWeight = FontWeight.ExtraBold)
        }
        Spacer(modifier = Modifier.width(8.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(entry.title, color = Color(0xFFE2E8F0), fontSize = 11.sp, fontWeight = FontWeight.Bold)
            Spacer(modifier = Modifier.height(2.dp))
            // Command in monospace-ish style
            Surface(
                color = Color(0xFF0F1923),
                shape = RoundedCornerShape(4.dp),
                modifier = Modifier.fillMaxWidth()
            ) {
                Text(
                    entry.command,
                    color = Color(0xFF76b900),
                    fontSize = 9.5.sp,
                    fontFamily = androidx.compose.ui.text.font.FontFamily.Monospace,
                    modifier = Modifier.padding(horizontal = 6.dp, vertical = 3.dp)
                )
            }
            if (entry.note.isNotEmpty()) {
                Spacer(modifier = Modifier.height(2.dp))
                Text(entry.note, color = Color(0xFF6B7280), fontSize = 9.sp, fontStyle = FontStyle.Italic)
            }
        }
    }
}
