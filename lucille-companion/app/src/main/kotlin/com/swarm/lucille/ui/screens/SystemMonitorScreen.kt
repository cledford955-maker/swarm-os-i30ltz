package com.swarm.lucille.ui.screens

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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.swarm.lucille.data.db.DeviceSyncEntity
import com.swarm.lucille.data.service.SystemStats
import com.swarm.lucille.ui.theme.*

private const val PHONE_ID = -1L

// ProcessEntryAvatar + processesForDevice defined in DrI3oltzFullAvatarScreen.kt (internal)

@Composable
fun SystemMonitorScreen(
    stats: SystemStats,
    devices: List<DeviceSyncEntity>,
    onRefreshStats: () -> Unit,
    onSuperchargeClick: () -> Unit,
    onOptimizeDevice: (Long) -> Unit,
    onMalwareScanDevice: (Long) -> Unit
) {
    var selectedId by remember { mutableStateOf(PHONE_ID) }
    var killedProcs by remember { mutableStateOf(setOf<String>()) }
    var scanning by remember { mutableStateOf(false) }
    var lastKilled by remember { mutableStateOf<String?>(null) }

    val selectedDevice = if (selectedId == PHONE_ID) null else devices.find { it.id == selectedId }

    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val measured = selectedDevice?.takeIf { it.isConnected && System.currentTimeMillis() - it.lastSyncTime < 60_000 }
    val cpuPct = measured?.cpuLoadPercent ?: -1
    val ramPct = if (selectedId == PHONE_ID) stats.ramPercentage else measured?.ramLoadPercent ?: -1
    val pingMs = measured?.pingMs
    val processState = rememberDeviceProcesses(selectedDevice)
    val processes = processState.entries

    LaunchedEffect(lastKilled) {
        if (lastKilled != null) {
            kotlinx.coroutines.delay(2500)
            lastKilled = null
        }
    }

    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 16.dp),
        contentPadding = PaddingValues(bottom = 100.dp, top = 8.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        // ── Header ──────────────────────────────────────────────────────────────
        item {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column {
                    Text("System & Fleet Monitor", color = TextPrimary, fontSize = 20.sp, fontWeight = FontWeight.Bold)
                    Text("Real-Time Telemetry — All Devices", color = TextSecondary, fontSize = 12.sp)
                }
                IconButton(
                    onClick = onRefreshStats,
                    modifier = Modifier
                        .clip(CircleShape)
                        .background(CarbonSurfaceVariant)
                        .border(1.dp, CarbonBorder, CircleShape)
                        .testTag("refresh_stats_button")
                ) {
                    Icon(Icons.Default.Refresh, contentDescription = "Refresh", tint = LightningYellow)
                }
            }
        }

        // ── Device Selector ──────────────────────────────────────────────────────
        item {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .horizontalScroll(rememberScrollState()),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                DeviceChip(
                    label = "📱 This Phone",
                    selected = selectedId == PHONE_ID,
                    isOnline = true,
                    onClick = { selectedId = PHONE_ID; killedProcs = emptySet() }
                )
                devices.forEach { dev ->
                    val icon = when {
                        dev.deviceType.contains("PC") || dev.deviceType.contains("Windows") -> "💻"
                        dev.deviceType.contains("Tailscale") -> "🔵"
                        else -> "📡"
                    }
                    DeviceChip(
                        label = "$icon ${dev.deviceName}",
                        selected = selectedId == dev.id,
                        isOnline = dev.isConnected,
                        onClick = { selectedId = dev.id; killedProcs = emptySet() }
                    )
                }
            }
        }

        // ── Device Status Bar ───────────────────────────────────────────────────
        if (selectedId != PHONE_ID && selectedDevice != null) {
            item {
                Surface(
                    color = if (selectedDevice.isConnected) NeonGreen.copy(alpha = 0.1f) else ElectricRed.copy(alpha = 0.1f),
                    shape = RoundedCornerShape(12.dp),
                    modifier = Modifier
                        .fillMaxWidth()
                        .border(1.dp, if (selectedDevice.isConnected) NeonGreen.copy(alpha = 0.4f) else ElectricRed.copy(alpha = 0.4f), RoundedCornerShape(12.dp))
                ) {
                    Row(
                        modifier = Modifier.padding(horizontal = 14.dp, vertical = 8.dp),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            Box(modifier = Modifier.size(8.dp).clip(CircleShape).background(if (selectedDevice.isConnected) NeonGreen else ElectricRed))
                            Text(selectedDevice.syncStatus, color = TextPrimary, fontSize = 12.sp, fontWeight = FontWeight.Medium)
                        }
                        Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                            Text("${selectedDevice.ipAddress}", color = TextMuted, fontSize = 11.sp)
                            if (pingMs != null) Text("${pingMs}ms", color = ElectricCyan, fontSize = 11.sp, fontWeight = FontWeight.Bold)
                        }
                    }
                }
            }
        }

        // ── CPU Card ─────────────────────────────────────────────────────────────
        item {
            TelemetryCard(
                icon = Icons.Default.Speed,
                iconTint = NvidiaGreen,
                title = "CPU LOAD",
                badge = if (cpuPct < 0) "UNAVAILABLE" else "$cpuPct% ACTIVE",
                badgeColor = if (cpuPct > 80) ElectricRed else NvidiaGreen
            ) {
                LinearProgressIndicator(
                    progress = { cpuPct.coerceAtLeast(0) / 100f },
                    modifier = Modifier.fillMaxWidth().height(10.dp).clip(CircleShape),
                    color = NvidiaGreen,
                    trackColor = CarbonSurfaceVariant
                )
                Spacer(modifier = Modifier.height(10.dp))
                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    InfoStat("Active", if (cpuPct < 0) "Unavailable" else "$cpuPct%")
                    InfoStat("Idle", if (cpuPct < 0) "Unavailable" else "${100 - cpuPct}%")
                    if (pingMs != null) InfoStat("Network Ping", "${pingMs}ms")
                    InfoStat("Visible processes", if (selectedId == PHONE_ID) "${stats.runningProcessCount}" else "${processes.size}")
                }
            }
        }

        // ── RAM Card ─────────────────────────────────────────────────────────────
        item {
            TelemetryCard(
                icon = Icons.Default.Memory,
                iconTint = ElectricPurple,
                title = "RAM & ZRAM SWAP",
                badge = if (ramPct < 0) "UNAVAILABLE" else "$ramPct% USED",
                badgeColor = if (ramPct > 80) ElectricRed else NeonGreen
            ) {
                LinearProgressIndicator(
                    progress = { ramPct.coerceAtLeast(0) / 100f },
                    modifier = Modifier.fillMaxWidth().height(10.dp).clip(CircleShape),
                    color = ElectricPurple,
                    trackColor = CarbonSurfaceVariant
                )
                Spacer(modifier = Modifier.height(10.dp))
                if (selectedId == PHONE_ID) {
                    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                        InfoStat("Used", "${stats.usedRamMb} MB")
                        InfoStat("Free", "${stats.freeRamMb} MB")
                        InfoStat("Total", "${stats.totalRamMb} MB")
                        InfoStat("SWAP", if (stats.swapTotalMb < 0) "Unavailable" else "${stats.swapTotalMb} MB")
                    }
                } else {
                    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                        InfoStat("Load", if (ramPct < 0) "Unavailable" else "$ramPct%")
                        InfoStat("Free", if (ramPct < 0) "Unavailable" else "${100 - ramPct}%")
                        InfoStat("Status", if (ramPct < 0) "Unavailable" else if (ramPct < 60) "Measured" else "High Load")
                    }
                }
            }
        }

        // ── Storage Card ─────────────────────────────────────────────────────────
        item {
            TelemetryCard(
                icon = Icons.Default.Storage,
                iconTint = ElectricCyan,
                title = "STORAGE DYNAMICS",
                badge = if (selectedId == PHONE_ID) "${stats.storagePercentage}% USED" else if ((measured?.storageAvailableGb ?: -1) < 0) "UNAVAILABLE" else "${measured?.storageAvailableGb} GB FREE",
                badgeColor = ElectricCyan
            ) {
                if (selectedId == PHONE_ID) {
                    LinearProgressIndicator(
                        progress = { stats.storagePercentage / 100f },
                        modifier = Modifier.fillMaxWidth().height(10.dp).clip(CircleShape),
                        color = ElectricCyan,
                        trackColor = CarbonSurfaceVariant
                    )
                    Spacer(modifier = Modifier.height(10.dp))
                    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                        InfoStat("Used", "${stats.usedStorageGb} GB")
                        InfoStat("Free", "${stats.freeStorageGb} GB")
                        InfoStat("Total", "${stats.totalStorageGb} GB")
                    }
                } else {
                    Text(if ((measured?.storageAvailableGb ?: -1) < 0) "This node does not report storage measurements." else "${measured?.storageAvailableGb} GB available on ${selectedDevice?.deviceName}", color = TextSecondary, fontSize = 12.sp)
                }
            }
        }

        // ── Battery Card (phone only) ─────────────────────────────────────────────
        if (selectedId == PHONE_ID) {
            item {
                TelemetryCard(
                    icon = Icons.Default.BatteryChargingFull,
                    iconTint = LightningYellow,
                    title = "BATTERY & THERMAL",
                    badge = if (stats.isCharging) "CHARGING ⚡" else "DISCHARGING",
                    badgeColor = NeonGreen
                ) {
                    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                        InfoStat("Level", "${stats.batteryLevel}%")
                        InfoStat("Temperature", "${stats.batteryTemperature}°C")
                        InfoStat("Health", stats.batteryHealth)
                    }
                }
            }
        }

        // ── Action Buttons ────────────────────────────────────────────────────────
        item {
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Button(
                    onClick = { onOptimizeDevice(selectedId) },
                    modifier = Modifier.weight(1f),
                    colors = ButtonDefaults.buttonColors(containerColor = NvidiaGreen),
                    shape = RoundedCornerShape(10.dp)
                ) {
                    Icon(Icons.Default.Bolt, contentDescription = null, modifier = Modifier.size(16.dp))
                    Spacer(modifier = Modifier.width(6.dp))
                    Text("OPTIMIZE", fontSize = 11.sp, fontWeight = FontWeight.Bold)
                }
                Button(
                    onClick = {
                        scanning = true
                        onMalwareScanDevice(selectedId)
                        // Visual reset after delay — real state managed by VM
                    },
                    modifier = Modifier.weight(1f),
                    colors = ButtonDefaults.buttonColors(containerColor = ElectricRed),
                    shape = RoundedCornerShape(10.dp)
                ) {
                    Icon(Icons.Default.BugReport, contentDescription = null, modifier = Modifier.size(16.dp))
                    Spacer(modifier = Modifier.width(6.dp))
                    Text("SECURITY AUDIT", fontSize = 11.sp, fontWeight = FontWeight.Bold)
                }
            }
        }

        // ── Kill notification ─────────────────────────────────────────────────────
        if (lastKilled != null) {
            item {
                Surface(
                    color = ElectricRed.copy(alpha = 0.15f),
                    shape = RoundedCornerShape(10.dp),
                    modifier = Modifier
                        .fillMaxWidth()
                        .border(1.dp, ElectricRed.copy(alpha = 0.4f), RoundedCornerShape(10.dp))
                ) {
                    Row(
                        modifier = Modifier.padding(12.dp),
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Icon(Icons.Default.Close, contentDescription = null, tint = ElectricRed, modifier = Modifier.size(16.dp))
                        Text("$lastKilled", color = ElectricRed, fontSize = 12.sp, fontWeight = FontWeight.Bold)
                    }
                }
            }
        }

        // ── Process Manager ──────────────────────────────────────────────────────
        item {
            Card(
                colors = CardDefaults.cardColors(containerColor = CarbonSurface),
                shape = RoundedCornerShape(18.dp),
                modifier = Modifier.fillMaxWidth().border(1.dp, CarbonBorder, RoundedCornerShape(18.dp))
            ) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Column {
                            Text("ACTIVE PROCESS MANAGER", color = TextPrimary, fontWeight = FontWeight.Bold, fontSize = 14.sp)
                            Text(processState.status, color = TextSecondary, fontSize = 11.sp)
                        }
                        Button(
                            onClick = { onSuperchargeClick() },
                            colors = ButtonDefaults.buttonColors(containerColor = ElectricRed),
                            shape = RoundedCornerShape(10.dp),
                            contentPadding = PaddingValues(horizontal = 12.dp, vertical = 6.dp)
                        ) {
                            Text("BOOST ALL", fontSize = 10.sp, fontWeight = FontWeight.Bold)
                        }
                    }

                    Spacer(modifier = Modifier.height(12.dp))

                    processes.forEach { proc ->
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(vertical = 5.dp),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Column(modifier = Modifier.weight(1f)) {
                                Text(
                                    proc.label,
                                    color = if (proc.isSystem) TextSecondary else TextPrimary,
                                    fontSize = 12.sp,
                                    fontWeight = FontWeight.Medium,
                                    maxLines = 1,
                                    overflow = TextOverflow.Ellipsis
                                )
                                Text(
                                    proc.pkg,
                                    color = TextMuted,
                                    fontSize = 9.sp,
                                    maxLines = 1,
                                    overflow = TextOverflow.Ellipsis
                                )
                            }
                            Spacer(modifier = Modifier.width(8.dp))
                            Text(if (proc.memMb < 0) "RAM unavailable" else "${proc.memMb} MB", color = TextSecondary, fontSize = 11.sp, fontWeight = FontWeight.Bold)
                            Spacer(modifier = Modifier.width(8.dp))
                            if (!proc.isSystem) {
                                Box(
                                    modifier = Modifier
                                        .clip(RoundedCornerShape(6.dp))
                                        .background(ElectricRed.copy(alpha = 0.15f))
                                        .border(1.dp, ElectricRed.copy(alpha = 0.5f), RoundedCornerShape(6.dp))
                                        .clickable {
                                            scope.launch { lastKilled = terminateMeasuredProcess(context, selectedDevice, proc) }
                                        }
                                        .padding(horizontal = 8.dp, vertical = 4.dp)
                                ) {
                                    Text("KILL", color = ElectricRed, fontSize = 9.sp, fontWeight = FontWeight.Bold)
                                }
                            } else {
                                Text("SYSTEM", color = TextMuted, fontSize = 9.sp, fontWeight = FontWeight.Bold)
                            }
                        }
                        Divider(color = CarbonBorder, thickness = 0.5.dp)
                    }
                }
            }
        }

        // ── Pooled Resources ────────────────────────────────────────────────────
        item {
            Card(
                colors = CardDefaults.cardColors(containerColor = CarbonSurface),
                shape = RoundedCornerShape(18.dp),
                modifier = Modifier.fillMaxWidth().border(1.dp, ElectricPurple.copy(alpha = 0.4f), RoundedCornerShape(18.dp))
            ) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        Icon(Icons.Default.Devices, contentDescription = null, tint = ElectricPurple, modifier = Modifier.size(20.dp))
                        Text("POOLED FLEET RESOURCES", color = TextPrimary, fontWeight = FontWeight.Bold, fontSize = 14.sp)
                    }
                    Spacer(modifier = Modifier.height(12.dp))

                    val fresh = devices.filter { it.isConnected && System.currentTimeMillis() - it.lastSyncTime < 60_000 }
                    val allCpus = fresh.map { it.cpuLoadPercent }.filter { it >= 0 }
                    val allRams = fresh.map { it.ramLoadPercent }.filter { it >= 0 } + stats.ramPercentage
                    val storage = fresh.map { it.storageAvailableGb }.filter { it >= 0 }
                    val totalStorage = storage.sumOf { it.toLong() }
                    val connectedCount = fresh.size + 1
                    val avgCpu = if (allCpus.isEmpty()) -1 else allCpus.average().toInt()
                    val avgRam = allRams.average().toInt()

                    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                        PoolStat("Devices Online", "$connectedCount / ${devices.size + 1}", NeonGreen)
                        PoolStat("Avg CPU", if (avgCpu < 0) "Unavailable" else "$avgCpu%", NvidiaGreen)
                        PoolStat("Avg RAM", "$avgRam%", ElectricPurple)
                        PoolStat("Fleet Storage", if (storage.isEmpty()) "Unavailable" else "${totalStorage} GB reported", ElectricCyan)
                    }

                    Spacer(modifier = Modifier.height(10.dp))

                    Text("CPU Load Across Fleet", color = TextMuted, fontSize = 10.sp)
                    Spacer(modifier = Modifier.height(4.dp))
                    LinearProgressIndicator(
                        progress = { avgCpu.coerceAtLeast(0) / 100f },
                        modifier = Modifier.fillMaxWidth().height(8.dp).clip(CircleShape),
                        color = NvidiaGreen,
                        trackColor = CarbonSurfaceVariant
                    )
                    Spacer(modifier = Modifier.height(6.dp))
                    Text("RAM Utilization Across Fleet", color = TextMuted, fontSize = 10.sp)
                    Spacer(modifier = Modifier.height(4.dp))
                    LinearProgressIndicator(
                        progress = { avgRam / 100f },
                        modifier = Modifier.fillMaxWidth().height(8.dp).clip(CircleShape),
                        color = ElectricPurple,
                        trackColor = CarbonSurfaceVariant
                    )
                }
            }
        }
    }
}

