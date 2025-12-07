import 'package:flutter/material.dart';
import 'app_curves.dart';
import 'app_durations.dart';

/// A mixin that provides staggered animation capabilities for list items.
/// 
/// Use this mixin on StatefulWidgets that need to animate multiple items
/// in sequence with a configurable delay between each item.
/// 
/// Example usage:
/// ```dart
/// class MyListScreen extends StatefulWidget {
///   @override
///   State<MyListScreen> createState() => _MyListScreenState();
/// }
/// 
/// class _MyListScreenState extends State<MyListScreen>
///     with TickerProviderStateMixin, StaggeredAnimationMixin {
///   @override
///   void initState() {
///     super.initState();
///     initStaggeredAnimation(itemCount: 10);
///     playStaggeredAnimation();
///   }
///   
///   @override
///   Widget build(BuildContext context) {
///     return ListView.builder(
///       itemCount: 10,
///       itemBuilder: (context, index) {
///         return buildStaggeredItem(
///           index: index,
///           child: ListTile(title: Text('Item $index')),
///         );
///       },
///     );
///   }
/// }
/// ```
mixin StaggeredAnimationMixin<T extends StatefulWidget> on State<T>, TickerProviderStateMixin<T> {
  AnimationController? _staggerController;
  final List<Animation<double>> _itemAnimations = [];
  bool _isStaggerInitialized = false;

  /// Initializes the staggered animation system.
  /// 
  /// [itemCount] - The number of items to animate
  /// [staggerDelay] - The delay between each item's animation start (default: 50ms)
  /// [itemDuration] - The duration of each item's animation (default: 300ms)
  void initStaggeredAnimation({
    required int itemCount,
    Duration staggerDelay = AppDurations.staggerDelay,
    Duration itemDuration = AppDurations.medium,
  }) {
    if (_isStaggerInitialized) {
      _disposeStaggerAnimation();
    }

    if (itemCount <= 0) return;

    final totalDuration = Duration(
      milliseconds: itemDuration.inMilliseconds + 
          ((itemCount - 1) * staggerDelay.inMilliseconds),
    );

    _staggerController = AnimationController(
      vsync: this,
      duration: totalDuration,
    );

    _itemAnimations.clear();

    for (var i = 0; i < itemCount; i++) {
      final startTime = i * staggerDelay.inMilliseconds;
      final endTime = startTime + itemDuration.inMilliseconds;
      
      final startInterval = startTime / totalDuration.inMilliseconds;
      final endInterval = (endTime / totalDuration.inMilliseconds).clamp(0.0, 1.0);

      _itemAnimations.add(
        Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(
            parent: _staggerController!,
            curve: Interval(
              startInterval,
              endInterval,
              curve: AppCurves.enter,
            ),
          ),
        ),
      );
    }

    _isStaggerInitialized = true;
  }

  /// Gets the animation for a specific item index.
  /// Returns a completed animation if index is out of bounds.
  Animation<double> getItemAnimation(int index) {
    if (index < 0 || index >= _itemAnimations.length) {
      return const AlwaysStoppedAnimation(1.0);
    }
    return _itemAnimations[index];
  }

  /// Plays the staggered animation from the beginning.
  void playStaggeredAnimation() {
    _staggerController?.forward(from: 0);
  }

  /// Resets the staggered animation to the beginning.
  void resetStaggeredAnimation() {
    _staggerController?.reset();
  }

  /// Reverses the staggered animation.
  void reverseStaggeredAnimation() {
    _staggerController?.reverse();
  }

  /// Builds a widget with staggered fade and slide-up animation.
  /// 
  /// [index] - The index of the item in the list
  /// [child] - The widget to animate
  /// [slideOffset] - The vertical offset to slide from (default: 20.0)
  Widget buildStaggeredItem({
    required int index,
    required Widget child,
    double slideOffset = 20.0,
  }) {
    final animation = getItemAnimation(index);
    
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        return Opacity(
          opacity: animation.value,
          child: Transform.translate(
            offset: Offset(0, slideOffset * (1 - animation.value)),
            child: child,
          ),
        );
      },
    );
  }

  /// Builds a widget with staggered fade-only animation.
  /// 
  /// [index] - The index of the item in the list
  /// [child] - The widget to animate
  Widget buildStaggeredFadeItem({
    required int index,
    required Widget child,
  }) {
    final animation = getItemAnimation(index);
    
    return FadeTransition(
      opacity: animation,
      child: child,
    );
  }

  /// Builds a widget with staggered scale animation.
  /// 
  /// [index] - The index of the item in the list
  /// [child] - The widget to animate
  /// [beginScale] - The starting scale (default: 0.8)
  Widget buildStaggeredScaleItem({
    required int index,
    required Widget child,
    double beginScale = 0.8,
  }) {
    final animation = getItemAnimation(index);
    
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final scale = beginScale + (1 - beginScale) * animation.value;
        return Opacity(
          opacity: animation.value,
          child: Transform.scale(
            scale: scale,
            child: child,
          ),
        );
      },
    );
  }

  void _disposeStaggerAnimation() {
    _staggerController?.dispose();
    _staggerController = null;
    _itemAnimations.clear();
    _isStaggerInitialized = false;
  }

  @override
  void dispose() {
    _disposeStaggerAnimation();
    super.dispose();
  }
}
