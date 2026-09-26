// Theme.kt — SWARM OS blue × black design tokens  v1.0.0 · 2026-09-26
package os.swarm.lucille.ui

import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp

// — Palette —
val Void      = Color(0xFF000814)
val Void2     = Color(0xFF010D24)
val Plasma    = Color(0xFF1A7FFF)
val PlasmaHi  = Color(0xFF60B8FF)
val Arc       = Color(0xFF00D4FF)
val Filament  = Color(0xFFDDF0FF)
val Smoke     = Color(0xFF7AABCC)
val SmokeDim  = Color(0xFF3D6080)
val PanelFill = Color(0xD5000814)   // 84 % opacity
val Ok        = Color(0xFF32D998)
val Warn      = Color(0xFFFFc04D)
val Crit      = Color(0xFFFF3355)

val darkScheme = darkColorScheme(
    primary          = Plasma,
    onPrimary        = Filament,
    secondary        = Arc,
    onSecondary      = Void,
    background       = Void,
    onBackground     = Filament,
    surface          = Void2,
    onSurface        = Filament,
    surfaceVariant   = PanelFill,
    onSurfaceVariant = Smoke,
    error            = Crit,
    outline          = SmokeDim,
)

val LucilleTypography = Typography(
    displayLarge  = TextStyle(fontFamily = FontFamily.Default, fontWeight = FontWeight.Bold,   fontSize = 28.sp, color = Filament),
    titleLarge    = TextStyle(fontFamily = FontFamily.Default, fontWeight = FontWeight.Bold,   fontSize = 18.sp, color = Filament),
    titleMedium   = TextStyle(fontFamily = FontFamily.Default, fontWeight = FontWeight.Medium, fontSize = 14.sp, color = Filament),
    bodyLarge     = TextStyle(fontFamily = FontFamily.Default, fontWeight = FontWeight.Normal, fontSize = 14.sp, color = Filament),
    bodySmall     = TextStyle(fontFamily = FontFamily.Default, fontWeight = FontWeight.Normal, fontSize = 11.sp, color = Smoke),
    labelSmall    = TextStyle(fontFamily = FontFamily.Default, fontWeight = FontWeight.Medium, fontSize = 10.sp, color = SmokeDim, letterSpacing = 0.1.sp),
    labelMedium   = TextStyle(fontFamily = FontFamily.Monospace, fontWeight = FontWeight.Normal, fontSize = 12.sp, color = Arc),
)

@Composable
fun LucilleTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = darkScheme,
        typography  = LucilleTypography,
        content     = content
    )
}
