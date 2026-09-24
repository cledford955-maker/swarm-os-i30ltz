// InboxScreen.kt — Unified Gmail inbox  v1.0.0  2026-09-24
package com.swarm.lucille.ui.screen

import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.*
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.*
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.swarm.lucille.data.network.MailMessage
import com.swarm.lucille.ui.theme.*
import com.swarm.lucille.ui.viewmodel.MainViewModel

@Composable
fun InboxScreen(vm: MainViewModel) {
    val state by vm.mail.collectAsStateWithLifecycle()
    var activeLabel by remember { mutableStateOf("INBOX") }
    val labels = listOf("INBOX", "UNREAD", "STARRED", "SENT")

    LaunchedEffect(activeLabel) { vm.loadMail(activeLabel) }

    Column(modifier = Modifier.fillMaxSize().background(SwarmBg)) {
        // Label filter strip
        ScrollableTabRow(
            selectedTabIndex = labels.indexOf(activeLabel).coerceAtLeast(0),
            containerColor   = SwarmSurface,
            contentColor     = SwarmCyan,
            edgePadding      = 8.dp,
            indicator = { tabs ->
                val idx = labels.indexOf(activeLabel).coerceAtLeast(0)
                TabRowDefaults.SecondaryIndicator(
                    modifier = Modifier.tabIndicatorOffset(tabs[idx]),
                    color    = SwarmCyan
                )
            }
        ) {
            labels.forEach { label ->
                Tab(
                    selected = label == activeLabel,
                    onClick  = { activeLabel = label },
                    text = {
                        Text(label, style = MaterialTheme.typography.labelLarge,
                            color = if (label == activeLabel) SwarmCyan else TextDisabled)
                    }
                )
            }
        }

        when {
            state.loading    -> SwarmLoading("Loading inbox…")
            state.error != null -> SwarmError(state.error!!) { vm.loadMail(activeLabel) }
            else -> {
                val msgs = state.data?.inbox?.messages ?: emptyList()
                if (msgs.isEmpty()) {
                    SwarmEmpty("Inbox is empty") { vm.loadMail(activeLabel) }
                } else {
                    LazyColumn(
                        contentPadding = PaddingValues(vertical = 8.dp),
                        modifier = Modifier.fillMaxSize()
                    ) {
                        item {
                            Row(
                                modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 6.dp),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Text("${msgs.size} messages", style = MaterialTheme.typography.labelMedium)
                                TextButton(onClick = { vm.loadMail(activeLabel) }) {
                                    Text("↺", color = SwarmCyan)
                                }
                            }
                        }
                        items(msgs, key = { it.id }) { msg ->
                            MailMessageRow(msg, onClick = { /* future: expand thread */ })
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun MailMessageRow(msg: MailMessage, onClick: () -> Unit) {
    val unread = msg.isUnread
    val senderInitials = msg.from
        ?.split("<")?.firstOrNull()
        ?.trim()
        ?.split(" ")
        ?.filter { it.isNotBlank() }
        ?.let { parts ->
            when {
                parts.size >= 2 -> "${parts[0].first()}${parts[1].first()}".uppercase()
                parts.isNotEmpty() -> parts[0].take(2).uppercase()
                else -> "?"
            }
        } ?: "?"

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .background(if (unread) SwarmSurface2 else SwarmBg)
            .padding(horizontal = 16.dp, vertical = 12.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        // Avatar circle
        Box(
            modifier = Modifier
                .size(42.dp)
                .clip(CircleShape)
                .background(if (unread) SwarmPurple else SwarmBorder),
            contentAlignment = Alignment.Center
        ) {
            Text(senderInitials, style = MaterialTheme.typography.labelLarge,
                color = if (unread) TextPrimary else TextSecondary)
        }

        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Text(
                    msg.from?.split("<")?.firstOrNull()?.trim() ?: "Unknown",
                    style = MaterialTheme.typography.headlineSmall,
                    fontWeight = if (unread) FontWeight.Bold else FontWeight.Normal,
                    color = if (unread) TextPrimary else TextSecondary,
                    maxLines = 1, overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.weight(1f)
                )
                Text(
                    msg.date?.take(10) ?: "",
                    style = MaterialTheme.typography.labelSmall
                )
            }
            Text(
                msg.subject ?: "(no subject)",
                style = MaterialTheme.typography.bodyMedium,
                maxLines = 1, overflow = TextOverflow.Ellipsis,
                color = if (unread) TextPrimary else TextSecondary
            )
            Text(
                msg.snippet ?: "",
                style = MaterialTheme.typography.bodySmall,
                maxLines = 1, overflow = TextOverflow.Ellipsis
            )
        }

        // Unread dot
        if (unread) {
            Box(
                modifier = Modifier
                    .size(8.dp)
                    .clip(CircleShape)
                    .background(SwarmCyan)
            )
        }
    }
    HorizontalDivider(color = SwarmBorder, thickness = 0.5.dp)
}
