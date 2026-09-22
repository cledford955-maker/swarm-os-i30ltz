package com.example.ui.screens

import android.net.Uri
import android.provider.DocumentsContract
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

@Composable
fun OsDeploymentScreen(
    isoDownloadProgress: Float, isUsbMounted: Boolean, grubCommandProposal: String, isOfflineAi: Boolean,
    onDownloadIso: (String) -> Unit, onToggleUsbMount: () -> Unit, onAskGrubHelp: (String) -> Unit,
    onSendHidCommand: (String) -> Unit, onSendHidEnter: () -> Unit, onToggleAiMode: () -> Unit
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var issue by remember { mutableStateOf("") }
    var selected by remember { mutableStateOf<List<Uri>>(emptyList()) }
    var report by remember { mutableStateOf("Choose accessible files, then a separate destination such as a USB OTG drive. Originals are never deleted.") }
    var busy by remember { mutableStateOf(false) }
    val files = rememberLauncherForActivityResult(ActivityResultContracts.OpenMultipleDocuments()) { selected = it }
    val destination = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocumentTree()) { tree ->
        if(tree != null && selected.isNotEmpty()) {
            busy = true
            val sources = selected.toList()
            scope.launch {
                report = withContext(Dispatchers.IO) {
                    var completed = 0; var bytes = 0L
                    val errors = mutableListOf<String>()
                    val resolver = context.contentResolver
                    val parent = DocumentsContract.buildDocumentUriUsingTree(tree, DocumentsContract.getTreeDocumentId(tree))
                    for(source in sources) {
                        var target: Uri? = null
                        var name = "recovered-file"
                        try {
                            resolver.query(source, arrayOf(android.provider.OpenableColumns.DISPLAY_NAME), null, null, null)?.use { c -> if(c.moveToFirst()) name = c.getString(0) }
                            // Unique destination avoids overwriting an existing backup or source.
                            val backupName = "${java.util.UUID.randomUUID().toString().take(8)}-$name"
                            target = checkNotNull(DocumentsContract.createDocument(resolver, parent, resolver.getType(source) ?: "application/octet-stream", backupName)) { "Destination refused file creation" }
                            val expected = java.security.MessageDigest.getInstance("SHA-256")
                            var copied = 0L
                            checkNotNull(resolver.openInputStream(source)).use { input ->
                                checkNotNull(resolver.openOutputStream(target, "w")).use { output ->
                                    val buffer = ByteArray(65536)
                                    while(true) { val n = input.read(buffer); if(n < 0) break; output.write(buffer,0,n); expected.update(buffer,0,n); copied += n }
                                }
                            }
                            val actual = java.security.MessageDigest.getInstance("SHA-256")
                            checkNotNull(resolver.openInputStream(target)).use { input -> val buffer=ByteArray(65536); while(true) { val n=input.read(buffer);if(n<0)break;actual.update(buffer,0,n) } }
                            check(expected.digest().contentEquals(actual.digest())) { "Destination verification failed" }
                            completed++; bytes += copied
                        } catch(e: Exception) {
                            target?.let { runCatching { DocumentsContract.deleteDocument(resolver,it) } }
                            errors.add("$name: ${e.message}")
                        }
                    }
                    "Copied and SHA-256 verified $completed/${sources.size} files ($bytes bytes). Originals preserved." + if(errors.isEmpty()) "" else "\nFailed:\n" + errors.joinToString("\n")
                }
                busy = false
            }
        }
    }
    Column(Modifier.fillMaxSize().padding(16.dp).verticalScroll(rememberScrollState()), verticalArrangement=Arrangement.spacedBy(14.dp)) {
        Text("I30LTZ Recovery OS tools", style=MaterialTheme.typography.headlineSmall)
        Text("Install and repair the PC through Remote PC / Terminal while I30LTZ Recovery OS is running. Check the target disk and keep backups before using installer or repair commands.")
        Text("SWARM release ISOs live only at /mnt/ventoy/ISO/SWARM_OS/ on the paired computer: ten rolling builds, plus releases you explicitly mark Stable. Use that computer's Manage SWARM ISOs desktop shortcut. This phone does not download duplicate releases.")
        HorizontalDivider()
        Text("Rescue accessible files", style=MaterialTheme.typography.titleMedium)
        Text("Copy readable files from phone storage or a connected USB drive to a separate backup. This does not recover deleted sectors or bypass Android encryption. Deleted-file and damaged-disk recovery runs in I30LTZ Recovery OS on the PC.")
        Button(onClick={files.launch(arrayOf("*/*"))},enabled=!busy) { Text("Choose files (${selected.size})") }
        Button(onClick={destination.launch(null)},enabled=selected.isNotEmpty() && !busy) { Text("Choose backup destination & copy") }
        if(busy) LinearProgressIndicator(Modifier.fillMaxWidth())
        SelectionContainer { Text(report) }
        HorizontalDivider()
        Text("GRUB help", style=MaterialTheme.typography.titleMedium)
        Text("Describe the actual error, boot mode and disks. AI suggestions require review and are never executed automatically. USB keyboard injection and phone-as-boot-drive emulation are unavailable in this app.")
        OutlinedTextField(issue,{issue=it},label={Text("Boot error and system details")},modifier=Modifier.fillMaxWidth())
        Button(onClick={onAskGrubHelp(issue)},enabled=issue.isNotBlank()){Text("Ask I30LTZ")}
        if(grubCommandProposal.isNotBlank()) {
            SelectionContainer { Text(grubCommandProposal) }
            OutlinedButton(onClick={onSendHidCommand(grubCommandProposal)}){Text("Copy suggested command")}
        }
        Text("Offline AI is not installed. Saved reference material remains available under Cheat Sheet.")
    }
}
