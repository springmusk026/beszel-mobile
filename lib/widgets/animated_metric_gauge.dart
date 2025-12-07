import 'package:flutter/material.dart';
import '../animations/app_curves.dart';
import '../animations/app_durations.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';

/// An animated metric gauge widget that displays progress with smooth transitions.
/// Supports customizable color, label, and icon.
class AnimatedMetricGauge extends StatefulWidget {
  /// The current value (0-100).
  final double value;

  /// The color of the progress indicator.
  final Color color;

  /// The label text displayed next to the icon.
  final String label;

  /// The icon displayed before the label.
  final IconData icon;

  /// Optional suffix for the value display (e.g., '%', 'GB').
  final String valueSuffix;

  /// The height of the progress bar.
  final double barHeight;

  /// Whether to show the icon.
  final bool showIcon;

  /// Creates an animated metric gauge.
  const AnimatedMetricGauge({
    super.key,
    required this.value,
    required this.color,
    required this.label,
    required this.icon,
    this.valueSuffix = '%',
    this.barHeight = 6,
    this.showIcon = true,
  });

  @override
  State<AnimatedMetricGauge> createState() => _AnimatedMetricGaugeState();
}

class _AnimatedMetricGaugeState extends State<AnimatedMetricGauge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _progressAnimation;
  double _previousValue = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppDurations.metricGauge, // 500ms
    );

    _progressAnimation = Tween<double>(
      begin: 0,
      end: widget.value.clamp(0, 100),
    ).animate(
      CurvedAnimation(parent: _controller, curve: AppCurves.standard),
    );

    _controller.forward();
  }

  @override
  void didUpdateWidget(AnimatedMetricGauge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _previousValue = _progressAnimation.value;
      _progressAnimation = Tween<double>(
        begin: _previousValue,
        end: widget.value.clamp(0, 100),
      ).animate(
        CurvedAnimation(parent: _controller, curve: AppCurves.standard),
      );
      _controller.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _progressAnimation,
      builder: (context, child) {
        return _buildGauge(_progressAnimation.value);
      },
    );
  }

  Widget _buildGauge(double value) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            if (widget.showIcon) ...[
              Icon(widget.icon, color: widget.color, size: 16),
              SizedBox(width: AppSpacing.sm),
            ],
            Text(
              widget.label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            Text(
              '${value.toStringAsFixed(1)}${widget.valueSuffix}',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
        SizedBox(height: AppSpacing.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.small),
          child: LinearProgressIndicator(
            value: value / 100,
            backgroundColor: widget.color.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation(widget.color),
            minHeight: widget.barHeight,
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

/// A compact version of the animated metric gauge without label row.
class AnimatedMetricBar extends StatefulWidget {
  /// The current value (0-100).
  final double value;

  /// The color of the progress indicator.
  final Color color;

  /// The height of the progress bar.
  final double barHeight;

  /// Creates a compact animated metric bar.
  const AnimatedMetricBar({
    super.key,
    required this.value,
    required this.color,
    this.barHeight = 4,
  });

  @override
  State<AnimatedMetricBar> createState() => _AnimatedMetricBarState();
}

class _AnimatedMetricBarState extends State<AnimatedMetricBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _progressAnimation;
  double _previousValue = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppDurations.metricGauge,
    );

    _progressAnimation = Tween<double>(
      begin: 0,
      end: widget.value.clamp(0, 100),
    ).animate(
      CurvedAnimation(parent: _controller, curve: AppCurves.standard),
    );

    _controller.forward();
  }

  @override
  void didUpdateWidget(AnimatedMetricBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _previousValue = _progressAnimation.value;
      _progressAnimation = Tween<double>(
        begin: _previousValue,
        end: widget.value.clamp(0, 100),
      ).animate(
        CurvedAnimation(parent: _controller, curve: AppCurves.standard),
      );
      _controller.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _progressAnimation,
      builder: (context, child) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.small),
          child: LinearProgressIndicator(
            value: _progressAnimation.value / 100,
            backgroundColor: widget.color.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation(widget.color),
            minHeight: widget.barHeight,
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
