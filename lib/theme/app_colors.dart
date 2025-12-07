import 'package:flutter/material.dart';

/// Design tokens for colors used throughout the Beszel application.
/// Provides consistent color palettes for light and dark themes,
/// as well as semantic status colors.
abstract class AppColors {
  // Light theme colors
  static const Color primaryLight = Color(0xFF1A56DB);
  static const Color secondaryLight = Color(0xFF6366F1);
  static const Color surfaceLight = Color(0xFFFAFAFA);
  static const Color backgroundLight = Color(0xFFFFFFFF);
  static const Color onPrimaryLight = Color(0xFFFFFFFF);
  static const Color onSecondaryLight = Color(0xFFFFFFFF);
  static const Color onSurfaceLight = Color(0xFF1F2937);
  static const Color onBackgroundLight = Color(0xFF1F2937);
  static const Color surfaceVariantLight = Color(0xFFF3F4F6);
  static const Color outlineLight = Color(0xFFE5E7EB);

  // Dark theme colors
  static const Color primaryDark = Color(0xFF3B82F6);
  static const Color secondaryDark = Color(0xFF818CF8);
  static const Color surfaceDark = Color(0xFF1E1E1E);
  static const Color backgroundDark = Color(0xFF121212);
  static const Color onPrimaryDark = Color(0xFFFFFFFF);
  static const Color onSecondaryDark = Color(0xFFFFFFFF);
  static const Color onSurfaceDark = Color(0xFFF9FAFB);
  static const Color onBackgroundDark = Color(0xFFF9FAFB);
  static const Color surfaceVariantDark = Color(0xFF2D2D2D);
  static const Color outlineDark = Color(0xFF404040);

  // Status colors (shared between themes)
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color inactive = Color(0xFF9CA3AF);

  // Status colors with opacity variants
  static const Color successLight = Color(0xFFDCFCE7);
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color errorLight = Color(0xFFFEE2E2);
  static const Color inactiveLight = Color(0xFFF3F4F6);

  /// Returns the appropriate ColorScheme for light theme
  static ColorScheme get lightColorScheme => const ColorScheme.light(
        primary: primaryLight,
        secondary: secondaryLight,
        surface: surfaceLight,
        error: error,
        onPrimary: onPrimaryLight,
        onSecondary: onSecondaryLight,
        onSurface: onSurfaceLight,
        onError: Color(0xFFFFFFFF),
        surfaceContainerHighest: surfaceVariantLight,
        outline: outlineLight,
      );

  /// Returns the appropriate ColorScheme for dark theme
  static ColorScheme get darkColorScheme => const ColorScheme.dark(
        primary: primaryDark,
        secondary: secondaryDark,
        surface: surfaceDark,
        error: error,
        onPrimary: onPrimaryDark,
        onSecondary: onSecondaryDark,
        onSurface: onSurfaceDark,
        onError: Color(0xFFFFFFFF),
        surfaceContainerHighest: surfaceVariantDark,
        outline: outlineDark,
      );

  /// Maps system status to appropriate color
  static Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'up':
      case 'healthy':
      case 'online':
        return success;
      case 'down':
      case 'critical':
      case 'offline':
        return error;
      case 'paused':
      case 'warning':
        return warning;
      case 'pending':
      case 'inactive':
      default:
        return inactive;
    }
  }
}
