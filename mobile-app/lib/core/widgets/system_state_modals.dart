import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/theme/meta_gym_icons.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_svg_icon.dart';

/// 6 trạng thái Modal hệ thống chuẩn Meta Gym (Level 3 Overlay Glass).
enum MetaGymSystemModalKind {
  maintenance,
  comingSoon,
  serverError,
  updateAvailable,
  offline,
  sessionExpired,
}

/// Hiển thị Modal trạng thái hệ thống sử dụng Level 3 Overlay Glass (blur 18px
/// có `RepaintBoundary` & fallback `disableAnimations`).
Future<void> showMetaGymSystemModal(
  BuildContext context, {
  required MetaGymSystemModalKind kind,
  String? customTitle,
  String? customMessage,
  String? primaryActionLabel,
  VoidCallback? onPrimaryAction,
  String? secondaryActionLabel,
  VoidCallback? onSecondaryAction,
}) {
  final spec = _specForKind(kind);
  return showDialog<void>(
    context: context,
    barrierColor: MetaGymTheme.scrim,
    builder: (dialogContext) {
      final isLight = MetaGymTheme.isLightPalette(dialogContext);
      final palette = MetaGymTheme.paletteOf(dialogContext);
      final disableAnimations = MediaQuery.disableAnimationsOf(dialogContext);
      final enableBlur =
          !isLight &&
          !disableAnimations &&
          !MetaGymTheme.isFlutterTestEnvironment;
      final radius = BorderRadius.circular(MetaGymTheme.radiusGlassDock);

      final content = Container(
        constraints: const BoxConstraints(maxWidth: 360),
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
        decoration: BoxDecoration(
          color: isLight ? palette.surfaceSolid : MetaGymTheme.overlayGlass,
          borderRadius: radius,
          border: Border.all(
            color: isLight
                ? palette.borderSolid
                : MetaGymTheme.overlayGlassBorder,
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: spec.badgeTint.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: spec.badgeTint.withValues(alpha: 0.35),
                ),
              ),
              alignment: Alignment.center,
              child: MetaGymSvgIcon(
                spec.svgAsset,
                size: 36,
                fallbackIcon: spec.fallbackIcon,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              customTitle ?? spec.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              customMessage ?? spec.message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: palette.textSecondary,
                fontSize: 13.5,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  onPrimaryAction?.call();
                },
                child: Text(primaryActionLabel ?? spec.primaryLabel),
              ),
            ),
            if (secondaryActionLabel != null ||
                spec.secondaryLabel != null) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    onSecondaryAction?.call();
                  },
                  child: Text(
                    secondaryActionLabel ?? spec.secondaryLabel!,
                    style: TextStyle(color: palette.textSecondary),
                  ),
                ),
              ),
            ],
          ],
        ),
      );

      return Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        child: enableBlur
            ? RepaintBoundary(
                child: ClipRRect(
                  borderRadius: radius,
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: MetaGymTheme.overlayGlassBlur,
                      sigmaY: MetaGymTheme.overlayGlassBlur,
                    ),
                    child: content,
                  ),
                ),
              )
            : content,
      );
    },
  );
}

class _SystemModalSpec {
  const _SystemModalSpec({
    required this.title,
    required this.message,
    required this.svgAsset,
    required this.fallbackIcon,
    required this.badgeTint,
    required this.primaryLabel,
    this.secondaryLabel,
  });

  final String title;
  final String message;
  final String svgAsset;
  final IconData fallbackIcon;
  final Color badgeTint;
  final String primaryLabel;
  final String? secondaryLabel;
}

_SystemModalSpec _specForKind(MetaGymSystemModalKind kind) => switch (kind) {
  MetaGymSystemModalKind.maintenance => const _SystemModalSpec(
    title: 'Hệ thống đang bảo trì',
    message:
        'Meta Gym đang nâng cấp máy chủ để mang lại trải nghiệm mượt mà hơn. Vui lòng quay lại sau ít phút.',
    svgAsset: MetaGymIcons.stateMaintenance,
    fallbackIcon: Icons.engineering_outlined,
    badgeTint: MetaGymTheme.warning,
    primaryLabel: 'Đã hiểu',
  ),
  MetaGymSystemModalKind.comingSoon => const _SystemModalSpec(
    title: 'Tính năng sắp ra mắt',
    message:
        'Tính năng này đang được đội ngũ Meta Gym hoàn thiện và sẽ mở sớm trong bản cập nhật tới.',
    svgAsset: MetaGymIcons.stateComingSoon,
    fallbackIcon: Icons.rocket_launch_outlined,
    badgeTint: MetaGymTheme.infoSteelBlue,
    primaryLabel: 'Nhận thông báo',
    secondaryLabel: 'Để sau',
  ),
  MetaGymSystemModalKind.serverError => const _SystemModalSpec(
    title: 'Lỗi kết nối hệ thống',
    message:
        'Không thể xử lý yêu cầu lúc này (500 / 503). Bạn vui lòng thử lại hoặc liên hệ hỗ trợ.',
    svgAsset: MetaGymIcons.stateError,
    fallbackIcon: Icons.error_outline_rounded,
    badgeTint: MetaGymTheme.dangerCoral,
    primaryLabel: 'Thử lại',
    secondaryLabel: 'Đóng',
  ),
  MetaGymSystemModalKind.updateAvailable => const _SystemModalSpec(
    title: 'Có bản cập nhật mới',
    message:
        'Meta Gym v1.1.0 đã sẵn sàng với nhiều cải tiến hiệu năng và trải nghiệm tập luyện.',
    svgAsset: MetaGymIcons.stateUpdate,
    fallbackIcon: Icons.system_update_outlined,
    badgeTint: MetaGymTheme.success,
    primaryLabel: 'Cập nhật ngay',
    secondaryLabel: 'Để sau',
  ),
  MetaGymSystemModalKind.offline => const _SystemModalSpec(
    title: 'Mất kết nối mạng',
    message:
        'Thiết bị hiện không có kết nối Wi-Fi hoặc 4G. Vui lòng kiểm tra lại kết nối và thử lại.',
    svgAsset: MetaGymIcons.stateNoNetwork,
    fallbackIcon: Icons.wifi_off_rounded,
    badgeTint: MetaGymTheme.reflectionBlue,
    primaryLabel: 'Kiểm tra lại',
  ),
  MetaGymSystemModalKind.sessionExpired => const _SystemModalSpec(
    title: 'Phiên đăng nhập hết hạn',
    message:
        'Vì lý do bảo mật tài khoản, phiên làm việc của bạn đã hết hạn. Vui lòng đăng nhập lại.',
    svgAsset: MetaGymIcons.stateWarning,
    fallbackIcon: Icons.lock_clock_outlined,
    badgeTint: MetaGymTheme.warning,
    primaryLabel: 'Đăng nhập lại',
  ),
};
