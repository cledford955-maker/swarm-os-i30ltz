// Theme.kt — Sakura Cyberpunk / Lucille Signature design tokens  v2.0.0 · 2026
package os.swarm.lucille.ui

import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp

// — Palette (Sakura Cyberpunk / Lucille Signature) —
val SakuraPink  = Color(0xFFFF2E88)
val SakuraGlow  = Color(0xFFFF66B2)
val SakuraSoft  = Color(0xFFFF99CC)
val VoidDeep    = Color(0xFF0F050C)
val Void2       = Color(0xFF1A0A17)
val VoidPanel   = Color(0xE01F0A1B)
val Plasma      = Color(0xFFFF2E88)
val PlasmaHi    = Color(0xFFFF66B2)
val Arc         = Color(0xFFFF99CC)
val Filament    = Color(0xFFFFE6F2)
val Smoke       = Color(0xFFD9A3C7)
val SmokeDim    = Color(0xFF804D70)
val PanelFill   = Color(0xE01F0A1B)   // 88 % opacity cyberpunk panel
val Ok          = Color(0xFF32D998)
val Warn        = Color(0xFFFFC04D)
val Crit        = Color(0xFFFF3355)

val darkScheme = darkColorScheme(
    primary          = SakuraPink,
    onPrimary        = Filament,
    secondary        = SakuraGlow,
    onSecondary      = VoidDeep,
    background       = VoidDeep,
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
