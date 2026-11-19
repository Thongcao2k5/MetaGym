import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_bottom_nav.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/core/widgets/muscle_anatomy_tile.dart';
import 'package:meta_gym_app/features/catalog/presentation/exercise_library_page.dart';
import 'package:meta_gym_app/features/catalog/presentation/gym_equipment_page.dart';
import 'package:meta_gym_app/features/coaching/data/member_coaching_service.dart';
import 'package:meta_gym_app/features/coaching/domain/member_coaching_models.dart';
import 'package:meta_gym_app/features/coaching/presentation/coach_selection_page.dart';
import 'package:meta_gym_app/features/coaching/presentation/member_coaching_page.dart';
import 'package:meta_gym_app/features/membership/domain/membership_models.dart';
import 'package:meta_gym_app/features/membership/presentation/membership_controller.dart';
import 'package:meta_gym_app/features/membership/presentation/membership_page.dart';
import 'package:meta_gym_app/features/progress/presentation/member_journal_page.dart';
import 'package:meta_gym_app/features/training/data/member_self_training_api.dart';
import 'package:meta_gym_app/features/training/data/self_training_icon_store.dart';
import 'package:meta_gym_app/features/training/domain/member_self_training_day.dart';
import 'package:meta_gym_app/features/training/presentation/gym_visits_page.dart';
import 'package:meta_gym_app/features/training/presentation/member_self_training_page.dart';
import 'package:meta_gym_app/features/training/presentation/member_training_page.dart';
import 'package:provider/provider.dart';

/// Overview of the Member training area. Synchronized with Member Home's
/// Futuristic Performance Glass palette and 80/20 material hierarchy.
class MemberTrainingHubPage extends StatefulWidget {
  const MemberTrainingHubPage({
    this.bottomPadding,
    this.membershipController,
    this.coachingService,
    this.selfTrainingApi,
    super.key,
  });

  final double? bottomPadding;
  final MembershipController? membershipController;
  final MemberCoachingService? coachingService;
  final MemberSelfTrainingApi? selfTrainingApi;

  @override
  State<MemberTrainingHubPage> createState() => _MemberTrainingHubPageState();
}

