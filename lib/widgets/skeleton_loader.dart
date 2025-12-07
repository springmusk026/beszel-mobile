import 'package:flutter/material.dart';
import '../animations/app_curves.dart';
import '../animations/app_durations.dart';
import '../theme/app_radius.dart';

/// A skeleton loader widget with shimmer animation for loading states.
/// Displays a placeholder with a shimmer effect while content is loading.
class SkeletonLoader extends StatefulWidget {
  /// The width of the skeleton. Defaults to full width.
  final double width;

  /// The height of the skeleton.
  final double height;

  /// The border radius of the skeleton.
  final double borderRadius;

  /// Creates a skeleton loader with configurable dimensions.
  const SkeletonLoader({
    super.key,
    this.width = double.infinity,
    this.height = 16,
    this.borderRadius = AppRadius.small,
  });

  /// Creates a circular skeleton loader.
  const SkeletonLoader.circular({
    super.key,
    required double size,
  })  : width = size,
        height = size,
        borderRadius = AppRadius.circular;

  /// Creates a rectangular skeleton loader with medium border radius.
  const SkeletonLoader.rectangular({
    super.key,
    this.width = double.infinity,
    required this.height,
  }) : borderRadius = AppRadius.medium;

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppDurations.shimmerCycle,
    )..repeat();

    _shimmerAnimation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: AppCurves.shimmer),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final baseColor = scheme.surfaceContainerHighest;
    final highlightColor = scheme.surfaceContainerHighest.withValues(alpha: 0.5);

    return AnimatedBuilder(
      animation: _shimmerAnimation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(_shimmerAnimation.value - 1, 0),
              end: Alignment(_shimmerAnimation.value, 0),
              colors: [
                baseColor,
                highlightColor,
                baseColor,
              ],
            ),
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

/// A row of skeleton loaders for text content.
class SkeletonText extends StatelessWidget {
  /// Number of lines to display.
  final int lines;

  /// Height of each line.
  final double lineHeight;

  /// Spacing between lines.
  final double spacing;

  /// Whether the last line should be shorter.
  final bool lastLineShort;

  const SkeletonText({
    super.key,
    this.lines = 3,
    this.lineHeight = 14,
    this.spacing = 8,
    this.lastLineShort = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(lines, (index) {
        final isLast = index == lines - 1;
        return Padding(
          padding: EdgeInsets.only(bottom: isLast ? 0 : spacing),
          child: SkeletonLoader(
            height: lineHeight,
            width: isLast && lastLineShort ? 150 : double.infinity,
            borderRadius: AppRadius.small,
          ),
        );
      }),
    );
  }
}
