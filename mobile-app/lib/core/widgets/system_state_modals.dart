import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/theme/meta_gym_icons.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_svg_icon.dart';

/// Các trạng thái hệ thống chuẩn Meta Gym (Level 3 Overlay Glass).
enum MetaGymSystemModalKind {
  empty,
  loading,
  streak,
  membershipPromo,
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
  bool showSecondaryAction = true,
}) {
  final spec = _specForKind(kind);
  final mascot = metaGymSystemMascotAsset(kind);
  return showDialog<void>(
    context: context,
    barrierColor: MetaGymColors.of(context).scrim,
    builder: (dialogContext) {
      final isLight = MetaGymTheme.isLightPalette(dialogContext);
      final palette = MetaGymTheme.paletteOf(dialogContext);
      final badgeTint = _badgeTintForKind(kind, palette);
      final disableAnimations = MediaQuery.disableAnimationsOf(dialogContext);
      final enableBlur =
          !isLight &&
          !disableAnimations &&
          !MetaGymTheme.isFlutterTestEnvironment;
      final radius = BorderRadius.circular(MetaGymTheme.radiusGlassDock);

      final modalSvg = MetaGymSvgIcon(
        spec.svgAsset,
        size: 36,
        fallbackIcon: spec.fallbackIcon,
      );

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
          boxShadow: isLight
              ? const [
                  BoxShadow(
                    color: Color(0x3811151A),
                    blurRadius: 50,
                    offset: Offset(0, 20),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (mascot != null)
              Image.asset(
                mascot,
                width: 136,
                height: 136,
                fit: BoxFit.contain,
                semanticLabel: customTitle ?? spec.title,
              )
            else
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: badgeTint.withValues(alpha: isLight ? 0.12 : 0.16),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: badgeTint.withValues(alpha: 0.35),
                  ),
                ),
                alignment: Alignment.center,
                child: modalSvg,
              ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: badgeTint.withValues(alpha: isLight ? 0.12 : 0.14),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                metaGymSystemStateLabel(kind),
                style: TextStyle(
                  color: badgeTint,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              customTitle ?? spec.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 16,
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
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                if (showSecondaryAction &&
                    (secondaryActionLabel != null ||
                        spec.secondaryLabel != null)) ...[
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton(
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
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: FilledButton(
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                        onPrimaryAction?.call();
                      },
                      child: Text(
                        primaryActionLabel ??
                            (onPrimaryAction == null
                                ? 'Đóng'
                                : spec.primaryLabel),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );

      final scrollableContent = SingleChildScrollView(child: content);
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
                    child: scrollableContent,
                  ),
                ),
              )
            : scrollableContent,
      );
    },
  );
}

String? metaGymSystemMascotAsset(MetaGymSystemModalKind kind) => switch (kind) {
  MetaGymSystemModalKind.empty => 'assets/images/mascot/meta_kong_empty.webp',
  MetaGymSystemModalKind.loading =>
    'assets/images/mascot/meta_kong_loading.webp',
  MetaGymSystemModalKind.streak => 'assets/images/mascot/meta_kong_streak.webp',
  MetaGymSystemModalKind.membershipPromo =>
    'assets/images/mascot/meta_kong_membership_promo.webp',
  MetaGymSystemModalKind.maintenance =>
    'assets/images/mascot/meta_kong_maintenance.webp',
  MetaGymSystemModalKind.serverError =>
    'assets/images/mascot/meta_kong_error.webp',
  MetaGymSystemModalKind.updateAvailable =>
    'assets/images/mascot/meta_kong_update.webp',
  MetaGymSystemModalKind.offline =>
    'assets/images/mascot/meta_kong_offline.webp',
  MetaGymSystemModalKind.sessionExpired =>
    'assets/images/mascot/meta_kong_session.webp',
  MetaGymSystemModalKind.comingSoon => null,
};

String metaGymSystemStateLabel(MetaGymSystemModalKind kind) => switch (kind) {
  MetaGymSystemModalKind.empty => 'Danh sách trống',
  MetaGymSystemModalKind.loading => 'Đang đồng bộ',
  MetaGymSystemModalKind.streak => 'Thành tựu tập luyện',
  MetaGymSystemModalKind.membershipPromo => 'Đặc quyền hội viên',
  MetaGymSystemModalKind.maintenance => 'Bảo trì hệ thống',
  MetaGymSystemModalKind.serverError => 'Lỗi hệ thống',
  MetaGymSystemModalKind.updateAvailable => 'Cập nhật ứng dụng',
  MetaGymSystemModalKind.offline => 'Mất kết nối',
  MetaGymSystemModalKind.sessionExpired => 'Bảo mật tài khoản',
  MetaGymSystemModalKind.comingSoon => 'Sắp ra mắt',
};

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

Color _badgeTintForKind(
  MetaGymSystemModalKind kind,
  MetaGymPalette palette,
) => switch (kind) {
  MetaGymSystemModalKind.empty ||
  MetaGymSystemModalKind.offline => palette.reflection,
  MetaGymSystemModalKind.loading ||
  MetaGymSystemModalKind.membershipPromo => palette.primaryText,
  MetaGymSystemModalKind.streak ||
  MetaGymSystemModalKind.updateAvailable => palette.success,
  MetaGymSystemModalKind.maintenance ||
  MetaGymSystemModalKind.sessionExpired => palette.warning,
  MetaGymSystemModalKind.comingSoon => palette.info,
  MetaGymSystemModalKind.serverError => palette.error,
};