class _MemberTrainingHubPageState extends State<MemberTrainingHubPage> {
  MembershipController? _membership;
  MemberCoachingService? _coaching;
  MemberCoachRelationship? _relationship;
  MemberSelfTrainingDay? _todaySelfPlan;
  String? _todaySelfIconKey;
  String? _coachName;
  String? _error;
  bool _loading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_membership != null) return;
    _membership =
        widget.membershipController ?? context.read<MembershipController>();
    _coaching = widget.coachingService ?? context.read<MemberCoachingService>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    MemberSelfTrainingApi? selfApi = widget.selfTrainingApi;
    if (selfApi == null) {
      try {
        selfApi = MemberSelfTrainingApi(context.read<ApiClient>());
      } catch (_) {
        selfApi = null;
      }
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _membership!.load();
      if (_membership!.errorMessage != null) {
        throw StateError(_membership!.errorMessage!);
      }
      final relationship = await _coaching!.getCurrentRelationship();
      String? coachName;
      if (relationship != null) {
        try {
          coachName = (await _coaching!.getCoachNames())[relationship.coachId];
        } catch (_) {
          // The relationship is still useful if the public Coach list is offline.
        }
      }
      MemberSelfTrainingDay? todaySelfPlan;
      String? todaySelfIconKey;
      if (selfApi != null) {
        try {
          final vnNow = DateTime.now().toUtc().add(const Duration(hours: 7));
          final todayStr =
              '${vnNow.year.toString().padLeft(4, '0')}-${vnNow.month.toString().padLeft(2, '0')}-${vnNow.day.toString().padLeft(2, '0')}';
          final results = await Future.wait([
            selfApi.getRange(todayStr, todayStr),
            SelfTrainingIconStore().loadAll(),
          ]);
          final plans = results[0] as List<MemberSelfTrainingDay>;
          final icons = results[1] as Map<String, String>;
          todaySelfPlan = plans.firstOrNull;
          if (todaySelfPlan != null) {
            todaySelfIconKey =
                icons[todaySelfPlan.planDate] ?? todaySelfPlan.iconKey;
          }
        } catch (_) {
          // Optional summary enhancement; hub remains usable without self-plan API.
        }
      }
      if (!mounted) return;
      setState(() {
        _relationship = relationship;
        _todaySelfPlan = todaySelfPlan;
        _todaySelfIconKey = todaySelfIconKey;
        _coachName = coachName;
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Chưa tải được thông tin gói tập. Hãy thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Membership? get _currentGym {
    final now = DateTime.now();
    for (final item in _membership!.memberships) {
      final end = DateTime.tryParse(item.endDate);
      if (item.status == 'ACTIVE' &&
          end != null &&
          !end.isBefore(DateTime(now.year, now.month, now.day))) {
        return item;
      }
    }
    return null;
  }

  bool get _hadGym =>
      _membership!.history.isNotEmpty || _membership!.memberships.isNotEmpty;

  bool get _hasCoach =>
      _relationship != null && _relationship!.status == 'ACTIVE';

  void _open(Widget page) {
    Navigator.of(context)
        .push<void>(MaterialPageRoute(builder: (_) => page))
        .then((_) {
          if (mounted) _load();
        });
  }

  Future<void> _requirePackage({
    required bool coach,
    required String feature,
  }) async {
    final isExpired = !coach && _hadGym;
    final destination = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: const Color(0xFF24201D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                coach
                    ? 'Cần gói Coach'
                    : isExpired
                    ? 'Gói tập đã hết hạn'
                    : 'Cần gói tập',
                style: const TextStyle(
                  color: MetaGymTheme.textPrimary,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                coach
                    ? 'Đăng ký gói Coach để mở $feature.'
                    : '${isExpired ? 'Gia hạn' : 'Đăng ký'} gói tập để sử dụng $feature.',
                style: const TextStyle(
                  color: MetaGymTheme.textSecondary,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(
                  backgroundColor: MetaGymTheme.primary,
                  foregroundColor: MetaGymTheme.onPrimary,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: const Text('Đăng ký ngay'),
              ),
              if (isExpired) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Xem lịch sử'),
                ),
              ],
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Để sau'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (destination == true) {
      _open(coach ? const CoachSelectionPage() : const MembershipPage());
    } else if (destination == false && isExpired) {
      _open(
        feature == 'nhật ký tập luyện'
            ? const MemberJournalPage()
            : const MemberTrainingPage(),
      );
    }
  }

  void _openPlan() {
    if (_loading || _error != null) {
      _load();
      return;
    }
    if (_currentGym == null) {
      _requirePackage(coach: false, feature: 'giáo trình của Coach');
    } else if (!_hasCoach) {
      _requirePackage(coach: true, feature: 'giáo trình của Coach');
    } else {
      _open(const MemberTrainingPage());
    }
  }

  void _openJournal() {
    if (_loading || _error != null) {
      _load();
      return;
    }
    if (_currentGym == null) {
      _requirePackage(coach: false, feature: 'nhật ký tập luyện');
    } else {
      _open(const MemberJournalPage());
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom =
        widget.bottomPadding ?? MetaGymBottomNav.contentBottomPadding(context);
    final disableBlur = _disableBackdropBlur(context);
    final gym = _membership == null ? null : _currentGym;
    final relationship = _relationship;
    final hasGym = gym != null;
    final hasCoach = _hasCoach;
    final end = gym == null ? null : DateTime.tryParse(gym.endDate);
    final daysLeft = end == null
        ? null
        : DateTime(end.year, end.month, end.day)
                  .difference(
                    DateTime(
                      DateTime.now().year,
                      DateTime.now().month,
                      DateTime.now().day,
                    ),
                  )
                  .inDays +
              1;
    final coachInitials = _extractInitials(_coachName);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: MetaGymTheme.darkCanvas,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const _TrainingBackground(),
            SafeArea(
              bottom: false,
              child: RefreshIndicator(
                color: MetaGymTheme.primary,
                backgroundColor: const Color(0xFF282320),
                onRefresh: _load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    MetaGymTheme.pageGutter,
                    0,
                    MetaGymTheme.pageGutter,
                    bottom + 24,
                  ),
                  children: [
                    const SizedBox(height: 6),
                    _TrainingHeader(
                      disableBlur: disableBlur,
                      onOpenLibrary: () => _open(const ExerciseLibraryPage()),
                      onOpenHistory: () => _open(const GymVisitsPage()),
                    ),
                    const SizedBox(height: 14),
                    const _SectionTitle('Dịch vụ của bạn'),
                    const SizedBox(height: 10),
                    _ServiceHeroGlassCard(
                      disableBlur: disableBlur,
                      child: _buildServiceContent(
                        disableBlur: disableBlur,
                        hasGym: hasGym,
                        daysLeft: daysLeft,
                        endDate: end,
                        relationship: relationship,
                        coachInitials: coachInitials,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const _SectionTitle('Kế hoạch tập luyện', accent: true),
                    const SizedBox(height: 10),
                    _FeaturedPlanCard(
                      disableBlur: disableBlur,
                      icon: Icons.menu_book_outlined,
                      iconColor: MetaGymTheme.primary,
                      locked: !hasGym || !hasCoach,
                      showActionPill:
                          !_loading && _error == null && (!hasGym || !hasCoach),
                      actionPillLabel: 'Đăng ký',
                      title: 'Giáo trình của Coach',
                      detail: _loading || _error != null
                          ? 'Kế hoạch tập luyện và ăn uống từ Coach'
                          : !hasGym
                          ? 'Cần gói tập và gói Coach'
                          : !hasCoach
                          ? 'Cần gói Coach'
                          : 'Kế hoạch tập luyện và ăn uống từ Coach',
                      onTap: _openPlan,
                    ),
                    const SizedBox(height: 10),
                    _FeaturedPlanCard(
                      disableBlur: disableBlur,
                      icon: Icons.event_note_rounded,
                      iconColor: MetaGymTheme.reflectionBlue,
                      locked: false,
                      title: 'Lịch tập của tôi',
                      leadingTile: _todaySelfPlan == null
                          ? null
                          : MuscleAnatomyTile(
                              focuses: resolveMuscleFocusSet(
                                _todaySelfPlan!.title,
                                exerciseNames: _todaySelfPlan!.exercises
                                    .map((e) => e.name)
                                    .toList(),
                                explicitKey: _todaySelfIconKey,
                              ),
                              width: 44,
                              height: 50,
                            ),
                      statusBadge: _todaySelfPlan == null ? null : 'Hôm nay',
                      detail: _todaySelfPlan == null
                          ? 'Tự lên lịch theo tuần hoặc tháng'
                          : [
                              'Hôm nay',
                              if (_todaySelfPlan!.startTime != null)
                                _todaySelfPlan!.startTime!,
                              _todaySelfPlan!.title,
                            ].join(' · '),
                      onTap: () => _open(const MemberSelfTrainingPage()),
                    ),
                    const SizedBox(height: 20),
                    const _SectionTitle('Công cụ & Khám phá'),
                    const SizedBox(height: 10),
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _BentoToolCard(
                              disableBlur: disableBlur,
                              icon: Icons.calendar_month_outlined,
                              iconColor: MetaGymTheme.success,
                              locked: !hasGym,
                              title: 'Nhật ký tập luyện',
                              detail: _loading || _error != null
                                  ? 'Ghi thành tích, ảnh và số đo theo ngày'
                                  : !hasGym
                                  ? _hadGym
                                        ? 'Chỉ xem · Gia hạn gói tập để ghi thêm'
                                        : 'Cần gói tập để ghi nhật ký'
                                  : 'Ghi thành tích, ảnh và số đo theo ngày',
                              ctaPillLabel:
                                  !_loading && _error == null && !hasGym
                                  ? (_hadGym ? 'Gia hạn' : 'Đăng ký')
                                  : null,
                              onTap: _openJournal,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _BentoToolCard(
                              disableBlur: disableBlur,
                              icon: Icons.history_rounded,
                              iconColor: MetaGymTheme.reflectionBlue,
                              locked: false,
                              title: 'Lịch sử tập luyện',
                              detail: 'Xem các ngày và lượt đến phòng gym',
                              onTap: () => _open(const GymVisitsPage()),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _BentoToolCard(
                              disableBlur: disableBlur,
                              icon: Icons.sports_gymnastics_outlined,
                              iconColor: MetaGymTheme.primary,
                              locked: false,
                              title: 'Thư viện bài tập',
                              detail:
                                  'Tìm bài theo nhóm cơ và xem cách thực hiện',
                              onTap: () => _open(const ExerciseLibraryPage()),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _BentoToolCard(
                              disableBlur: disableBlur,
                              icon: Icons.fitness_center_outlined,
                              iconColor: MetaGymTheme.warning,
                              locked: false,
                              title: 'Phòng gym & thiết bị',
                              detail: 'Nội quy và hướng dẫn dùng máy',
                              onTap: () => _open(const GymEquipmentPage()),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceContent({
    required bool disableBlur,
    required bool hasGym,
    required int? daysLeft,
    required DateTime? endDate,
    required MemberCoachRelationship? relationship,
    required String? coachInitials,
  }) {
    if (_loading) {
      return SizedBox(
        height: 148,
        child: Center(
          child: MetaGymTheme.isFlutterTestEnvironment
              ? const CircularProgressIndicator(
                  value: 0.5,
                  color: MetaGymTheme.primary,
                  strokeWidth: 2.2,
                )
              : const CircularProgressIndicator(
                  color: MetaGymTheme.primary,
                  strokeWidth: 2.2,
                ),
        ),
      );
    }
    if (_error != null) {
      return _ServiceErrorPanel(message: _error!, onRetry: _load);
    }

    final gymStatus = hasGym
        ? 'Hiệu lực'
        : _hadGym
        ? 'Hết hạn'
        : 'Chưa có';
    final gymStatusColor = hasGym
        ? MetaGymTheme.success
        : _hadGym
        ? MetaGymTheme.warning
        : MetaGymTheme.textSecondary;

    final coachStatus = relationship == null
        ? 'Khám phá'
        : relationship.status == 'ACTIVE'
        ? 'Hiệu lực'
        : relationship.status == 'PAUSED'
        ? 'Tạm ngưng'
        : relationship.statusLabel;
    final coachStatusColor = relationship == null
        ? MetaGymTheme.reflectionBlue
        : relationship.status == 'ACTIVE'
        ? MetaGymTheme.success
        : relationship.status == 'PAUSED'
        ? MetaGymTheme.warning
        : MetaGymTheme.textSecondary;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _ServiceMetricPanel(
              disableBlur: disableBlur,
              onTap: () => _open(const MembershipPage()),
              leading: Icon(
                Icons.card_membership_outlined,
                color: MetaGymTheme.primary,
                size: 16,
              ),
              title: 'Gói tập',
              statusText: gymStatus,
              statusColor: gymStatusColor,
              headline: hasGym
                  ? '$daysLeft ngày'
                  : _hadGym
                  ? 'Đã hết hạn'
                  : 'Chưa có gói',
              isNumericHeadline: hasGym,
              detail: hasGym
                  ? 'Còn lại · Hết hạn ${DateFormat('dd/MM/yyyy').format(endDate!)}'
                  : _hadGym
                  ? 'Gia hạn để tiếp tục tập luyện.'
                  : 'Chọn gói phù hợp để bắt đầu.',
              action: hasGym
                  ? 'Xem gói tập'
                  : _hadGym
                  ? 'Gia hạn gói tập'
                  : 'Xem các gói tập',
              actionColor: hasGym
                  ? MetaGymTheme.reflectionBlue
                  : MetaGymTheme.primary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ServiceMetricPanel(
              disableBlur: disableBlur,
              onTap: () => _open(
                relationship == null
                    ? const CoachSelectionPage()
                    : const MemberCoachingPage(),
              ),
              leading: coachInitials != null && relationship != null
                  ? Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: MetaGymTheme.coachAvatarBackground,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        coachInitials,
                        style: const TextStyle(
                          color: MetaGymTheme.coachAvatarForeground,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    )
                  : const Icon(
                      Icons.person_outline_rounded,
                      color: MetaGymTheme.reflectionBlue,
                      size: 16,
                    ),
              title: 'Gói Coach',
              statusText: coachStatus,
              statusColor: coachStatusColor,
              headline: relationship == null
                  ? 'Khám phá Coach'
                  : _coachName ?? 'Coach của bạn',
              isNumericHeadline: false,
              detail: relationship == null
                  ? hasGym
                        ? 'Xem Coach và gói phù hợp.'
                        : 'Xem hồ sơ trước khi mua gói tập.'
                  : relationship.status == 'PAUSED'
                  ? 'Tạm ngưng · Gia hạn gói tập để tiếp tục.'
                  : 'Coach cá nhân · ${relationship.statusLabel}',
              action: relationship == null ? 'Xem danh sách' : 'Xem gói Coach',
              actionColor: MetaGymTheme.reflectionBlue,
            ),
          ),
        ],
      ),
    );
  }
}

bool _disableBackdropBlur(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context) ||
    MetaGymTheme.isFlutterTestEnvironment;

String? _extractInitials(String? name) {
  if (name == null) return null;
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return null;
  if (parts.length >= 2) {
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
  final word = parts.first;
  return word.substring(0, word.length >= 2 ? 2 : 1).toUpperCase();
}

/// Same photo, ambient lights and dark scrim as the approved Member Home.
/// Kept behind the scroll view so the image is decoded once and stays still.
class _TrainingBackground extends StatelessWidget {
  const _TrainingBackground();

  @override
  Widget build(BuildContext context) => const IgnorePointer(
    child: Stack(
      fit: StackFit.expand,
      children: [
        Image(
          image: AssetImage('assets/images/gym_banner.png'),
          fit: BoxFit.cover,
          errorBuilder: _backgroundFallback,
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0.85, -0.75),
              radius: 0.9,
              colors: [Color(0x2E8EB9E5), Colors.transparent],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(-0.85, 0.75),
              radius: 0.8,
              colors: [Color(0x24FF5A36), Colors.transparent],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x9E0F1115), Color(0x900F1115), Color(0xAA0F1115)],
              stops: [0, 0.48, 1],
            ),
          ),
        ),
      ],
    ),
  );

  static Widget _backgroundFallback(
    BuildContext context,
    Object error,
    StackTrace? stackTrace,
  ) => const ColoredBox(color: MetaGymTheme.darkCanvas);
}

class _TrainingHeader extends StatelessWidget {
  const _TrainingHeader({
    required this.disableBlur,
    required this.onOpenLibrary,
    required this.onOpenHistory,
  });

  final bool disableBlur;
  final VoidCallback onOpenLibrary;
  final VoidCallback onOpenHistory;

  @override
  Widget build(BuildContext context) {
    return MetaGymBrandHeader(
      eyebrow: 'META GYM · TẬP LUYỆN',
      title: 'Tập luyện',
      actionSpacing: 4,
      actions: [
        _CircleHeaderActionButton(
          disableBlur: disableBlur,
          icon: Icons.sports_gymnastics_outlined,
          semanticLabel: 'Mở thư viện bài tập',
          onTap: onOpenLibrary,
        ),
        _CircleHeaderActionButton(
          disableBlur: disableBlur,
          icon: Icons.history_rounded,
          semanticLabel: 'Mở lịch sử tập luyện',
          onTap: onOpenHistory,
        ),
      ],
    );
  }
}

class _CircleHeaderActionButton extends StatelessWidget {
  const _CircleHeaderActionButton({
    required this.disableBlur,
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
  });

  final bool disableBlur;
  final IconData icon;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Tooltip(
        message: semanticLabel,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              child: Center(
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: disableBlur
                        ? const Color(0xFF282320)
                        : const Color(0x9E2F2924),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0x95ADA295),
                      width: 1,
                    ),
                  ),
                  child: Icon(icon, color: const Color(0xFFF7F9FC), size: 20),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label, {this.accent = false});

  final String label;
  final bool accent;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      if (accent) ...[
        Container(
          width: 3,
          height: 17,
          decoration: BoxDecoration(
            color: MetaGymTheme.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
      ],
      Flexible(
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFFF7F9FC),
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ],
  );
}

/// Level 2 Hero Smoked Glass card synchronized 1:1 with Member Home's
/// `_buildMembershipGlassCard`. Uses `BackdropFilter` only on this hero card.
class _ServiceHeroGlassCard extends StatelessWidget {
  const _ServiceHeroGlassCard({required this.disableBlur, required this.child});

  final bool disableBlur;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(24);
    final surface = Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: disableBlur ? const Color(0xFF282320) : null,
        gradient: disableBlur
            ? null
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xCD342D28), Color(0xC829241F)],
              ),
        borderRadius: radius,
        border: Border.all(color: const Color(0xB7B3A99D), width: 1.2),
      ),
      child: Stack(
        children: [
          const Positioned(
            left: 20,
            right: 20,
            top: 0,
            child: SizedBox(
              height: 1,
              child: ColoredBox(color: Color(0x75FFF5E9)),
            ),
          ),
          Padding(padding: const EdgeInsets.all(12), child: child),
        ],
      ),
    );
    if (disableBlur) {
      return surface;
    }
    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: surface,
        ),
      ),
    );
  }
}

