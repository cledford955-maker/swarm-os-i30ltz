import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'swarm_colors.dart';

/// SWARM OS Typography System
/// Uses Geist (sans) and JetBrains Mono (code) — matching the Next.js version
class SwarmTextStyles {
  SwarmTextStyles._();

  // ─── Display (hero / splash) ────────────────────────────────
  static TextStyle displayLarge = GoogleFonts.inter(
    fontSize: 48,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.2,
    height: 1.1,
    color: SwarmColors.textPrimary,
  );

  static TextStyle displayMedium = GoogleFonts.inter(
    fontSize: 36,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.8,
    height: 1.15,
    color: SwarmColors.textPrimary,
  );

  // ─── Heading ───────────────────────────────────────────────
  static TextStyle h1 = GoogleFonts.inter(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    height: 1.2,
    color: SwarmColors.textPrimary,
  );

  static TextStyle h2 = GoogleFonts.inter(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
    height: 1.25,
    color: SwarmColors.textPrimary,
  );

  static TextStyle title = h2;

  static TextStyle h3 = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    height: 1.3,
    color: SwarmColors.textPrimary,
  );

  // ─── Body ──────────────────────────────────────────────────
  static TextStyle body = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: SwarmColors.textPrimary,
  );

  static TextStyle headlineMedium = h1;
  static TextStyle bodyMedium = body;

  static TextStyle bodySmall = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: SwarmColors.textSecondary,
  );

  // ─── Labels / UI ───────────────────────────────────────────
  static TextStyle label = GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.8,
    height: 1.2,
    color: SwarmColors.textMuted,
  );

  static TextStyle labelSmall = GoogleFonts.inter(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.6,
    height: 1.2,
    color: SwarmColors.textMuted,
  );

  static TextStyle stat = GoogleFonts.inter(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    height: 1.1,
    color: SwarmColors.accent,
  );

  // ─── Code / Mono ───────────────────────────────────────────
  static TextStyle code = GoogleFonts.jetBrainsMono(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.6,
    color: SwarmColors.textPrimary,
  );

  static TextStyle codeSmall = GoogleFonts.jetBrainsMono(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: SwarmColors.textSecondary,
  );

  static TextStyle terminal = GoogleFonts.jetBrainsMono(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.7,
    color: SwarmColors.accent,
  );
}