_SystemModalSpec _specForKind(MetaGymSystemModalKind kind) => switch (kind) {
  MetaGymSystemModalKind.empty => const _SystemModalSpec(
    title: 'Chưa có buổi tập nào',
    message: 'Chọn một giáo trình hoặc đặt lịch 1:1 cùng Coach để bắt đầu hành trình tập luyện.',
    svgAsset: MetaGymIcons.stateEmptyWorkout,
    fallbackIcon: Icons.event_note_outlined,
    badgeTint: MetaGymTheme.reflectionBlue,
    primaryLabel: 'Tạo lịch tập',
    secondaryLabel: 'Để sau',
  ),
  MetaGymSystemModalKind.loading => const _SystemModalSpec(
    title: 'Đang khởi động dữ liệu...',
    message: 'Meta Kong đang chuẩn bị giáo trình, thực đơn và tiến độ mới nhất cho bạn.',
    svgAsset: MetaGymIcons.stateLoading,
    fallbackIcon: Icons.sync_rounded,
    badgeTint: MetaGymTheme.brandOrange,
    primaryLabel: 'Tiếp tục',
  ),
  MetaGymSystemModalKind.streak => const _SystemModalSpec(
    title: 'Giữ vững phong độ!',
    message: 'Tiếp tục ghi lại các buổi tập và theo dõi hành trình tiến bộ của bạn cùng Meta Kong.',
    svgAsset: MetaGymIcons.rewardTrophy,
    fallbackIcon: Icons.emoji_events_outlined,
    badgeTint: MetaGymTheme.success,
    primaryLabel: 'Xem thành tích',
  ),
  MetaGymSystemModalKind.membershipPromo => const _SystemModalSpec(
    title: 'Mở khóa đặc quyền VIP',
    message: 'Khám phá các hạng thẻ hội viên NFC và lựa chọn gói tập phù hợp với mục tiêu của bạn.',
    svgAsset: MetaGymIcons.membershipTierVip,
    fallbackIcon: Icons.workspace_premium_outlined,
    badgeTint: MetaGymTheme.brandOrange,
    primaryLabel: 'Xem gói tập',
    secondaryLabel: 'Để sau',
  ),
  MetaGymSystemModalKind.maintenance => const _SystemModalSpec(
    title: 'Hệ thống đang bảo trì',
    message: 'Meta Gym đang nâng cấp máy chủ để mang lại trải nghiệm mượt mà hơn. Vui lòng quay lại sau ít phút.',
    svgAsset: MetaGymIcons.stateMaintenance,
    fallbackIcon: Icons.engineering_outlined,
    badgeTint: MetaGymTheme.warning,
    primaryLabel: 'Đã hiểu',
  ),
  MetaGymSystemModalKind.comingSoon => const _SystemModalSpec(
    title: 'Tính năng sắp ra mắt',
    message: 'Tính năng này đang được đội ngũ Meta Gym hoàn thiện và sẽ mở sớm trong bản cập nhật tới.',
    svgAsset: MetaGymIcons.stateComingSoon,
    fallbackIcon: Icons.rocket_launch_outlined,
    badgeTint: MetaGymTheme.infoSteelBlue,
    primaryLabel: 'Nhận thông báo',
    secondaryLabel: 'Để sau',
  ),
  MetaGymSystemModalKind.serverError => const _SystemModalSpec(
    title: 'Lỗi kết nối hệ thống',
    message: 'Không thể xử lý yêu cầu lúc này (500 / 503). Bạn vui lòng thử lại hoặc liên hệ hỗ trợ.',
    svgAsset: MetaGymIcons.stateError,
    fallbackIcon: Icons.error_outline_rounded,
    badgeTint: MetaGymTheme.dangerCoral,
    primaryLabel: 'Thử lại',
    secondaryLabel: 'Đóng',
  ),
  MetaGymSystemModalKind.updateAvailable => const _SystemModalSpec(
    title: 'Có bản cập nhật mới',
    message: 'Có phiên bản Meta Gym mới. Xem thông tin phát hành trước khi cập nhật ứng dụng.',
    svgAsset: MetaGymIcons.stateUpdate,
    fallbackIcon: Icons.system_update_outlined,
    badgeTint: MetaGymTheme.success,
    primaryLabel: 'Cập nhật ngay',
    secondaryLabel: 'Để sau',
  ),
  MetaGymSystemModalKind.offline => const _SystemModalSpec(
    title: 'Mất kết nối mạng',
    message: 'Thiết bị hiện không có kết nối Wi-Fi hoặc 4G. Vui lòng kiểm tra lại kết nối và thử lại.',
    svgAsset: MetaGymIcons.stateNoNetwork,
    fallbackIcon: Icons.wifi_off_rounded,
    badgeTint: MetaGymTheme.reflectionBlue,
    primaryLabel: 'Kiểm tra lại',
  ),
  MetaGymSystemModalKind.sessionExpired => const _SystemModalSpec(
    title: 'Phiên đăng nhập hết hạn',
    message: 'Vì lý do bảo mật tài khoản, phiên làm việc của bạn đã hết hạn. Vui lòng đăng nhập lại.',
    svgAsset: MetaGymIcons.stateWarning,
    fallbackIcon: Icons.lock_clock_outlined,
    badgeTint: MetaGymTheme.warning,
    primaryLabel: 'Đăng nhập lại',
  ),
};
