import 'package:flutter/material.dart';
import 'swarm_colors.dart';
import 'swarm_text_styles.dart';

/// Master SWARM OS ThemeData
/// Matches the oklch dark purple nightsky + NVIDIA green accent design
class SwarmTheme {
  SwarmTheme._();

  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: SwarmColors.bg,
      canvasColor: SwarmColors.bg,
      
      colorScheme: const ColorScheme.dark(
        surface: SwarmColors.bgSurface,
        primary: SwarmColors.accent,
        onPrimary: Color(0xFF0D0A18),
        secondary: SwarmColors.agentPurple,
        onSecondary: SwarmColors.textPrimary,
        error: SwarmColors.statusCritical,
        onError: SwarmColors.textPrimary,
        onSurface: SwarmColors.textPrimary,
        outline: SwarmColors.border,
        outlineVariant: SwarmColors.borderSubtle,
        surfaceContainerHighest: SwarmColors.bgPanel,
        surfaceContainerHigh: SwarmColors.bgElevated,
        surfaceContainer: SwarmColors.bgSurface,
        surfaceContainerLow: SwarmColors.bg,
      ),

      // ─── AppBar ────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: SwarmColors.bgSurface,
        foregroundColor: SwarmColors.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: SwarmTextStyles.h2,
      ),

      // ─── Card ──────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: SwarmColors.bgElevated,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: SwarmColors.border, width: 1),
        ),
      ),

      // ─── Elevated Button ───────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: SwarmColors.accent,
          foregroundColor: SwarmColors.bg,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: SwarmTextStyles.label.copyWith(
            color: SwarmColors.bg,
            letterSpacing: 1.0,
          ),
        ),
      ),

      // ─── Outlined Button ───────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: SwarmColors.textPrimary,
          side: const BorderSide(color: SwarmColors.border),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),

      // ─── Text Button ───────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: SwarmColors.accent,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      ),

      // ─── Icon ──────────────────────────────────────────────
      iconTheme: const IconThemeData(
        color: SwarmColors.textSecondary,
        size: 20,
      ),

      // ─── Input / TextField ─────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: SwarmColors.bgSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: SwarmColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: SwarmColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: SwarmColors.accent, width: 1.5),
        ),
        hintStyle: SwarmTextStyles.body.copyWith(color: SwarmColors.textDisabled),
        labelStyle: SwarmTextStyles.label,
      ),

      // ─── Divider ───────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color: SwarmColors.border,
        thickness: 1,
        space: 0,
      ),

      // ─── Tooltip ───────────────────────────────────────────
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: SwarmColors.bgPanel,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: SwarmColors.border),
        ),
        textStyle: SwarmTextStyles.bodySmall,
      ),

      // ─── Scrollbar ─────────────────────────────────────────
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(SwarmColors.border),
        thickness: WidgetStateProperty.all(4),
        radius: const Radius.circular(2),
      ),

      // ─── Dialog ────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor: SwarmColors.bgElevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: SwarmColors.border),
        ),
      ),
    );
  }
}
