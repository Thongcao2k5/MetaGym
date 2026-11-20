import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';

/// Prevents rapid repeated taps from pushing the same declarative route twice.
/// The in-flight route remains locked until it is popped from the stack.
abstract final class MetaGymNavigation {
  static final Expando<Set<String>> _pendingPaths = Expando('MetaGym routes');
  static final Expando<bool> _openingRoutes = Expando('MetaGym detail routes');
  static final Expando<bool> _openingOverlays = Expando('MetaGym overlays');

  static Future<T?> showDialogOnce<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool barrierDismissible = true,
    Color? barrierColor,
  }) => _overlayOnce(
    context,
    () => showDialog<T>(
      context: context,
      builder: builder,
      barrierDismissible: barrierDismissible,
      barrierColor: barrierColor,
      animationStyle: AnimationStyle(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : MetaGymTheme.pageTransitionDuration,
        reverseDuration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 240),
      ),
    ),
  );

  static Future<T?> showSheetOnce<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    Color? backgroundColor,
    ShapeBorder? shape,
    bool isScrollControlled = false,
    bool useSafeArea = false,
    bool isDismissible = true,
    bool enableDrag = true,
    bool? showDragHandle,
  }) => _overlayOnce(
    context,
    () => showModalBottomSheet<T>(
      context: context,
      builder: builder,
      backgroundColor: backgroundColor,
      shape: shape,
      isScrollControlled: isScrollControlled,
      useSafeArea: useSafeArea,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      showDragHandle: showDragHandle,
      sheetAnimationStyle: AnimationStyle(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : MetaGymTheme.pageTransitionDuration,
        reverseDuration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 240),
      ),
    ),
  );

  static Future<T?> _overlayOnce<T>(
    BuildContext context,
    Future<T?> Function() open,
  ) async {
    final source = ModalRoute.of(context);
    if (source != null &&
        (!source.isCurrent || _openingOverlays[source] == true)) {
      return null;
    }
    if (source != null) _openingOverlays[source] = true;
    try {
      return await open();
    } finally {
      if (source != null) _openingOverlays[source] = false;
    }
  }

  static Future<T?> pushOnce<T>(
    BuildContext context,
    Route<T> destination,
  ) async {
    final source = ModalRoute.of(context);
    if (source != null &&
        (!source.isCurrent || _openingRoutes[source] == true)) {
      return null;
    }
    if (source != null) _openingRoutes[source] = true;
    try {
      return await Navigator.of(context).push<T>(destination);
    } finally {
      if (source != null) _openingRoutes[source] = false;
    }
  }

  static Future<T?> pushPathOnce<T>(BuildContext context, String path) async {
    final router = GoRouter.of(context);
    if (router.state.uri.toString() == path) return null;

    final paths = _pendingPaths[router] ??= <String>{};
    if (!paths.add(path)) return null;

    try {
      return await router.push<T>(path);
    } finally {
      paths.remove(path);
    }
  }
}

/// Keeps native back gestures and Navigator results, with bounded page motion.
class MetaGymPageRoute<T> extends MaterialPageRoute<T> {
  MetaGymPageRoute({
    required super.builder,
    super.settings,
    super.fullscreenDialog,
    super.maintainState,
  });

  @override
  Duration get transitionDuration => MetaGymTheme.pageTransitionDuration;

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 240);

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return super.buildTransitions(
      context,
      animation,
      secondaryAnimation,
      child,
    );
  }
}
