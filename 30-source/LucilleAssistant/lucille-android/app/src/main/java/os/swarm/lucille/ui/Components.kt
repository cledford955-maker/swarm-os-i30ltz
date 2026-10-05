// Components.kt — shared UI primitives with Sakura Cyberpunk theme  v2.0.0 · 2026
package os.swarm.lucille.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/** Glowing Sakura frosted panel card */
@Composable
fun SwarmCard(
    modifier: Modifier = Modifier,
    content: @Composable ColumnScope.() -> Unit
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(PanelFill)
            .border(1.dp, SakuraPink.copy(alpha = 0.45f), RoundedCornerShape(16.dp))
            .padding(16.dp),
        content = content
    )
}

/** Status badge: OK / WARN / CRIT */
@Composable
fun StatusDot(ok: Boolean, warn: Boolean = false) {
    val color = when { !ok && !warn -> Crit; warn -> Warn; else -> Ok }
    Box(
        Modifier
            .size(8.dp)
            .clip(RoundedCornerShape(50))
            .background(color)
    )
}

/** Section label */
@Composable
fun SectionLabel(text: String) {
    Text(
        text      = text.uppercase(),
        fontSize  = 10.sp,
        color     = SakuraSoft,
        fontWeight = FontWeight.Bold,
        letterSpacing = 1.5.sp,
        modifier  = Modifier.padding(bottom = 6.dp)
    )
}

/** Mono value chip */
@Composable
fun MonoChip(text: String, color: Color = SakuraGlow) {
    Box(
        Modifier
            .clip(RoundedCornerShape(6.dp))
            .background(color.copy(alpha = 0.15f))
            .border(1.dp, color.copy(alpha = 0.35f), RoundedCornerShape(6.dp))
            .padding(horizontal = 8.dp, vertical = 4.dp)
    ) {
        Text(text, fontFamily = FontFamily.Monospace, fontSize = 12.sp, color = color)
    }
}

/** Pulsing load spinner */
@Composable
fun LoadingPane(label: String = "Loading…") {
    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(12.dp)) {
            CircularProgressIndicator(color = SakuraPink, strokeWidth = 2.dp, modifier = Modifier.size(32.dp))
            Text(label, color = Smoke, fontSize = 13.sp)
        }
    }
}

/** Error pane with retry */
@Composable
fun ErrorPane(msg: String, onRetry: () -> Unit) {
    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(16.dp),
            modifier = Modifier.padding(24.dp)
        ) {
            Text("🌸", fontSize = 32.sp)
            Text(msg, color = Smoke, fontSize = 13.sp, textAlign = androidx.compose.ui.text.style.TextAlign.Center)
            Button(
                onClick = onRetry,
                colors  = ButtonDefaults.buttonColors(containerColor = SakuraPink)
            ) { Text("Retry", color = Filament) }
        }
    }
}

/** Plasma action button */
@Composable
fun PlasmaButton(label: String, modifier: Modifier = Modifier, onClick: () -> Unit) {
    Button(
        onClick = onClick,
        modifier = modifier,
        colors   = ButtonDefaults.buttonColors(containerColor = SakuraPink),
        shape    = RoundedCornerShape(10.dp)
    ) { Text(label, color = Filament, fontWeight = FontWeight.SemiBold) }
}

/** Gradient header bar */
@Composable
fun GradientHeader(title: String, subtitle: String = "") {
    Box(
        Modifier
            .fillMaxWidth()
            .background(
                Brush.horizontalGradient(listOf(SakuraPink.copy(alpha = 0.25f), Color.Transparent))
            )
            .border(
                width = 1.dp,
                brush = Brush.horizontalGradient(listOf(SakuraPink.copy(alpha = 0.6f), Color.Transparent)),
                shape = RoundedCornerShape(topStart = 16.dp, topEnd = 16.dp)
            )
            .padding(horizontal = 16.dp, vertical = 12.dp)
    ) {
        Column {
            Text(title, style = MaterialTheme.typography.titleLarge, color = Filament)
            if (subtitle.isNotBlank()) Text(subtitle, style = MaterialTheme.typography.bodySmall)
        }
    }
}

/** Divider in SWARM Sakura style */
@Composable
fun SwarmDivider() =
    HorizontalDivider(color = SakuraPink.copy(alpha = 0.25f), thickness = 1.dp, modifier = Modifier.padding(vertical = 8.dp))
