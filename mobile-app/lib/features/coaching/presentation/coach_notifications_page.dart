import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/features/coaching/data/coach_v2_api.dart';
import 'package:meta_gym_app/features/coaching/presentation/coaching_ui.dart';
import 'package:provider/provider.dart';

class CoachNotificationsPage extends StatefulWidget {
  const CoachNotificationsPage({super.key});

  @override
  State<CoachNotificationsPage> createState() => _CoachNotificationsPageState();
}

class _CoachNotificationsPageState extends State<CoachNotificationsPage> {
  late final _api = CoachV2Api(context.read<ApiClient>());
  late Future<List<CoachRecord>> _items = _api.list('/coach-notifications');
  bool _saving = false;

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

  Future<void> _markAllAsRead(List<CoachRecord> items) async {
    final unreadItems = items
        .where((item) => item['readAt'] == null && item['id'] != null)
        .toList();
    if (_saving || unreadItems.isEmpty) return;
    setState(() => _saving = true);
    try {
      for (final item in unreadItems) {
        await _api.patch('/coach-notifications/${item['id']}/read', {});
      }
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

  IconData _iconForKind(Object? kind, {required bool unread}) => switch (kind) {
    'BOOKED' => Icons.event_available_rounded,
    'COMPLETED' => Icons.task_alt_rounded,
    'CANCELLED' => Icons.event_busy_rounded,
    'PACKAGE_ACTIVE' => Icons.verified_rounded,
    'PACKAGE_QUEUED' => Icons.hourglass_top_rounded,
    'PACKAGE_EXTENDED' => Icons.update_rounded,
    'PACKAGE_LAST_SESSION' || 'PACKAGE_EXPIRING' => Icons.schedule_rounded,
    'PACKAGE_ENDED' => Icons.inventory_2_outlined,
    _ =>
      unread
          ? Icons.notifications_active_outlined
          : Icons.notifications_none_rounded,
  };

  Color _accentForKind(Object? kind, {required bool unread}) {
    if (!unread) return MetaGymTheme.textSecondary;
    return switch (kind) {
      'COMPLETED' || 'PACKAGE_ACTIVE' => MetaGymTheme.success,
      'CANCELLED' => MetaGymTheme.dangerCoral,
      'PACKAGE_LAST_SESSION' || 'PACKAGE_EXPIRING' => MetaGymTheme.warning,
      _ => MetaGymTheme.brandOrange,
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
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Thông báo',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: MetaGymTheme.textPrimary,
                fontSize: 18.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'Thông báo Coach',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Color(0xFFC8C2BC),
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
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
                      children: [
                        MetaGymHeroGlassCard(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: const Color(0x26FF5E36),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: const Color(0x66FF5E36),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.notifications_none_rounded,
                                  color: MetaGymTheme.brandOrange,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 14),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Chưa có thông báo.',
                                      style: TextStyle(
                                        color: MetaGymTheme.textPrimary,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Các cập nhật lịch tập và gói Coach sẽ xuất hiện tại đây.',
                                      style: TextStyle(
                                        color: Color(0xFFC8C2BC),
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
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: MetaGymMetricPanel(
                                      child: _NotificationMetric(
                                        label: 'Chưa đọc',
                                        value: '$unreadCount',
                                        accent: unreadCount > 0,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: MetaGymMetricPanel(
                                      child: _NotificationMetric(
                                        label: 'Tổng thông báo',
                                        value: '${items.length}',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (unreadCount > 0) ...[
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  height: 44,
                                  child: OutlinedButton.icon(
                                    onPressed: _saving
                                        ? null
                                        : () => _markAllAsRead(items),
                                    icon: const Icon(
                                      Icons.done_all_rounded,
                                      size: 18,
                                      color: MetaGymTheme.brandOrange,
                                    ),
                                    label: const Text(
                                      'Đánh dấu đã đọc hết',
                                      style: TextStyle(
                                        color: MetaGymTheme.textPrimary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      backgroundColor: const Color(0x22FF5E36),
                                      side: const BorderSide(
                                        color: Color(0x66FF5E36),
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      }

                      final item = items[index - 1];
                      final unread = item['readAt'] == null;
                      final createdAt = item['createdAt'] as String?;
                      final kind = item['kind'];
                      final accentColor = _accentForKind(kind, unread: unread);

                      return CoachingGraphiteCard(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(15),
                        backgroundColor: unread
                            ? const Color(0xE628221E)
                            : const Color(0xD8211E1C),
                        borderColor: unread
                            ? MetaGymTheme.brandOrange.withValues(alpha: 0.55)
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
                                    ? accentColor.withValues(alpha: 0.16)
                                    : MetaGymTheme.elevatedSurface,
                                borderRadius: BorderRadius.circular(13),
                                border: Border.all(
                                  color: unread
                                      ? accentColor.withValues(alpha: 0.45)
                                      : MetaGymTheme.cardBorder,
                                ),
                              ),
                              child: Icon(
                                _iconForKind(kind, unread: unread),
                                color: accentColor,
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
                                          _titleForKind(kind),
                                          style: TextStyle(
                                            color: MetaGymTheme.textPrimary,
                                            fontWeight: unread
                                                ? FontWeight.w700
                                                : FontWeight.w600,
                                            fontSize: 14.5,
                                            height: 1.35,
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
                                            boxShadow: [
                                              BoxShadow(
                                                color: Color(0x66FF5E36),
                                                blurRadius: 6,
                                              ),
                                            ],
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
                                            color: Color(0xFFC8C2BC),
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
          style: const TextStyle(
            color: Color(0xFFC8C2BC),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
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
