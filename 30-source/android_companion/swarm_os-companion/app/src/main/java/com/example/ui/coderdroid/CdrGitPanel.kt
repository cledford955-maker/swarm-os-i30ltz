package com.example.ui.coderdroid

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.ui.theme.*

/**
 * Source-control panel for CoderDroid — status/stage/commit/push/pull over
 * JGit ([CdrGitService]), scoped to whatever workspace is currently open.
 * Sits in the sidebar column, swapped in for the file tree via the Git icon
 * in [CdrTopBar].
 */
@Composable
fun CdrGitPanel(
    gitState: CdrGitState,
    hasCredentials: Boolean,
    modifier: Modifier = Modifier,
    onRefresh: () -> Unit,
    onStage: (String) -> Unit,
    onUnstage: (String) -> Unit,
    onStageAll: () -> Unit,
    onCommit: (String) -> Unit,
    onPush: () -> Unit,
    onPull: () -> Unit,
    onSaveCredentials: (username: String, token: String) -> Unit
) {
    var commitMessage by remember { mutableStateOf("") }
    var showCredentialsDialog by remember { mutableStateOf(false) }

    if (showCredentialsDialog) {
        CdrGitCredentialsDialog(
            onDismiss = { showCredentialsDialog = false },
            onSave = { u, t -> onSaveCredentials(u, t); showCredentialsDialog = false }
        )
    }

    Column(
        modifier = modifier
            .background(CarbonSurface)
            .border(1.dp, CarbonBorder)
    ) {
        // ── Header: branch + ahead/behind + actions ──────────────────────────────
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 10.dp, vertical = 6.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                Icon(Icons.Default.AccountTree, null, tint = ElectricCyan, modifier = Modifier.size(13.dp))
                Text(
                    text = if (gitState.isRepo) gitState.branch.ifBlank { "detached" } else "not a repo",
                    color = Color.White,
                    fontSize = 11.sp,
                    fontFamily = FontFamily.Monospace
                )
                if (gitState.ahead > 0) Text("↑${gitState.ahead}", color = NeonGreen, fontSize = 10.sp)
                if (gitState.behind > 0) Text("↓${gitState.behind}", color = LightningYellow, fontSize = 10.sp)
            }
            Row(horizontalArrangement = Arrangement.spacedBy(0.dp)) {
                CdrGitIconButton(Icons.Default.VpnKey, "GitHub token", if (hasCredentials) NeonGreen else TextMuted) {
                    showCredentialsDialog = true
                }
                CdrGitIconButton(Icons.Default.CloudDownload, "Pull", ElectricCyan, enabled = gitState.isRepo && !gitState.isBusy) { onPull() }
                CdrGitIconButton(Icons.Default.CloudUpload, "Push", ElectricCyan, enabled = gitState.isRepo && !gitState.isBusy) { onPush() }
                CdrGitIconButton(Icons.Default.Refresh, "Refresh", TextSecondary, enabled = !gitState.isBusy) { onRefresh() }
            }
        }

        if (gitState.isBusy) {
            LinearProgressIndicator(
                modifier = Modifier.fillMaxWidth().height(2.dp),
                color = ElectricPurple,
                trackColor = CarbonSurfaceVariant
            )
        }

        gitState.lastError?.let { err ->
            Text(
                text = "⚠ $err",
                color = Color(0xFFFF6B6B),
                fontSize = 10.sp,
                modifier = Modifier.fillMaxWidth().padding(horizontal = 10.dp, vertical = 4.dp)
            )
        }

        if (!gitState.isRepo) {
            Text(
                text = "This workspace isn't a git repository.",
                color = TextMuted,
                fontSize = 11.sp,
                modifier = Modifier.padding(12.dp)
            )
            return@Column
        }

        // ── File lists ────────────────────────────────────────────────────────────
        LazyColumn(modifier = Modifier.weight(1f).fillMaxWidth()) {
            if (gitState.staged.isNotEmpty()) {
                item { CdrGitSectionHeader("Staged (${gitState.staged.size})") }
                items(gitState.staged, key = { "staged:" + it.path }) { f ->
                    CdrGitFileRow(f, actionIcon = Icons.Default.Remove, actionTint = TextMuted) { onUnstage(f.path) }
                }
            }
            if (gitState.unstaged.isNotEmpty()) {
                item {
                    Row(
                        modifier = Modifier.fillMaxWidth().padding(start = 10.dp, end = 6.dp, top = 8.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Text("CHANGES (${gitState.unstaged.size})", color = TextMuted, fontSize = 10.sp, fontWeight = androidx.compose.ui.text.font.FontWeight.Bold)
                        Text(
                            "stage all",
                            color = ElectricCyan,
                            fontSize = 10.sp,
                            modifier = Modifier.clickable { onStageAll() }
                        )
                    }
                }
                items(gitState.unstaged, key = { "unstaged:" + it.path }) { f ->
                    CdrGitFileRow(f, actionIcon = Icons.Default.Add, actionTint = NeonGreen) { onStage(f.path) }
                }
            }
            if (!gitState.hasChanges) {
                item {
                    Text(
                        text = "Working tree clean",
                        color = TextMuted,
                        fontSize = 11.sp,
                        modifier = Modifier.padding(12.dp)
                    )
                }
            }
        }

        // ── Commit box ────────────────────────────────────────────────────────────
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .background(CarbonSurfaceVariant)
                .border(1.dp, CarbonBorder)
                .padding(8.dp)
        ) {
            BasicTextField(
                value = commitMessage,
                onValueChange = { commitMessage = it },
                textStyle = TextStyle(color = Color.White, fontSize = 11.sp),
                cursorBrush = SolidColor(ElectricCyan),
                modifier = Modifier
                    .fillMaxWidth()
                    .background(CarbonBackground, RoundedCornerShape(4.dp))
                    .padding(8.dp),
                decorationBox = { inner ->
                    if (commitMessage.isEmpty()) {
                        Text("Commit message…", color = TextMuted, fontSize = 11.sp)
                    }
                    inner()
                }
            )
            Spacer(modifier = Modifier.height(6.dp))
            Button(
                onClick = { onCommit(commitMessage); commitMessage = "" },
                enabled = gitState.staged.isNotEmpty() && commitMessage.isNotBlank() && !gitState.isBusy,
                colors = ButtonDefaults.buttonColors(containerColor = ElectricPurple),
                modifier = Modifier.fillMaxWidth().height(34.dp),
                contentPadding = PaddingValues(0.dp)
            ) {
                Text("Commit", fontSize = 12.sp)
            }
        }
    }
}

