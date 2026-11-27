import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:meta_gym_app/core/navigation/meta_gym_navigation.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/theme/meta_gym_icons.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_svg_icon.dart';
import 'package:meta_gym_app/features/auth/domain/auth_models.dart';
import 'package:meta_gym_app/features/auth/presentation/session_controller.dart';
import 'package:meta_gym_app/features/member/presentation/widgets/member_home_qr_modal.dart';
import 'package:meta_gym_app/features/training/data/gym_visits_service.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

/// Màn hình Điểm danh QR (Lịch sử đến gym) đồng bộ bảng màu & định dạng thẻ
/// với preview 2.4 (`tab2-training.js`), Trang chủ Hội viên và Hồ sơ.
class GymVisitsPage extends StatefulWidget {
  const GymVisitsPage({this.api, this.todayOverride, super.key});

  final GymVisitsApi? api;
  final DateTime? todayOverride;

  @override
  State<GymVisitsPage> createState() => _GymVisitsPageState();
}

class _GymVisitsPageState extends State<GymVisitsPage> {
  GymVisitsApi? _api;
  late DateTime _month;
  GymVisitMonth? _data;
  bool _loading = true;
  String? _error;

  DateTime get _today {
    final now = widget.todayOverride ?? DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  void initState() {
    super.initState();
    final t = _today;
    _month = DateTime(t.year, t.month);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_api != null) return;
    _api = widget.api ?? GymVisitsApi(context.read<ApiClient>());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _api!.getMonth(_month);
      if (mounted) setState(() => _data = data);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không tải được lịch sử đến gym.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _moveMonth(int delta) {
    final next = DateTime(_month.year, _month.month + delta);
    final now = _today;
    if (next.isAfter(DateTime(now.year, now.month))) return;
    setState(() {
      _month = next;
      _data = null;
    });
    _load();
  }

  AuthUser? _trySessionUser() {
    try {
      return context.read<SessionController>().user;
    } catch (_) {
      return null;
    }
  }

  Future<void> _openMemberQrModal() {
    final user = _trySessionUser();
    final userName = user?.fullName.trim().isNotEmpty == true
        ? user!.fullName.trim()
        : 'Hội viên Meta Gym';
    final userId = user?.id ?? '2048';
    final numericSuffix = userId.replaceAll(RegExp(r'[^0-9]'), '');
    final memberCode =
        'MG-${numericSuffix.length >= 4 ? numericSuffix.substring(numericSuffix.length - 4) : '2048'}';
    return showMemberQrCheckinModal(
      context,
      memberName: userName,
      memberCode: memberCode,
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _scan() async {
    final visited = await MetaGymNavigation.pushOnce<bool>(
      context,
      MetaGymPageRoute(builder: (_) => _GymQrScanner(api: _api!)),
    );
    if (visited == true && mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final palette = MetaGymTheme.paletteOf(context);
    final colors = MetaGymColors.of(context);
    final isLight = MetaGymTheme.isLightPalette(context);
    final now = _today;
    final isCurrentMonth = _month.year == now.year && _month.month == now.month;
    final canGoForward = _month.isBefore(DateTime(now.year, now.month));
    final data = _data;
    final todayVisits = data == null
        ? const <GymVisit>[]
        : data.visits
              .where((v) => _isSameDay(v.day, now))
              .toList(growable: false);

    return Scaffold(
      backgroundColor: palette.canvas,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const MetaGymBackground(),
          SafeArea(
            bottom: false,
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
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ĐIỂM DANH QR',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: palette.primaryText,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.0,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              'Lịch sử đến gym',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: palette.textPrimary,
                                fontSize: 20,
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
                        onTap: _loading ? null : _load,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _load,
                    color: MetaGymTheme.brandOrange,
                    backgroundColor: colors.surface,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 118),
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        if (!_loading &&
                            _error == null &&
                            data != null &&
                            isCurrentMonth) ...[
                          _buildTodayCheckinBanner(todayVisits),
                          const SizedBox(height: 12),
                        ],
                        MetaGymHeroGlassCard(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const MetaGymSvgIcon(
                                    MetaGymIcons.workoutPlanCalendar,
                                    size: 18,
                                    fallbackIcon: Icons.calendar_month_rounded,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Lịch đến gym',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: palette.textPrimary,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: palette.metricPanelBg,
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: palette.metricPanelBorder,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          visualDensity: VisualDensity.compact,
                                          constraints: const BoxConstraints(
                                            minWidth: 44,
                                            minHeight: 44,
                                          ),
                                          padding: EdgeInsets.zero,
                                          onPressed: () => _moveMonth(-1),
                                          tooltip: 'Tháng trước',
                                          icon: const MetaGymSvgIcon(
                                            MetaGymIcons.commonChevronLeft,
                                            size: 20,
                                            fallbackIcon:
                                                Icons.chevron_left_rounded,
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 4,
                                          ),
                                          child: Text(
                                            DateFormat('MM/yyyy')
                                                .format(_month),
                                            style: TextStyle(
                                              color: palette.textPrimary,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              fontFeatures:
                                                  MetaGymTheme.tabularFigures,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          visualDensity: VisualDensity.compact,
                                          constraints: const BoxConstraints(
                                            minWidth: 44,
                                            minHeight: 44,
                                          ),
                                          padding: EdgeInsets.zero,
                                          onPressed: canGoForward
                                              ? () => _moveMonth(1)
                                              : null,
                                          tooltip: 'Tháng sau',
                                          icon: Opacity(
                                            opacity: canGoForward ? 1.0 : 0.35,
                                            child: const MetaGymSvgIcon(
                                              MetaGymIcons.commonChevronRight,
                                              size: 20,
                                              fallbackIcon:
                                                  Icons.chevron_right_rounded,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (_loading)
                                const Padding(
                                  padding: EdgeInsets.all(28),
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      color: MetaGymTheme.brandOrange,
                                    ),
                                  ),
                                )
                              else if (_error != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: MetaGymMetricPanel(
                                    onTap: _load,
                                    child: Row(
                                      children: [
                                        const MetaGymSvgIcon(
                                          MetaGymIcons.commonRefresh,
                                          size: 20,
                                          fallbackIcon: Icons.refresh_rounded,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            '$_error · Chạm để thử lại',
                                            style: TextStyle(
                                              color: palette.textPrimary,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              else if (data != null) ...[
                                const SizedBox(height: 14),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _stat(
                                        'Đã đến gym',
                                        data.visitedDays,
                                        palette.primaryText,
                                        MetaGymIcons.checkinBadge,
                                        Icons.bolt_rounded,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _stat(
                                        'Ngày chưa đến',
                                        (data.eligibleDays - data.visitedDays)
                                            .clamp(0, 31),
                                        palette.textPrimary,
                                        MetaGymIcons.workoutPlanCalendar,
                                        Icons.event_busy_outlined,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                _calendar(data),
                                const SizedBox(height: 10),
                                _calendarLegend(),
                                const SizedBox(height: 6),
                                Text(
                                  'Ngày chưa đến chỉ tính khi gói tập có hiệu lực.',
                                  style: TextStyle(
                                    color: palette.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            const MetaGymSvgIcon(
                              MetaGymIcons.workoutHistory,
                              size: 18,
                              fallbackIcon: Icons.history_rounded,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Các lần đến gym',
                                style: TextStyle(
                                  color: palette.textPrimary,
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (data != null && !_loading && _error == null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: palette.success.withValues(
                                    alpha: 0.14,
                                  ),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: palette.success.withValues(
                                      alpha: 0.42,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  '${data.entryCount} lượt quét',
                                  style: TextStyle(
                                    color: palette.success,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    fontFeatures: MetaGymTheme.tabularFigures,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (data != null && !_loading && _error == null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '${data.entryCount} lượt quét trong tháng · Có thể vào nhiều lần mỗi ngày',
                              style: TextStyle(
                                color: palette.textSecondary,
                                fontSize: 12,
                                fontFeatures: MetaGymTheme.tabularFigures,
                              ),
                            ),
                          ),
                        const SizedBox(height: 12),
                        if (!_loading &&
                            _error == null &&
                            data != null &&
                            data.visits.isEmpty)
                          MetaGymGlassCard(
                            solid: false,
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: palette.metricPanelBg,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: palette.metricPanelBorder,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: const MetaGymSvgIcon(
                                    MetaGymIcons.emptyVisits,
                                    size: 20,
                                    fallbackIcon: Icons.info_outline_rounded,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Chưa có lượt đến gym trong tháng này.',
                                    style: TextStyle(
                                      color: palette.textSecondary,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else if (data != null && !_loading && _error == null)
                          ...data.visits.map(
                            (visit) => _buildVisitCard(visit, now),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                16,
                14,
                16,
                14 + MediaQuery.paddingOf(context).bottom,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: isLight
                      ? const [
                          Color(0xFAE8EEF5),
                          Color(0xCCE8EEF5),
                          Color(0x00E8EEF5),
                        ]
                      : const [
                          Color(0xFA0F1115),
                          Color(0xCC0F1115),
                          Color(0x000F1115),
                        ],
                ),
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x45FF5E36),
                      blurRadius: 18,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: FilledButton.icon(
                  onPressed: _scan,
                  icon: const MetaGymSvgIcon(
                    MetaGymIcons.qrScanFrame,
                    size: 20,
                    color: Colors.white,
                    adaptForLightMode: false,
                    fallbackIcon: Icons.qr_code_scanner_rounded,
                  ),
                  label: const Text(
                    'Quét QR tại phòng gym',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: MetaGymTheme.brandOrange,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayCheckinBanner(List<GymVisit> todayVisits) {
    final palette = MetaGymTheme.paletteOf(context);
    final isCheckedIn = todayVisits.isNotEmpty;
    final accent = isCheckedIn ? palette.success : MetaGymTheme.brandOrange;
    final textAccent = isCheckedIn ? palette.success : palette.primaryText;

    return MetaGymGlassCard(
      solid: false,
      key: Key(
        isCheckedIn
            ? 'gym-visits-checked-in-banner'
            : 'gym-visits-checkin-alert',
      ),
      borderColor: accent.withValues(alpha: 0.48),
      padding: EdgeInsets.zero,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              accent.withValues(alpha: 0.14),
              accent.withValues(alpha: 0.03),
            ],
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: accent.withValues(alpha: 0.42)),
              ),
              alignment: Alignment.center,
              child: MetaGymSvgIcon(
                isCheckedIn
                    ? MetaGymIcons.checkinBadge
                    : MetaGymIcons.qrScanFrame,
                size: 20,
                color: textAccent,
                adaptForLightMode: false,
                fallbackIcon: isCheckedIn
                    ? Icons.verified_rounded
                    : Icons.qr_code_2_rounded,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isCheckedIn
                        ? 'Hôm nay đã điểm danh'
                        : 'Hôm nay chưa điểm danh',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isCheckedIn
                        ? '${DateFormat('HH:mm').format(todayVisits.first.checkedInAt.toLocal())} · ${todayVisits.first.gymName}'
                        : 'Mở mã QR hoặc thẻ NFC tại cổng',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 11.5,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            isCheckedIn
                ? OutlinedButton(
                    key: const Key('gym-visits-open-qr-btn'),
                    onPressed: _openMemberQrModal,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: palette.success,
                      side: BorderSide(
                        color: palette.success.withValues(alpha: 0.52),
                      ),
                      minimumSize: const Size(0, 38),
                      padding: const EdgeInsets.symmetric(horizontal: 11),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(11),
                      ),
                    ),
                    child: const Text(
                      'Mở QR',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                : FilledButton(
                    key: const Key('gym-visits-open-qr-btn'),
                    onPressed: _openMemberQrModal,
                    style: FilledButton.styleFrom(
                      backgroundColor: MetaGymTheme.brandOrange,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 38),
                      padding: const EdgeInsets.symmetric(horizontal: 11),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(11),
                      ),
                    ),
                    child: const Text(
                      'Điểm danh',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildVisitCard(GymVisit visit, DateTime now) {
    final palette = MetaGymTheme.paletteOf(context);
    final isToday = _isSameDay(visit.day, now);
    final formattedDate = DateFormat('dd/MM/yyyy').format(visit.day);
    final formattedTime = DateFormat('HH:mm').format(visit.checkedInAt.toLocal());

    return MetaGymGlassCard(
      solid: false,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      borderColor: isToday ? palette.success.withValues(alpha: 0.38) : null,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isToday
                  ? palette.success.withValues(alpha: 0.14)
                  : palette.chipActiveBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isToday
                    ? palette.success.withValues(alpha: 0.36)
                    : MetaGymTheme.primary.withValues(alpha: 0.35),
              ),
            ),
            alignment: Alignment.center,
            child: MetaGymSvgIcon(
              MetaGymIcons.checkinBadge,
              size: 20,
              color: isToday ? palette.success : palette.primaryText,
              adaptForLightMode: false,
              fallbackIcon: Icons.place_outlined,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        visit.gymName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (isToday)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: palette.success.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: palette.success.withValues(alpha: 0.42),
                          ),
                        ),
                        child: Text(
                          'Hôm nay',
                          style: TextStyle(
                            color: palette.success,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    else
                      Text(
                        DateFormat('dd/MM').format(visit.day),
                        style: TextStyle(
                          color: palette.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          fontFeatures: MetaGymTheme.tabularFigures,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '$formattedDate · $formattedTime · ${visit.gymAddress}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 12,
                    fontFeatures: MetaGymTheme.tabularFigures,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _calendarLegend() {
    final palette = MetaGymTheme.paletteOf(context);
    Widget dot(Color fill, Color border, String label) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: border),
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(color: palette.textSecondary, fontSize: 11),
          ),
        ],
      );
    }

    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: [
        dot(MetaGymTheme.brandOrange, MetaGymTheme.brandOrange, 'Đã đến'),
        dot(palette.metricPanelBg, palette.reflection, 'Hôm nay'),
        dot(
          palette.metricPanelBg.withValues(alpha: 0.55),
          palette.metricPanelBorder,
          'Chưa đến',
        ),
      ],
    );
  }

  Widget _calendar(GymVisitMonth data) {
    final palette = MetaGymTheme.paletteOf(context);
    final first = DateTime(_month.year, _month.month);
    final leading = first.weekday - 1;
    final days = DateTime(_month.year, _month.month + 1, 0).day;
    final visits = data.visits.map((v) => v.day.day).toSet();
    final now = _today;
    final isCurrentMonth = _month.year == now.year && _month.month == now.month;
    return Column(
      children: [
        Row(
          children: ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN']
              .map(
                (label) => Expanded(
                  child: Center(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 8),
        ...List.generate(
          ((leading + days) / 7).ceil(),
          (week) => Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Row(
              children: List.generate(7, (weekday) {
                final day = week * 7 + weekday - leading + 1;
                if (day < 1 || day > days) {
                  return const Expanded(child: SizedBox(height: 42));
                }
                final visited = visits.contains(day);
                final future = isCurrentMonth && day > now.day;
                final today = isCurrentMonth && day == now.day;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Container(
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: visited
                            ? const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFFFF6D3F), Color(0xFFFF4F2B)],
                              )
                            : null,
                        color: visited
                            ? null
                            : future
                            ? palette.metricPanelBg.withValues(alpha: 0.55)
                            : palette.metricPanelBg,
                        border: Border.all(
                          color: today
                              ? palette.reflection
                              : visited
                              ? const Color(0xFFFF8566)
                              : palette.metricPanelBorder,
                          width: today ? 1.4 : 1.0,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$day',
                        style: TextStyle(
                          color: visited
                              ? Colors.white
                              : future
                              ? palette.textSecondary.withValues(alpha: 0.55)
                              : palette.textPrimary,
                          fontWeight: visited || today
                              ? FontWeight.w800
                              : FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ],
    );
  }

  Widget _stat(
    String label,
    int value,
    Color accent,
    String svgAsset,
    IconData fallbackIcon,
  ) {
    final palette = MetaGymTheme.paletteOf(context);
    return MetaGymMetricPanel(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              MetaGymSvgIcon(
                svgAsset,
                size: 15,
                color: accent,
                adaptForLightMode: false,
                fallbackIcon: fallbackIcon,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$value',
                style: TextStyle(
                  color: accent,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  height: 1.05,
                  fontFeatures: MetaGymTheme.tabularFigures,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'ngày',
                style: TextStyle(
                  color: palette.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GymQrScanner extends StatefulWidget {
  const _GymQrScanner({required this.api});
  final GymVisitsApi api;
  @override
  State<_GymQrScanner> createState() => _GymQrScannerState();
}

class _GymQrScannerState extends State<_GymQrScanner> {
  final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );
  bool _busy = false;
  bool _completed = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _detected(BarcodeCapture capture) async {
    if (_busy || capture.barcodes.isEmpty) return;
    final code = capture.barcodes.first.rawValue;
    if (code == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _controller.stop();
      await widget.api.checkIn(code);
      if (!mounted) return;
      _completed = true;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã ghi nhận lượt đến gym hôm nay.')),
      );
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Không thể điểm danh. Hãy thử lại.');
      }
    } finally {
      if (mounted && !_completed) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = MetaGymTheme.paletteOf(context);
    final colors = MetaGymColors.of(context);
    return Scaffold(
      backgroundColor: palette.canvas,
      appBar: AppBar(
        title: const Text('Quét mã tại quầy'),
        backgroundColor: colors.surface,
        foregroundColor: palette.textPrimary,
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _detected,
            errorBuilder: (context, error) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Không mở được camera. Hãy cấp quyền camera rồi thử lại.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: palette.textPrimary),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: MetaGymHeroGlassCard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Đưa mã QR tại quầy vào khung hình.',
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (_busy)
                      const Padding(
                        padding: EdgeInsets.all(8),
                        child: CircularProgressIndicator(
                          color: MetaGymTheme.brandOrange,
                        ),
                      ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Column(
                          children: [
                            Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: palette.warning),
                            ),
                            TextButton(
                              onPressed: () async {
                                setState(() => _error = null);
                                try {
                                  await _controller.start();
                                } catch (_) {
                                  if (mounted) {
                                    setState(
                                      () => _error =
                                          'Không mở được camera. Hãy thử lại.',
                                    );
                                  }
                                }
                              },
                              child: const Text('Quét lại'),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
