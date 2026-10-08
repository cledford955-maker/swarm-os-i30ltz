package com.swarm.lucille.ui.screens

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.widget.Toast
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ContentCopy
import androidx.compose.material.icons.filled.Info
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.swarm.lucille.ui.theme.*

data class CheatCommand(
    val title: String,
    val description: String,
    val command: String,
    val category: String = "EMERGENCY"
)

val emergencyCommands = listOf(
    CheatCommand("Inspect disks", "Read-only. Identify disks, UUIDs and filesystems before any installer or repair operation.", "lsblk -o NAME,SIZE,MODEL,FSTYPE,UUID,MOUNTPOINTS", "RECOVERY"),
    CheatCommand("Inspect mounted filesystems", "Read-only. Confirm which filesystem and subvolume are actually mounted.", "findmnt -o TARGET,SOURCE,FSTYPE,OPTIONS", "RECOVERY"),
    CheatCommand("Check boot mode", "Read-only. EFI firmware exposes this directory; its absence indicates legacy boot.", "test -d /sys/firmware/efi && echo UEFI || echo Legacy", "RECOVERY"),
    CheatCommand("Recent boot errors", "Read-only. Review logs before changing services or filesystems.", "journalctl -b -p err --no-pager", "RECOVERY"),
    CheatCommand("SWARM desktop logs", "Read-only. Run on the SWARM system being diagnosed.", "journalctl -b -u swarm-ui -u lucy-server --no-pager -n 100", "RECOVERY"),
    CheatCommand("SWARM installer help", "Read usage on the mounted development drive. Installation must target a disk chosen by the owner after backup.", "bash /mnt/Lucy/30-source/install_swarm_os.sh --help", "INSTALLATION"),
    CheatCommand("List canonical ISO releases", "Read-only. Ventoy must be mounted. Stable labels are set explicitly by the owner.", "python3 /mnt/Lucy/70-scripts/swarm_iso_manager.py list", "INSTALLATION"),
    CheatCommand("Check network addresses", "Read-only. Use a trusted private connection and configured credentials for remote access.", "ip -br address", "NETWORK"),
    CheatCommand("ADB device authorization", "Read-only. A device must report device, not unauthorized or offline, before installing an APK.", "adb devices -l", "ANDROID"),
    CheatCommand("Build Android debug APK", "Runs project Gradle code on a computer with Java and Android SDK. Use trusted source only.", "./gradlew assembleDebug", "ANDROID")
)

@Composable
fun CheatSheetScreen(
    onNavigateBack: () -> Unit = {}
) {
    val context = LocalContext.current
    var selectedCategory by androidx.compose.runtime.remember { androidx.compose.runtime.mutableStateOf("ALL") }

    fun copyToClipboard(text: String) {
        val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        val clip = ClipData.newPlainText("Command", text)
        clipboard.setPrimaryClip(clip)
        Toast.makeText(context, "Command copied: $text", Toast.LENGTH_SHORT).show()
    }

    val categories = listOf("ALL", "INSTALLATION", "BLUETOOTH & SSH", "SERVICES", "STORAGE & BOOT")
    val filteredCommands = if (selectedCategory == "ALL") {
        emergencyCommands
    } else {
        emergencyCommands.filter { it.category == selectedCategory }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
            .padding(16.dp)
    ) {
        // Header
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                imageVector = Icons.Default.Info,
                contentDescription = null,
                tint = NvidiaGreen,
                modifier = Modifier.size(24.dp)
            )
            Spacer(modifier = Modifier.width(8.dp))
            Column {
                Text(
                    text = "I30LTZ RECOVERY REFERENCE",
                    color = NvidiaGreen,
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Bold,
                    fontFamily = FontFamily.Monospace
                )
                Text(
                    text = "Read-only diagnosis and explicit build commands",
                    color = TextMuted,
                    fontSize = 10.sp
                )
            }
        }

        Spacer(modifier = Modifier.height(6.dp))

        // Category Filter Chips
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(vertical = 4.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            categories.forEach { cat ->
                val isSelected = selectedCategory == cat
                Surface(
                    color = if (isSelected) NvidiaGreen.copy(alpha = 0.2f) else CarbonSurface,
                    shape = RoundedCornerShape(8.dp),
                    border = androidx.compose.foundation.BorderStroke(
                        1.dp,
                        if (isSelected) NvidiaGreen else CarbonBorder
                    ),
                    modifier = Modifier.clickable { selectedCategory = cat }
                ) {
                    Text(
                        text = cat,
                        color = if (isSelected) NvidiaGreen else TextMuted,
                        fontSize = 10.sp,
                        fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal,
                        fontFamily = FontFamily.Monospace,
                        modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp)
                    )
                }
            }
        }

        Spacer(modifier = Modifier.height(10.dp))

        // List of Commands
        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            items(filteredCommands) { cmd ->
                CommandCard(cmd, onCopy = { copyToClipboard(cmd.command) })
            }
            item {
                Spacer(modifier = Modifier.height(80.dp)) // padding for bottom nav
            }
        }
    }
}

@Composable
fun CommandCard(cmd: CheatCommand, onCopy: () -> Unit) {
    Surface(
        color = CarbonSurface,
        shape = RoundedCornerShape(12.dp),
        border = androidx.compose.foundation.BorderStroke(1.dp, CarbonBorder),
        modifier = Modifier.fillMaxWidth()
    ) {
        Column(
            modifier = Modifier.padding(12.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = cmd.title,
                    color = LightningYellow,
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Bold
                )
                Surface(
                    color = Color.Black.copy(alpha = 0.5f),
                    shape = RoundedCornerShape(4.dp),
                    border = androidx.compose.foundation.BorderStroke(0.5.dp, CarbonBorder)
                ) {
                    Text(
                        text = cmd.category,
                        color = TextMuted,
                        fontSize = 9.sp,
                        fontFamily = FontFamily.Monospace,
                        modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp)
                    )
                }
            }
            Spacer(modifier = Modifier.height(4.dp))
            Text(
                text = cmd.description,
                color = TextPrimary,
                fontSize = 11.sp,
                lineHeight = 16.sp
            )
            Spacer(modifier = Modifier.height(8.dp))
            
            // Command snippet row
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(8.dp))
                    .background(Color(0xFF0A0C10))
                    .border(1.dp, NvidiaGreen.copy(alpha = 0.3f), RoundedCornerShape(8.dp))
                    .clickable { onCopy() }
                    .padding(8.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "$ ${cmd.command}",
                    color = NvidiaGreen,
                    fontFamily = FontFamily.Monospace,
                    fontSize = 12.sp,
                    modifier = Modifier.weight(1f)
                )
                Icon(
                    imageVector = Icons.Default.ContentCopy,
                    contentDescription = "Copy",
                    tint = TextMuted,
                    modifier = Modifier.size(16.dp)
                )
            }
        }
    }
}
