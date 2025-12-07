import 'package:flutter/material.dart';
import '../animations/app_curves.dart';
import '../animations/app_durations.dart';
import '../theme/app_spacing.dart';

/// An animated card widget with tap feedback.
/// Provides scale-down and elevation change animations on tap.
class AnimatedCard extends StatefulWidget {
  /// The child widget to display inside the card.
  final Widget child;

  /// Callback when the card is tapped.
  final VoidCallback? onTap;

  /// Callback when the card is long-pressed.
  final VoidCallback? onLongPress;

  /// Padding inside the card.
  final EdgeInsets? padding;

  /// The card's elevation when not pressed.
  final double elevation;

  /// The card's elevation when pressed.
  final double pressedElevation;

  /// The card's background color.
  final Color? color;

  /// The card's border radius.
  final BorderRadius? borderRadius;

  /// Creates an animated card with tap feedback.
  const AnimatedCard({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.padding,
    this.elevation = 1.0,
    this.pressedElevation = 4.0,
    this.color,
    this.borderRadius,
  });

  @override
  State<AnimatedCard> createState() => _AnimatedCardState();
}

class _AnimatedCardState extends State<AnimatedCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _elevationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppDurations.fast, // 150ms
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _controller, curve: AppCurves.standard),
    );

    _elevationAnimation = Tween<double>(
      begin: widget.elevation,
      end: widget.pressedElevation,
    ).animate(
      CurvedAnimation(parent: _controller, curve: AppCurves.standard),
    );
  }

  @override
  void didUpdateWidget(AnimatedCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.elevation != widget.elevation ||
        oldWidget.pressedElevation != widget.pressedElevation) {
      _elevationAnimation = Tween<double>(
        begin: widget.elevation,
        end: widget.pressedElevation,
      ).animate(
        CurvedAnimation(parent: _controller, curve: AppCurves.standard),
      );
    }
  }

  void _handleTapDown(TapDownDetails details) {
    _controller.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    _controller.reverse();
  }

  void _handleTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Card(
              elevation: _elevationAnimation.value,
              color: widget.color,
              shape: widget.borderRadius != null
                  ? RoundedRectangleBorder(borderRadius: widget.borderRadius!)
                  : null,
              child: Padding(
                padding: widget.padding ?? EdgeInsets.all(AppSpacing.lg),
                child: widget.child,
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
