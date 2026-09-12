package com.example.ui.coderdroid

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.ui.theme.*

@Composable
fun CdrTabBar(
    tabs: List<CdrEditorTab>,
    activeTabId: String?,
    onTabClick: (String) -> Unit,
    onTabClose: (String) -> Unit,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .height(38.dp)
            .background(CarbonSurface)
            .border(1.dp, CarbonBorder)
            .horizontalScroll(rememberScrollState()),
        verticalAlignment = Alignment.CenterVertically
    ) {
        if (tabs.isEmpty()) {
            Text(
                text = "No files open",
                modifier = Modifier.padding(horizontal = 16.dp),
                color = TextMuted,
                fontSize = 11.sp
            )
        }
        tabs.forEach { tab ->
            CdrTabItem(
                tab = tab,
                isActive = tab.id == activeTabId,
                onClick = { onTabClick(tab.id) },
                onClose = { onTabClose(tab.id) }
            )
        }
    }
}

@Composable
private fun CdrTabItem(
    tab: CdrEditorTab,
    isActive: Boolean,
    onClick: () -> Unit,
    onClose: () -> Unit
) {
    val bg     = if (isActive) CarbonBackground else CarbonSurface
    val border = if (isActive) ElectricPurple else Color.Transparent
    val text   = if (isActive) TextPrimary else TextMuted

    Row(
        modifier = Modifier
            .height(38.dp)
            .clip(RoundedCornerShape(topStart = 6.dp, topEnd = 6.dp))
            .background(bg)
            .border(1.dp, border, RoundedCornerShape(topStart = 6.dp, topEnd = 6.dp))
            .clickable { onClick() }
            .padding(horizontal = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp)
    ) {
        Text(
            text = tab.title,
            color = text,
            fontSize = 11.sp,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis
        )
        Icon(
            imageVector = Icons.Default.Close,
            contentDescription = "Close",
            tint = text.copy(alpha = 0.5f),
            modifier = Modifier.size(12.dp).clickable { onClose() }
        )
    }
}
