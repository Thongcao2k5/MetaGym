import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/theme/meta_gym_icons.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_auth_background.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_svg_icon.dart';

/// Màn hình Chính sách bảo mật — đồng bộ 1:1 với `auth-privacy-policy` trong HTML Preview.
class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  void _handleBack(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else if (context.canPop()) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = MetaGymTheme.paletteOf(context);
    return Scaffold(
      backgroundColor: palette.canvas,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(child: MetaGymAuthBackground()),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                  child: Row(
                    children: [
                      MetaGymCircleIconButton(
                        icon: Icons.arrow_back_rounded,
                        svgAsset: MetaGymIcons.commonBack,
                        tooltip: 'Quay lại',
                        onTap: () => _handleBack(context),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'BẢO VỆ DỮ LIỆU CÁ NHÂN',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: palette.primaryText,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.4,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Chính sách bảo mật',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: palette.textPrimary,
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
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
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                    children: [
                      MetaGymHeroGlassCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 13,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: palette.metricPanelBg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: palette.metricPanelBorder,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: const MetaGymSvgIcon(
                                MetaGymIcons.settingSecurityShield,
                                size: 24,
                                fallbackIcon: Icons.shield_outlined,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Mã hóa chuẩn AES-256',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: palette.textPrimary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Cập nhật 01/11/2026 · Tuân thủ Nghị định 13/2023',
                                    style: TextStyle(
                                      color: palette.textWarmMuted,
                                      fontSize: 12,
                                      fontFeatures: MetaGymTheme.tabularFigures,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      const _PrivacySectionCard(
                        title: '1. Dữ liệu chúng tôi thu thập',
                        body:
                            '• Định danh: Họ tên, Email, Số điện thoại, Ngày sinh.\n'
                            '• Sức khỏe & Tập luyện: Chiều cao, Cân nặng, BMI, InBody, nhật ký tập, lịch sử điểm danh QR/NFC.\n'
                            '• Giao dịch: Mã hóa đơn gói tập (không lưu số thẻ ngân hàng).',
                      ),
                      const SizedBox(height: 10),
                      const _PrivacySectionCard(
                        title: '2. Chia sẻ dữ liệu với Coach',
                        body: 'Chỉ số cơ thể và nhật ký dinh dưỡng chỉ được chia sẻ với Huấn luyện viên đang trực tiếp phụ trách bạn. Bạn có thể bật hoặc tắt quyền này bất kỳ lúc nào tại Hồ sơ → Quyền riêng tư.',
                      ),
                      const SizedBox(height: 10),
                      const _PrivacySectionCard(
                        title: '3. Bảo mật Sinh trắc học (Face ID / Vân tay)',
                        body: 'Dữ liệu khuôn mặt và vân tay chỉ được xử lý cục bộ trong vùng bảo mật phần cứng (Secure Enclave / Keystore) trên điện thoại của bạn. Meta Gym không bao giờ thu thập hay lưu trữ lên máy chủ.',
                      ),
                      const SizedBox(height: 10),
                      const _PrivacySectionCard(
                        title: '4. Quyền kiểm soát & Xóa dữ liệu',
                        body: 'Bạn có quyền xem, tải xuống bản sao dữ liệu hoặc yêu cầu xóa vĩnh viễn tài khoản trong vòng 7 ngày làm việc qua privacy@metagym.vn.',
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      key: const Key('privacy-accept-btn'),
                      onPressed: () => _handleBack(context),
                      child: const Text('Tôi đã hiểu & Đồng ý'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivacySectionCard extends StatelessWidget {
  const _PrivacySectionCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final palette = MetaGymTheme.paletteOf(context);
    return MetaGymGlassCard(
      solid: false,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: TextStyle(
              color: palette.textWarmMuted,
              fontSize: 14,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
