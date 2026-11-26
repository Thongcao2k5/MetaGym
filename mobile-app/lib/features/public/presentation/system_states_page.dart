import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_auth_background.dart';
import 'package:meta_gym_app/core/widgets/system_state_modals.dart';

/// Catalogue available from the debug login tools, using the product dialogs.
class SystemStatesPage extends StatelessWidget {
  const SystemStatesPage({super.key});

  static const _states = [
    (
      kind: MetaGymSystemModalKind.empty,
      title: 'Màn hình Trống (Empty State)',
      subtitle: 'Chưa có lịch tập / dữ liệu · Gợi ý bắt đầu',
    ),
    (
      kind: MetaGymSystemModalKind.offline,
      title: 'Mất kết nối mạng (Offline)',
      subtitle: 'Không có Wi-Fi / 4G · Kiểm tra kết nối',
    ),
    (
      kind: MetaGymSystemModalKind.serverError,
      title: 'Lỗi hệ thống (Error / Retry)',
      subtitle: 'Thông báo lỗi · Thử lại khi có tác vụ thật',
    ),
    (
      kind: MetaGymSystemModalKind.loading,
      title: 'Đang tải dữ liệu (Loading)',
      subtitle: 'Meta Kong đẩy tạ · Đồng bộ buổi tập',
    ),
    (
      kind: MetaGymSystemModalKind.streak,
      title: 'Chúc mừng Thành tựu (Streak)',
      subtitle: 'Cúp lửa chuỗi ngày tập',
    ),
    (
      kind: MetaGymSystemModalKind.maintenance,
      title: 'Hệ thống đang bảo trì',
      subtitle: 'Tạm dừng dịch vụ để nâng cấp',
    ),
    (
      kind: MetaGymSystemModalKind.membershipPromo,
      title: 'Mời gọi mua gói tập VIP',
      subtitle: 'Khám phá quyền lợi thẻ kim loại NFC',
    ),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: MetaGymTheme.darkCanvas,
    body: Stack(
      children: [
        const Positioned.fill(child: MetaGymAuthBackground()),
        SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    MetaGymCircleIconButton(
                      icon: Icons.arrow_back_rounded,
                      tooltip: 'Quay lại',
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SYSTEM STATES & ALERTS',
                            style: TextStyle(
                              color: MetaGymTheme.brandOrange,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Modal Hệ thống',
                            style: TextStyle(
                              color: MetaGymTheme.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  children: [
                    MetaGymHeroGlassCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Image.asset(
                            'assets/images/mascot/meta_kong_hero.webp',
                            width: 78,
                            height: 78,
                            fit: BoxFit.contain,
                            semanticLabel: 'Meta Kong',
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'LINH VẬT META KONG',
                                  style: TextStyle(
                                    color: MetaGymTheme.brandOrange,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Trạng thái Hệ thống & Thành tựu',
                                  style: TextStyle(
                                    color: MetaGymTheme.textPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Bấm từng trạng thái để xem trực tiếp.',
                                  style: TextStyle(
                                    color: MetaGymTheme.paletteOf(context)
                                        .textWarmMuted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (final state in _states) ...[
                      MetaGymGlassCard(
                        solid: false,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 13,
                          vertical: 11,
                        ),
                        onTap: () => showMetaGymSystemModal(
                          context,
                          kind: state.kind,
                          primaryActionLabel: 'Đã hiểu',
                          secondaryActionLabel: 'Đóng',
                        ),
                        child: Row(
                          children: [
                            Image.asset(
                              metaGymSystemMascotAsset(state.kind)!,
                              width: 48,
                              height: 48,
                              fit: BoxFit.contain,
                              excludeFromSemantics: true,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    state.title,
                                    style: const TextStyle(
                                      color: MetaGymTheme.textPrimary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    state.subtitle,
                                    style: TextStyle(
                                      color: MetaGymTheme.paletteOf(context)
                                          .textWarmMuted,
                                      fontSize: 12,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Xem ›',
                              style: TextStyle(
                                color: MetaGymTheme.brandOrange,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Text(
                      'Chế độ xem thử: các nút chỉ đóng hộp thoại, không tạo giao dịch, nhận thưởng hoặc thay đổi dữ liệu.',
                      style: TextStyle(
                        color: MetaGymTheme.paletteOf(context).textWarmMuted,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
