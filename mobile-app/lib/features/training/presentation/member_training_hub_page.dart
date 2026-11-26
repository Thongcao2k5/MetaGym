import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:meta_gym_app/core/navigation/meta_gym_navigation.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/theme/meta_gym_icons.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_bottom_nav.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_svg_icon.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_tap.dart';
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

import 'nutrition_tracking_page.dart';

/// 2.1 Trung tâm Tập luyện — Luxury Warm Smoked Glass design synchronized with
/// the approved Member Home & Tab 2 preview studio.
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
    MetaGymNavigation.pushOnce<void>(
      context,
      MetaGymPageRoute(builder: (_) => page),
    ).then((_) {
      if (mounted) _load();
    });
  }

  Future<void> _requirePackage({
    required bool coach,
    required String feature,
  }) async {
    final isExpired = !coach && _hadGym;
    final colors = MetaGymColors.of(context);
    final destination = await MetaGymNavigation.showSheetOnce<bool>(
      context: context,
      backgroundColor: colors.overlayGlass,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final sheetPalette = MetaGymTheme.paletteOf(context);
        return SafeArea(
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
                  style: TextStyle(
                    color: sheetPalette.textPrimary,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  coach
                      ? 'Đăng ký gói Coach để mở $feature.'
                      : '${isExpired ? 'Gia hạn' : 'Đăng ký'} gói tập để sử dụng $feature.',
                  style: TextStyle(
                    color: sheetPalette.textSecondary,
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
        );
      },
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
    final lockedCurriculum =
        !_loading && _error == null && (!hasGym || !hasCoach);

    final palette = MetaGymTheme.paletteOf(context);
    final colors = MetaGymColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: palette.canvas,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const MetaGymBackground(),
            SafeArea(
              bottom: false,
              child: RefreshIndicator(
                color: MetaGymTheme.primary,
                backgroundColor: colors.surface,
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
                      onOpenLibrary: () => _open(const ExerciseLibraryPage()),
                      onOpenHistory: () => _open(const GymVisitsPage()),
                    ),
                    const SizedBox(height: 12),
                    _TodayWorkoutHeroCard(
                      locked: lockedCurriculum,
                      hasGym: hasGym,
                      coachName: _coachName,
                      coachInitials: coachInitials,
                      todaySelfPlan: _todaySelfPlan,
                      onStartWorkout: lockedCurriculum
                          ? _openPlan
                          : _openJournal,
                      onOpenCurriculum: _openPlan,
                    ),
                    const SizedBox(height: 12),
                    _buildServiceBento(
                      hasGym: hasGym,
                      daysLeft: daysLeft,
                      endDate: end,
                      relationship: relationship,
                      coachInitials: coachInitials,
                    ),
                    const SizedBox(height: 16),
                    const _SectionHeader(
                      title: 'Kế hoạch & Dinh dưỡng',
                      trailing: 'Tuần 4',
                    ),
                    const SizedBox(height: 10),
                    _NutritionTodayCard(
                      onTap: () => _open(const NutritionTrackingPage()),
                    ),
                    const SizedBox(height: 10),
                    _WeeklySelfPlanCard(
                      todaySelfPlan: _todaySelfPlan,
                      todaySelfIconKey: _todaySelfIconKey,
                      onTap: () => _open(const MemberSelfTrainingPage()),
                    ),
                    const SizedBox(height: 16),
                    const _SectionHeader(
                      title: 'Công cụ & Thư viện',
                      trailing: '4 tiện ích',
                    ),
                    const SizedBox(height: 10),
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _BentoToolCard(
                              svgAsset: MetaGymIcons.statsReport,
                              fallbackIcon: Icons.calendar_month_outlined,
                              accentColor: MetaGymTheme.primary,
                              locked: !hasGym && !_loading && _error == null,
                              title: 'Nhật ký tập luyện',
                              subtitle: _loading || _error != null
                                  ? 'Lưu PR, ảnh & số đo'
                                  : !hasGym
                                  ? (_hadGym
                                        ? 'Chỉ xem · Gia hạn'
                                        : 'Cần gói tập')
                                  : 'Lưu PR, ảnh & số đo',
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
                              svgAsset: MetaGymIcons.workoutHistory,
                              fallbackIcon: Icons.history_rounded,
                              accentColor: MetaGymTheme.success,
                              locked: false,
                              title: 'Lịch sử & Check-in',
                              subtitle: '18 lượt đến phòng gym',
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
                              svgAsset: MetaGymIcons.equipBarbell,
                              fallbackIcon: Icons.sports_gymnastics_outlined,
                              accentColor: MetaGymTheme.warning,
                              locked: false,
                              title: 'Thư viện bài tập',
                              subtitle: '120+ bài chuẩn form',
                              onTap: () => _open(const ExerciseLibraryPage()),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _BentoToolCard(
                              svgAsset: MetaGymIcons.equipMachine,
                              fallbackIcon: Icons.fitness_center_outlined,
                              accentColor: MetaGymTheme.reflectionBlue,
                              locked: false,
                              title: 'Phòng gym & Thiết bị',
                              subtitle: 'Hướng dẫn máy & nội quy',
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

  Widget _buildServiceBento({
    required bool hasGym,
    required int? daysLeft,
    required DateTime? endDate,
    required MemberCoachRelationship? relationship,
    required String? coachInitials,
  }) {
    if (_loading) {
      return _WarmGlassShell(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 108,
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
        ),
      );
    }
    if (_error != null) {
      return _WarmGlassShell(
        padding: const EdgeInsets.all(14),
        child: _ServiceErrorPanel(message: _error!, onRetry: _load),
      );
    }

    final gymProgress = hasGym && daysLeft != null
        ? (daysLeft / 60).clamp(0.18, 0.96)
        : 0.0;
    final coachActive = relationship != null && relationship.status == 'ACTIVE';
    final coachPaused = relationship != null && relationship.status == 'PAUSED';

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _MembershipBentoCard(
              hasGym: hasGym,
              hadGym: _hadGym,
              daysLeft: daysLeft,
              endDate: endDate,
              progress: gymProgress,
              onTap: () => _open(const MembershipPage()),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _CoachBentoCard(
              relationship: relationship,
              coachActive: coachActive,
              coachPaused: coachPaused,
              coachName: _coachName,
              coachInitials: coachInitials,
              onTap: () => _open(
                relationship == null
                    ? const CoachSelectionPage()
                    : const MemberCoachingPage(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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

class _TrainingHeader extends StatelessWidget {
  const _TrainingHeader({
    required this.onOpenLibrary,
    required this.onOpenHistory,
  });

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
          svgAsset: MetaGymIcons.equipDumbbell,
          fallbackIcon: Icons.sports_gymnastics_outlined,
          semanticLabel: 'Mở thư viện bài tập',
          onTap: onOpenLibrary,
        ),
        _CircleHeaderActionButton(
          svgAsset: MetaGymIcons.workoutHistory,
          fallbackIcon: Icons.history_rounded,
          semanticLabel: 'Mở lịch sử tập luyện',
          onTap: onOpenHistory,
        ),
      ],
    );
  }
}

class _CircleHeaderActionButton extends StatelessWidget {
  const _CircleHeaderActionButton({
    required this.svgAsset,
    required this.fallbackIcon,
    required this.semanticLabel,
    required this.onTap,
  });

  final String svgAsset;
  final IconData fallbackIcon;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = MetaGymColors.of(context);
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Tooltip(
        message: semanticLabel,
        child: Material(
          color: Colors.transparent,
          child: MetaGymTap(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              child: Center(
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: colors.circleButtonBg,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: colors.circleButtonBorder,
                      width: 1,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: MetaGymSvgIcon(
                    svgAsset,
                    size: 20,
                    fallbackIcon: fallbackIcon,
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.trailing});

  final String title;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    final palette = MetaGymTheme.paletteOf(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          trailing,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: palette.textWarmMuted,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            fontFeatures: MetaGymTheme.tabularFigures,
          ),
        ),
      ],
    );
  }
}

/// Shared Warm Smoked Glass container (zero scrolling BackdropFilter).
class _WarmGlassShell extends StatelessWidget {
  const _WarmGlassShell({
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.radius = 20,
    this.gradient,
    this.borderColor,
    this.cornerGlowColor,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Gradient? gradient;
  final Color? borderColor;
  final Color? cornerGlowColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = MetaGymColors.of(context);
    final isLight = MetaGymTheme.isLightPalette(context);
    final borderRadius = BorderRadius.circular(radius);
    final content = Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        if (cornerGlowColor != null)
          Positioned(
            top: -24,
            right: -24,
            child: IgnorePointer(
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [cornerGlowColor!, Colors.transparent],
                    stops: const [0.0, 0.72],
                  ),
                ),
              ),
            ),
          ),
        Positioned(
          top: 0,
          left: 18,
          right: 18,
          child: SizedBox(
            height: 1,
            child: ColoredBox(color: colors.warmGlassHighlight),
          ),
        ),
        Padding(padding: padding, child: child),
      ],
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: gradient == null ? colors.liquidGlass : null,
        gradient: gradient,
        borderRadius: borderRadius,
        border: Border.all(
          color: borderColor ?? colors.liquidGlassBorder,
          width: 1.1,
        ),
        boxShadow: isLight
            ? const [
                BoxShadow(
                  color: Color(0x140F172A),
                  blurRadius: 14,
                  offset: Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: borderRadius,
        clipBehavior: Clip.antiAlias,
        child: onTap == null
            ? content
            : MetaGymTap(
                onTap: onTap,
                borderRadius: borderRadius,
                child: content,
              ),
      ),
    );
  }
}

/// Hero Card: Buổi tập hôm nay (Warm coral-tinted Smoked Glass).
class _TodayWorkoutHeroCard extends StatelessWidget {
  const _TodayWorkoutHeroCard({
    required this.locked,
    required this.hasGym,
    required this.coachName,
    required this.coachInitials,
    required this.todaySelfPlan,
    required this.onStartWorkout,
    required this.onOpenCurriculum,
  });

  final bool locked;
  final bool hasGym;
  final String? coachName;
  final String? coachInitials;
  final MemberSelfTrainingDay? todaySelfPlan;
  final VoidCallback onStartWorkout;
  final VoidCallback onOpenCurriculum;

  @override
  Widget build(BuildContext context) {
    final palette = MetaGymTheme.paletteOf(context);
    final isLight = MetaGymTheme.isLightPalette(context);
    final timeBadge = todaySelfPlan?.startTime != null
        ? '● Hôm nay · ${todaySelfPlan!.startTime}'
        : '● Hôm nay · 18:00';
    final headline = locked
        ? 'Giáo trình của Coach'
        : (todaySelfPlan?.title ?? 'Ngực & Tay sau · Chest & Triceps');
    final exerciseCount =
        todaySelfPlan != null && todaySelfPlan!.exercises.isNotEmpty
        ? '${todaySelfPlan!.exercises.length}'
        : '6';
    final displayCoach = coachName ?? 'Lê Hoàng Nam';
    final displayInitials = coachInitials ?? 'LN';

    return _WarmGlassShell(
      padding: const EdgeInsets.all(15),
      radius: 22,
      borderColor: isLight
          ? const Color(0x66D9431E)
          : const Color(0x85FF8A5B),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isLight
            ? const [Color(0xFFFFF6F2), Color(0xFFFFFFFF), Color(0xFFF8FAFC)]
            : const [Color(0xE0422C23), Color(0xD22B2622), Color(0xDC201C19)],
        stops: const [0.0, 0.55, 1.0],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: palette.chipActiveBg,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: MetaGymTheme.primary.withValues(alpha: 0.42),
                      width: 0.9,
                    ),
                  ),
                  child: Text(
                    timeBadge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isLight
                          ? palette.primaryText
                          : const Color(0xFFFF9B73),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      fontFeatures: MetaGymTheme.tabularFigures,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: palette.metricPanelBg,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: palette.metricPanelBorder,
                      width: 0.9,
                    ),
                  ),
                  child: Text(
                    locked ? 'Chưa kích hoạt' : '90 phút · Push Day',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      fontFeatures: MetaGymTheme.tabularFigures,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            headline,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 16.5,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: MetaGymTheme.coachAvatarBackground,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  locked ? 'MG' : displayInitials,
                  style: const TextStyle(
                    color: MetaGymTheme.coachAvatarForeground,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  locked
                      ? (!hasGym
                            ? 'Cần gói tập và gói Coach để mở giáo trình'
                            : 'Cần gói Coach để mở giáo trình 1:1')
                      : 'Giáo trình tuần 4 · HLV $displayCoach',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _HeroMetricBox(
                  value: exerciseCount,
                  label: 'Bài tập',
                  valueColor: palette.textPrimary,
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: _HeroMetricBox(
                  value: '22',
                  label: 'Tổng hiệp',
                  valueColor: palette.primaryText,
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: _HeroMetricBox(
                  value: '~540',
                  label: 'Kcal',
                  valueColor: palette.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: FilledButton(
                    onPressed: onStartWorkout,
                    style: FilledButton.styleFrom(
                      backgroundColor: MetaGymTheme.primary,
                      foregroundColor: MetaGymTheme.onPrimary,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        locked ? 'Đăng ký' : 'Bắt đầu tập →',
                        maxLines: 1,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: OutlinedButton(
                    onPressed: onOpenCurriculum,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: palette.textPrimary,
                      backgroundColor: isLight
                          ? palette.surfaceRaised
                          : const Color(0x55181513),
                      side: BorderSide(
                        color: isLight
                            ? palette.borderSolid
                            : const Color(0x70B3A99D),
                        width: 1,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                    child: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Xem giáo trình',
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroMetricBox extends StatelessWidget {
  const _HeroMetricBox({
    required this.value,
    required this.label,
    required this.valueColor,
  });

  final String value;
  final String label;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    final palette = MetaGymTheme.paletteOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: palette.metricPanelBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.metricPanelBorder, width: 0.9),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                color: valueColor,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                fontFeatures: MetaGymTheme.tabularFigures,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.textSecondary,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Left Bento Card: HẠNG VÀNG / Gói tập (100% single-line text, no wrapping).
class _MembershipBentoCard extends StatelessWidget {
  const _MembershipBentoCard({
    required this.hasGym,
    required this.hadGym,
    required this.daysLeft,
    required this.endDate,
    required this.progress,
    required this.onTap,
  });

  final bool hasGym;
  final bool hadGym;
  final int? daysLeft;
  final DateTime? endDate;
  final double progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = MetaGymTheme.paletteOf(context);
    final isLight = MetaGymTheme.isLightPalette(context);
    final gold = isLight ? palette.warning : const Color(0xFFF5B041);
    final statusColor = hasGym
        ? palette.success
        : hadGym
        ? palette.warning
        : palette.textSecondary;

    return _WarmGlassShell(
      padding: const EdgeInsets.fromLTRB(12, 13, 12, 12),
      radius: 20,
      borderColor: hasGym
          ? (isLight ? const Color(0x70B45309) : const Color(0x6BF5B041))
          : null,
      cornerGlowColor: hasGym
          ? (isLight ? const Color(0x20B45309) : const Color(0x42F5B041))
          : null,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isLight
            ? const [Color(0xFFFFFBF2), Color(0xFFFFFFFF)]
            : const [Color(0xE03A2F24), Color(0xDC24201C)],
      ),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const MetaGymSvgIcon(
                    MetaGymIcons.premiumCrown,
                    size: 13,
                    fallbackIcon: Icons.workspace_premium_rounded,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      hasGym ? 'HẠNG VÀNG' : 'GÓI TẬP',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: gold,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  _StatusDot(color: statusColor),
                ],
              ),
              const SizedBox(height: 8),
              if (hasGym && daysLeft != null) ...[
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '$daysLeft',
                        maxLines: 1,
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontSize: 23,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.6,
                          height: 1,
                          fontFeatures: MetaGymTheme.tabularFigures,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'ngày còn lại',
                        maxLines: 1,
                        style: TextStyle(
                          color: palette.textSecondary,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  endDate != null
                      ? 'Hạn ${DateFormat('dd/MM/yyyy').format(endDate!)}'
                      : 'Đang hiệu lực',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 10.5,
                    fontFeatures: MetaGymTheme.tabularFigures,
                  ),
                ),
              ] else ...[
                Text(
                  hadGym ? 'Đã hết hạn' : 'Chưa có gói',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hadGym ? 'Gia hạn để tiếp tục' : 'Chọn gói để bắt đầu',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ],
          ),
          Column(
            children: [
              const SizedBox(height: 10),
              _MiniProgressBar(
                progress: progress,
                colors: const [Color(0xFFF5B041), Color(0xFF2ECC71)],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      hasGym
                          ? 'Xem gói tập'
                          : hadGym
                          ? 'Gia hạn gói'
                          : 'Xem gói tập',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: gold,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    '›',
                    style: TextStyle(
                      color: gold,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Right Bento Card: COACH 1:1 (100% single-line text, no wrapping).
class _CoachBentoCard extends StatelessWidget {
  const _CoachBentoCard({
    required this.relationship,
    required this.coachActive,
    required this.coachPaused,
    required this.coachName,
    required this.coachInitials,
    required this.onTap,
  });

  final MemberCoachRelationship? relationship;
  final bool coachActive;
  final bool coachPaused;
  final String? coachName;
  final String? coachInitials;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = MetaGymTheme.paletteOf(context);
    final isLight = MetaGymTheme.isLightPalette(context);
    final statusColor = coachActive
        ? palette.success
        : coachPaused
        ? palette.warning
        : palette.reflection;

    return _WarmGlassShell(
      padding: const EdgeInsets.fromLTRB(12, 13, 12, 12),
      radius: 20,
      borderColor: coachActive
          ? (isLight ? const Color(0x66D9431E) : const Color(0x6BFF5E36))
          : null,
      cornerGlowColor: coachActive
          ? (isLight ? const Color(0x1CFF5E36) : const Color(0x3DFF5E36))
          : null,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isLight
            ? const [Color(0xFFFFF7F4), Color(0xFFFFFFFF)]
            : const [Color(0xE03C2923), Color(0xDC24201C)],
      ),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'COACH 1:1',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.primaryText,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  _StatusDot(color: statusColor),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (relationship != null)
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: MetaGymTheme.coachAvatarBackground,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: MetaGymTheme.coachAvatarBackground
                                .withValues(alpha: 0.28),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Text(
                        coachInitials ?? 'HL',
                        style: const TextStyle(
                          color: MetaGymTheme.coachAvatarForeground,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    )
                  else
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: palette.reflection.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: palette.reflection.withValues(alpha: 0.38),
                        ),
                      ),
                      child: MetaGymSvgIcon(MetaGymIcons.settingPersonalInfo, size: 16, fallbackIcon: Icons.person_outline_rounded),
                    ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          relationship == null
                              ? 'Khám phá Coach'
                              : (coachName ?? 'Coach của bạn'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: palette.textPrimary,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          relationship == null
                              ? 'Chọn HLV cá nhân'
                              : coachPaused
                              ? 'Tạm ngưng · Gia hạn'
                              : 'Còn 14/24 buổi',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: palette.textSecondary,
                            fontSize: 10,
                            fontFeatures: MetaGymTheme.tabularFigures,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          Column(
            children: [
              const SizedBox(height: 10),
              _MiniProgressBar(
                progress: coachActive ? 0.58 : 0.0,
                colors: const [MetaGymTheme.primary, Color(0xFFFF9B73)],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      relationship == null ? 'Xem danh sách' : 'Lịch Coach',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.primaryText,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    '›',
                    style: TextStyle(
                      color: palette.primaryText,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.7), blurRadius: 6),
        ],
      ),
    );
  }
}

class _MiniProgressBar extends StatelessWidget {
  const _MiniProgressBar({
    required this.progress,
    required this.colors,
    this.height = 4,
  });

  final double progress;
  final List<Color> colors;
  final double height;

  @override
  Widget build(BuildContext context) {
    final isLight = MetaGymTheme.isLightPalette(context);
    final clamped = progress.clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: height,
        color: isLight ? const Color(0xFFDCE4EE) : const Color(0x22FFFFFF),
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: clamped,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: colors),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
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
    final palette = MetaGymTheme.paletteOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            MetaGymSvgIcon(MetaGymIcons.stateWarning, size: 20, fallbackIcon: Icons.warning_amber_rounded),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: palette.textPrimary,
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
            minimumSize: const Size(120, 48),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: const MetaGymSvgIcon(MetaGymIcons.commonRefresh, size: 18, fallbackIcon: Icons.refresh_rounded),
          label: const Text(
            'Thử lại',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

/// Dinh dưỡng hôm nay card with 48x48 accessible right action target.
class _NutritionTodayCard extends StatelessWidget {
  const _NutritionTodayCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = MetaGymTheme.paletteOf(context);
    return _WarmGlassShell(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 13),
      radius: 20,
      onTap: onTap,
      child: Column(
        key: const Key('nutrition-tool-card'),
        children: [
          Row(
            children: [
              _SvgIconWell(
                svgAsset: MetaGymIcons.actionNutrition,
                fallbackIcon: Icons.restaurant_menu_rounded,
                accentColor: palette.success,
                size: 38,
                iconSize: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dinh dưỡng hôm nay',
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
                      '1.840 / 2.400 kcal · Đạm 140/160g',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 11,
                        fontFeatures: MetaGymTheme.tabularFigures,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Material(
                color: Colors.transparent,
                child: MetaGymTap(
                  key: const Key('nutrition-tool-open'),
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(14),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: palette.success.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: palette.success.withValues(alpha: 0.42),
                          ),
                        ),
                        child: Text(
                          '77%',
                          maxLines: 1,
                          style: TextStyle(
                            color: palette.success,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            fontFeatures: MetaGymTheme.tabularFigures,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.only(right: 4),
            child: _MiniProgressBar(
              progress: 0.77,
              height: 5,
              colors: [MetaGymTheme.success, Color(0xFF59E59A)],
            ),
          ),
        ],
      ),
    );
  }
}

/// Lịch tập tuần của tôi with 7-day strip and MuscleAnatomyTile when today's
/// self-training plan exists.
class _WeeklySelfPlanCard extends StatelessWidget {
  const _WeeklySelfPlanCard({
    required this.todaySelfPlan,
    required this.todaySelfIconKey,
    required this.onTap,
  });

  final MemberSelfTrainingDay? todaySelfPlan;
  final String? todaySelfIconKey;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = MetaGymTheme.paletteOf(context);
    final subtitle = todaySelfPlan == null
        ? 'Hoàn thành 3/5 buổi mục tiêu'
        : [
            'Hôm nay',
            if (todaySelfPlan!.startTime != null) todaySelfPlan!.startTime!,
            todaySelfPlan!.title,
          ].join(' · ');

    return _WarmGlassShell(
      padding: const EdgeInsets.all(14),
      radius: 20,
      onTap: onTap,
      child: Column(
        children: [
          Row(
            children: [
              if (todaySelfPlan != null)
                MuscleAnatomyTile(
                  focuses: resolveMuscleFocusSet(
                    todaySelfPlan!.title,
                    exerciseNames: todaySelfPlan!.exercises
                        .map((e) => e.name)
                        .toList(),
                    explicitKey: todaySelfIconKey,
                  ),
                  width: 38,
                  height: 42,
                )
              else
                _SvgIconWell(
                  svgAsset: MetaGymIcons.workoutPlanCalendar,
                  fallbackIcon: Icons.event_note_rounded,
                  accentColor: palette.reflection,
                  size: 38,
                  iconSize: 20,
                ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lịch tập tuần của tôi',
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
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Mở ›',
                maxLines: 1,
                style: TextStyle(
                  color: palette.primaryText,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Row(
            children: [
              Expanded(
                child: _DayChip(label: 'T2✓', state: _DayState.done),
              ),
              SizedBox(width: 5),
              Expanded(
                child: _DayChip(label: 'T3✓', state: _DayState.done),
              ),
              SizedBox(width: 5),
              Expanded(
                child: _DayChip(label: 'T4', state: _DayState.today),
              ),
              SizedBox(width: 5),
              Expanded(
                child: _DayChip(label: 'T5', state: _DayState.upcoming),
              ),
              SizedBox(width: 5),
              Expanded(
                child: _DayChip(label: 'T6', state: _DayState.upcoming),
              ),
              SizedBox(width: 5),
              Expanded(
                child: _DayChip(label: 'T7', state: _DayState.upcoming),
              ),
              SizedBox(width: 5),
              Expanded(
                child: _DayChip(label: 'CN', state: _DayState.rest),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _DayState { done, today, upcoming, rest }

class _DayChip extends StatelessWidget {
  const _DayChip({required this.label, required this.state});

  final String label;
  final _DayState state;

  @override
  Widget build(BuildContext context) {
    final palette = MetaGymTheme.paletteOf(context);
    final isLight = MetaGymTheme.isLightPalette(context);
    final (bg, border, textColor, weight) = switch (state) {
      _DayState.done => (
        palette.success.withValues(alpha: 0.14),
        palette.success.withValues(alpha: 0.42),
        palette.success,
        FontWeight.w700,
      ),
      _DayState.today => (
        isLight ? MetaGymTheme.primary : const Color(0x38FF5E36),
        MetaGymTheme.primary,
        const Color(0xFFFFFFFF),
        FontWeight.w800,
      ),
      _DayState.upcoming => (
        isLight ? const Color(0xFFE8EEF5) : const Color(0x8C181513),
        isLight ? const Color(0xFFB8C4D2) : const Color(0x47B3A99D),
        palette.textSecondary,
        FontWeight.w600,
      ),
      _DayState.rest => (
        isLight ? const Color(0xFFF1F5F9) : const Color(0x59181513),
        isLight ? const Color(0xFFCBD5E1) : const Color(0x2EB3A99D),
        palette.textSecondary,
        FontWeight.w600,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: border, width: 0.9),
      ),
      alignment: Alignment.center,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          label,
          maxLines: 1,
          style: TextStyle(
            color: textColor,
            fontSize: 10,
            fontWeight: weight,
            fontFeatures: MetaGymTheme.tabularFigures,
          ),
        ),
      ),
    );
  }
}

/// 2x2 Bento Tool Card (strictly single-line title & subtitle).
class _BentoToolCard extends StatelessWidget {
  const _BentoToolCard({
    required this.svgAsset,
    required this.fallbackIcon,
    required this.accentColor,
    required this.locked,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.ctaPillLabel,
  });

  final String svgAsset;
  final IconData fallbackIcon;
  final Color accentColor;
  final bool locked;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String? ctaPillLabel;

  @override
  Widget build(BuildContext context) {
    final palette = MetaGymTheme.paletteOf(context);
    return _WarmGlassShell(
      padding: const EdgeInsets.all(12),
      radius: 18,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _SvgIconWell(
                svgAsset: svgAsset,
                fallbackIcon: fallbackIcon,
                accentColor: locked ? palette.textSecondary : accentColor,
                size: 34,
                iconSize: 18,
                locked: locked,
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
                    maxLines: 1,
                    style: const TextStyle(
                      color: MetaGymTheme.onPrimary,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              else
                Text(
                  '›',
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.textSecondary,
              fontSize: 10.5,
              fontFeatures: MetaGymTheme.tabularFigures,
            ),
          ),
        ],
      ),
    );
  }
}

class _SvgIconWell extends StatelessWidget {
  const _SvgIconWell({
    required this.svgAsset,
    required this.fallbackIcon,
    required this.accentColor,
    required this.size,
    required this.iconSize,
    this.locked = false,
  });

  final String svgAsset;
  final IconData fallbackIcon;
  final Color accentColor;
  final double size;
  final double iconSize;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final colors = MetaGymColors.of(context);
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
              color: accentColor.withValues(alpha: locked ? 0.12 : 0.16),
              borderRadius: BorderRadius.circular(size >= 38 ? 12 : 10),
              border: Border.all(
                color: accentColor.withValues(alpha: locked ? 0.28 : 0.38),
                width: 1,
              ),
            ),
            alignment: Alignment.center,
            child: MetaGymSvgIcon(
              svgAsset,
              size: iconSize,
              fallbackIcon: fallbackIcon,
            ),
          ),
          if (locked)
            Positioned(
              right: -3,
              bottom: -3,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: colors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: MetaGymTheme.primary, width: 1),
                ),
                alignment: Alignment.center,
                child: const MetaGymSvgIcon(MetaGymIcons.settingPrivacyLock, size: 9, fallbackIcon: Icons.lock_rounded),
              ),
            ),
        ],
      ),
    );
  }
}
