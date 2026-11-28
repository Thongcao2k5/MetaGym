import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/network/api_cache_interceptor.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_tap.dart';

/// Lớp phủ hiển thị thông báo gọn phía trên khi app đang ngoại tuyến,
/// chờ đồng bộ thao tác hoặc đang đồng bộ tự động lên máy chủ.
///
/// Tuân thủ `DESIGN.md`: dùng bề mặt đặc Level 1 (`surfaceSolid`, không blur),
/// màu ngữ nghĩa cảnh báo (`warning`) / đồng bộ (`info`), chữ `12px` Be Vietnam Pro
/// tương phản >= 4.5:1 và nút đóng đạt vùng chạm tối thiểu `44x44`.
class OfflineCacheBannerOverlay extends StatelessWidget {
  const OfflineCacheBannerOverlay({
    required this.controller,
    required this.child,
    super.key,
  });

  final ApiCacheStatusController controller;
  final Widget child;

  static String formatBannerMessage(ApiCacheStatusController controller) {
    final pending = controller.pendingMutationCount;
    if (controller.isSyncing) {
      return pending > 0
          ? 'Đang đồng bộ $pending thao tác lên máy chủ...'
          : 'Đang đồng bộ dữ liệu mới...';
    }
    if (pending > 0) {
      return 'Đang ngoại tuyến · Chờ đồng bộ $pending thao tác';
    }
    final lastSyncedAt = controller.lastSyncedAt;
    if (lastSyncedAt == null) {
      return 'Đang xem dữ liệu đã lưu';
    }
    final local = lastSyncedAt.toLocal();
    final nowLocal = DateTime.now();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    final isToday =
        local.year == nowLocal.year &&
        local.month == nowLocal.month &&
        local.day == nowLocal.day;
    if (isToday) {
      return 'Đang xem dữ liệu đã lưu · Cập nhật lúc $hh:$mm';
    }
    final dd = local.day.toString().padLeft(2, '0');
    final mo = local.month.toString().padLeft(2, '0');
    return 'Đang xem dữ liệu đã lưu · Cập nhật $dd/$mo $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final visible = controller.shouldShowBanner;
        return Stack(
          children: [
            child,
            if (visible)
              Positioned(
                top: MediaQuery.paddingOf(context).top + 8,
                left: 16,
                right: 16,
                child: _OfflineBannerCard(
                  message: formatBannerMessage(controller),
                  isSyncing: controller.isSyncing,
                  hasPendingMutations: controller.pendingMutationCount > 0,
                  onDismiss: controller.dismissBanner,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _OfflineBannerCard extends StatelessWidget {
  const _OfflineBannerCard({
    required this.message,
    required this.isSyncing,
    required this.hasPendingMutations,
    required this.onDismiss,
  });

  final String message;
  final bool isSyncing;
  final bool hasPendingMutations;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final palette = MetaGymTheme.paletteOf(context);
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final accentColor = isSyncing ? palette.info : palette.warning;
    final iconData = isSyncing
        ? Icons.sync_rounded
        : hasPendingMutations
        ? Icons.cloud_upload_outlined
        : Icons.cloud_off_rounded;

    final card = Material(
      type: MaterialType.transparency,
      child: Container(
        key: const Key('offline-cache-banner'),
        decoration: BoxDecoration(
          color: palette.surfaceSolid,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accentColor.withValues(alpha: 0.45)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x28000000),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.only(left: 12, right: 4, top: 4, bottom: 4),
          child: Row(
            children: [
              Icon(iconData, size: 18, color: accentColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ),
              if (!isSyncing)
                Semantics(
                  button: true,
                  label: 'Ẩn thông báo ngoại tuyến',
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: MetaGymTap(
                      key: const Key('offline-cache-banner-dismiss'),
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
                )
              else
                const SizedBox(width: 12, height: 44),
            ],
          ),
        ),
      ),
    );

    if (disableAnimations) {
      return card;
    }

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(opacity: value, child: child),
      child: card,
    );
  }
}
