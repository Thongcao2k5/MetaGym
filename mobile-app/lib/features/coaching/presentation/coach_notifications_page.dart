import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:meta_gym_app/core/theme/meta_gym_icons.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_icon.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_tap.dart';
import 'package:meta_gym_app/features/coaching/data/coach_v2_api.dart';
import 'package:meta_gym_app/features/coaching/presentation/coaching_ui.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_svg_icon.dart';

enum _NotificationFilter { all, unread, session, package }

/// Màn hình **5.10 Thông báo** đồng bộ `tab5-profile-sub.js` (`member-notifications`)
/// và chuẩn Warm Smoked Liquid Glass (Dark + Light Daylight Studio).
class CoachNotificationsPage extends StatefulWidget {
  const CoachNotificationsPage({this.apiClient, this.now, super.key});

  final ApiClient? apiClient;
  final DateTime Function()? now;

  @override
  State<CoachNotificationsPage> createState() => _CoachNotificationsPageState();
}

class _CoachNotificationsPageState extends State<CoachNotificationsPage> {
  ApiClient? _client;
  CoachV2Api? _api;
  bool _initialized = false;
  bool _loading = true;
  bool _saving = false;
  String? _loadError;
  String? _actionError;
  List<CoachRecord> _records = const [];
  _NotificationFilter _filter = _NotificationFilter.all;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final client = widget.apiClient ?? optionalProvider<ApiClient>(context);
    if (_initialized && identical(client, _client)) return;
    _bindClient(client);
  }

  @override
  void didUpdateWidget(covariant CoachNotificationsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.apiClient != widget.apiClient) {
      final client = widget.apiClient ?? optionalProvider<ApiClient>(context);
      if (!identical(client, _client)) {
        _bindClient(client);
      }
    }
  }

  void _bindClient(ApiClient? client) {
    _initialized = true;
    _client = client;
    _records = const [];
    _actionError = null;
    _filter = _NotificationFilter.all;
    if (client != null) {
      _api = CoachV2Api(client);
      _loading = true;
      _loadError = null;
      _fetchNotifications();
    } else {
      _api = null;
      _loading = false;
      _loadError = 'Không tải được thông báo.';
    }
  }

  DateTime _nowVietnam() {
    final current = (widget.now?.call() ?? DateTime.now()).toUtc();
    return current.add(const Duration(hours: 7));
  }

  DateTime? _parseVietnamDateTime(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final parsed = DateTime.tryParse(raw.trim());
    if (parsed == null) return null;
    return parsed.isUtc ? parsed.add(const Duration(hours: 7)) : parsed;
  }

  String? _timestampRaw(CoachRecord item) {
    final createdAt = item['createdAt'] as String?;
    if (createdAt != null && createdAt.trim().isNotEmpty) return createdAt;
    final eventAt = item['eventAt'] as String?;
    if (eventAt != null && eventAt.trim().isNotEmpty) return eventAt;
    return null;
  }

  bool _isUnread(CoachRecord item) => item['readAt'] == null;

  bool _isToday(CoachRecord item) {
    final parsed = _parseVietnamDateTime(_timestampRaw(item));
    if (parsed == null) return _isUnread(item);
    final now = _nowVietnam();
    return parsed.year == now.year &&
        parsed.month == now.month &&
        parsed.day == now.day;
  }

  String _formatTimestamp(CoachRecord item) {
    final raw = _timestampRaw(item);
    final parsed = _parseVietnamDateTime(raw);
    if (parsed == null) {
      return raw == null || raw.trim().isEmpty ? '' : raw.trim();
    }
    final now = _nowVietnam();
    final sameDay =
        parsed.year == now.year &&
        parsed.month == now.month &&
        parsed.day == now.day;
    final diff = now.difference(parsed);

    if (sameDay && !diff.isNegative) {
      if (diff.inMinutes < 1) return 'Vừa xong';
      if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
      if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    }
    if (sameDay) {
      return DateFormat('HH:mm').format(parsed);
    }
    if (parsed.year == now.year) {
      return DateFormat('dd/MM').format(parsed);
    }
    return DateFormat('dd/MM/yy').format(parsed);
  }

  Future<void> _load({bool initial = false}) async {
    final api = _api;
    if (api == null) return;
    if (initial || _records.isEmpty) {
      setState(() {
        _loading = true;
        _loadError = null;
        _actionError = null;
      });
    } else {
      setState(() {
        _actionError = null;
      });
    }
    await _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    final api = _api;
    if (api == null) return;
    try {
      final list = await api.list('/coach-notifications');
      if (!mounted || !identical(api, _api)) return;
      setState(() {
        _records = list;
        _loadError = null;
        _actionError = null;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted || !identical(api, _api)) return;
      setState(() {
        _loading = false;
        if (_records.isEmpty) {
          _loadError = error.message;
        } else {
          _actionError = error.message;
        }
      });
    } catch (_) {
      if (!mounted || !identical(api, _api)) return;
      setState(() {
        _loading = false;
        if (_records.isEmpty) {
          _loadError = 'Không tải được thông báo.';
        } else {
          _actionError = 'Không tải lại được thông báo.';
        }
      });
    }
  }

  Future<void> _read(CoachRecord item) async {
    final api = _api;
    if (api == null || _saving || !_isUnread(item) || item['id'] == null) {
      return;
    }
    setState(() {
      _saving = true;
      _actionError = null;
    });
    try {
      await api.patch('/coach-notifications/${item['id']}/read', {});
      if (mounted) await _load();
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

  Future<void> _markAllAsRead() async {
    final api = _api;
    final unreadItems = _records
        .where((item) => _isUnread(item) && item['id'] != null)
        .toList();
    if (api == null || _saving || unreadItems.isEmpty) return;
    setState(() {
      _saving = true;
      _actionError = null;
    });
    var updatedAny = false;
    try {
      for (final item in unreadItems) {
        await api.patch('/coach-notifications/${item['id']}/read', {});
        updatedAny = true;
      }
      if (mounted) {
        await _load();
        if (mounted) {
          showCoachingSnackBar(context, 'Đã đánh dấu tất cả thông báo đã đọc.');
        }
      }
    } on ApiException catch (error) {
      if (mounted) {
        if (updatedAny) await _load();
        if (mounted) showCoachingSnackBar(context, error.message);
      }
    } catch (_) {
      if (mounted) {
        if (updatedAny) await _load();
        if (mounted) {
          showCoachingSnackBar(
            context,
            'Không cập nhật được trạng thái đã đọc.',
          );
        }
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _titleForRecord(CoachRecord item) {
    final customTitle = item['title'] as String?;
    if (customTitle != null && customTitle.trim().isNotEmpty) {
      return customTitle.trim();
    }
    return _titleForKind(item['kind']);
  }

  String _titleForKind(Object? kind) => switch (kind) {
    'BOOKED' => 'Có lịch tập mới với Coach',
    'COMPLETED' => 'Coach đã xác nhận buổi tập',
    'CANCELLED' => 'Lịch tập đã hủy hoặc thay đổi',
    'NO_SHOW' => 'Buổi tập ghi nhận vắng mặt',
    'RESCHEDULED' => 'Lịch tập đã được dời giờ',
    'NUTRITION_UPDATED' || 'MEAL_PLAN_UPDATED' => 'Coach đã cập nhật thực đơn',
    'PACKAGE_ACTIVE' => 'Gói Coach đã kích hoạt',
    'PACKAGE_QUEUED' => 'Gói Coach đang chờ kích hoạt',
    'PACKAGE_EXTENDED' => 'Gói Coach được thêm 7 ngày',
    'PACKAGE_LAST_SESSION' => 'Gói Coach còn 1 buổi',
    'PACKAGE_ENDED' => 'Gói Coach đã kết thúc',
    'PACKAGE_EXPIRING' => 'Gói Coach còn tối đa 7 ngày',
    'COACH_LOCKED' => 'Tài khoản Coach đang tạm khóa',
    'COACH_UNLOCKED_RESTORED' => 'Coach đã hoạt động trở lại',
    'MEMBER_LOCKED' => 'Tài khoản hội viên đang tạm khóa',
    'MEMBER_UNLOCKED_RESTORED' => 'Tài khoản đã được mở khóa',
    'TERMINATION_REQUESTED' => 'Có yêu cầu kết thúc sớm',
    'TERMINATION_ACCEPTED' => 'Đã đồng ý kết thúc sớm',
    'TERMINATION_WITHDRAWN' => 'Yêu cầu kết thúc sớm đã rút',
    'TERMINATION_DISPUTED' => 'Yêu cầu đang chờ Admin phân xử',
    'TERMINATION_ADMIN_APPROVED' => 'Admin đã duyệt kết thúc sớm',
    'TERMINATION_ADMIN_REJECTED' => 'Admin từ chối yêu cầu kết thúc sớm',
    'COACH_TRANSFERRED' => 'Đã chuyển đổi Coach đồng hành',
    'SIMULATED_REFUND_COMPLETED' => 'Hoàn tiền mô phỏng hoàn tất',
    _ => 'Có cập nhật về Coach',
  };

  String _descriptionForRecord(CoachRecord item) {
    for (final key in const ['body', 'message', 'description']) {
      final raw = item[key] as String?;
      if (raw != null && raw.trim().isNotEmpty) return raw.trim();
    }
    return switch (item['kind']) {
      'BOOKED' => 'Buổi tập 1:1 với Coach đã được ghi nhận. Kiểm tra khung giờ trong mục Lịch hẹn.',
      'COMPLETED' =>
        'Buổi tập đã hoàn tất và cập nhật vào số buổi còn lại trong gói Coach.',
      'CANCELLED' => 'Một buổi tập với Coach đã hủy hoặc thay đổi. Bạn có thể đặt lại khung giờ phù hợp.',
      'NO_SHOW' => 'Buổi tập đã qua giờ hẹn và được ghi nhận vắng mặt theo quy định gói tập.',
      'RESCHEDULED' => 'Khung giờ buổi tập 1:1 vừa được cập nhật. Xem chi tiết trong mục Lịch hẹn.',
      'NUTRITION_UPDATED' || 'MEAL_PLAN_UPDATED' =>
        'Thực đơn dinh dưỡng cá nhân hóa đã sẵn sàng trong mục Dinh dưỡng.',
      'PACKAGE_ACTIVE' => 'Gói huấn luyện 1:1 đã kích hoạt. Bạn có thể bắt đầu đặt lịch tập cùng Coach.',
      'PACKAGE_QUEUED' => 'Gói mới đã được xếp hàng và sẽ tự kích hoạt ngay sau khi gói hiện tại kết thúc.',
      'PACKAGE_EXTENDED' =>
        'Thời hạn sử dụng gói Coach của bạn vừa được cộng thêm 7 ngày.',
      'PACKAGE_LAST_SESSION' => 'Bạn còn 1 buổi trong gói hiện tại. Cân nhắc gia hạn để giữ nhịp tập luyện.',
      'PACKAGE_ENDED' =>
        'Gói huấn luyện 1:1 đã sử dụng hết số buổi hoặc kết thúc thời hạn.',
      'PACKAGE_EXPIRING' => 'Gói tập của bạn sắp hết hạn trong 7 ngày tới. Hãy hoàn thành các buổi còn lại.',
      'COACH_LOCKED' => 'Gói tập đã được đóng băng tự động. Vào Coach & Lịch hẹn để chọn phương án xử lý.',
      'COACH_UNLOCKED_RESTORED' =>
        'Quan hệ huấn luyện và gói tập của bạn đã được khôi phục bình thường.',
      'MEMBER_LOCKED' =>
        'Quan hệ huấn luyện đang tạm ngưng trong thời gian tài khoản tạm khóa.',
      'MEMBER_UNLOCKED_RESTORED' =>
        'Quan hệ huấn luyện đã được khôi phục và có thể tiếp tục đặt lịch.',
      'TERMINATION_REQUESTED' => 'Yêu cầu kết thúc sớm quan hệ Coach đang chờ phản hồi trong vòng 72 giờ.',
      'TERMINATION_ACCEPTED' =>
        'Hai bên đã xác nhận kết thúc sớm quan hệ huấn luyện 1:1.',
      'TERMINATION_WITHDRAWN' => 'Yêu cầu kết thúc sớm đã được rút lại; quan hệ Coach tiếp tục bình thường.',
      'TERMINATION_DISPUTED' =>
        'Yêu cầu kết thúc sớm đang được bộ phận quản trị xem xét và phản hồi.',
      'TERMINATION_ADMIN_APPROVED' =>
        'Quản trị viên đã phê duyệt yêu cầu kết thúc sớm quan hệ huấn luyện.',
      'TERMINATION_ADMIN_REJECTED' => 'Quản trị viên không chấp thuận kết thúc sớm; quan hệ Coach được giữ nguyên.',
      'COACH_TRANSFERRED' => 'Gói tập và lịch trình của bạn đã được chuyển sang Coach mới thành công.',
      'SIMULATED_REFUND_COMPLETED' =>
        'Yêu cầu hoàn giá trị các buổi tập chưa sử dụng đã được xử lý xong.',
      _ => 'Kiểm tra mục Coach & Lịch hẹn để xem thông tin chi tiết mới nhất.',
    };
  }

  String _svgAssetForKind(
    Object? kind, {
    required bool unread,
  }) => switch (kind) {
    'BOOKED' =>
      unread
          ? MetaGymIcons.commNotificationUnread
          : MetaGymIcons.actionSchedule,
    'RESCHEDULED' => MetaGymIcons.actionSchedule,
    'COMPLETED' ||
    'COACH_UNLOCKED_RESTORED' ||
    'MEMBER_UNLOCKED_RESTORED' ||
    'TERMINATION_ADMIN_APPROVED' => MetaGymIcons.stateSuccess,
    'NUTRITION_UPDATED' || 'MEAL_PLAN_UPDATED' => MetaGymIcons.actionNutrition,
    'PACKAGE_ACTIVE' => MetaGymIcons.paymentSuccess,
    'PACKAGE_QUEUED' => MetaGymIcons.membershipScheduled,
    'PACKAGE_EXTENDED' => MetaGymIcons.stateUpdate,
    'PACKAGE_LAST_SESSION' || 'PACKAGE_EXPIRING' => MetaGymIcons.timeAlarm,
    'PACKAGE_ENDED' => MetaGymIcons.coachPkg1on1,
    'CANCELLED' || 'TERMINATION_REQUESTED' => MetaGymIcons.coachingTermination,
    'NO_SHOW' || 'TERMINATION_DISPUTED' => MetaGymIcons.stateWarning,
    'COACH_LOCKED' => MetaGymIcons.coachingFreeze,
    'MEMBER_LOCKED' => MetaGymIcons.settingPrivacyLock,
    'COACH_TRANSFERRED' => MetaGymIcons.actionCoach,
    'SIMULATED_REFUND_COMPLETED' => MetaGymIcons.paymentRefundReversal,
    'TERMINATION_ACCEPTED' ||
    'TERMINATION_WITHDRAWN' ||
    'TERMINATION_ADMIN_REJECTED' => MetaGymIcons.stateInfo,
    _ =>
      unread
          ? MetaGymIcons.commNotificationUnread
          : MetaGymIcons.settingNotificationsBell,
  };

  Color _accentForKind(
    Object? kind,
    MetaGymColors colors, {
    required bool unread,
  }) {
    if (!unread) {
      return switch (kind) {
        'COMPLETED' ||
        'PACKAGE_ACTIVE' ||
        'NUTRITION_UPDATED' ||
        'MEAL_PLAN_UPDATED' ||
        'COACH_UNLOCKED_RESTORED' ||
        'MEMBER_UNLOCKED_RESTORED' ||
        'SIMULATED_REFUND_COMPLETED' => colors.success,
        'CANCELLED' || 'NO_SHOW' => colors.error,
        'PACKAGE_LAST_SESSION' ||
        'PACKAGE_EXPIRING' ||
        'COACH_LOCKED' ||
        'TERMINATION_DISPUTED' => colors.warning,
        _ => colors.textSecondary,
      };
    }
    return switch (kind) {
      'COMPLETED' ||
      'PACKAGE_ACTIVE' ||
      'NUTRITION_UPDATED' ||
      'MEAL_PLAN_UPDATED' ||
      'COACH_UNLOCKED_RESTORED' ||
      'MEMBER_UNLOCKED_RESTORED' ||
      'SIMULATED_REFUND_COMPLETED' => colors.success,
      'CANCELLED' ||
      'NO_SHOW' ||
      'MEMBER_LOCKED' ||
      'TERMINATION_REQUESTED' => colors.error,
      'PACKAGE_LAST_SESSION' ||
      'PACKAGE_EXPIRING' ||
      'COACH_LOCKED' ||
      'TERMINATION_DISPUTED' => colors.warning,
      _ => colors.primary,
    };
  }

  bool _matchesFilter(CoachRecord item) {
    final kind = (item['kind'] as String? ?? '').toUpperCase();
    return switch (_filter) {
      _NotificationFilter.all => true,
      _NotificationFilter.unread => _isUnread(item),
      _NotificationFilter.session =>
        kind == 'BOOKED' ||
            kind == 'COMPLETED' ||
            kind == 'CANCELLED' ||
            kind == 'NO_SHOW' ||
            kind == 'RESCHEDULED',
      _NotificationFilter.package =>
        kind.startsWith('PACKAGE_') ||
            kind.startsWith('COACH_') ||
            kind.startsWith('MEMBER_') ||
            kind.startsWith('TERMINATION_') ||
            kind == 'SIMULATED_REFUND_COMPLETED' ||
            kind == 'NUTRITION_UPDATED' ||
            kind == 'MEAL_PLAN_UPDATED',
    };
  }

  Widget _buildHeader(
    BuildContext context,
    MetaGymColors colors, {
    required int unreadCount,
    required bool hasItems,
  }) {
    final canPop = Navigator.of(context).canPop();
    final gutter = MediaQuery.sizeOf(context).width >= 600
        ? MetaGymTheme.tabletGutter
        : MetaGymTheme.pageGutter;

    return Padding(
      padding: EdgeInsets.fromLTRB(gutter, 8, gutter, 10),
      child: Row(
        children: [
          if (canPop) ...[
            _NotificationsBackButton(
              onTap: () => Navigator.of(context).maybePop(),
            ),
            const SizedBox(width: 11),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'META GYM',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.primaryText,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Thông báo',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  'Thông báo Coach',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          if (hasItems) ...[
            const SizedBox(width: 8),
            _MarkAllHeaderAction(
              key: const Key('notifications-mark-all-btn'),
              enabled: unreadCount > 0 && !_saving,
              busy: _saving,
              onTap: unreadCount > 0 && !_saving ? _markAllAsRead : null,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryStrip(
    MetaGymColors colors, {
    required int unreadCount,
    required int totalCount,
  }) {
    return MetaGymGlassCard(
      solid: false,
      key: const Key('notifications-summary-card'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: MetaGymMetricPanel(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: _NotificationMetric(
                label: 'Tổng thông báo',
                value: '$totalCount',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRow(MetaGymColors colors, {required int unreadCount}) {
    final filters = <(_NotificationFilter, String, Key)>[
      (_NotificationFilter.all, 'Tất cả', const Key('notif-filter-all')),
      (
        _NotificationFilter.unread,
        'Chưa đọc ($unreadCount)',
        const Key('notif-filter-unread'),
      ),
      (
        _NotificationFilter.session,
        'Lịch tập',
        const Key('notif-filter-session'),
      ),
      (
        _NotificationFilter.package,
        'Gói Coach',
        const Key('notif-filter-package'),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            for (var i = 0; i < filters.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              _NotificationFilterPill(
                key: filters[i].$3,
                label: filters[i].$2,
                selected: _filter == filters[i].$1,
                onTap: () => setState(() => _filter = filters[i].$1),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    MetaGymColors colors, {
    required String title,
    int? unreadBadgeCount,
    bool topTight = false,
  }) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Padding(
      padding: EdgeInsets.fromLTRB(2, topTight ? 2 : 12, 2, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (unreadBadgeCount != null && unreadBadgeCount > 0) ...[
            const SizedBox(width: 8),
            Container(
              key: const Key('notifications-unread-pill'),
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
              decoration: BoxDecoration(
                color: isLight
                    ? MetaGymTheme.brandOrange.withValues(alpha: 0.12)
                    : MetaGymTheme.brandOrange.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(MetaGymTheme.radiusFull),
                border: Border.all(
                  color: MetaGymTheme.brandOrange.withValues(
                    alpha: isLight ? 0.36 : 0.42,
                  ),
                  width: 0.9,
                ),
              ),
              child: Text(
                '$unreadBadgeCount chưa đọc',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.primaryText,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  fontFeatures: MetaGymTheme.tabularFigures,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNotificationCard(
    BuildContext context,
    MetaGymColors colors,
    CoachRecord item,
  ) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final unread = _isUnread(item);
    final kind = item['kind'];
    final accent = _accentForKind(kind, colors, unread: unread);
    final timeLabel = _formatTimestamp(item);
    final title = _titleForRecord(item);
    final description = _descriptionForRecord(item);
    final svgAsset = _svgAssetForKind(kind, unread: unread);
    final itemId = item['id'];

    final iconWellDecoration = isLight
        ? BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFE8EEF7), Color(0xFFDCE5F2)],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: unread
                  ? accent.withValues(alpha: 0.38)
                  : const Color(0xFFBAC7D9),
            ),
          )
        : BoxDecoration(
            color: accent.withValues(alpha: unread ? 0.16 : 0.13),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: accent.withValues(alpha: unread ? 0.36 : 0.24),
            ),
          );

    return MetaGymGlassCard(
      solid: false,
      key: itemId == null ? null : Key('notification-card-$itemId'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      borderColor: unread
          ? MetaGymTheme.brandOrange.withValues(alpha: isLight ? 0.50 : 0.48)
          : null,
      onTap: unread && !_saving ? () => _read(item) : null,
      child: Opacity(
        opacity: unread ? 1.0 : (isLight ? 0.88 : 0.84),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: iconWellDecoration,
              alignment: Alignment.center,
              child: MetaGymIcon(
                svgAsset,
                size: MetaGymIconSize.md,
                excludeFromSemantics: true,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 13.5,
                            fontWeight: unread
                                ? FontWeight.w700
                                : FontWeight.w600,
                            height: 1.32,
                          ),
                        ),
                      ),
                      if (timeLabel.isNotEmpty || unread) ...[
                        const SizedBox(width: 8),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 116),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (timeLabel.isNotEmpty)
                                Flexible(
                                  child: Text(
                                    timeLabel,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                      color: unread
                                          ? colors.primaryText
                                          : colors.textSecondary,
                                      fontSize: 11.5,
                                      fontWeight: unread
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                      fontFeatures: MetaGymTheme.tabularFigures,
                                    ),
                                  ),
                                ),
                              if (unread) ...[
                                if (timeLabel.isNotEmpty)
                                  const SizedBox(width: 5),
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: const BoxDecoration(
                                    color: MetaGymTheme.brandOrange,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.textWarmMuted,
                      fontSize: 12,
                      height: 1.42,
                    ),
                  ),
                  if (unread) ...[
                    const SizedBox(height: 7),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        MetaGymSvgIcon(MetaGymIcons.stateSuccess, size: 13.5, fallbackIcon: Icons.done_rounded),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'Chạm để đánh dấu đã đọc',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.primaryText,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingBody(MetaGymColors colors) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: MetaGymTheme.brandOrange),
            const SizedBox(height: 14),
            Text(
              'Đang tải thông báo...',
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBody(
    BuildContext context,
    MetaGymColors colors,
    double gutter,
  ) {
    return RefreshIndicator(
      color: MetaGymTheme.brandOrange,
      backgroundColor: colors.overlayGlass,
      onRefresh: () => _load(initial: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          gutter,
          8,
          gutter,
          MediaQuery.paddingOf(context).bottom + 28,
        ),
        children: [
          CoachingErrorBanner(
            message: _loadError ?? 'Không tải được thông báo.',
          ),
          MetaGymGlassCard(
            solid: false,
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: colors.error.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: colors.error.withValues(alpha: 0.36),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: const MetaGymIcon(
                    MetaGymIcons.stateNoNetwork,
                    size: MetaGymIconSize.lg,
                    excludeFromSemantics: true,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Không thể tải danh sách thông báo',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Kiểm tra kết nối mạng và thử tải lại.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.textWarmMuted,
                    fontSize: 12.5,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 16),
                CoachingSecondaryButton(
                  label: 'Thử lại',
                  expand: true,
                  onPressed: () => _load(initial: true),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyBody(
    BuildContext context,
    MetaGymColors colors,
    double gutter,
  ) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return RefreshIndicator(
      color: MetaGymTheme.brandOrange,
      backgroundColor: colors.overlayGlass,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          gutter,
          8,
          gutter,
          MediaQuery.paddingOf(context).bottom + 28,
        ),
        children: [
          MetaGymGlassCard(
            solid: false,
            key: const Key('notifications-empty-card'),
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: isLight
                            ? colors.metricPanelBg
                            : MetaGymTheme.brandOrange.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isLight
                              ? colors.metricPanelBorder
                              : MetaGymTheme.brandOrange.withValues(
                                  alpha: 0.42,
                                ),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: const MetaGymIcon(
                        MetaGymIcons.settingNotificationsBell,
                        size: MetaGymIconSize.md,
                        excludeFromSemantics: true,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Chưa có thông báo.',
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Các cập nhật lịch tập, thực đơn và gói Coach sẽ xuất hiện tại đây.',
                            style: TextStyle(
                              color: colors.textWarmMuted,
                              fontSize: 12.5,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                CoachingSecondaryButton(
                  label: 'Tải lại',
                  expand: true,
                  onPressed: _load,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilteredEmptyCard(MetaGymColors colors) {
    final message = _filter == _NotificationFilter.unread
        ? 'Bạn đã đọc hết toàn bộ thông báo.'
        : 'Chưa có thông báo nào thuộc nhóm này.';
    return MetaGymGlassCard(
      solid: false,
      key: const Key('notifications-filtered-empty'),
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          const MetaGymIcon(
            MetaGymIcons.settingNotificationsBell,
            size: MetaGymIconSize.md,
            excludeFromSemantics: true,
          ),
          const SizedBox(height: 8),
          Text(
            'Không có thông báo phù hợp',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.textWarmMuted,
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          CoachingSecondaryButton(
            label: 'Xem tất cả',
            onPressed: () => setState(() => _filter = _NotificationFilter.all),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = MetaGymColors.of(context);
    final gutter = MediaQuery.sizeOf(context).width >= 600
        ? MetaGymTheme.tabletGutter
        : MetaGymTheme.pageGutter;
    final unreadCount = _records.where(_isUnread).length;
    final filtered = _records.where(_matchesFilter).toList();
    final todayItems = filtered.where(_isToday).toList();
    final earlierItems = filtered.where((item) => !_isToday(item)).toList();

    Widget content;
    if (_loading && _records.isEmpty) {
      content = _buildLoadingBody(colors);
    } else if (_loadError != null && _records.isEmpty) {
      content = _buildErrorBody(context, colors, gutter);
    } else if (_records.isEmpty) {
      content = _buildEmptyBody(context, colors, gutter);
    } else {
      content = RefreshIndicator(
        color: MetaGymTheme.brandOrange,
        backgroundColor: colors.overlayGlass,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            gutter,
            4,
            gutter,
            MediaQuery.paddingOf(context).bottom + 28,
          ),
          children: [
            if (_actionError != null)
              CoachingErrorBanner(message: _actionError!),
            _buildSummaryStrip(
              colors,
              unreadCount: unreadCount,
              totalCount: _records.length,
            ),
            _buildFilterRow(colors, unreadCount: unreadCount),
            if (filtered.isEmpty)
              _buildFilteredEmptyCard(colors)
            else ...[
              if (todayItems.isNotEmpty) ...[
                _buildSectionHeader(
                  colors,
                  title: 'Hôm nay',
                  unreadBadgeCount: unreadCount,
                  topTight: true,
                ),
                for (final item in todayItems)
                  _buildNotificationCard(context, colors, item),
              ],
              if (earlierItems.isNotEmpty) ...[
                _buildSectionHeader(
                  colors,
                  title: 'Trước đó',
                  unreadBadgeCount: todayItems.isEmpty ? unreadCount : null,
                  topTight: todayItems.isEmpty,
                ),
                for (final item in earlierItems)
                  _buildNotificationCard(context, colors, item),
              ],
            ],
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: colors.canvas,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(child: MetaGymBackground()),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _buildHeader(
                  context,
                  colors,
                  unreadCount: unreadCount,
                  hasItems: _records.isNotEmpty,
                ),
                Expanded(child: content),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Nút quay lại hình tròn đồng bộ `.circle-btn` + `common_back.svg` (Dark & Light).
/// Giữ `MetaGymSvgIcon(MetaGymIcons.commonBack, fallbackIcon: Icons.arrow_back_rounded)` trong suốt để các bài test hiện hữu tìm
/// `find.byIcon(Icons.arrow_back_rounded)` vẫn hoạt động không lỗi.
class _NotificationsBackButton extends StatelessWidget {
  const _NotificationsBackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = MetaGymColors.of(context);
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Tooltip(
      message: 'Quay lại',
      child: Semantics(
        button: true,
        label: 'Quay lại',
        child: SizedBox(
          width: 48,
          height: 48,
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: MetaGymTap(
              onTap: onTap,
              customBorder: const CircleBorder(),
              splashColor: MetaGymTheme.brandOrange.withValues(alpha: 0.16),
              highlightColor: MetaGymTheme.brandOrange.withValues(alpha: 0.10),
              focusColor: colors.focus.withValues(alpha: 0.22),
              child: Center(
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.circleButtonBg,
                    gradient: isLight
                        ? const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFFFFFFFF), Color(0xFFE5ECF5)],
                          )
                        : null,
                    border: Border.all(
                      color: colors.circleButtonBorder,
                      width: 1,
                    ),
                    boxShadow: isLight
                        ? const [
                            BoxShadow(
                              color: Color(0x1A0F172A),
                              blurRadius: 10,
                              offset: Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: const Stack(
                    alignment: Alignment.center,
                    children: [
                      MetaGymIcon(
                        MetaGymIcons.commonBack,
                        size: MetaGymIconSize.md,
                        excludeFromSemantics: true,
                      ),
                      ExcludeSemantics(
                        child: MetaGymSvgIcon(MetaGymIcons.commonBack, size: 20, fallbackIcon: Icons.arrow_back_rounded),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Nút hành động header `.sec-link` ("Đọc tất cả") khớp preview 5.10 với vùng chạm >= 44px.
class _MarkAllHeaderAction extends StatelessWidget {
  const _MarkAllHeaderAction({
    required this.enabled,
    required this.busy,
    required this.onTap,
    super.key,
  });

  final bool enabled;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = MetaGymColors.of(context);
    final labelColor = enabled
        ? colors.primaryText
        : colors.textSecondary.withValues(alpha: 0.7);
    return Semantics(
      button: true,
      enabled: enabled,
      label: 'Đọc tất cả',
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(MetaGymTheme.radiusSm),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(MetaGymTheme.radiusSm),
          splashColor: MetaGymTheme.brandOrange.withValues(alpha: 0.14),
          highlightColor: MetaGymTheme.brandOrange.withValues(alpha: 0.08),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (busy) ...[
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.8,
                        color: colors.primaryText,
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    'Đọc tất cả',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: labelColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pill lọc thông báo đồng bộ `.filter-pill` trong `tokens.css` (không bọc MetaGymTap).
class _NotificationFilterPill extends StatelessWidget {
  const _NotificationFilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = MetaGymColors.of(context);
    final isLight = Theme.of(context).brightness == Brightness.light;
    final bg = selected
        ? (isLight ? colors.chipActiveBg : const Color(0xFF493025))
        : (isLight ? colors.surface : colors.liquidGlass);
    final border = selected
        ? MetaGymTheme.brandOrange
        : (isLight ? colors.borderStrong : colors.liquidGlassBorder);
    final fg = selected
        ? (isLight ? colors.chipActiveText : colors.textPrimary)
        : colors.textWarmMuted;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MetaGymTheme.radiusFull),
          side: BorderSide(color: border, width: selected ? 1.2 : 1.0),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(MetaGymTheme.radiusFull),
          splashColor: MetaGymTheme.brandOrange.withValues(alpha: 0.14),
          highlightColor: MetaGymTheme.brandOrange.withValues(alpha: 0.08),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: fg,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                height: 1.2,
                fontFeatures: MetaGymTheme.tabularFigures,
              ),
            ),
          ),
        ),
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
    final colors = MetaGymColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: colors.textWarmMuted,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: accent ? colors.primaryText : colors.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            fontFeatures: MetaGymTheme.tabularFigures,
          ),
        ),
      ],
    );
  }
}
