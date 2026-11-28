import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/theme/meta_gym_icons.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_action_button.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_icon.dart';
import 'package:meta_gym_app/features/auth/domain/auth_models.dart';
import 'package:meta_gym_app/features/notifications/domain/notification_models.dart';

String? resolveNotificationRoute(AppNotification item, UserRole? role) {
  final isCoach = role == UserRole.coach;
  final rawRoute = item.actionRoute?.trim();
  if (rawRoute != null && rawRoute.isNotEmpty) {
    if (isCoach && rawRoute.startsWith('/coach/')) return rawRoute;
    if (!isCoach && rawRoute.startsWith('/member/')) return rawRoute;
    if (rawRoute == '/profile') return rawRoute;
    if (isCoach && rawRoute.startsWith('/member/features/')) {
      return rawRoute.replaceFirst('/member/features/', '/coach/features/');
    }
    if (!isCoach && rawRoute.startsWith('/coach/features/')) {
      return rawRoute.replaceFirst('/coach/features/', '/member/features/');
    }
  }

  final kind = item.kind.toUpperCase();
  if (kind == 'BOOKED' ||
      kind == 'COMPLETED' ||
      kind == 'CANCELLED' ||
      kind == 'NO_SHOW' ||
      kind == 'RESCHEDULED') {
    return isCoach ? '/coach/features/sessions' : '/member/features/sessions';
  }
  if (kind == 'TRAINING_PLAN_UPDATED') {
    return isCoach ? '/coach/features/training' : '/member/features/training';
  }
  if (kind == 'NUTRITION_UPDATED' || kind == 'MEAL_PLAN_UPDATED') {
    return isCoach ? '/coach/features/nutrition' : '/member/features/nutrition';
  }
  if (kind == 'NEW_MESSAGE') {
    return isCoach ? '/coach/features/messages' : '/member/features/messages';
  }
  if (kind == 'MISSED_CALL' || kind == 'INCOMING_CALL') {
    return isCoach ? '/coach/features/calls' : '/member/features/calls';
  }
  if (kind.startsWith('PACKAGE_') ||
      kind.startsWith('TERMINATION_') ||
      kind.startsWith('COACH_') ||
      kind.startsWith('MEMBER_') ||
      kind == 'SIMULATED_REFUND_COMPLETED') {
    return isCoach ? '/coach/features/members' : '/member/features/my-coach';
  }
  return null;
}

Future<void> openNotificationTarget(
  BuildContext context,
  AppNotification item, {
  UserRole? role,
  GoRouter? router,
}) async {
  final route = resolveNotificationRoute(item, role);
  if (route != null) {
    final go = router ?? _maybeRouter(context);
    if (go != null) {
      await go.push(route);
      return;
    }
  }
  if (!context.mounted) return;
  await showNotificationDetailSheet(context, item);
}

GoRouter? _maybeRouter(BuildContext context) {
  try {
    return GoRouter.of(context);
  } catch (_) {
    return null;
  }
}

Future<void> showNotificationDetailSheet(
  BuildContext context,
  AppNotification item,
) {
  final palette = MetaGymTheme.paletteOf(context);
  final isLight = MetaGymTheme.isLightPalette(context);
  final disableAnimations = MediaQuery.disableAnimationsOf(context);
  final enableBlur =
      !isLight && !disableAnimations && !MetaGymTheme.isFlutterTestEnvironment;

  String formattedTime = '';
  if (item.eventAt != null) {
    final parsed = DateTime.tryParse(item.eventAt!);
    if (parsed != null) {
      final vn = parsed.isUtc ? parsed.add(const Duration(hours: 7)) : parsed;
      formattedTime = DateFormat('HH:mm · dd/MM/yyyy').format(vn);
    }
  }

  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    barrierColor: MetaGymTheme.scrim,
    builder: (sheetCtx) {
      final content = Container(
        decoration: BoxDecoration(
          color: isLight ? palette.surfaceSolid : MetaGymTheme.overlayGlass,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(MetaGymTheme.radiusGlassDock),
          ),
          border: Border.all(
            color: isLight
                ? palette.borderSolid
                : MetaGymTheme.overlayGlassBorder,
          ),
        ),
        padding: EdgeInsets.fromLTRB(
          20,
          14,
          20,
          MediaQuery.paddingOf(sheetCtx).bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: palette.textSecondary.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(MetaGymTheme.radiusFull),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: MetaGymTheme.brandOrange.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: MetaGymTheme.brandOrange.withValues(alpha: 0.35),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: const MetaGymIcon(
                    MetaGymIcons.settingNotificationsBell,
                    size: MetaGymIconSize.md,
                    excludeFromSemantics: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title ?? 'Thông báo từ Meta Gym',
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (formattedTime.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          formattedTime,
                          style: TextStyle(
                            color: palette.textSecondary,
                            fontSize: 12,
                            fontFeatures: MetaGymTheme.tabularFigures,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              item.body ?? 'Hệ thống Meta Gym đã gửi cập nhật mới.',
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 18),
            MetaGymActionButton(
              label: 'Đóng',
              onPressed: () => Navigator.of(sheetCtx).pop(),
            ),
          ],
        ),
      );

      if (!enableBlur) return content;
      return ClipRRect(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(MetaGymTheme.radiusGlassDock),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: MetaGymTheme.overlayGlassBlur,
            sigmaY: MetaGymTheme.overlayGlassBlur,
          ),
          child: content,
        ),
      );
    },
  );
}
