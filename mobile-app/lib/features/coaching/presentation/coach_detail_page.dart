import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/theme/meta_gym_icons.dart';
import 'package:meta_gym_app/core/navigation/meta_gym_navigation.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_icon.dart';
import 'package:meta_gym_app/features/auth/presentation/session_controller.dart';
import 'package:meta_gym_app/features/coaching/data/coach_outcome_service.dart';
import 'package:meta_gym_app/features/coaching/data/coach_selection_service.dart';
import 'package:meta_gym_app/features/coaching/data/coach_v2_api.dart';
import 'package:meta_gym_app/features/coaching/domain/coach_models.dart';
import 'package:meta_gym_app/features/coaching/domain/coach_outcome_models.dart';
import 'package:meta_gym_app/features/coaching/presentation/coach_offers_page.dart';
import 'package:meta_gym_app/features/coaching/presentation/coaching_ui.dart';
import 'package:meta_gym_app/features/messaging/data/messaging_service.dart';
import 'package:meta_gym_app/features/messaging/presentation/conversations_page.dart';
import 'package:meta_gym_app/features/progress/data/member_photo_service.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_svg_icon.dart';

/// Màn hình **5.8 Chi tiết Coach** đồng bộ `tab5-profile-sub.js` (`member-coach-detail`)
/// và chuẩn Warm Smoked Liquid Glass (Dark + Light Daylight Studio).
class CoachDetailPage extends StatefulWidget {
  const CoachDetailPage({
    required this.coachId,
    required this.service,
    this.messagingService,
    this.currentUserId,
    this.paletteIndex = 0,
    super.key,
  });

  final String coachId;
  final CoachSelectionService service;
  final MessagingService? messagingService;
  final String? currentUserId;
  final int paletteIndex;

  @override
  State<CoachDetailPage> createState() => _CoachDetailPageState();
}

