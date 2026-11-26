import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/theme/meta_gym_icons.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_auth_background.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_svg_icon.dart';

/// Màn hình Điều khoản sử dụng — đồng bộ 1:1 với `auth-terms` trong HTML Preview.
class TermsOfServicePage extends StatelessWidget {
  const TermsOfServicePage({super.key});

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
                              'PHÁP LÝ & QUY ĐỊNH',
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
                              'Điều khoản sử dụng',
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const MetaGymSvgIcon(
                                  MetaGymIcons.settingAboutPolicy,
                                  size: 20,
                                  fallbackIcon: Icons.description_outlined,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Meta Gym Member Agreement',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: palette.textPrimary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: palette.chipActiveBg,
                                    borderRadius: BorderRadius.circular(
                                      MetaGymTheme.radiusFull,
                                    ),
                                  ),
                                  child: Text(
                                    'v1.0',
                                    style: TextStyle(
                                      color: palette.primaryText,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      fontFeatures: MetaGymTheme.tabularFigures,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Hiệu lực từ 01/11/2026 · Áp dụng cho Hội viên & Coach',
                              style: TextStyle(
                                color: palette.textWarmMuted,
                                fontSize: 12,
                                fontFeatures: MetaGymTheme.tabularFigures,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      const _LegalSectionCard(
                        title: '1. Tài khoản & Thẻ Hội viên NFC',
                        body: 'Mỗi hội viên sử dụng một tài khoản định danh duy nhất. Thẻ hội viên kim loại NFC và mã QR Check-in trong ngày chỉ phục vụ cá nhân đăng ký và không được chuyển nhượng hoặc chia sẻ cho người khác.',
                      ),
                      const SizedBox(height: 10),
                      const _LegalSectionCard(
                        title: '2. Gói tập, Coach 1:1 & Chính sách hủy lịch',
                        body:
                            '• Gói tập kích hoạt ngay sau khi thanh toán thành công qua MoMo, VNPay hoặc chuyển khoản.\n'
                            '• Buổi tập 1:1 với Coach cần thông báo hủy hoặc đổi lịch trước tối thiểu 12 giờ để bảo lưu số buổi.\n'
                            '• Yêu cầu bảo lưu gói tập từ 15 ngày trở lên cần xác nhận tại quầy lễ tân hoặc hỗ trợ trực tuyến.',
                      ),
                      const SizedBox(height: 10),
                      const _LegalSectionCard(
                        title: '3. An toàn tập luyện & Khai báo sức khỏe',
                        body: 'Hội viên cam kết khai báo trung thực các chỉ số cơ thể, tiền sử chấn thương và bệnh nền trong mục Khai báo thể trạng (PAR-Q) để Huấn luyện viên xây dựng giáo án an toàn, phù hợp nhất.',
                      ),
                      const SizedBox(height: 10),
                      const _LegalSectionCard(
                        title: '4. Quyền sở hữu & Liên hệ pháp lý',
                        body: 'Toàn bộ giáo trình, bài viết dinh dưỡng và thương hiệu thuộc quyền sở hữu của Meta Gym Studio. Mọi câu hỏi xin gửi về legal@metagym.vn.',
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
                      key: const Key('terms-accept-btn'),
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

class _LegalSectionCard extends StatelessWidget {
  const _LegalSectionCard({required this.title, required this.body});

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
