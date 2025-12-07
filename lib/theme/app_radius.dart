import 'package:flutter/material.dart';

/// Design tokens for border radius used throughout the Beszel application.
/// Provides consistent border radius values for cards, buttons, inputs, etc.
abstract class AppRadius {
  /// Small radius: 8.0 - for small elements like chips, badges
  static const double small = 8.0;

  /// Medium radius: 12.0 - for cards, buttons, inputs
  static const double medium = 12.0;

  /// Large radius: 16.0 - for dialogs, bottom sheets
  static const double large = 16.0;

  /// Extra large radius: 24.0 - for special containers
  static const double extraLarge = 24.0;

  /// Circular radius for fully rounded elements
  static const double circular = 999.0;

  // Pre-built BorderRadius objects for convenience
  static BorderRadius get smallBorderRadius => BorderRadius.circular(small);
  static BorderRadius get mediumBorderRadius => BorderRadius.circular(medium);
  static BorderRadius get largeBorderRadius => BorderRadius.circular(large);
  static BorderRadius get extraLargeBorderRadius =>
      BorderRadius.circular(extraLarge);
  static BorderRadius get circularBorderRadius => BorderRadius.circular(circular);
}
