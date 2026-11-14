import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/features/coaching/data/coach_v2_api.dart';
import 'package:provider/provider.dart';

/// Màn hình Thông báo Coach đồng bộ bảng màu & định dạng thẻ
/// với Trang chủ Hội viên (`member_dashboard_view.dart`) và Hồ sơ (`profile_page.dart`).
class CoachNotificationsPage extends StatefulWidget {
  const CoachNotificationsPage({super.key});

  @override
  State<CoachNotificationsPage> createState() => _CoachNotificationsPageState();
}

class _CoachNotificationsPageState extends State<CoachNotificationsPage> {
  late final _api = CoachV2Api(context.read<ApiClient>());
  late var _items = _api.list('/coach-notifications');
  bool _saving = false;

  void _reload() => setState(() => _items = _api.list('/coach-notifications'));

  Future<void> _read(CoachRecord item) async {
    if (_saving || item['readAt'] != null) return;
    setState(() => _saving = true);
    try {
      await _api.patch('/coach-notifications/${item['id']}/read', {});
      if (mounted) _reload();
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _titleForKind(Object? kind) => switch (kind) {
    'BOOKED' => 'Có lịch tập mới với Coach',
    'COMPLETED' => 'Coach đã xác nhận buổi tập',
    'CANCELLED' => 'Lịch tập đã hủy hoặc thay đổi',
    'PACKAGE_ACTIVE' => 'Gói Coach đã kích hoạt',
    'PACKAGE_QUEUED' => 'Gói Coach đang chờ kích hoạt',
    'PACKAGE_EXTENDED' => 'Gói Coach được thêm 7 ngày',
    'PACKAGE_LAST_SESSION' => 'Gói Coach còn 1 buổi',
    'PACKAGE_ENDED' => 'Gói Coach đã kết thúc',
    'PACKAGE_EXPIRING' => 'Gói Coach còn tối đa 7 ngày',
    _ => 'Có cập nhật về Coach',
  };

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: MetaGymTheme.scaffoldBackground,
    body: Stack(
      fit: StackFit.expand,
      children: [
        const MetaGymBackground(),
        SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                child: Row(
                  children: [
                    if (Navigator.of(context).canPop()) ...[
                      MetaGymCircleIconButton(
                        icon: Icons.arrow_back_rounded,
                        tooltip: 'Quay lại',
                        onTap: () => Navigator.of(context).maybePop(),
                      ),
                      const SizedBox(width: 12),
                    ],
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'THÔNG BÁO & LỊCH TẬP',
                            style: TextStyle(
                              color: Color(0xFFB7B2AF),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.0,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Thông báo Coach',
                            style: TextStyle(
                              color: Color(0xFFF7F9FC),
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    MetaGymCircleIconButton(
                      icon: Icons.refresh_rounded,
                      tooltip: 'Tải lại',
                      onTap: _reload,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: FutureBuilder<List<CoachRecord>>(
                  future: _items,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: MetaGymTheme.brandOrange,
                        ),
                      );
                    }
                    if (snapshot.hasError) {
                      final error = snapshot.error;
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: MetaGymGlassCard(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.error_outline_rounded,
                                  color: Color(0xFFF15B64),
                                  size: 28,
                                ),
                                const SizedBox(height: 10),
                                TextButton(
                                  onPressed: _reload,
                                  child: Text(
                                    error is ApiException
                                        ? '${error.message} · Thử lại'
                                        : 'Không tải được thông báo · Thử lại',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: MetaGymTheme.brandOrange,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }
                    final items = snapshot.data!;
                    final unreadCount = items
                        .where((item) => item['readAt'] == null)
                        .length;

                    if (items.isEmpty) {
                      return ListView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                        children: const [
                          MetaGymHeroGlassCard(
                            child: Row(
                              children: [
                                Icon(
                                  Icons.notifications_none_rounded,
                                  color: MetaGymTheme.brandOrange,
                                  size: 22,
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Chưa có thông báo.',
                                    style: TextStyle(
                                      color: Color(0xFFF7F9FC),
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                      itemCount: items.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return MetaGymHeroGlassCard(
                            margin: const EdgeInsets.only(bottom: 16),
                            child: Row(
                              children: [
                                Expanded(
                                  child: MetaGymMetricPanel(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Chưa đọc',
                                          style: TextStyle(
                                            color: Color(0xFFB7B2AF),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '$unreadCount',
                                          style: const TextStyle(
                                            color: MetaGymTheme.brandOrange,
                                            fontSize: 26,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: MetaGymMetricPanel(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Tổng thông báo',
                                          style: TextStyle(
                                            color: Color(0xFFB7B2AF),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${items.length}',
                                          style: const TextStyle(
                                            color: Color(0xFFF7F9FC),
                                            fontSize: 26,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        final item = items[index - 1];
                        final unread = item['readAt'] == null;
                        return MetaGymGlassCard(
                          featured: unread,
                          margin: const EdgeInsets.only(bottom: 10),
                          child: InkWell(
                            onTap: unread && !_saving
                                ? () => _read(item)
                                : null,
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: unread
                                          ? const Color(0x24FF5A36)
                                          : const Color(0x80211E1C),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: unread
                                            ? const Color(0x4DFF5A36)
                                            : const Color(0x9A8C8176),
                                      ),
                                    ),
                                    child: Icon(
                                      unread
                                          ? Icons.notifications_active_outlined
                                          : Icons.notifications_none,
                                      color: unread
                                          ? MetaGymTheme.brandOrange
                                          : const Color(0xFFB7B2AF),
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _titleForKind(item['kind']),
                                          style: TextStyle(
                                            color: const Color(0xFFF7F9FC),
                                            fontWeight: unread
                                                ? FontWeight.w700
                                                : FontWeight.w600,
                                            fontSize: 14.5,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          unread
                                              ? 'Chưa đọc · Chạm để đánh dấu đã đọc'
                                              : 'Đã đọc',
                                          style: TextStyle(
                                            color: unread
                                                ? MetaGymTheme.brandOrange
                                                : const Color(0xFFB7B2AF),
                                            fontSize: 12.5,
                                            fontWeight: unread
                                                ? FontWeight.w600
                                                : FontWeight.w400,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (unread)
                                    Container(
                                      width: 9,
                                      height: 9,
                                      decoration: const BoxDecoration(
                                        color: MetaGymTheme.brandOrange,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
