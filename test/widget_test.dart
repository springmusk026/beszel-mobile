// Basic Flutter widget tests for Beszel app
//
// Tests for design system foundation components

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Beszel/theme/app_colors.dart';
import 'package:Beszel/theme/app_typography.dart';
import 'package:Beszel/theme/app_spacing.dart';
import 'package:Beszel/theme/app_radius.dart';
import 'package:Beszel/animations/app_durations.dart';
import 'package:Beszel/animations/app_curves.dart';

void main() {
  group('Design System Foundation Tests', () {
    group('AppColors', () {
      test('light theme colors are defined', () {
        expect(AppColors.primaryLight, isA<Color>());
        expect(AppColors.secondaryLight, isA<Color>());
        expect(AppColors.surfaceLight, isA<Color>());
        expect(AppColors.backgroundLight, isA<Color>());
      });

      test('dark theme colors are defined', () {
        expect(AppColors.primaryDark, isA<Color>());
        expect(AppColors.secondaryDark, isA<Color>());
        expect(AppColors.surfaceDark, isA<Color>());
        expect(AppColors.backgroundDark, isA<Color>());
      });

      test('status colors are defined', () {
        expect(AppColors.success, isA<Color>());
        expect(AppColors.warning, isA<Color>());
        expect(AppColors.error, isA<Color>());
        expect(AppColors.inactive, isA<Color>());
      });
    });

    group('AppTypography', () {
      test('typography styles are defined', () {
        expect(AppTypography.headlineLarge, isA<TextStyle>());
        expect(AppTypography.headlineMedium, isA<TextStyle>());
        expect(AppTypography.titleLarge, isA<TextStyle>());
        expect(AppTypography.titleMedium, isA<TextStyle>());
        expect(AppTypography.bodyLarge, isA<TextStyle>());
        expect(AppTypography.bodyMedium, isA<TextStyle>());
        expect(AppTypography.labelLarge, isA<TextStyle>());
        expect(AppTypography.caption, isA<TextStyle>());
      });

      test('font family is defined', () {
        expect(AppTypography.fontFamily, isA<String>());
        expect(AppTypography.fontFamily.isNotEmpty, isTrue);
      });
    });

    group('AppSpacing', () {
      test('spacing constants are defined', () {
        expect(AppSpacing.xs, isA<double>());
        expect(AppSpacing.sm, isA<double>());
        expect(AppSpacing.md, isA<double>());
        expect(AppSpacing.lg, isA<double>());
        expect(AppSpacing.xl, isA<double>());
        expect(AppSpacing.xxl, isA<double>());
      });

      test('spacing values are positive', () {
        expect(AppSpacing.xs, greaterThan(0));
        expect(AppSpacing.sm, greaterThan(0));
        expect(AppSpacing.md, greaterThan(0));
        expect(AppSpacing.lg, greaterThan(0));
        expect(AppSpacing.xl, greaterThan(0));
        expect(AppSpacing.xxl, greaterThan(0));
      });

      test('spacing values are in ascending order', () {
        expect(AppSpacing.xs, lessThan(AppSpacing.sm));
        expect(AppSpacing.sm, lessThan(AppSpacing.md));
        expect(AppSpacing.md, lessThan(AppSpacing.lg));
        expect(AppSpacing.lg, lessThan(AppSpacing.xl));
        expect(AppSpacing.xl, lessThan(AppSpacing.xxl));
      });
    });

    group('AppRadius', () {
      test('radius constants are defined', () {
        expect(AppRadius.small, isA<double>());
        expect(AppRadius.medium, isA<double>());
        expect(AppRadius.large, isA<double>());
        expect(AppRadius.extraLarge, isA<double>());
      });

      test('radius values match design spec (8, 12, 16)', () {
        expect(AppRadius.small, equals(8.0));
        expect(AppRadius.medium, equals(12.0));
        expect(AppRadius.large, equals(16.0));
      });
    });
  });

  group('Animation System Tests', () {
    group('AppDurations', () {
      test('duration constants are defined', () {
        expect(AppDurations.instant, isA<Duration>());
        expect(AppDurations.fast, isA<Duration>());
        expect(AppDurations.normal, isA<Duration>());
        expect(AppDurations.medium, isA<Duration>());
        expect(AppDurations.slow, isA<Duration>());
        expect(AppDurations.chart, isA<Duration>());
      });

      test('durations are within bounds (100ms to 600ms)', () {
        expect(AppDurations.instant.inMilliseconds, greaterThanOrEqualTo(100));
        expect(AppDurations.chart.inMilliseconds, lessThanOrEqualTo(600));
      });

      test('durations are in ascending order', () {
        expect(AppDurations.instant.inMilliseconds, lessThanOrEqualTo(AppDurations.fast.inMilliseconds));
        expect(AppDurations.fast.inMilliseconds, lessThanOrEqualTo(AppDurations.normal.inMilliseconds));
        expect(AppDurations.normal.inMilliseconds, lessThanOrEqualTo(AppDurations.medium.inMilliseconds));
        expect(AppDurations.medium.inMilliseconds, lessThanOrEqualTo(AppDurations.slow.inMilliseconds));
        expect(AppDurations.slow.inMilliseconds, lessThanOrEqualTo(AppDurations.chart.inMilliseconds));
      });
    });

    group('AppCurves', () {
      test('curve constants are defined', () {
        expect(AppCurves.standard, isA<Curve>());
        expect(AppCurves.enter, isA<Curve>());
        expect(AppCurves.exit, isA<Curve>());
        expect(AppCurves.bounce, isA<Curve>());
      });
    });
  });
}
