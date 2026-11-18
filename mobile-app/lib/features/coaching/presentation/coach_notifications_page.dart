import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/features/auth/domain/auth_models.dart';
import 'package:meta_gym_app/features/auth/presentation/session_controller.dart';
import 'package:meta_gym_app/features/coaching/data/coach_v2_api.dart';
import 'package:meta_gym_app/features/coaching/presentation/coaching_ui.dart';
import 'package:provider/provider.dart';

class CoachNotificationsPage extends StatefulWidget {
  const CoachNotificationsPage({this.coachRole = false, super.key});

  final bool coachRole;

  @override
  State<CoachNotificationsPage> createState() => _CoachNotificationsPageState();
}

class _CoachNotificationsPageState extends State<CoachNotificationsPage> {
  late final _api = CoachV2Api(context.read<ApiClient>());
  late Future<List<CoachRecord>> _items = _api.list('/coach-notifications');
  bool _saving = false;

  bool get _isCoachRole =>
      widget.coachRole ||
      optionalProvider<SessionController>(context)?.user?.role ==
          UserRole.coach;

  Future<void> _reload() async {
    final future = _api.list('/coach-notifications');
    setState(() {
      _items = future;
    });
    try {
      await future;
    } catch (_) {}
  }

  Future<void> _read(CoachRecord item) async {
    if (_saving || item['readAt'] != null) return;
    setState(() => _saving = true);
    try {
      await _api.patch('/coach-notifications/${item['id']}/read', {});
      if (mounted) await _reload();
    } on ApiException catch (error) {
      if (mounted) showCoachingSnackBar(context, error.message);
    } catch (_) {
      if (mounted) {
        showCoachingSnackBar(context, 'Không cập nhật được trạng thái đã đọc.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _markAllRead(List<CoachRecord> items) async {
    final unread = items.where((item) => item['readAt'] == null).toList();
    if (_saving || unread.isEmpty) return;
    setState(() => _saving = true);
    try {
      for (final item in unread) {
        await _api.patch('/coach-notifications/${item['id']}/read', {});
      }
      if (mounted) {
        await _reload();
        if (mounted) {
          showCoachingSnackBar(context, 'Đã đánh dấu tất cả là đã đọc.');
        }
      }
    } on ApiException catch (error) {
      if (mounted) showCoachingSnackBar(context, error.message);
    } catch (_) {
      if (mounted) {
        showCoachingSnackBar(context, 'Không cập nhật được trạng thái đã đọc.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _titleForKind(Object? kind) {
    if (_isCoachRole) {
      return switch (kind) {
        'BOOKED' => 'Học viên vừa đặt lịch dạy 90 phút',
        'COMPLETED' => 'Buổi dạy 90 phút đã hoàn tất',
        'CANCELLED' => 'Buổi dạy đã hủy hoặc đổi lịch',
        'PACKAGE_ACTIVE' => 'Gói PT của học viên đã kích hoạt',
        'PACKAGE_QUEUED' => 'Học viên có gói PT chờ nối tiếp',
        'PACKAGE_EXTENDED' => 'Gói PT học viên được gia hạn 7 ngày',
        'PACKAGE_LAST_SESSION' => 'Học viên còn 1 buổi PT cuối',
        'PACKAGE_ENDED' => 'Gói PT của học viên đã kết thúc',
        'PACKAGE_EXPIRING' => 'Gói PT học viên còn tối đa 7 ngày',
        _ => 'Có cập nhật mới từ học viên',
      };
    }
    return switch (kind) {
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
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();

    return Scaffold(
      backgroundColor: MetaGymTheme.darkCanvas,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leadingWidth: canPop ? 68 : null,
        leading: canPop
            ? Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Center(
                  child: Tooltip(
                    message: 'Back',
                    child: MetaGymCircleIconButton(
                      icon: Icons.arrow_back_rounded,
                      tooltip: 'Quay lại',
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                ),
              )
            : null,
        title: const Text(
          'Thông báo Coach',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: MetaGymTheme.textPrimary,
            fontSize: 19,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: MetaGymCircleIconButton(
                icon: Icons.refresh_rounded,
                tooltip: 'Tải lại',
                onTap: _saving ? null : _reload,
              ),
            ),
          ),
        ],
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: MetaGymTheme.textPrimary),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const MetaGymBackground(),
          SafeArea(
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
                  final message = error is ApiException
                      ? error.message
                      : 'Không tải được thông báo.';
                  return RefreshIndicator(
                    color: MetaGymTheme.brandOrange,
                    backgroundColor: MetaGymTheme.cardSurface,
                    onRefresh: _reload,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                      children: [
                        CoachingErrorBanner(message: message),
                        CoachingSecondaryButton(
                          label: 'Thử lại',
                          expand: true,
                          onPressed: _reload,
                        ),
                      ],
                    ),
                  );
                }

                final items = snapshot.data ?? const [];
                final unreadCount = items
                    .where((item) => item['readAt'] == null)
                    .length;

                if (items.isEmpty) {
                  return RefreshIndicator(
                    color: MetaGymTheme.brandOrange,
                    backgroundColor: MetaGymTheme.cardSurface,
                    onRefresh: _reload,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                      children: const [
                        MetaGymHeroGlassCard(
                          padding: EdgeInsets.all(20),
                          child: Row(
                            children: [
                              Icon(
                                Icons.notifications_none_rounded,
                                color: MetaGymTheme.brandOrange,
                                size: 24,
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Chưa có thông báo.',
                                      style: TextStyle(
                                        color: MetaGymTheme.textPrimary,
                                        fontSize: 15.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Các cập nhật lịch tập và gói Coach sẽ xuất hiện tại đây.',
                                      style: TextStyle(
                                        color: Color(0xFFBEC3CB),
                                        fontSize: 12.5,
                                        height: 1.45,
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

                return RefreshIndicator(
                  color: MetaGymTheme.brandOrange,
                  backgroundColor: MetaGymTheme.cardSurface,
                  onRefresh: _reload,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                    itemCount: items.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return MetaGymHeroGlassCard(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _NotificationMetric(
                                      label: 'Chưa đọc',
                                      value: '$unreadCount',
                                      accent: unreadCount > 0,
                                    ),
                                  ),
                                  Container(
                                    width: 1,
                                    height: 40,
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                    ),
                                    color: const Color(0x26FFFFFF),
                                  ),
                                  Expanded(
                                    child: _NotificationMetric(
                                      label: 'Tổng thông báo',
                                      value: '${items.length}',
                                    ),
                                  ),
                                ],
                              ),
                              if (unreadCount > 0) ...[
                                const SizedBox(height: 12),
                                CoachingCompactAccentButton(
                                  label: _saving
                                      ? 'Đang cập nhật…'
                                      : 'Đánh dấu tất cả đã đọc',
                                  icon: Icons.done_all_rounded,
                                  expand: true,
                                  loading: _saving,
                                  onPressed: _saving
                                      ? null
                                      : () => _markAllRead(items),
                                ),
                              ],
                            ],
                          ),
                        );
                      }

                      final item = items[index - 1];
                      final unread = item['readAt'] == null;
                      final createdAt = item['createdAt'] as String?;

                      return CoachingGraphiteCard(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        borderColor: unread
                            ? MetaGymTheme.primary.withValues(alpha: 0.45)
                            : MetaGymTheme.cardBorder,
                        onTap: unread && !_saving ? () => _read(item) : null,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: unread
                                    ? const Color(0x24FF5E36)
                                    : MetaGymTheme.elevatedSurface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: unread
                                      ? const Color(0x55FF5E36)
                                      : MetaGymTheme.cardBorder,
                                ),
                              ),
                              child: Icon(
                                unread
                                    ? Icons.notifications_active_outlined
                                    : Icons.notifications_none_rounded,
                                color: unread
                                    ? MetaGymTheme.brandOrange
                                    : MetaGymTheme.textSecondary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _titleForKind(item['kind']),
                                          style: TextStyle(
                                            color: MetaGymTheme.textPrimary,
                                            fontWeight: unread
                                                ? FontWeight.w700
                                                : FontWeight.w600,
                                            fontSize: 14.5,
                                          ),
                                        ),
                                      ),
                                      if (unread) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          width: 8,
                                          height: 8,
                                          margin: const EdgeInsets.only(top: 6),
                                          decoration: const BoxDecoration(
                                            color: MetaGymTheme.brandOrange,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      CoachingPill(
                                        label: unread
                                            ? 'Chưa đọc · Chạm để đánh dấu'
                                            : 'Đã đọc',
                                        tone: unread
                                            ? CoachingPillTone.coral
                                            : CoachingPillTone.neutral,
                                      ),
                                      if (createdAt != null &&
                                          createdAt.isNotEmpty)
                                        Text(
                                          formatVietnamTime(createdAt),
                                          style: const TextStyle(
                                            color: MetaGymTheme.textSecondary,
                                            fontSize: 12,
                                            fontFeatures:
                                                MetaGymTheme.tabularFigures,
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationMetric extends StatelessWidget {
  const _NotificationMetric({
    required this.label,
    required this.value,
    this.accent = false,
  });

  final String label;
  final String value;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFFBEC3CB), fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: accent ? MetaGymTheme.brandOrange : MetaGymTheme.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.w800,
            fontFeatures: MetaGymTheme.tabularFigures,
          ),
        ),
      ],
    );
  }
}
