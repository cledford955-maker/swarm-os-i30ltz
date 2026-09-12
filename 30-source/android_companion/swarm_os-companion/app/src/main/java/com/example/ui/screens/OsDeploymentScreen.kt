package com.example.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.ui.theme.*

@Composable
fun OsDeploymentScreen(
    isoDownloadProgress: Float,
    isUsbMounted: Boolean,
    grubCommandProposal: String,
    isOfflineAi: Boolean,
    onDownloadIso: (String) -> Unit,
    onToggleUsbMount: () -> Unit,
    onAskGrubHelp: (String) -> Unit,
    onSendHidCommand: (String) -> Unit,
    onSendHidEnter: () -> Unit,
    onToggleAiMode: () -> Unit
) {
    var grubIssue by remember { mutableStateOf("") }

    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        item {
            Text(
                text = "OS Deployment & Live USB",
                color = TextPrimary,
                fontSize = 24.sp,
                fontWeight = FontWeight.Bold
            )
            Spacer(modifier = Modifier.height(4.dp))
            Text(
                text = "Download ISOs and boot via USB Mass Storage Emulation.",
                color = TextSecondary,
                fontSize = 12.sp
            )
        }

        // Live USB Controls
        item {
            Card(
                colors = CardDefaults.cardColors(containerColor = CarbonSurface),
                shape = RoundedCornerShape(16.dp),
                modifier = Modifier
                    .fillMaxWidth()
                    .border(1.dp, CarbonBorder, RoundedCornerShape(16.dp))
            ) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Text("Select ISO to Download", color = NvidiaGreen, fontWeight = FontWeight.Bold, fontSize = 14.sp)
                    Spacer(modifier = Modifier.height(12.dp))

                    IsoRow("SWARM_OS_v1.iso", "64-bit • 2.1 GB", onDownloadIso)
                    Spacer(modifier = Modifier.height(8.dp))
                    IsoRow("Ubuntu_24.04.iso", "64-bit • 3.5 GB", onDownloadIso)

                    if (isoDownloadProgress > 0f && isoDownloadProgress < 1f) {
                        Spacer(modifier = Modifier.height(16.dp))
                        Text("Downloading...", color = TextSecondary, fontSize = 12.sp)
                        LinearProgressIndicator(
                            progress = { isoDownloadProgress },
                            modifier = Modifier.fillMaxWidth().height(8.dp).clip(RoundedCornerShape(4.dp)),
                            color = NvidiaGreen,
                            trackColor = CarbonSurfaceVariant
                        )
                    }

                    Spacer(modifier = Modifier.height(24.dp))
                    Divider(color = CarbonBorder)
                    Spacer(modifier = Modifier.height(16.dp))

                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Column {
                            Text("USB Mass Storage Emulation", color = TextPrimary, fontWeight = FontWeight.Bold)
                            Text(if (isUsbMounted) "Phone acting as bootable flash drive" else "Disconnected", color = if (isUsbMounted) NvidiaGreen else TextSecondary, fontSize = 12.sp)
                        }
                        Switch(
                            checked = isUsbMounted,
                            onCheckedChange = { onToggleUsbMount() },
                            colors = SwitchDefaults.colors(
                                checkedThumbColor = Color.Black,
                                checkedTrackColor = NvidiaGreen,
                                uncheckedThumbColor = TextMuted,
                                uncheckedTrackColor = CarbonSurfaceVariant
                            )
                        )
                    }
                }
            }
        }

        item {
            Text(
                text = "DR. I30LTZ GRUB Recovery & HID Keyboard",
                color = TextPrimary,
                fontSize = 18.sp,
                fontWeight = FontWeight.Bold,
                modifier = Modifier.padding(top = 16.dp)
            )
            Spacer(modifier = Modifier.height(4.dp))
            Text(
                text = "Phone acts as USB Keyboard. Review AI command before injecting.",
                color = TextSecondary,
                fontSize = 12.sp
            )
        }

        // AI Mode Toggle
        item {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(8.dp))
                    .background(CarbonSurfaceVariant)
                    .padding(12.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Default.CloudOff, contentDescription = "Offline Mode", tint = if (isOfflineAi) NvidiaGreen else TextMuted, modifier = Modifier.size(20.dp))
                    Spacer(modifier = Modifier.width(8.dp))
                    Text("DR. I30LTZ Offline Nano-Model", color = TextPrimary, fontSize = 14.sp)
                }
                Switch(
                    checked = isOfflineAi,
                    onCheckedChange = { onToggleAiMode() },
                    colors = SwitchDefaults.colors(
                        checkedThumbColor = Color.Black,
                        checkedTrackColor = NvidiaGreen,
                        uncheckedThumbColor = TextMuted,
                        uncheckedTrackColor = CarbonSurface
                    )
                )
            }
        }

        // GRUB Keyboard
        item {
            Card(
                colors = CardDefaults.cardColors(containerColor = CarbonSurface),
                shape = RoundedCornerShape(16.dp),
                modifier = Modifier
                    .fillMaxWidth()
                    .border(1.dp, CarbonBorder, RoundedCornerShape(16.dp))
            ) {
                Column(modifier = Modifier.padding(16.dp)) {
                    OutlinedTextField(
                        value = grubIssue,
                        onValueChange = { grubIssue = it },
                        modifier = Modifier.fillMaxWidth(),
                        placeholder = { Text("e.g., Bootmgr missing, how to chainload Windows?", color = TextMuted) },
                        colors = OutlinedTextFieldDefaults.colors(
                            focusedBorderColor = NvidiaGreen,
                            unfocusedBorderColor = CarbonBorder,
                            focusedTextColor = TextPrimary,
                            unfocusedTextColor = TextPrimary,
                            cursorColor = NvidiaGreen
                        ),
                        singleLine = true
                    )
                    Spacer(modifier = Modifier.height(12.dp))
                    Button(
                        onClick = { onAskGrubHelp(grubIssue) },
                        modifier = Modifier.fillMaxWidth(),
                        colors = ButtonDefaults.buttonColors(containerColor = CarbonSurfaceVariant, contentColor = NvidiaGreen),
                        shape = RoundedCornerShape(8.dp)
                    ) {
                        Icon(Icons.Default.Psychology, contentDescription = null, modifier = Modifier.size(16.dp))
                        Spacer(modifier = Modifier.width(8.dp))
                        Text("Ask DR. I30LTZ for GRUB Command")
                    }

                    if (grubCommandProposal.isNotBlank()) {
                        Spacer(modifier = Modifier.height(16.dp))
                        Text("AI Recommended Command:", color = TextSecondary, fontSize = 12.sp)
                        Box(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clip(RoundedCornerShape(8.dp))
                                .background(Color.Black)
                                .border(1.dp, CarbonBorder, RoundedCornerShape(8.dp))
                                .padding(12.dp)
                        ) {
                            Text(grubCommandProposal, color = NvidiaGreen, fontSize = 13.sp, fontFamily = androidx.compose.ui.text.font.FontFamily.Monospace)
                        }

                        Spacer(modifier = Modifier.height(16.dp))
                        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            Button(
                                onClick = { onSendHidCommand(grubCommandProposal) },
                                modifier = Modifier.weight(1f),
                                colors = ButtonDefaults.buttonColors(containerColor = NvidiaGreen, contentColor = Color.Black),
                                shape = RoundedCornerShape(8.dp)
                            ) {
                                Icon(Icons.Default.Keyboard, contentDescription = null, modifier = Modifier.size(16.dp))
                                Spacer(modifier = Modifier.width(8.dp))
                                Text("Type via USB")
                            }

                            Button(
                                onClick = { onSendHidEnter() },
                                modifier = Modifier.weight(1f),
                                colors = ButtonDefaults.buttonColors(containerColor = ElectricRed, contentColor = Color.White),
                                shape = RoundedCornerShape(8.dp)
                            ) {
                                Icon(Icons.Default.KeyboardReturn, contentDescription = null, modifier = Modifier.size(16.dp))
                                Spacer(modifier = Modifier.width(8.dp))
                                Text("Send ENTER")
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun IsoRow(name: String, details: String, onDownload: (String) -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(8.dp))
            .background(CarbonSurfaceVariant.copy(alpha = 0.5f))
            .border(1.dp, CarbonBorder, RoundedCornerShape(8.dp))
            .clickable { onDownload(name) }
            .padding(12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(Icons.Default.Save, contentDescription = null, tint = NvidiaGreen, modifier = Modifier.size(24.dp))
        Spacer(modifier = Modifier.width(12.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(name, color = TextPrimary, fontWeight = FontWeight.Bold, fontSize = 14.sp)
            Text(details, color = TextSecondary, fontSize = 12.sp)
        }
        Icon(Icons.Default.Download, contentDescription = null, tint = TextPrimary, modifier = Modifier.size(20.dp))
    }
}
