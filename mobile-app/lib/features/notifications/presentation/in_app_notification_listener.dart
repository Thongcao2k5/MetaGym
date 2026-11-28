import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/theme/meta_gym_icons.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_icon.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_tap.dart';
import 'package:meta_gym_app/features/auth/presentation/session_controller.dart';
import 'package:meta_gym_app/features/notifications/domain/notification_models.dart';
import 'package:meta_gym_app/features/notifications/presentation/notification_router.dart';
import 'package:meta_gym_app/features/notifications/presentation/notifications_controller.dart';

class InAppNotificationListener extends StatefulWidget {
  const InAppNotificationListener({
    required this.navigatorKey,
    required this.controller,
    required this.session,
    required this.child,
    this.router,
    super.key,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final NotificationsController controller;
  final SessionController session;
  final GoRouter? router;
  final Widget child;

  @override
  State<InAppNotificationListener> createState() =>
      _InAppNotificationListenerState();
}

class _InAppNotificationListenerState extends State<InAppNotificationListener>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _opacityAnim;
  late final Animation<Offset> _slideAnim;
  StreamSubscription<AppNotification>? _bannerSub;
  StreamSubscription<AppNotification>? _tapSub;
  Timer? _dismissTimer;
  AppNotification? _current;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
      reverseDuration: const Duration(milliseconds: 180),
    );
    final curved = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _opacityAnim = curved;
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(curved);

    _bannerSub = widget.controller.bannerEvents.listen(_showBanner);
    _tapSub = widget.controller.tapEvents.listen(_handleTap);
  }

  @override
  void didUpdateWidget(covariant InAppNotificationListener oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      unawaited(_bannerSub?.cancel());
      unawaited(_tapSub?.cancel());
      _bannerSub = widget.controller.bannerEvents.listen(_showBanner);
      _tapSub = widget.controller.tapEvents.listen(_handleTap);
    }
  }

  void _showBanner(AppNotification item) {
    if (!mounted) return;
    _dismissTimer?.cancel();
    setState(() => _current = item);
    if (MediaQuery.disableAnimationsOf(context)) {
      _animController.value = 1;
    } else {
      _animController.forward(from: 0);
    }
    _dismissTimer = Timer(const Duration(seconds: 4), _dismissBanner);
  }

  Future<void> _dismissBanner() async {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    if (!mounted || _current == null) return;
    if (!MediaQuery.disableAnimationsOf(context)) {
      await _animController.reverse();
    } else {
      _animController.value = 0;
    }
    if (mounted) {
      setState(() => _current = null);
    }
  }

  Future<void> _handleTap(AppNotification item) async {
    await _dismissBanner();
    if (item.isUnread && item.id.isNotEmpty) {
      unawaited(widget.controller.markRead(item.id));
    }
    final navContext = widget.navigatorKey.currentContext;
    final targetContext = navContext != null && navContext.mounted
        ? navContext
        : (mounted ? context : null);
    if (targetContext == null || !targetContext.mounted) return;
    await openNotificationTarget(
      targetContext,
      item,
      role: widget.session.user?.role,
      router: widget.router,
    );
  }

  String _svgForCategory(NotificationCategory category) => switch (category) {
    NotificationCategory.training => MetaGymIcons.actionCurriculum,
    NotificationCategory.message => MetaGymIcons.commNotificationUnread,
    NotificationCategory.system => MetaGymIcons.stateInfo,
    NotificationCategory.coach ||
    NotificationCategory.all ||
    NotificationCategory.unread => MetaGymIcons.settingNotificationsBell,
  };

  @override
  void dispose() {
    _dismissTimer?.cancel();
    unawaited(_bannerSub?.cancel());
    unawaited(_tapSub?.cancel());
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = _current;
    return Stack(
      children: [
        widget.child,
        if (current != null)
          Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            left: 16,
            right: 16,
            child: SlideTransition(
              position: _slideAnim,
              child: FadeTransition(
                opacity: _opacityAnim,
                child: Dismissible(
                  key: ValueKey('in-app-banner-${current.id}'),
                  direction: DismissDirection.up,
                  onDismissed: (_) {
                    _dismissTimer?.cancel();
                    setState(() => _current = null);
                  },
                  child: _NotificationOverlayBanner(
                    title: current.title ?? 'Thông báo mới',
                    body: current.body ?? '',
                    svgAsset: _svgForCategory(current.category),
                    onTap: () => _handleTap(current),
                    onDismiss: _dismissBanner,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _NotificationOverlayBanner extends StatelessWidget {
  const _NotificationOverlayBanner({
    required this.title,
    required this.body,
    required this.svgAsset,
    required this.onTap,
    required this.onDismiss,
  });

  final String title;
  final String body;
  final String svgAsset;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final palette = MetaGymTheme.paletteOf(context);
    final isLight = MetaGymTheme.isLightPalette(context);
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final enableBlur =
        !isLight && !disableAnimations && !MetaGymTheme.isFlutterTestEnvironment;
    final radius = BorderRadius.circular(MetaGymTheme.radiusGlassDock);

    final inner = Container(
      key: const Key('in-app-notification-banner'),
      decoration: BoxDecoration(
        color: isLight ? palette.surfaceSolid : MetaGymTheme.overlayGlass,
        borderRadius: radius,
        border: Border.all(
          color: isLight
              ? palette.borderSolid
              : MetaGymTheme.overlayGlassBorder,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: MetaGymTap(
          onTap: onTap,
          borderRadius: radius,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: MetaGymTheme.brandOrange.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: MetaGymTheme.brandOrange.withValues(alpha: 0.4),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: MetaGymIcon(
                    svgAsset,
                    size: MetaGymIconSize.md,
                    excludeFromSemantics: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: MetaGymTheme.brandOrange,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: palette.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (body.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: palette.textSecondary,
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Semantics(
                  button: true,
                  label: 'Đóng thông báo',
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: MetaGymTap(
                      onTap: onDismiss,
                      customBorder: const CircleBorder(),
                      child: Center(
                        child: Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: palette.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (!enableBlur) return inner;
    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: MetaGymTheme.overlayGlassBlur,
            sigmaY: MetaGymTheme.overlayGlassBlur,
          ),
          child: inner,
        ),
      ),
    );
  }
}
