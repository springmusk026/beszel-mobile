/// Design tokens for animation durations used throughout the Beszel application.
/// Provides consistent timing values for animations and transitions.
abstract class AppDurations {
  /// Instant duration: 100ms - for micro-interactions like button taps
  static const Duration instant = Duration(milliseconds: 100);

  /// Fast duration: 150ms - for quick feedback animations
  static const Duration fast = Duration(milliseconds: 150);

  /// Normal duration: 200ms - for standard transitions
  static const Duration normal = Duration(milliseconds: 200);

  /// Medium duration: 300ms - for page transitions forward
  static const Duration medium = Duration(milliseconds: 300);

  /// Slow duration: 400ms - for complex animations
  static const Duration slow = Duration(milliseconds: 400);

  /// Chart duration: 600ms - for chart drawing animations
  static const Duration chart = Duration(milliseconds: 600);

  /// Metric gauge duration: 500ms - for progress value animations
  static const Duration metricGauge = Duration(milliseconds: 500);

  /// Reverse transition duration: 250ms - for backward navigation
  static const Duration reverseTransition = Duration(milliseconds: 250);

  /// Tab cross-fade duration: 200ms - for tab switching
  static const Duration tabCrossFade = Duration(milliseconds: 200);

  /// Stagger delay: 50ms - delay between staggered list items
  static const Duration staggerDelay = Duration(milliseconds: 50);

  /// Theme switch duration: 300ms - for theme transition animation
  static const Duration themeSwitch = Duration(milliseconds: 300);

  /// Shimmer cycle duration: 1500ms - for skeleton loader shimmer
  static const Duration shimmerCycle = Duration(milliseconds: 1500);

  /// Alert pulse duration: 2000ms - for alert state pulsing
  static const Duration alertPulse = Duration(milliseconds: 2000);
}
