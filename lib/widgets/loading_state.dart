import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../animations/app_curves.dart';
import '../animations/app_durations.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// The current state of a loading operation.
enum LoadingStatus {
  /// Data is currently loading.
  loading,

  /// An error occurred during loading.
  error,

  /// Data loaded successfully.
  success,
}

/// A wrapper widget that handles loading, error, and content states
/// with smooth fade transitions.
class LoadingState extends StatelessWidget {
  /// The current loading status.
  final LoadingStatus status;

  /// The widget to display when loading.
  final Widget loadingWidget;

  /// The widget to display when content is loaded.
  final Widget contentWidget;

  /// Optional error message to display.
  final String? errorMessage;

  /// Callback when retry is pressed.
  final VoidCallback? onRetry;

  /// Duration of the fade transition between states.
  final Duration transitionDuration;

  /// Creates a loading state wrapper.
  const LoadingState({
    super.key,
    required this.status,
    required this.loadingWidget,
    required this.contentWidget,
    this.errorMessage,
    this.onRetry,
    this.transitionDuration = AppDurations.normal, // 200ms
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: transitionDuration,
      switchInCurve: AppCurves.enter,
      switchOutCurve: AppCurves.exit,
      child: _buildChild(),
    );
  }

  Widget _buildChild() {
    switch (status) {
      case LoadingStatus.loading:
        return KeyedSubtree(
          key: const ValueKey('loading'),
          child: loadingWidget,
        );
      case LoadingStatus.error:
        return KeyedSubtree(
          key: const ValueKey('error'),
          child: ErrorStateWidget(
            message: errorMessage ?? 'An error occurred',
            onRetry: onRetry,
          ),
        );
      case LoadingStatus.success:
        return KeyedSubtree(
          key: const ValueKey('content'),
          child: contentWidget,
        );
    }
  }
}

/// A widget that displays an error state with shake animation and retry button.
class ErrorStateWidget extends StatefulWidget {
  /// The error message to display.
  final String message;

  /// Callback when retry is pressed.
  final VoidCallback? onRetry;

  /// The icon to display.
  final IconData icon;

  /// Creates an error state widget.
  const ErrorStateWidget({
    super.key,
    required this.message,
    this.onRetry,
    this.icon = Icons.error_outline,
  });

  @override
  State<ErrorStateWidget> createState() => _ErrorStateWidgetState();
}

class _ErrorStateWidgetState extends State<ErrorStateWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _shakeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );

    // Play shake animation on mount
    _shakeController.forward();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: AnimatedBuilder(
          animation: _shakeAnimation,
          builder: (context, child) {
            final shake = math.sin(_shakeAnimation.value * math.pi * 4) * 8;
            return Transform.translate(
              offset: Offset(shake * (1 - _shakeAnimation.value), 0),
              child: child,
            );
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.errorLight,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  widget.icon,
                  size: 48,
                  color: AppColors.error,
                ),
              ),
              SizedBox(height: AppSpacing.lg),
              Text(
                'Something went wrong',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: AppSpacing.sm),
              Text(
                widget.message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              if (widget.onRetry != null) ...[
                SizedBox(height: AppSpacing.lg),
                FilledButton.icon(
                  onPressed: widget.onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }
}

/// A simple loading indicator with optional message.
class LoadingIndicator extends StatelessWidget {
  /// Optional message to display below the indicator.
  final String? message;

  /// The size of the progress indicator.
  final double size;

  /// Creates a loading indicator.
  const LoadingIndicator({
    super.key,
    this.message,
    this.size = 32,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: theme.colorScheme.primary,
            ),
          ),
          if (message != null) ...[
            SizedBox(height: AppSpacing.md),
            Text(
              message!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
