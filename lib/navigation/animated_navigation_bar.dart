import 'package:flutter/material.dart';
import '../animations/app_durations.dart';
import '../animations/app_curves.dart';

/// An animated navigation bar with icon scale animations on selection.
/// Implements icon scale animation (1.0 → 1.1 → 1.0) on selection
/// with 200ms animation duration per Requirements 6.1, 6.2, 6.3.
class AnimatedNavigationBar extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<NavigationDestination> destinations;

  const AnimatedNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
  });

  @override
  State<AnimatedNavigationBar> createState() => _AnimatedNavigationBarState();
}

class _AnimatedNavigationBarState extends State<AnimatedNavigationBar>
    with TickerProviderStateMixin {
  late List<AnimationController> _iconControllers;
  late List<Animation<double>> _scaleAnimations;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    // Start animation for initially selected item
    _iconControllers[widget.selectedIndex].forward();
  }

  void _initializeAnimations() {
    _iconControllers = List.generate(
      widget.destinations.length,
      (index) => AnimationController(
        vsync: this,
        duration: AppDurations.normal, // 200ms per requirements
      ),
    );

    _scaleAnimations = _iconControllers.map((controller) {
      return TweenSequence<double>([
        TweenSequenceItem(
          tween: Tween<double>(begin: 1.0, end: 1.1)
              .chain(CurveTween(curve: AppCurves.enter)),
          weight: 50,
        ),
        TweenSequenceItem(
          tween: Tween<double>(begin: 1.1, end: 1.0)
              .chain(CurveTween(curve: AppCurves.exit)),
          weight: 50,
        ),
      ]).animate(controller);
    }).toList();
  }

  @override
  void didUpdateWidget(AnimatedNavigationBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      // Reset previous selection
      _iconControllers[oldWidget.selectedIndex].reset();
      // Animate new selection
      _iconControllers[widget.selectedIndex].forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: widget.selectedIndex,
      onDestinationSelected: widget.onDestinationSelected,
      animationDuration: AppDurations.normal, // 200ms indicator animation
      destinations: widget.destinations.asMap().entries.map((entry) {
        final index = entry.key;
        final dest = entry.value;
        final isSelected = index == widget.selectedIndex;

        return NavigationDestination(
          icon: AnimatedBuilder(
            animation: _scaleAnimations[index],
            builder: (context, child) {
              return Transform.scale(
                scale: isSelected ? _scaleAnimations[index].value : 1.0,
                child: dest.icon,
              );
            },
          ),
          selectedIcon: AnimatedBuilder(
            animation: _scaleAnimations[index],
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimations[index].value,
                child: dest.selectedIcon ?? dest.icon,
              );
            },
          ),
          label: dest.label,
        );
      }).toList(),
    );
  }

  @override
  void dispose() {
    for (final controller in _iconControllers) {
      controller.dispose();
    }
    super.dispose();
  }
}
