package com.example.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

private val DarkColorScheme = darkColorScheme(
    primary = NvidiaGreen,
    onPrimary = Color.Black,
    primaryContainer = SwarmGreen,
    onPrimaryContainer = Color.Black,
    secondary = NvidiaGreen,
    onSecondary = Color.Black,
    secondaryContainer = SwarmGreen,
    onSecondaryContainer = Color.Black,
    tertiary = LightningYellow,
    onTertiary = Color.Black,
    background = CarbonBackground,
    onBackground = TextPrimary,
    surface = CarbonSurface,
    onSurface = TextPrimary,
    surfaceVariant = CarbonSurfaceVariant,
    onSurfaceVariant = TextSecondary,
    outline = CarbonBorder
)

@Composable
fun MyApplicationTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    dynamicColor: Boolean = false,
    content: @Composable () -> Unit
) {
    MaterialTheme(
        colorScheme = DarkColorScheme,
        typography = Typography,
        content = content
    )
}
