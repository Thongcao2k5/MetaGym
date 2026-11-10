import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:meta_gym_app/app/app_router.dart';
import 'package:meta_gym_app/app/feature_navigation.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/features/auth/presentation/session_controller.dart';
import 'package:meta_gym_app/features/workbench/flow_workbench_config.dart';
import 'package:provider/provider.dart';

class CoachHomePage extends StatelessWidget {
  const CoachHomePage({super.key});

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF162232),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Đăng xuất Coach',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Bạn có chắc chắn muốn đăng xuất khỏi tài khoản Huấn luyện viên không?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy', style: TextStyle(color: Colors.white60)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFF453A),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await context.read<SessionController>().signOut();
    }
  }

  IconData _iconForTitle(String title) {
    if (title.contains('Yêu cầu')) return Icons.pending_actions_rounded;
    if (title.contains('Hội viên')) return Icons.people_alt_rounded;
    if (title.contains('Giáo trình')) return Icons.menu_book_rounded;
    if (title.contains('Dinh dưỡng')) return Icons.restaurant_menu_rounded;
    if (title.contains('Lịch tập')) return Icons.calendar_month_rounded;
    if (title.contains('Tiến độ')) return Icons.insights_rounded;
    if (title.contains('Tin nhắn')) return Icons.chat_bubble_outline_rounded;
    if (title.contains('Cuộc gọi')) return Icons.call_outlined;
    if (title.contains('Trợ lý')) return Icons.auto_awesome;
    if (title.contains('Phòng gym')) return Icons.fitness_center_rounded;
    return Icons.arrow_forward_ios_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<SessionController>().user;
    final sections = coachDestinations.map((item) => item.section).toSet();

    return Scaffold(
      backgroundColor: MetaGymTheme.darkCanvas,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Coach',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.3,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Color(0xFFFF6961)),
            tooltip: 'Đăng xuất',
            onPressed: () => _confirmSignOut(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const MetaGymBackground(),
          SafeArea(
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                // 1. Thẻ chào mừng HLV
                MetaGymGlassCard(
                  padding: const EdgeInsets.all(18),
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF7E58), Color(0xFFFF4820)],
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0x66FFFFFF),
                            width: 1.5,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          (user?.fullName.isNotEmpty == true)
                              ? user!.fullName[0].toUpperCase()
                              : 'C',
                          style: const TextStyle(
                            color: Color(0xFF111317),
                            fontWeight: FontWeight.w800,
                            fontSize: 22,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.fullName ?? 'Huấn luyện viên',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 17,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              user?.email ?? 'c@c.com',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2.5,
                              ),
                              decoration: BoxDecoration(
                                color: MetaGymTheme.brandOrange.withValues(
                                  alpha: 0.2,
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'HUẤN LUYỆN VIÊN CHUYÊN NGHIỆP',
                                style: TextStyle(
                                  color: MetaGymTheme.brandOrange,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10.5,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Tiêu đề bắt buộc cho test finder
                Padding(
                  padding: const EdgeInsets.only(bottom: 12, top: 4),
                  child: Text(
                    'Không gian dành cho huấn luyện viên',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                // Danh mục các tính năng theo từng Section
                for (final section in sections) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 10, bottom: 8),
                    child: Text(
                      section,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white70,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  for (final destination in coachDestinations.where(
                    (item) => item.section == section,
                  ))
                    MetaGymGlassCard(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: MetaGymTheme.brandOrange.withValues(
                              alpha: 0.18,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            _iconForTitle(destination.title),
                            color: MetaGymTheme.brandOrange,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          destination.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        subtitle: Text(
                          'Giao diện cơ bản: ${destination.task}',
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 12,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.chevron_right,
                          color: Colors.white54,
                          size: 20,
                        ),
                        onTap: () => context.push(destination.path),
                      ),
                    ),
                ],

                // Hồ sơ của tôi
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 8),
                  child: const Text(
                    'Tài khoản cá nhân',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                MetaGymGlassCard(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0x338EB9E5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.person_outline_rounded,
                        color: Color(0xFF8EB9E5),
                        size: 20,
                      ),
                    ),
                    title: const Text(
                      'Hồ sơ của tôi',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: Colors.white54,
                      size: 20,
                    ),
                    onTap: () => context.push(AppRoutes.profile),
                  ),
                ),

                if (FlowWorkbenchConfig.enabled)
                  Padding(
                    padding: const EdgeInsets.only(top: 6, bottom: 12),
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: MetaGymTheme.brandOrange,
                        side: const BorderSide(color: Color(0x4DFF5A36)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () => context.push(AppRoutes.coachWorkbench),
                      child: const Text(
                        'Kiểm thử các luồng Coach',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),

                const SizedBox(height: 8),
                // Nút Đăng xuất ở chân trang
                MetaGymGlassCard(
                  margin: const EdgeInsets.only(bottom: 24),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0x33FF453A),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.logout_rounded,
                        color: Color(0xFFFF6961),
                        size: 20,
                      ),
                    ),
                    title: const Text(
                      'Đăng xuất tài khoản Coach',
                      style: TextStyle(
                        color: Color(0xFFFF6961),
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    subtitle: const Text(
                      'Thoát phiên đăng nhập hiện tại',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    onTap: () => _confirmSignOut(context),
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