class _ServiceMetricPanel extends StatelessWidget {
  const _ServiceMetricPanel({
    required this.disableBlur,
    required this.onTap,
    required this.leading,
    required this.title,
    required this.statusText,
    required this.statusColor,
    required this.headline,
    required this.isNumericHeadline,
    required this.detail,
    required this.action,
    required this.actionColor,
  });

  final bool disableBlur;
  final VoidCallback onTap;
  final Widget leading;
  final String title;
  final String statusText;
  final Color statusColor;
  final String headline;
  final bool isNumericHeadline;
  final String detail;
  final String action;
  final Color actionColor;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(17);
    return Material(
      color: disableBlur ? MetaGymTheme.cardSurface : const Color(0x80211E1C),
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(
          color: disableBlur
              ? MetaGymTheme.cardBorder
              : const Color(0x9A8C8176),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 136),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(11, 11, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    leading,
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFF7F9FC),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _StatusBadge(label: statusText, color: statusColor),
                const SizedBox(height: 8),
                Text(
                  headline,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: const Color(0xFFF7F9FC),
                    fontSize: isNumericHeadline ? 20 : 15,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                    fontFeatures: isNumericHeadline
                        ? MetaGymTheme.tabularFigures
                        : null,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  detail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFB7B2AF),
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
                const Spacer(),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        action,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: actionColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: actionColor,
                      size: 16,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.42), width: 0.8),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          height: 1.15,
        ),
      ),
    );
  }
}

