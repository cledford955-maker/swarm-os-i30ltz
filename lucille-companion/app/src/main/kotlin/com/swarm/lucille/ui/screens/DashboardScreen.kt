package com.swarm.lucille.ui.screens

import androidx.compose.animation.*
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.swarm.lucille.data.db.SystemScanEntity
import com.swarm.lucille.data.service.SystemStats
import com.swarm.lucille.ui.components.DrI3oltzAvatar
import com.swarm.lucille.ui.components.LightningGauge
import com.swarm.lucille.ui.screens.SwarmOsHeader
import com.swarm.lucille.ui.theme.*

@Composable
fun DashboardScreen(
    stats: SystemStats,
    recentScans: List<SystemScanEntity>,
    avatarSpeech: String? = null,
    isSpeaking: Boolean = false,
    isMuted: Boolean,
    isOptimizing: Boolean,
    onAvatarClick: () -> Unit,
    onSuperchargeClick: () -> Unit,
    onMuteToggle: () -> Unit,
    onNavigateToTab: (com.swarm.lucille.ui.NavigationTab) -> Unit
) {
    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 16.dp),
        contentPadding = PaddingValues(bottom = 90.dp, top = 8.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        // Top Action Bar Header
        item {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = 4.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        SwarmOsHeader(fontSizeSp = 20)
                        Spacer(modifier = Modifier.width(6.dp))
                        Icon(
                            imageVector = Icons.Default.Terminal,
                            contentDescription = "Terminal",
                            tint = NvidiaGreen,
                            modifier = Modifier.size(20.dp)
                        )
                    }
                    Text(
                        text = "DR. i3OLTZ IT Agent • Powered by SWARM CORE",
                        color = TextSecondary,
                        fontSize = 12.sp
                    )
                }

                IconButton(
                    onClick = onMuteToggle,
                    modifier = Modifier
                        .clip(CircleShape)
                        .background(CarbonSurfaceVariant)
                        .border(1.dp, CarbonBorder, CircleShape)
                        .testTag("mute_button")
                ) {
                    Icon(
                        imageVector = if (isMuted) Icons.Default.VolumeOff else Icons.Default.VolumeUp,
                        contentDescription = "Toggle Mute",
                        tint = if (isMuted) TextMuted else LightningYellow
                    )
                }
            }
        }

        // DR. I30LTZ Purple Electricity Front Page Hero Card
        item {
            Card(
                colors = CardDefaults.cardColors(containerColor = CarbonSurface),
                shape = RoundedCornerShape(24.dp),
                modifier = Modifier
                    .fillMaxWidth()
                    .border(
                        2.dp,
                        Brush.horizontalGradient(
                            listOf(Color(0xFFE040FB), ElectricPurple, ElectricRed, LightningYellow)
                        ),
                        RoundedCornerShape(24.dp)
                    )
            ) {
                Column(
                    modifier = Modifier.padding(18.dp),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    // DR. I30LTZ Title & Watermark Header
                    Surface(
                        color = Color(0xFFE040FB).copy(alpha = 0.15f),
                        shape = RoundedCornerShape(12.dp),
                        modifier = Modifier.border(1.dp, Color(0xFFE040FB).copy(alpha = 0.4f), RoundedCornerShape(12.dp))
                    ) {
                        Row(
                            modifier = Modifier.padding(horizontal = 12.dp, vertical = 4.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Icon(
                                imageVector = Icons.Default.AutoAwesome,
                                contentDescription = null,
                                tint = Color(0xFFE040FB),
                                modifier = Modifier.size(14.dp)
                            )
                            Spacer(modifier = Modifier.width(6.dp))
                            Text(
                                text = "DR. I30LTZ • NATIVE CORE CODER",
                                color = Color(0xFFE040FB),
                                fontSize = 11.sp,
                                fontWeight = FontWeight.ExtraBold,
                                letterSpacing = 2.sp
                            )
                        }
                    }

                    Spacer(modifier = Modifier.height(12.dp))

                    DrI3oltzAvatar(
                        isSpeaking = isSpeaking,
                        speechText = avatarSpeech,
                        onAvatarClick = { onNavigateToTab(com.swarm.lucille.ui.NavigationTab.AVATAR_3D) }
                    )

                    Spacer(modifier = Modifier.height(10.dp))

                    Text(
                        text = "DR. I30LTZ CORE CODER",
                        color = Color(0xFFE040FB),
                        fontSize = 20.sp,
                        fontWeight = FontWeight.Black,
                        letterSpacing = 2.sp
                    )

                    Text(
                        text = "DR. i3OLTZ IT FIELD AGENT ACTIVE",
                        color = NvidiaGreen,
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Bold,
                        letterSpacing = 1.sp
                    )

                    Spacer(modifier = Modifier.height(14.dp))

                    // 1-Tap Supercharger Button
                    Button(
                        onClick = onSuperchargeClick,
                        enabled = !isOptimizing,
                        colors = ButtonDefaults.buttonColors(
                            containerColor = ElectricPurple,
                            contentColor = Color.White
                        ),
                        shape = RoundedCornerShape(14.dp),
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(52.dp)
                            .testTag("supercharge_button")
                    ) {
                        if (isOptimizing) {
                            CircularProgressIndicator(
                                color = Color.White,
                                modifier = Modifier.size(20.dp),
                                strokeWidth = 2.dp
                            )
                            Spacer(modifier = Modifier.width(8.dp))
                            Text("OPTIMIZING SYSTEM VIA DR. I30LTZ AI...")
                        } else {
                            Icon(
                                imageVector = Icons.Default.Bolt,
                                contentDescription = "Supercharge",
                                tint = LightningYellow
                            )
                            Spacer(modifier = Modifier.width(6.dp))
                            Text(
                                "1-TAP DR. I30LTZ SUPERCHARGER",
                                fontWeight = FontWeight.ExtraBold,
                                fontSize = 14.sp
                            )
                        }
                    }
                }
            }
        }

        // Live Telemetry Lightning Gauges Grid
        item {
            // New Tailscale / VPN / SSE Connection Indicator Card
            Card(
                colors = CardDefaults.cardColors(containerColor = CarbonSurfaceVariant.copy(alpha = 0.5f)),
                shape = RoundedCornerShape(14.dp),
                modifier = Modifier
                    .fillMaxWidth()
                    .border(1.dp, NvidiaGreen, RoundedCornerShape(14.dp))
                    .padding(bottom = 12.dp)
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth().padding(12.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(Icons.Default.VpnKey, contentDescription = "VPN", tint = NvidiaGreen, modifier = Modifier.size(24.dp))
                    Spacer(modifier = Modifier.width(12.dp))
                    Column {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text("COMPUTER:", color = TextSecondary, fontSize = 10.sp, fontWeight = FontWeight.Bold)
                            Spacer(modifier = Modifier.width(4.dp))
                            Text("Check connection in Remote PC", color = NvidiaGreen, fontSize = 10.sp, fontWeight = FontWeight.Bold)
                        }
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text("MEMORY SYNC:", color = TextSecondary, fontSize = 10.sp, fontWeight = FontWeight.Bold)
                            Spacer(modifier = Modifier.width(4.dp))
                            Text(com.swarm.lucille.data.memory.MemorySyncEngine.status.collectAsState().value, color = NvidiaGreen, fontSize = 10.sp, fontWeight = FontWeight.Bold)
                        }
                    }
                    Spacer(modifier = Modifier.weight(1f))
                    Icon(Icons.Default.ArrowForwardIos, contentDescription = "Swipe", tint = TextMuted, modifier = Modifier.size(16.dp))
                    Text("SWIPE", color = TextMuted, fontSize = 8.sp)
                }
            }

            Text(
                text = "SYSTEM TELEMETRY GAUGES",
                color = TextSecondary,
                fontSize = 12.sp,
                fontWeight = FontWeight.Bold,
                letterSpacing = 1.sp
            )

            Spacer(modifier = Modifier.height(8.dp))

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                LightningGauge(
                    percentage = stats.ramPercentage,
                    label = "RAM LOAD",
                    subLabel = "${stats.usedRamMb}/${stats.totalRamMb}MB",
                    color = ElectricPurple
                )

                LightningGauge(
                    percentage = stats.storagePercentage,
                    label = "STORAGE",
                    subLabel = "${stats.freeStorageGb} GB free",
                    color = ElectricCyan
                )

                LightningGauge(
                    percentage = stats.batteryLevel,
                    label = "BATTERY",
                    subLabel = "${stats.batteryTemperature}°C",
                    color = if (stats.batteryTemperature > 40) ElectricRed else NeonGreen
                )
            }
        }

        // Quick Navigation Command Grid
        item {
            Text(
                text = "COMMAND MODULES",
                color = TextSecondary,
                fontSize = 12.sp,
                fontWeight = FontWeight.Bold,
                letterSpacing = 1.sp
            )

            Spacer(modifier = Modifier.height(8.dp))

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                CommandTile(
                    title = "Task & PC Sync",
                    subtitle = "Cross-Device Tunnel",
                    icon = Icons.Default.Sync,
                    color = ElectricPurple,
                    modifier = Modifier.weight(1f)
                ) {
                    onNavigateToTab(com.swarm.lucille.ui.NavigationTab.TASKS_SYNC)
                }

                CommandTile(
                    title = "Antivirus Shield",
                    subtitle = "Malware & Permissions",
                    icon = Icons.Default.Shield,
                    color = ElectricRed,
                    modifier = Modifier.weight(1f)
                ) {
                    onNavigateToTab(com.swarm.lucille.ui.NavigationTab.ANTIVIRUS)
                }
            }

            Spacer(modifier = Modifier.height(8.dp))

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                CommandTile(
                    title = "System Monitor",
                    subtitle = "RAM, Swap & Battery",
                    icon = Icons.Default.Memory,
                    color = LightningYellow,
                    modifier = Modifier.weight(1f)
                ) {
                    onNavigateToTab(com.swarm.lucille.ui.NavigationTab.SYSTEM_MONITOR)
                }

                CommandTile(
                    title = "DR. I30LTZ AI Lab",
                    subtitle = "Live AI Voice Assistant",
                    icon = Icons.Default.Psychology,
                    color = ElectricCyan,
                    modifier = Modifier.weight(1f)
                ) {
                    onNavigateToTab(com.swarm.lucille.ui.NavigationTab.AI_LAB)
                }
            }
        }

        // Recent Scan Activity Logs
        item {
            Text(
                text = "RECENT DR i3OLTZ LOGS",
                color = TextSecondary,
                fontSize = 12.sp,
                fontWeight = FontWeight.Bold,
                letterSpacing = 1.sp
            )
        }

        if (recentScans.isEmpty()) {
            item {
                Card(
                    colors = CardDefaults.cardColors(containerColor = CarbonSurface),
                    shape = RoundedCornerShape(12.dp),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Text(
                        text = "No recent scans. Tap 1-Tap Supercharger above to optimize!",
                        color = TextMuted,
                        fontSize = 13.sp,
                        modifier = Modifier.padding(16.dp)
                    )
                }
            }
        } else {
            items(recentScans.take(3)) { scan ->
                Card(
                    colors = CardDefaults.cardColors(containerColor = CarbonSurface),
                    shape = RoundedCornerShape(14.dp),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(14.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Box(
                            modifier = Modifier
                                .size(40.dp)
                                .clip(CircleShape)
                                .background(ElectricPurple.copy(alpha = 0.2f)),
                            contentAlignment = Alignment.Center
                        ) {
                            Icon(
                                imageVector = Icons.Default.CheckCircle,
                                contentDescription = "Scan Log",
                                tint = NeonGreen
                            )
                        }

                        Spacer(modifier = Modifier.width(12.dp))

                        Column {
                            Text(
                                text = scan.scanType,
                                color = TextPrimary,
                                fontWeight = FontWeight.Bold,
                                fontSize = 14.sp
                            )
                            Text(
                                text = scan.summaryMessage,
                                color = TextSecondary,
                                fontSize = 12.sp
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun CommandTile(
    title: String,
    subtitle: String,
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    color: Color,
    modifier: Modifier = Modifier,
    onClick: () -> Unit
) {
    Card(
        colors = CardDefaults.cardColors(containerColor = CarbonSurface),
        shape = RoundedCornerShape(16.dp),
        onClick = onClick,
        modifier = modifier.border(1.dp, CarbonBorder, RoundedCornerShape(16.dp))
    ) {
        Column(
            modifier = Modifier.padding(14.dp),
            verticalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            Box(
                modifier = Modifier
                    .size(36.dp)
                    .clip(CircleShape)
                    .background(color.copy(alpha = 0.2f)),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = icon,
                    contentDescription = title,
                    tint = color,
                    modifier = Modifier.size(20.dp)
                )
            }
            Text(
                text = title,
                color = TextPrimary,
                fontWeight = FontWeight.Bold,
                fontSize = 13.sp
            )
            Text(
                text = subtitle,
                color = TextMuted,
                fontSize = 11.sp
            )
        }
    }
}
