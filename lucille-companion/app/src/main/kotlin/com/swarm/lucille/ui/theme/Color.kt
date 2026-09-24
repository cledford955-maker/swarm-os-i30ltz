// Color.kt — SWARM OS dark purple-lightning palette  v1.0.0  2026-09-24
package com.swarm.lucille.ui.theme

import androidx.compose.ui.graphics.Color

// ── SWARM OS Brand Colors ────────────────────────────────────────────────────
val SwarmBg         = Color(0xFF0A0010)   // near-black deep purple
val SwarmSurface    = Color(0xFF100820)   // slightly lighter surface
val SwarmSurface2   = Color(0xFF1A0E2E)   // card background
val SwarmBorder     = Color(0xFF2A1550)   // subtle card border

val SwarmPurple     = Color(0xFF7C3AED)   // primary purple
val SwarmPurpleLight= Color(0xFFA855F7)   // lighter violet
val SwarmCyan       = Color(0xFF00D8FF)   // electric cyan accent
val SwarmCyanDim    = Color(0xFF0096B3)   // dimmer cyan for secondary

val SwarmGold       = Color(0xFFFFB800)   // warning / achievement gold
val SwarmRed        = Color(0xFFFF4757)   // critical / error red
val SwarmGreen      = Color(0xFF2ED573)   // success / online green
val SwarmOrange     = Color(0xFFFF6B35)   // medium severity warning

// ── Text ─────────────────────────────────────────────────────────────────────
val TextPrimary     = Color(0xFFF0E8FF)   // primary text — warm white
val TextSecondary   = Color(0xFFBBA8D8)   // secondary text — muted lavender
val TextDisabled    = Color(0xFF5C4D7A)   // disabled / hint text

// ── Status colors ─────────────────────────────────────────────────────────────
val StatusCritical  = SwarmRed
val StatusWarn      = SwarmOrange
val StatusInfo      = SwarmCyan
val StatusOk        = SwarmGreen

// ── Gradient helpers (used in header cards) ───────────────────────────────────
val GradientPurpleCyan   = listOf(SwarmPurple, SwarmCyan)
val GradientPurpleViolet = listOf(Color(0xFF4B0082), SwarmPurple)
val GradientDarkPurple   = listOf(SwarmBg, SwarmSurface2)
