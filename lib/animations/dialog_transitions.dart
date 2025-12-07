import 'package:flutter/material.dart';
import 'app_curves.dart';
import 'app_durations.dart';

/// Custom dialog transition with scale-and-fade animation.
/// Provides a professional, polished appearance for dialogs.
///
/// Usage:
/// ```dart
/// showAnimatedDialog(
///   context: context,
///   builder: (context) => AlertDialog(
///     title: Text('Title'),
///     content: Text('Content'),
///   ),
/// );
/// ```
Future<T?> showAnimatedDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  String? barrierLabel,
  Color barrierColor = Colors.black54,
  bool useRootNavigator = true,
  RouteSettings? routeSettings,
  Offset? anchorPoint,
}) {
  return showGeneralDialog<T>(
    context: context,
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
    barrierDismissible: barrierDismissible,
    barrierLabel: barrierLabel ?? MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: barrierColor,
    transitionDuration: AppDurations.normal, // 200ms for appearance
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return _ScaleFadeDialogTransition(
        animation: animation,
        child: child,
      );
    },
    useRootNavigator: useRootNavigator,
    routeSettings: routeSettings,
    anchorPoint: anchorPoint,
  );
}

/// Custom dialog route with scale-and-fade transition.
/// Can be used with Navigator.push for more control.
class AnimatedDialogRoute<T> extends RawDialogRoute<T> {
  AnimatedDialogRoute({
    required WidgetBuilder builder,
    super.barrierDismissible = true,
    super.barrierLabel,
    super.barrierColor = Colors.black54,
    super.settings,
    super.anchorPoint,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => builder(context),
          transitionDuration: AppDurations.normal, // 200ms for appearance
          transitionBuilder: (context, animation, secondaryAnimation, child) {
            return _ScaleFadeDialogTransition(
              animation: animation,
              child: child,
            );
          },
        );

  @override
  Duration get reverseTransitionDuration => AppDurations.fast; // 150ms for dismissal
}

/// Internal widget that handles the scale-and-fade animation.
class _ScaleFadeDialogTransition extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;

  const _ScaleFadeDialogTransition({
    required this.animation,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final scaleAnimation = Tween<double>(
      begin: 0.85,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: animation,
      curve: AppCurves.enter,
      reverseCurve: AppCurves.exit,
    ));

    final fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: animation,
      curve: AppCurves.enter,
      reverseCurve: AppCurves.exit,
    ));

    return FadeTransition(
      opacity: fadeAnimation,
      child: ScaleTransition(
        scale: scaleAnimation,
        child: child,
      ),
    );
  }
}

/// A reusable animated dialog widget wrapper.
/// Wraps any dialog content with consistent styling and animations.
class AnimatedDialogWrapper extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? maxWidth;
  final double? maxHeight;

  const AnimatedDialogWrapper({
    super.key,
    required this.child,
    this.padding,
    this.maxWidth,
    this.maxHeight,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth ?? MediaQuery.of(context).size.width * 0.9,
          maxHeight: maxHeight ?? MediaQuery.of(context).size.height * 0.85,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: child,
        ),
      ),
    );
  }
}

/// Custom animated bottom sheet with slide-up animation and backdrop fade.
/// Provides a professional, polished appearance for bottom sheets.
///
/// Usage:
/// ```dart
/// showAnimatedBottomSheet(
///   context: context,
///   builder: (context) => Container(
///     child: Text('Bottom sheet content'),
///   ),
/// );
/// ```
Future<T?> showAnimatedBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isDismissible = true,
  bool enableDrag = true,
  bool showDragHandle = true,
  bool isScrollControlled = false,
  bool useRootNavigator = false,
  Color? backgroundColor,
  double? elevation,
  ShapeBorder? shape,
  Clip? clipBehavior,
  BoxConstraints? constraints,
  Color? barrierColor,
  RouteSettings? routeSettings,
  AnimationController? transitionAnimationController,
}) {
  return showModalBottomSheet<T>(
    context: context,
    builder: builder,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    showDragHandle: showDragHandle,
    isScrollControlled: isScrollControlled,
    useRootNavigator: useRootNavigator,
    backgroundColor: backgroundColor,
    elevation: elevation,
    shape: shape ?? const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    clipBehavior: clipBehavior ?? Clip.antiAlias,
    constraints: constraints,
    barrierColor: barrierColor,
    routeSettings: routeSettings,
    transitionAnimationController: transitionAnimationController,
  );
}

/// Custom bottom sheet route with enhanced slide-up animation and backdrop fade.
/// Provides more control over the animation behavior.
class AnimatedBottomSheetRoute<T> extends ModalBottomSheetRoute<T> {
  AnimatedBottomSheetRoute({
    required super.builder,
    super.capturedThemes,
    super.barrierLabel,
    super.barrierOnTapHint,
    super.backgroundColor,
    super.elevation,
    super.shape,
    super.clipBehavior,
    super.constraints,
    super.modalBarrierColor,
    super.isDismissible = true,
    super.enableDrag = true,
    super.showDragHandle = true,
    super.isScrollControlled = false,
    super.settings,
    super.transitionAnimationController,
    super.anchorPoint,
    super.useSafeArea = false,
  });

  @override
  Duration get transitionDuration => AppDurations.normal; // 200ms slide-up

  @override
  Duration get reverseTransitionDuration => AppDurations.fast; // 150ms slide-down

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // Enhanced slide-up animation with backdrop fade
    final slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: animation,
      curve: AppCurves.enter,
      reverseCurve: AppCurves.exit,
    ));

    return SlideTransition(
      position: slideAnimation,
      child: child,
    );
  }
}

/// Shows a bottom sheet using the custom AnimatedBottomSheetRoute.
/// Provides enhanced slide-up animation with backdrop fade.
Future<T?> showEnhancedBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isDismissible = true,
  bool enableDrag = true,
  bool showDragHandle = true,
  bool isScrollControlled = false,
  Color? backgroundColor,
  double? elevation,
  ShapeBorder? shape,
  Clip? clipBehavior,
  BoxConstraints? constraints,
  Color? barrierColor,
  RouteSettings? routeSettings,
  AnimationController? transitionAnimationController,
  bool useSafeArea = false,
}) {
  final NavigatorState navigator = Navigator.of(context, rootNavigator: false);
  final MaterialLocalizations localizations = MaterialLocalizations.of(context);

  return navigator.push(AnimatedBottomSheetRoute<T>(
    builder: builder,
    capturedThemes: InheritedTheme.capture(
      from: context,
      to: navigator.context,
    ),
    barrierLabel: localizations.scrimLabel,
    barrierOnTapHint: localizations.scrimOnTapHint(localizations.bottomSheetLabel),
    backgroundColor: backgroundColor,
    elevation: elevation,
    shape: shape ?? const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    clipBehavior: clipBehavior ?? Clip.antiAlias,
    constraints: constraints,
    modalBarrierColor: barrierColor ?? Colors.black54,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    showDragHandle: showDragHandle,
    isScrollControlled: isScrollControlled,
    settings: routeSettings,
    transitionAnimationController: transitionAnimationController,
    useSafeArea: useSafeArea,
  ));
}