@Composable
private fun DeviceChip(label: String, selected: Boolean, isOnline: Boolean, onClick: () -> Unit) {
    val bgColor = if (selected) ElectricPurple else CarbonSurfaceVariant
    val borderColor = if (selected) ElectricPurple else if (isOnline) NeonGreen.copy(alpha = 0.4f) else CarbonBorder
    Box(
        modifier = Modifier
            .clip(RoundedCornerShape(20.dp))
            .background(bgColor.copy(alpha = if (selected) 1f else 0.3f))
            .border(1.dp, borderColor, RoundedCornerShape(20.dp))
            .clickable(onClick = onClick)
            .padding(horizontal = 14.dp, vertical = 8.dp)
    ) {
        Text(label, color = if (selected) Color.White else TextPrimary, fontSize = 12.sp, fontWeight = if (selected) FontWeight.Bold else FontWeight.Normal)
    }
}

@Composable
private fun TelemetryCard(
    icon: ImageVector,
    iconTint: Color,
    title: String,
    badge: String,
    badgeColor: Color,
    content: @Composable ColumnScope.() -> Unit
) {
    Card(
        colors = CardDefaults.cardColors(containerColor = CarbonSurface),
        shape = RoundedCornerShape(18.dp),
        modifier = Modifier.fillMaxWidth().border(1.dp, CarbonBorder, RoundedCornerShape(18.dp))
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween,
                modifier = Modifier.fillMaxWidth()
            ) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    Icon(icon, contentDescription = title, tint = iconTint, modifier = Modifier.size(24.dp))
                    Text(title, color = TextPrimary, fontWeight = FontWeight.Bold, fontSize = 14.sp)
                }
                Text(badge, color = badgeColor, fontWeight = FontWeight.Bold, fontSize = 12.sp)
            }
            Spacer(modifier = Modifier.height(12.dp))
            content()
        }
    }
}

@Composable
private fun InfoStat(label: String, value: String) {
    Column {
        Text(label, color = TextMuted, fontSize = 10.sp)
        Text(value, color = TextPrimary, fontSize = 12.sp, fontWeight = FontWeight.Bold)
    }
}

@Composable
private fun PoolStat(label: String, value: String, valueColor: Color) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text(value, color = valueColor, fontSize = 16.sp, fontWeight = FontWeight.ExtraBold)
        Text(label, color = TextMuted, fontSize = 9.sp)
    }
}
