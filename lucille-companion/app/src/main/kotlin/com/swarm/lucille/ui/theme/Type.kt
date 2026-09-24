// Type.kt — SWARM OS typography  v1.0.0  2026-09-24
package com.swarm.lucille.ui.theme

import androidx.compose.material3.Typography
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp

// Use system default (Roboto on Android) — no custom font downloads needed.
// Override with a mono font for telemetry / code sections.
val SwarmTypography = Typography(
    // Large display — splash, brief headline
    displayLarge  = TextStyle(fontFamily = FontFamily.Default, fontWeight = FontWeight.Black,  fontSize = 32.sp, lineHeight = 38.sp, letterSpacing = (-0.5).sp, color = TextPrimary),
    displayMedium = TextStyle(fontFamily = FontFamily.Default, fontWeight = FontWeight.Bold,   fontSize = 24.sp, lineHeight = 30.sp, letterSpacing = 0.sp,      color = TextPrimary),
    displaySmall  = TextStyle(fontFamily = FontFamily.Default, fontWeight = FontWeight.Bold,   fontSize = 20.sp, lineHeight = 26.sp, letterSpacing = 0.sp,      color = TextPrimary),

    // Headlines — card titles
    headlineLarge  = TextStyle(fontFamily = FontFamily.Default, fontWeight = FontWeight.SemiBold, fontSize = 18.sp, lineHeight = 24.sp, color = TextPrimary),
    headlineMedium = TextStyle(fontFamily = FontFamily.Default, fontWeight = FontWeight.SemiBold, fontSize = 16.sp, lineHeight = 22.sp, color = TextPrimary),
    headlineSmall  = TextStyle(fontFamily = FontFamily.Default, fontWeight = FontWeight.Medium,   fontSize = 14.sp, lineHeight = 20.sp, color = TextPrimary),

    // Body — regular content
    bodyLarge  = TextStyle(fontFamily = FontFamily.Default, fontWeight = FontWeight.Normal, fontSize = 15.sp, lineHeight = 22.sp, color = TextPrimary),
    bodyMedium = TextStyle(fontFamily = FontFamily.Default, fontWeight = FontWeight.Normal, fontSize = 13.sp, lineHeight = 19.sp, color = TextSecondary),
    bodySmall  = TextStyle(fontFamily = FontFamily.Default, fontWeight = FontWeight.Normal, fontSize = 11.sp, lineHeight = 16.sp, color = TextSecondary),

    // Labels — badges, timestamps, captions
    labelLarge  = TextStyle(fontFamily = FontFamily.Monospace, fontWeight = FontWeight.Medium, fontSize = 12.sp, letterSpacing = 0.5.sp, color = SwarmCyan),
    labelMedium = TextStyle(fontFamily = FontFamily.Monospace, fontWeight = FontWeight.Normal, fontSize = 11.sp, letterSpacing = 0.5.sp, color = TextSecondary),
    labelSmall  = TextStyle(fontFamily = FontFamily.Monospace, fontWeight = FontWeight.Normal, fontSize = 9.sp,  letterSpacing = 0.5.sp, color = TextDisabled),

    // Title — section headers inside screens
    titleLarge  = TextStyle(fontFamily = FontFamily.Default, fontWeight = FontWeight.Bold,   fontSize = 20.sp, lineHeight = 26.sp, color = TextPrimary),
    titleMedium = TextStyle(fontFamily = FontFamily.Default, fontWeight = FontWeight.SemiBold, fontSize = 16.sp, lineHeight = 22.sp, color = TextPrimary),
    titleSmall  = TextStyle(fontFamily = FontFamily.Default, fontWeight = FontWeight.Medium, fontSize = 13.sp, lineHeight = 18.sp, color = TextSecondary),
)