class _CoachDetailPageState extends State<CoachDetailPage> {
  CoachProfile? _coach;
  List<CoachRecord> _workDays = const [];
  List<CoachOutcomeCase> _outcomes = const [];
  String? _loadError;
  String? _chatError;
  bool _openingChat = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant CoachDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.coachId != widget.coachId ||
        oldWidget.service != widget.service) {
      _coach = null;
      _workDays = const [];
      _outcomes = const [];
      _chatError = null;
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loadError = null;
    });
    try {
      final coach = await widget.service.getCoach(widget.coachId);
      List<CoachRecord> workDays = const [];
      List<CoachOutcomeCase> outcomes = const [];
      if (mounted) {
        final apiClient = optionalProvider<ApiClient>(context);
        if (apiClient != null) {
          try {
            final schedule = await CoachV2Api(apiClient)
                .get('/coaches/${widget.coachId}/work-slots');
            workDays = (schedule['days'] as List? ?? const [])
                .cast<CoachRecord>();
          } catch (_) {
            // Work slots are informational here; offers & checkout verify again.
          }
          try {
            outcomes = await CoachOutcomeApi(apiClient)
                .getPublicOutcomes(widget.coachId);
          } catch (_) {
            // Outcomes remain empty when not loaded or unavailable in fixture mode.
          }
        }
      }
      if (!mounted) return;
      setState(() {
        _coach = coach;
        _workDays = workDays;
        _outcomes = outcomes;
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _loadError = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _loadError = 'Không tải được chi tiết Coach.');
      }
    }
  }

  Future<void> _openChat() async {
    if (_openingChat) return;
    final messaging =
        widget.messagingService ?? optionalProvider<MessagingService>(context);
    final currentUserId =
        widget.currentUserId ??
        optionalProvider<SessionController>(context)?.user?.id;
    if (messaging == null || currentUserId == null) {
      setState(
        () => _chatError =
            'Chưa thể mở cuộc trò chuyện lúc này. Vui lòng thử lại sau.',
      );
      return;
    }
    setState(() {
      _openingChat = true;
      _chatError = null;
    });
    try {
      final conversation = await messaging.startConversation(
        coachId: widget.coachId,
      );
      if (!mounted) return;
      await MetaGymNavigation.pushOnce<void>(
        context,
        MetaGymPageRoute(
          builder: (_) => ConversationDetailPage(
            conversation: conversation,
            service: messaging,
            currentUserId: currentUserId,
            picker: DeviceProgressPhotoPicker(),
          ),
        ),
      );
    } on ApiException catch (error) {
      if (mounted) setState(() => _chatError = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _chatError = 'Không mở được cuộc trò chuyện.');
      }
    } finally {
      if (mounted) setState(() => _openingChat = false);
    }
  }

  String _weekdayName(int weekday) => switch (weekday) {
    1 => 'Thứ Hai',
    2 => 'Thứ Ba',
    3 => 'Thứ Tư',
    4 => 'Thứ Năm',
    5 => 'Thứ Sáu',
    6 => 'Thứ Bảy',
    7 => 'Chủ Nhật',
    _ => 'Thứ $weekday',
  };

  Widget _buildHeader(BuildContext context, MetaGymColors colors) {
    final canPop = Navigator.of(context).canPop();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Row(
        children: [
          if (canPop) ...[
            MetaGymCircleIconButton(
              svgAsset: MetaGymIcons.commonBack,
              tooltip: 'Quay lại',
              onTap: () => Navigator.of(context).maybePop(),
            ),
            const SizedBox(width: 11),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'HỒ SƠ HUẤN LUYỆN VIÊN',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.primaryText,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _coach?.fullName ?? 'Chi tiết Coach',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          MetaGymCircleIconButton(
            svgAsset: MetaGymIcons.commChat,
            tooltip: 'Nhắn Coach',
            onTap: _openingChat ? null : _openChat,
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard(MetaGymColors colors, CoachProfile coach) {
    final available = coach.availableSlots > 0;
    final metrics = <({String value, String label})>[
      if (coach.experienceYears != null)
        (value: '${coach.experienceYears} năm', label: 'Kinh nghiệm'),
      (value: '${coach.usedSlots}/${coach.memberLimit}', label: 'Học viên'),
      (value: '90p', label: 'Mỗi ca tập'),
    ];

    return MetaGymHeroGlassCard(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CoachingAvatar(
                fullName: coach.fullName,
                avatarUrl: coach.avatarUrl,
                size: 58,
                round: true,
                paletteIndex: widget.paletteIndex,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      coach.fullName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (coach.specialties.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        coach.specialties.join(' · '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.textWarmMuted,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        CoachingPill(
                          label: available
                              ? 'Còn ${coach.availableSlots} suất'
                              : 'Đã hết suất',
                          tone: available
                              ? CoachingPillTone.green
                              : CoachingPillTone.amber,
                        ),
                        const CoachingPill(
                          label: 'HLV 1:1 · 90p',
                          tone: CoachingPillTone.amber,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < metrics.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: MetaGymMetricPanel(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 9,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            metrics[i].value,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              fontFeatures: MetaGymTheme.tabularFigures,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            metrics[i].label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCredentialsCard(MetaGymColors colors, CoachProfile coach) {
    final qualTokens = (coach.qualifications ?? '')
        .split(RegExp(r'\s*[·,;]\s*'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final hasQualifications = qualTokens.isNotEmpty;
    final hasBio = coach.biography?.isNotEmpty == true;
    final hasSpecialties = coach.specialties.isNotEmpty;
    if (!hasQualifications && !hasBio && !hasSpecialties) {
      return const SizedBox.shrink();
    }

    return MetaGymGlassCard(
      solid: false,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const MetaGymIcon(
                MetaGymIcons.coachAchievement,
                size: MetaGymIconSize.sm,
                excludeFromSemantics: true,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  'Chứng chỉ & Giới thiệu',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (hasQualifications || hasSpecialties) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (hasQualifications)
                  CoachingPill(
                    label: qualTokens.first,
                    tone: CoachingPillTone.coral,
                  ),
                for (final extraCert in qualTokens.skip(1))
                  CoachingPill(
                    label: extraCert,
                    tone: CoachingPillTone.neutral,
                  ),
                for (final spec in coach.specialties)
                  CoachingPill(label: spec, tone: CoachingPillTone.neutral),
              ],
            ),
          ],
          if (hasBio) ...[
            const SizedBox(height: 9),
            Text(
              coach.biography!,
              style: TextStyle(
                color: colors.textWarmMuted,
                fontSize: 12.5,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildScheduleCard(
    BuildContext context,
    MetaGymColors colors,
    CoachProfile coach,
  ) {
    final summary = coach.availabilityNote?.isNotEmpty == true
        ? '${coach.availabilityNote!} · Khung 90 phút/buổi'
        : 'Khung 90 phút/buổi · chạm để xem khung giờ cố định';
    return MetaGymGlassCard(
      solid: false,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(bottom: 10),
          iconColor: colors.textPrimary,
          collapsedIconColor: colors.textSecondary,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const MetaGymIcon(
                    MetaGymIcons.actionCoachWorkweek,
                    size: MetaGymIconSize.sm,
                    excludeFromSemantics: true,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'Lịch dạy cố định',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                summary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.textWarmMuted,
                  fontSize: 12,
                  fontFeatures: MetaGymTheme.tabularFigures,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Xem lịch làm việc',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          children: [
            if (_workDays.isEmpty && coach.availabilityNote?.isNotEmpty != true)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Coach chưa cấu hình lịch cố định.',
                  style: TextStyle(color: colors.textSecondary, fontSize: 12.5),
                ),
              ),
            if (_workDays.isNotEmpty)
              SizedBox(
                height: 66,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _workDays.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, index) {
                    final day = _workDays[index];
                    final starts = (day['starts'] as List? ?? const [])
                        .cast<String>();
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: colors.metricPanelBg,
                        borderRadius: BorderRadius.circular(
                          MetaGymTheme.radiusInput,
                        ),
                        border: Border.all(color: colors.metricPanelBorder),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _weekdayName(day['weekday'] as int),
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            starts.take(2).join(' · '),
                            style: TextStyle(
                              color: colors.textWarmMuted,
                              fontSize: 11,
                              fontFeatures: MetaGymTheme.tabularFigures,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            if (coach.availabilityNote?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  coach.availabilityNote!,
                  style: TextStyle(color: colors.textWarmMuted, fontSize: 12.5),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Khung giờ để tham khảo; hệ thống kiểm tra suất khi thanh toán.',
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 11.5,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomCtaDock(BuildContext context, MetaGymColors colors) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Container(
      decoration: BoxDecoration(
        color: isLight ? colors.overlayGlass : const Color(0xF0181513),
        border: Border(
          top: BorderSide(
            color: colors.liquidGlassBorder.withValues(alpha: 0.65),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: MetaGymTheme.brandOrange,
                foregroundColor: MetaGymTheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
                ),
              ),
              onPressed: () => MetaGymNavigation.pushOnce<void>(
                context,
                MetaGymPageRoute(
                  builder: (_) => CoachOffersPage(coachId: widget.coachId),
                ),
              ),
              child: const Text(
                'Xem các gói Coach →',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = MetaGymColors.of(context);
    final coach = _coach;
    final hasApiClient = optionalProvider<ApiClient>(context) != null;

    return Scaffold(
      backgroundColor: colors.canvas,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const MetaGymBackground(),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _buildHeader(context, colors),
                Expanded(
                  child: coach == null && _loadError == null
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: MetaGymTheme.brandOrange,
                          ),
                        )
                      : RefreshIndicator(
                          color: MetaGymTheme.brandOrange,
                          backgroundColor: colors.overlayGlass,
                          onRefresh: _load,
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                            children: [
                              if (_loadError != null) ...[
                                CoachingErrorBanner(message: _loadError!),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: FilledButton.icon(
                                    onPressed: _load,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: MetaGymTheme.primary,
                                      foregroundColor: MetaGymTheme.onPrimary,
                                      minimumSize: const Size(120, 48),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    icon: const MetaGymSvgIcon(MetaGymIcons.commonRefresh, size: 18, fallbackIcon: Icons.refresh_rounded),
                                    label: const Text(
                                      'Thử lại',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                              if (_chatError != null)
                                CoachingErrorBanner(message: _chatError!),
                              if (coach != null) ...[
                                _buildHeroCard(colors, coach),
                                _buildCredentialsCard(colors, coach),
                                _buildScheduleCard(context, colors, coach),
                                if (hasApiClient) ...[
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      top: 4,
                                      bottom: 10,
                                    ),
                                    child: Row(
                                      children: [
                                        const MetaGymIcon(
                                          MetaGymIcons.outcomeConsentBadge,
                                          size: MetaGymIconSize.sm,
                                          excludeFromSemantics: true,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Thành quả học viên',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: colors.textPrimary,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (_outcomes.isEmpty)
                                    MetaGymGlassCard(
                                      solid: false,
                                      margin: const EdgeInsets.only(bottom: 10),
                                      padding: const EdgeInsets.all(14),
                                      child: Text(
                                        'Chưa có thành quả được học viên đồng ý công khai.',
                                        style: TextStyle(
                                          color: colors.textWarmMuted,
                                          fontSize: 12.5,
                                        ),
                                      ),
                                    )
                                  else
                                    for (final item in _outcomes)
                                      CoachOutcomeCard(outcome: item),
                                ] else
                                  MetaGymGlassCard(
                                    solid: false,
                                    margin: const EdgeInsets.only(top: 4),
                                    padding: const EdgeInsets.all(14),
                                    child: Text(
                                      'Vào mục Chọn gói Coach khi kết nối máy chủ để xem giá và thuê Coach.',
                                      style: TextStyle(
                                        color: colors.textWarmMuted,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                  ),
                              ],
                            ],
                          ),
                        ),
                ),
                if (coach != null && hasApiClient)
                  _buildBottomCtaDock(context, colors),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