@Composable
private fun CdrGitSectionHeader(text: String) {
    Text(
        text = text,
        color = TextMuted,
        fontSize = 10.sp,
        fontWeight = androidx.compose.ui.text.font.FontWeight.Bold,
        modifier = Modifier.padding(start = 10.dp, top = 6.dp, bottom = 2.dp)
    )
}

@Composable
private fun CdrGitFileRow(
    file: CdrGitFileStatus,
    actionIcon: androidx.compose.ui.graphics.vector.ImageVector,
    actionTint: Color,
    onAction: () -> Unit
) {
    val (letter, color) = when (file.kind) {
        CdrGitFileStatus.Kind.MODIFIED    -> "M" to LightningYellow
        CdrGitFileStatus.Kind.ADDED       -> "A" to NeonGreen
        CdrGitFileStatus.Kind.DELETED     -> "D" to Color(0xFFFF6B6B)
        CdrGitFileStatus.Kind.MISSING     -> "D" to Color(0xFFFF6B6B)
        CdrGitFileStatus.Kind.UNTRACKED   -> "U" to ElectricCyan
        CdrGitFileStatus.Kind.CONFLICTING -> "!" to Color(0xFFFF6B6B)
        CdrGitFileStatus.Kind.RENAMED     -> "R" to ElectricCyan
    }
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(start = 10.dp, end = 4.dp, top = 2.dp, bottom = 2.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp), modifier = Modifier.weight(1f)) {
            Text(letter, color = color, fontSize = 11.sp, fontFamily = FontFamily.Monospace, fontWeight = androidx.compose.ui.text.font.FontWeight.Bold)
            Text(
                text = file.path,
                color = TextSecondary,
                fontSize = 11.sp,
                fontFamily = FontFamily.Monospace,
                maxLines = 1
            )
        }
        IconButton(onClick = onAction, modifier = Modifier.size(24.dp)) {
            Icon(actionIcon, null, tint = actionTint, modifier = Modifier.size(14.dp))
        }
    }
}

@Composable
private fun CdrGitIconButton(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    desc: String,
    tint: Color,
    enabled: Boolean = true,
    onClick: () -> Unit
) {
    IconButton(onClick = onClick, enabled = enabled, modifier = Modifier.size(28.dp)) {
        Icon(icon, desc, tint = if (enabled) tint else TextMuted.copy(alpha = 0.4f), modifier = Modifier.size(15.dp))
    }
}

@Composable
private fun CdrGitCredentialsDialog(
    onDismiss: () -> Unit,
    onSave: (username: String, token: String) -> Unit
) {
    var username by remember { mutableStateOf("") }
    var token by remember { mutableStateOf("") }

    AlertDialog(
        onDismissRequest = onDismiss,
        containerColor = CarbonSurface,
        title = { Text("GitHub credentials", color = Color.White, fontSize = 14.sp) },
        text = {
            Column {
                Text(
                    "Used only for push/pull on this device. Stored encrypted (Android Keystore). Needs a personal access token with 'repo' scope.",
                    color = TextMuted,
                    fontSize = 11.sp
                )
                Spacer(modifier = Modifier.height(10.dp))
                OutlinedTextField(
                    value = username,
                    onValueChange = { username = it },
                    label = { Text("Username") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth()
                )
                Spacer(modifier = Modifier.height(8.dp))
                OutlinedTextField(
                    value = token,
                    onValueChange = { token = it },
                    label = { Text("Personal access token") },
                    singleLine = true,
                    visualTransformation = androidx.compose.ui.text.input.PasswordVisualTransformation(),
                    modifier = Modifier.fillMaxWidth()
                )
            }
        },
        confirmButton = {
            TextButton(onClick = { onSave(username, token) }, enabled = token.isNotBlank()) {
                Text("Save", color = ElectricCyan)
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text("Cancel", color = TextMuted) }
        }
    )
}
