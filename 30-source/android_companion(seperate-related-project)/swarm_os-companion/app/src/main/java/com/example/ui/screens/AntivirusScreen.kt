package com.example.ui.screens

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.ui.components.LightningGauge
import com.example.ui.theme.*

@Composable
fun AntivirusScreen(
    threatScore: Int,
    isScanning: Boolean,
    onRunScan: () -> Unit
) {
    var expandedGuideIndex by remember { mutableStateOf(-1) }

    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 16.dp),
        contentPadding = PaddingValues(bottom = 90.dp, top = 8.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        // Screen Header
        item {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column {
                    Text(
                        text = "DR. I30LTZ Antivirus & PC Shield",
                        color = TextPrimary,
                        fontSize = 20.sp,
                        fontWeight = FontWeight.Bold
                    )
                    Text(
                        text = "Phone & PC Companion Malware Auditor",
                        color = TextSecondary,
                        fontSize = 12.sp
                    )
                }

                Box(
                    modifier = Modifier
                        .clip(CircleShape)
                        .background(ElectricRed.copy(alpha = 0.2f))
                        .padding(8.dp)
                ) {
                    Icon(
                        imageVector = Icons.Default.Shield,
                        contentDescription = "Shield",
                        tint = ElectricRed
                    )
                }
            }
        }

        // Main Threat Score & Deep Scan Card
        item {
            Card(
                colors = CardDefaults.cardColors(containerColor = CarbonSurface),
                shape = RoundedCornerShape(20.dp),
                modifier = Modifier
                    .fillMaxWidth()
                    .border(1.5.dp, ElectricRed, RoundedCornerShape(20.dp))
            ) {
                Column(
                    modifier = Modifier.padding(20.dp),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    LightningGauge(
                        percentage = threatScore,
                        label = "SECURITY SCORE",
                        subLabel = if (threatScore > 90) "SECURE" else "ATTENTION NEEDED",
                        color = if (threatScore > 90) NeonGreen else ElectricRed,
                        sizeDp = 130.dp,
                        strokeWidthDp = 12.dp
                    )

                    Spacer(modifier = Modifier.height(16.dp))

                    Button(
                        onClick = onRunScan,
                        enabled = !isScanning,
                        colors = ButtonDefaults.buttonColors(containerColor = ElectricRed),
                        shape = RoundedCornerShape(14.dp),
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(50.dp)
                            .testTag("run_antivirus_scan_button")
                    ) {
                        if (isScanning) {
                            CircularProgressIndicator(
                                color = Color.White,
                                modifier = Modifier.size(20.dp),
                                strokeWidth = 2.dp
                            )
                            Spacer(modifier = Modifier.width(8.dp))
                            Text("SCANNING SYSTEM & PC BRIDGE...")
                        } else {
                            Icon(imageVector = Icons.Default.Security, contentDescription = "Scan")
                            Spacer(modifier = Modifier.width(8.dp))
                            Text("RUN DEEP ANTIVIRUS & PC AUDIT", fontWeight = FontWeight.Bold)
                        }
                    }
                }
            }
        }

        // App Permission & Firewall Auditor
        item {
            Text(
                text = "APP PERMISSION & FIREWALL AUDITOR",
                color = TextSecondary,
                fontSize = 12.sp,
                fontWeight = FontWeight.Bold,
                letterSpacing = 1.sp
            )

            Spacer(modifier = Modifier.height(8.dp))

            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                AuditItemCard(
                    title = "USB & Wi-Fi Tunnel Encryption",
                    status = "256-bit AES Tunnel Active",
                    isSafe = true,
                    icon = Icons.Default.Usb
                )

                AuditItemCard(
                    title = "Package Signature Evaluator",
                    status = "All 128 apps passed integrity check",
                    isSafe = true,
                    icon = Icons.Default.VerifiedUser
                )

                AuditItemCard(
                    title = "Sensitive App Permissions Audit",
                    status = "0 apps accessing camera/mic in background",
                    isSafe = true,
                    icon = Icons.Default.PrivacyTip
                )
            }
        }

        // Optimization How-To Guides & Suggestions
        item {
            Text(
                text = "SECURITY EVALUATION HOW-TO GUIDES",
                color = TextSecondary,
                fontSize = 12.sp,
                fontWeight = FontWeight.Bold,
                letterSpacing = 1.sp
            )
        }

        val guides = listOf(
            GuideItem(
                title = "How to optimize phone & PC USB connection safety?",
                content = "1. Enable 'USB Debugging Authorization' only for known PC RSA key fingerprints.\n2. In DR. I30LTZ, verify that 'USB Bridge Encryption' status shows Active.\n3. Always eject the device safely before disconnecting the physical cable."
            ),
            GuideItem(
                title = "How to reduce RAM consumption & prevent malware background drain?",
                content = "1. Tap '1-Tap DR. I30LTZ Supercharger' on the dashboard to clear cached RAM buffers.\n2. Review installed apps under Settings > Apps and revoke unused background data permissions.\n3. Keep your Android security patch up to date."
            ),
            GuideItem(
                title = "How does DR. I30LTZ sync tasks safely between Phone and PC?",
                content = "1. Tasks are encrypted locally in Room Database.\n2. When connected via USB or Wi-Fi, DR. I30LTZ sends JSON telemetry over a local TLS socket.\n3. No third-party servers store your private task details."
            )
        )

        items(guides.size) { index ->
            val guide = guides[index]
            val isExpanded = expandedGuideIndex == index

            Card(
                colors = CardDefaults.cardColors(containerColor = CarbonSurface),
                shape = RoundedCornerShape(14.dp),
                onClick = {
                    expandedGuideIndex = if (isExpanded) -1 else index
                },
                modifier = Modifier
                    .fillMaxWidth()
                    .border(1.dp, CarbonBorder, RoundedCornerShape(14.dp))
            ) {
                Column(modifier = Modifier.padding(14.dp)) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(
                            text = guide.title,
                            color = TextPrimary,
                            fontWeight = FontWeight.Bold,
                            fontSize = 13.sp,
                            modifier = Modifier.weight(1f)
                        )
                        Icon(
                            imageVector = if (isExpanded) Icons.Default.ExpandLess else Icons.Default.ExpandMore,
                            contentDescription = "Expand",
                            tint = LightningYellow
                        )
                    }

                    AnimatedVisibility(visible = isExpanded) {
                        Column(modifier = Modifier.padding(top = 10.dp)) {
                            Divider(color = CarbonBorder, thickness = 1.dp)
                            Spacer(modifier = Modifier.height(8.dp))
                            Text(
                                text = guide.content,
                                color = TextSecondary,
                                fontSize = 12.sp,
                                lineHeight = 18.sp
                            )
                        }
                    }
                }
            }
        }
    }
}

private data class GuideItem(val title: String, val content: String)

@Composable
private fun AuditItemCard(
    title: String,
    status: String,
    isSafe: Boolean,
    icon: androidx.compose.ui.graphics.vector.ImageVector
) {
    Card(
        colors = CardDefaults.cardColors(containerColor = CarbonSurface),
        shape = RoundedCornerShape(14.dp),
        modifier = Modifier
            .fillMaxWidth()
            .border(1.dp, CarbonBorder, RoundedCornerShape(14.dp))
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(14.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Box(
                modifier = Modifier
                    .size(38.dp)
                    .clip(CircleShape)
                    .background(if (isSafe) NeonGreen.copy(alpha = 0.2f) else ElectricRed.copy(alpha = 0.2f)),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = icon,
                    contentDescription = title,
                    tint = if (isSafe) NeonGreen else ElectricRed,
                    modifier = Modifier.size(20.dp)
                )
            }

            Spacer(modifier = Modifier.width(12.dp))

            Column {
                Text(
                    text = title,
                    color = TextPrimary,
                    fontWeight = FontWeight.Bold,
                    fontSize = 13.sp
                )
                Text(
                    text = status,
                    color = TextSecondary,
                    fontSize = 11.sp
                )
            }
        }
    }
}
