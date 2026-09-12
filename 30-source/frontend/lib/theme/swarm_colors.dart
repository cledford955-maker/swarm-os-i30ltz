import 'package:flutter/material.dart';

/// SWARM OS Design Tokens
/// Ported from oklch-based CSS design system in globals.css
class SwarmColors {
  SwarmColors._();

  // ─── Core Background Palette ────────────────────────────────
  static const Color bg = Color(0xFF0D0A18);           // oklch(0.12 0.04 280)
  static const Color bgSurface = Color(0xFF150F28);     // oklch(0.15 0.05 280)
  static const Color bgElevated = Color(0xFF1A1332);    // oklch(0.17 0.06 280)
  static const Color bgPanel = Color(0xFF1F173D);       // oklch(0.19 0.07 280)
  static const Color bgHover = Color(0xFF251D47);       // oklch(0.21 0.08 280)

  // ─── Text Palette ──────────────────────────────────────────
  static const Color textPrimary = Color(0xFFE8E0F0);   // oklch(0.92 0.03 280)
  static const Color textSecondary = Color(0xFFA89CC0); // oklch(0.72 0.06 280)
  static const Color textMuted = Color(0xFF7A6E96);     // oklch(0.55 0.07 280)
  static const Color textDisabled = Color(0xFF4D4168);   // oklch(0.38 0.08 280)

  // ─── Border & Divider ──────────────────────────────────────
  static const Color border = Color(0xFF2A2245);        // oklch(0.22 0.06 280)
  static const Color borderSubtle = Color(0xFF1E1638);  // oklch(0.18 0.05 280)
  static const Color borderFocus = Color(0xFF76B900);   // NVIDIA Green

  // ─── Accent: NVIDIA Green ──────────────────────────────────
  static const Color accent = Color(0xFF76B900);         // NVIDIA Green primary
  static const Color accentDim = Color(0xFF4A7500);      // Dimmed variant
  static const Color accentGlow = Color(0x3376B900);     // 20% opacity glow
  static const Color accentSurface = Color(0x1A76B900);  // 10% for backgrounds

  // ─── Status Colors ─────────────────────────────────────────
  static const Color statusOnline = Color(0xFF22C55E);   // Green
  static const Color statusOffline = Color(0xFFEF4444);  // Red
  static const Color statusIdle = Color(0xFFF59E0B);     // Amber
  static const Color statusBusy = Color(0xFFF97316);     // Orange
  static const Color statusCritical = Color(0xFFDC2626); // Dark Red

  // ─── Agent Accent Palette ──────────────────────────────────
  static const Color lucille = Color(0xFF76B900);        // NVIDIA Green
  static const Color agentPurple = Color(0xFF8B5CF6);    // Violet
  static const Color agentCyan = Color(0xFF06B6D4);      // Cyan
  static const Color agentAmber = Color(0xFFF59E0B);     // Amber
  static const Color agentRose = Color(0xFFF43F5E);      // Rose
  static const Color agentEmerald = Color(0xFF10B981);   // Emerald
  static const Color agentSky = Color(0xFF0EA5E9);       // Sky blue
  static const Color agentIndigo = Color(0xFF6366F1);    // Indigo
  static const Color agentOrange = Color(0xFFF97316);    // Orange
  static const Color agentTeal = Color(0xFF14B8A6);      // Teal
  static const Color agentPink = Color(0xFFEC4899);      // Pink
  static const Color agentLime = Color(0xFF84CC16);      // Lime

  // ─── Overlay & Scrim ───────────────────────────────────────
  static const Color scrim = Color(0xCC0D0A18);          // 80% bg
  static const Color overlay = Color(0x800D0A18);        // 50% bg

  // ─── Aliases & Convenience Colors ──────────────────────────
  static const Color bgBase = bg;
  static const Color statusHealthy = statusOnline;
  static const Color statusWarning = statusIdle;
  static const Color accentMuted = accentDim;
  static const Color success = statusOnline;
  static const Color warning = statusIdle;
  static const Color error = statusCritical;
  static const Color accentSky = agentSky;
  static const Color accentCyan = agentCyan;
  static const Color agentGreen = agentEmerald;
}

/// Helper for rounded shape borders
OutlinedBorder RoundedCornerShape(double radius) =>
    RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));
