// Theme.kt — SWARM OS Material3 dark theme  v1.0.0  2026-09-24
package com.swarm.lucille.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

private val SwarmDarkColors = darkColorScheme(
    primary          = SwarmPurple,
    onPrimary        = TextPrimary,
    primaryContainer = Color(0xFF3B1A6E),
    onPrimaryContainer = TextPrimary,

    secondary        = SwarmCyan,
    onSecondary      = Color(0xFF001F26),
    secondaryContainer = Color(0xFF003544),
    onSecondaryContainer = SwarmCyan,

    tertiary         = SwarmPurpleLight,
    onTertiary       = Color(0xFF1F0044),

    background       = SwarmBg,
    onBackground     = TextPrimary,

    surface          = SwarmSurface,
    onSurface        = TextPrimary,
    surfaceVariant   = SwarmSurface2,
    onSurfaceVariant = TextSecondary,

    outline          = SwarmBorder,
    outlineVariant   = Color(0xFF1E0E38),

    error            = SwarmRed,
    onError          = Color(0xFF2D0010),
    errorContainer   = Color(0xFF500020),
    onErrorContainer = SwarmRed,

    inverseSurface   = TextPrimary,
    inverseOnSurface = SwarmBg,
    inversePrimary   = SwarmPurple,

    scrim            = Color(0xAA000000),
    surfaceTint      = SwarmPurple,
)

@Composable
fun LucilleTheme(
    darkTheme: Boolean = true, // SWARM OS is always dark
    content: @Composable () -> Unit
) {
    MaterialTheme(
        colorScheme = SwarmDarkColors,
        typography  = SwarmTypography,
        content     = content
    )
}
