package com.example.ui.screens

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
import com.example.ui.theme.*

data class CheatCommand(
    val title: String,
    val description: String,
    val command: String,
    val category: String = "EMERGENCY"
)

val emergencyCommands = listOf(
    // --- LIVE BOOT & INSTALLATION ---
    CheatCommand(
        "Live ISO Login (Ventoy / Native)",
        "Login as root with blank password (just press Enter when prompted).",
        "root",
        "INSTALLATION"
    ),
    CheatCommand(
        "Run SWARM OS Full Installer",
        "Executes the automated LUKS2 encrypted btrfs installer script.",
        "cd /run/media/i30ltz/lucy-master/Luccile-v+ && sudo ./install_swarm_os.sh",
        "INSTALLATION"
    ),
    CheatCommand(
        "Mount Installer Drive (Ventoy)",
        "Mount your USB storage if booted into live ISO before running installer.",
        "sudo mkdir -p /mnt/repo && sudo mount /dev/sdX1 /mnt/repo",
        "INSTALLATION"
    ),
    CheatCommand(
        "Create LUKS2 Encrypted Partition",
        "Format NVMe partition with AES-XTS-512 LUKS2 encryption container.",
        "sudo cryptsetup luksFormat --type luks2 /dev/nvme0n1p2",
        "INSTALLATION"
    ),
    CheatCommand(
        "Open LUKS Container",
        "Unlock and map the encrypted partition to /dev/mapper/swarm-root.",
        "sudo cryptsetup open /dev/nvme0n1p2 swarm-root",
        "INSTALLATION"
    ),
    CheatCommand(
        "Format & Mount Btrfs Root",
        "Create btrfs filesystem and mount to /mnt/swarm_os.",
        "sudo mkfs.btrfs -f /dev/mapper/swarm-root && sudo mount /dev/mapper/swarm-root /mnt/swarm_os",
        "INSTALLATION"
    ),
    CheatCommand(
        "Set Passwords Before Reboot",
        "Enter chroot to set root and i30ltz user passwords before first boot.",
        "sudo arch-chroot /mnt/swarm_os passwd && sudo arch-chroot /mnt/swarm_os passwd i30ltz",
        "INSTALLATION"
    ),
    CheatCommand(
        "Unmount & Safe Reboot",
        "Cleanly sync, unmount, close LUKS2 container, and reboot into SWARM OS.",
        "sudo umount -R /mnt/swarm_os && sudo cryptsetup close swarm-root && sudo reboot",
        "INSTALLATION"
    ),

    // --- SYSTEM SERVICES & UI RECOVERY ---
    CheatCommand(
        "Check UI Status",
        "See why the Flutter UI might have crashed or stopped working.",
        "systemctl status swarm-ui",
        "SERVICES"
    ),
    CheatCommand(
        "View UI Logs",
        "See the full crash log for the Swarm OS GUI.",
        "journalctl -u swarm-ui -e",
        "SERVICES"
    ),
    CheatCommand(
        "Restart UI",
        "Force restart the Flutter cage UI if it's stuck on a black screen.",
        "sudo systemctl restart swarm-ui",
        "SERVICES"
    ),
    CheatCommand(
        "Check Backend Status",
        "Check if the LucyServer .NET backend is running.",
        "systemctl status lucy-server",
        "SERVICES"
    ),
    CheatCommand(
        "View Backend Logs",
        "View errors from the LucyServer backend.",
        "journalctl -u lucy-server -e",
        "SERVICES"
    ),
    CheatCommand(
        "Restart Backend",
        "Force restart the backend if it stops responding.",
        "sudo systemctl restart lucy-server",
        "SERVICES"
    ),
    CheatCommand(
        "Run UI Manually (Cage Kiosk)",
        "Run the UI directly from a root prompt to watch its output in real-time.",
        "cage -d /opt/swarm_os/swarm_flutter",
        "SERVICES"
    ),

    // --- STORAGE & BOOTLOADER REPAIR ---
    CheatCommand(
        "Check Storage Drives & UUIDs",
        "List all block devices and UUIDs to verify root & EFI partitions.",
        "lsblk -f",
        "STORAGE & BOOT"
    ),
    CheatCommand(
        "Mount Existing LUKS System",
        "Rescue mount an existing SWARM OS install into /mnt/swarm_os.",
        "sudo cryptsetup open /dev/nvme0n1p2 swarm-root && sudo mount /dev/mapper/swarm-root /mnt/swarm_os",
        "STORAGE & BOOT"
    ),
    CheatCommand(
        "Fix Corrupted File System",
        "Run filesystem check if dropped to initramfs recovery prompt.",
        "fsck /dev/mapper/swarm-root",
        "STORAGE & BOOT"
    ),
    // --- BLUETOOTH & REMOTE ACCESS ---
    CheatCommand(
        "Start Bluetooth Service",
        "Starts bluez daemon in live ISO or installed OS.",
        "sudo systemctl start bluetooth",
        "BLUETOOTH & SSH"
    ),
    CheatCommand(
        "Launch Bluetooth Interactive Tool",
        "Opens bluetoothctl to scan and pair wireless keyboards.",
        "bluetoothctl",
        "BLUETOOTH & SSH"
    ),
    CheatCommand(
        "Scan for Bluetooth Keyboard",
        "Turn on controller power, agent, and start scanning for keyboard MAC.",
        "power on && agent on && default-agent && scan on",
        "BLUETOOTH & SSH"
    ),
    CheatCommand(
        "Pair, Trust & Connect Keyboard",
        "Pair and trust keyboard MAC so it auto-reconnects on every boot.",
        "pair XX:XX:XX:XX:XX:XX && trust XX:XX:XX:XX:XX:XX && connect XX:XX:XX:XX:XX:XX",
        "BLUETOOTH & SSH"
    ),
    CheatCommand(
        "Start SSH Server (Phone Control)",
        "Start SSH daemon so you can control and install from your phone without keyboard.",
        "sudo systemctl start sshd",
        "BLUETOOTH & SSH"
    ),
    CheatCommand(
        "Find PC IP Address",
        "Show local IP address assigned to PC on Wi-Fi/Ethernet.",
        "ip -br a",
        "BLUETOOTH & SSH"
    ),
    CheatCommand(
        "Connect from Phone via SSH",
        "SSH into PC from phone terminal (Termux / ConnectBot) with blank password.",
        "ssh root@<PC_IP_ADDRESS>",
        "BLUETOOTH & SSH"
    )
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
                    text = "SWARM OS & EMERGENCY CHEAT SHEET",
                    color = NvidiaGreen,
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Bold,
                    fontFamily = FontFamily.Monospace
                )
                Text(
                    text = "Live install, Ventoy login, LUKS2, and system recovery commands",
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
