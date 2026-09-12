package com.example.ui.coderdroid

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.ui.theme.*
import java.io.File

@Composable
fun CdrFileTreePanel(
    workspaceRoot: File?,
    workspaceName: String,
    onFileClick: (CdrFileNode) -> Unit,
    modifier: Modifier = Modifier
) {
    var expandedPaths by remember { mutableStateOf(setOf<String>()) }

    Column(
        modifier = modifier
            .background(CarbonSurface)
            .border(1.dp, CarbonBorder)
    ) {
        // Header
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .background(CarbonSurfaceVariant)
                .padding(horizontal = 10.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                imageVector = Icons.Default.FolderOpen,
                contentDescription = null,
                tint = ElectricPurple,
                modifier = Modifier.size(13.dp)
            )
            Spacer(Modifier.width(6.dp))
            Text(
                text = workspaceName.uppercase(),
                fontSize = 10.sp,
                letterSpacing = 1.sp,
                color = TextSecondary
            )
        }

        Divider(color = CarbonBorder, thickness = 1.dp)

        if (workspaceRoot == null) {
            Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                Text("Open a folder to begin", fontSize = 11.sp, color = TextMuted)
            }
            return@Column
        }

        val nodes = remember(workspaceRoot, expandedPaths) {
            buildNodes(listOf(workspaceRoot), expandedPaths, 0)
        }

        LazyColumn(Modifier.fillMaxSize()) {
            items(nodes, key = { it.path }) { node ->
                CdrFileRow(
                    node = node,
                    isExpanded = node.path in expandedPaths,
                    onClick = {
                        if (node.isDirectory) {
                            expandedPaths = if (node.path in expandedPaths)
                                expandedPaths - node.path else expandedPaths + node.path
                        } else {
                            onFileClick(node)
                        }
                    }
                )
            }
        }
    }
}

@Composable
private fun CdrFileRow(node: CdrFileNode, isExpanded: Boolean, onClick: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(26.dp)
            .clickable { onClick() }
            .padding(start = (node.depth * 14 + 6).dp, end = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        if (node.isDirectory) {
            Icon(
                imageVector = if (isExpanded) Icons.Default.ExpandMore else Icons.Default.ChevronRight,
                contentDescription = null,
                tint = TextMuted,
                modifier = Modifier.size(13.dp)
            )
        } else {
            Spacer(Modifier.width(13.dp))
        }

        Icon(
            imageVector = if (node.isDirectory) Icons.Default.Folder else Icons.Default.InsertDriveFile,
            contentDescription = null,
            tint = if (node.isDirectory) ElectricPurple else when (node.extension) {
                "kt", "kts" -> ElectricCyan
                "java"      -> NvidiaGreen
                "xml"       -> LightningYellow
                "json"      -> NeonGreen
                else        -> TextSecondary
            },
            modifier = Modifier.size(13.dp)
        )

        Text(
            text = node.name,
            fontSize = 12.sp,
            color = TextPrimary,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis
        )
    }
}

private fun buildNodes(files: List<File>, expanded: Set<String>, depth: Int): List<CdrFileNode> {
    val result = mutableListOf<CdrFileNode>()
    files.sortedWith(compareBy({ !it.isDirectory }, { it.name.lowercase() })).forEach { f ->
        result.add(CdrFileNode(f, depth))
        if (f.isDirectory && f.absolutePath in expanded) {
            result.addAll(buildNodes(f.listFiles()?.toList() ?: emptyList(), expanded, depth + 1))
        }
    }
    return result
}