class _ServiceErrorPanel extends StatelessWidget {
  const _ServiceErrorPanel({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: MetaGymTheme.warning,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Color(0xFFEAE6E2),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onRetry,
            style: FilledButton.styleFrom(
              backgroundColor: MetaGymTheme.primary,
              foregroundColor: MetaGymTheme.onPrimary,
              minimumSize: const Size(120, 44),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text(
              'Thử lại',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

/// Level 1 stable content card synchronized with Member Home's
/// `_buildLiquidGlassCard` surface (zero backdrop blur, zero orange glow).
class _TrainingContentCard extends StatelessWidget {
  const _TrainingContentCard({
    required this.disableBlur,
    required this.onTap,
    required this.child,
    this.featured = false,
  });

  final bool disableBlur;
  final VoidCallback onTap;
  final Widget child;
  final bool featured;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(MetaGymTheme.radiusCard);
    final fillColor = disableBlur
        ? MetaGymTheme.cardSurface
        : (featured ? const Color(0xB82D2824) : const Color(0xC42B2622));
    final borderColor = disableBlur
        ? MetaGymTheme.cardBorder
        : const Color(0xA3A79D92);

    final surface = Material(
      color: fillColor,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: borderColor, width: 1.1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Stack(
          children: [
            if (featured && !disableBlur)
              const Positioned(
                top: 0,
                left: 18,
                right: 18,
                child: SizedBox(
                  height: 1,
                  child: ColoredBox(color: Color(0x70FFF6EA)),
                ),
              ),
            child,
          ],
        ),
      ),
    );
    if (!featured || disableBlur) return surface;
    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: surface,
        ),
      ),
    );
  }
}

