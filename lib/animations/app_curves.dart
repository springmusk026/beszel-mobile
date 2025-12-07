import 'package:flutter/material.dart';

/// Design tokens for animation curves used throughout the Beszel application.
/// Provides consistent easing curves for smooth, professional animations.
abstract class AppCurves {
  /// Standard curve: easeInOutCubic - for general purpose animations
  static const Curve standard = Curves.easeInOutCubic;

  /// Enter curve: easeOutCubic - for elements entering the screen
  static const Curve enter = Curves.easeOutCubic;

  /// Exit curve: easeInCubic - for elements leaving the screen
  static const Curve exit = Curves.easeInCubic;

  /// Bounce curve: elasticOut - for playful, attention-grabbing animations
  static const Curve bounce = Curves.elasticOut;

  /// Decelerate curve: decelerate - for elements coming to rest
  static const Curve decelerate = Curves.decelerate;

  /// Accelerate curve: easeIn - for elements starting motion
  static const Curve accelerate = Curves.easeIn;

  /// Linear curve: linear - for constant-rate animations like shimmer
  static const Curve linear = Curves.linear;

  /// Ease in out sine: easeInOutSine - for smooth shimmer effects
  static const Curve shimmer = Curves.easeInOutSine;

  /// Fast out slow in: fastOutSlowIn - Material Design standard
  static const Curve materialStandard = Curves.fastOutSlowIn;

  /// Ease out back: easeOutBack - for subtle overshoot effect
  static const Curve overshoot = Curves.easeOutBack;
}
