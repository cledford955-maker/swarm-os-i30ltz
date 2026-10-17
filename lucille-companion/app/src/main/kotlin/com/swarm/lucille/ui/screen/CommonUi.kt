// CommonUi.kt — Shared composables used across all screens  v1.0.0  2026-09-24
package com.swarm.lucille.ui.screen

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.*
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.*
import com.swarm.lucille.ui.theme.*

// ─── Layout primitives ────────────────────────────────────────────────────────

@Composable
fun SwarmCard(
    modifier: Modifier = Modifier,
    content: @Composable ColumnScope.() -> Unit
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(SwarmSurface2)
            .padding(16.dp),
        content = content
    )
}

@Composable
fun SectionHeader(text: String) {
    Text(
        text  = text,
        style = MaterialTheme.typography.labelLarge,
        color = SwarmCyan,
        modifier = Modifier.padding(top = 4.dp, bottom = 2.dp)
    )
}

@Composable
fun SwarmBadge(text: String, color: Color = SwarmPurple) {
    Box(
        modifier = Modifier
            .clip(RoundedCornerShape(6.dp))
            .background(color.copy(alpha = 0.2f))
            .padding(horizontal = 6.dp, vertical = 2.dp)
    ) {
        Text(text, style = MaterialTheme.typography.labelSmall, color = color, fontWeight = FontWeight.Bold)
    }
}

// ─── State placeholders ───────────────────────────────────────────────────────

@Composable
fun SwarmLoading(message: String = "Loading…") {
    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(12.dp)) {
            CircularProgressIndicator(color = SwarmPurple, strokeWidth = 2.dp, modifier = Modifier.size(32.dp))
            Text(message, style = MaterialTheme.typography.bodyMedium)
        }
    }
}

@Composable
fun SwarmError(message: String, onRetry: (() -> Unit)? = null) {
    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(12.dp),
            modifier = Modifier.padding(32.dp)
        ) {
            Text("⚠", fontSize = 36.sp)
            Text(message, style = MaterialTheme.typography.bodySmall, color = SwarmRed)
            onRetry?.let {
                OutlinedButton(
                    onClick = it,
                    colors = ButtonDefaults.outlinedButtonColors(contentColor = SwarmCyan)
                ) {
                    Text("RETRY")
                }
            }
        }
    }
}

@Composable
fun SwarmEmpty(message: String = "Nothing here yet", onLoad: (() -> Unit)? = null) {
    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Text("📭", fontSize = 40.sp)
            Text(message, style = MaterialTheme.typography.bodyMedium)
            onLoad?.let {
                TextButton(onClick = it) {
                    Text("LOAD", color = SwarmCyan)
                }
            }
        }
    }
}

// ─── Gauge bar widget ─────────────────────────────────────────────────────────

@Composable
fun GaugeBar(
    label:     String,
    pct:       Double,
    valueText: String = "${pct.toInt()}%",
    color:     Color  = gaugeColor(pct)
) {
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
            Text(label, style = MaterialTheme.typography.labelMedium)
            Text(valueText, style = MaterialTheme.typography.labelLarge, color = color)
        }
        LinearProgressIndicator(
            progress = { (pct.coerceIn(0.0, 100.0) / 100).toFloat() },
            modifier = Modifier.fillMaxWidth().height(6.dp).clip(RoundedCornerShape(3.dp)),
            color    = color,
            trackColor = SwarmBorder
        )
    }
}

fun gaugeColor(pct: Double): Color = when {
    pct >= 90 -> SwarmRed
    pct >= 75 -> SwarmGold
    pct >= 50 -> SwarmOrange
    else      -> SwarmGreen
}