class _FeaturedPlanCard extends StatelessWidget {
  const _FeaturedPlanCard({
    required this.disableBlur,
    required this.icon,
    required this.iconColor,
    required this.locked,
    required this.title,
    required this.detail,
    required this.onTap,
    this.leadingTile,
    this.statusBadge,
    this.showActionPill = false,
    this.actionPillLabel,
  });

  final bool disableBlur;
  final IconData icon;
  final Color iconColor;
  final bool locked;
  final String title;
  final String detail;
  final VoidCallback onTap;
  final Widget? leadingTile;
  final String? statusBadge;
  final bool showActionPill;
  final String? actionPillLabel;

  @override
  Widget build(BuildContext context) {
    return _TrainingContentCard(
      disableBlur: disableBlur,
      featured: true,
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 74),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              leadingTile ??
                  _IconBadge(
                    icon: icon,
                    iconColor: iconColor,
                    locked: locked,
                    size: 46,
                    iconSize: 22,
                  ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFFF7F9FC),
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (statusBadge != null) ...[
                          const SizedBox(width: 8),
                          _StatusBadge(
                            label: statusBadge!,
                            color: MetaGymTheme.success,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      detail,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFB7B2AF),
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (showActionPill && actionPillLabel != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: MetaGymTheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    actionPillLabel!,
                    style: const TextStyle(
                      color: MetaGymTheme.onPrimary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              else
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF9EAAB8),
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BentoToolCard extends StatelessWidget {
  const _BentoToolCard({
    required this.disableBlur,
    required this.icon,
    required this.iconColor,
    required this.locked,
    required this.title,
    required this.detail,
    required this.onTap,
    this.ctaPillLabel,
  });

  final bool disableBlur;
  final IconData icon;
  final Color iconColor;
  final bool locked;
  final String title;
  final String detail;
  final VoidCallback onTap;
  final String? ctaPillLabel;

  @override
  Widget build(BuildContext context) {
    return _TrainingContentCard(
      disableBlur: disableBlur,
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 122),
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _IconBadge(
                    icon: icon,
                    iconColor: iconColor,
                    locked: locked,
                    size: 36,
                    iconSize: 19,
                  ),
                  const Spacer(),
                  if (ctaPillLabel != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: MetaGymTheme.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        ctaPillLabel!,
                        style: const TextStyle(
                          color: MetaGymTheme.onPrimary,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  else
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Color(0xFF9EAAB8),
                      size: 19,
                    ),
                ],
              ),
              const SizedBox(height: 11),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFFF7F9FC),
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                detail,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFFB7B2AF),
                  fontSize: 11,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({
    required this.icon,
    required this.iconColor,
    required this.locked,
    required this.size,
    required this.iconSize,
  });

  final IconData icon;
  final Color iconColor;
  final bool locked;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = locked ? MetaGymTheme.textSecondary : iconColor;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: effectiveColor.withValues(alpha: locked ? 0.12 : 0.16),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: effectiveColor.withValues(alpha: locked ? 0.28 : 0.42),
                width: 1,
              ),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: iconSize, color: effectiveColor),
          ),
          if (locked)
            Positioned(
              right: -3,
              bottom: -3,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: MetaGymTheme.cardSurface,
                  shape: BoxShape.circle,
                  border: Border.all(color: MetaGymTheme.primary, width: 1),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.lock_rounded,
                  size: 10,
                  color: MetaGymTheme.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
