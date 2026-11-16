import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_bottom_nav.dart';
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
import 'package:meta_gym_app/features/training/presentation/member_training_page.dart';
import 'package:meta_gym_app/features/training/presentation/member_self_training_page.dart';
import 'package:meta_gym_app/features/training/presentation/training_history_page.dart';
import 'package:provider/provider.dart';

/// Overview of the Member training area. The detailed Coach plan keeps its own
/// page; this screen only routes to features available to the current Member.
class MemberTrainingHubPage extends StatefulWidget {
  const MemberTrainingHubPage({
    this.bottomPadding,
    this.membershipController,
    this.coachingService,
    super.key,
  });

  final double? bottomPadding;
  final MembershipController? membershipController;
  final MemberCoachingService? coachingService;

  @override
  State<MemberTrainingHubPage> createState() => _MemberTrainingHubPageState();
}

class _MemberTrainingHubPageState extends State<MemberTrainingHubPage> {
  MembershipController? _membership;
  MemberCoachingService? _coaching;
  MemberCoachRelationship? _relationship;
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
      if (!mounted) return;
      setState(() {
        _relationship = relationship;
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
      backgroundColor: MetaGymTheme.cardSurface,
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
                  minimumSize: const Size.fromHeight(52),
                  textStyle: const TextStyle(
                    fontSize: 19,
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

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: MetaGymTheme.darkCanvas,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const _TrainingBackground(),
            BackdropGroup(
              child: SafeArea(
                bottom: false,
                child: RefreshIndicator(
                  color: MetaGymTheme.primary,
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(16, 20, 16, bottom + 20),
                    children: [
                      const Text(
                        'Tập luyện',
                        style: TextStyle(
                          color: MetaGymTheme.textPrimary,
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const _SectionTitle('Dịch vụ của bạn'),
                      const SizedBox(height: 10),
                      if (_loading)
                        SizedBox(
                          height: 170,
                          child: Center(
                            child: MetaGymTheme.isFlutterTestEnvironment
                                ? const CircularProgressIndicator(
                                    value: 0.5,
                                    color: MetaGymTheme.primary,
                                  )
                                : const CircularProgressIndicator(
                                    color: MetaGymTheme.primary,
                                  ),
                          ),
                        )
                      else if (_error != null)
                        _ErrorCard(message: _error!, onRetry: _load)
                      else
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: _PackageTile(
                                  title: 'Gói tập',
                                  icon: Icons.card_membership_outlined,
                                  headline: hasGym
                                      ? '$daysLeft ngày'
                                      : _hadGym
                                      ? 'Đã hết hạn'
                                      : 'Chưa có gói',
                                  detail: hasGym
                                      ? 'Còn lại · Hết hạn ${DateFormat('dd/MM/yyyy').format(end!)}'
                                      : _hadGym
                                      ? 'Gia hạn để tiếp tục tập luyện.'
                                      : 'Chọn gói phù hợp để bắt đầu.',
                                  action: hasGym
                                      ? 'Xem gói tập'
                                      : _hadGym
                                      ? 'Gia hạn gói tập'
                                      : 'Xem các gói tập',
                                  onTap: () => _open(const MembershipPage()),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _PackageTile(
                                  title: 'Gói Coach',
                                  icon: Icons.person_outline_rounded,
                                  coachInitials:
                                      relationship != null && _coachName != null
                                      ? _coachName!
                                            .trim()
                                            .split(RegExp(r'\s+'))
                                            .map((word) => word[0])
                                            .take(2)
                                            .join()
                                      : null,
                                  headline: relationship == null
                                      ? 'Khám phá Coach'
                                      : _coachName ?? 'Coach của bạn',
                                  detail: relationship == null
                                      ? hasGym
                                            ? 'Xem Coach và gói phù hợp.'
                                            : 'Xem hồ sơ trước khi mua gói tập.'
                                      : relationship.status == 'PAUSED'
                                      ? 'Tạm ngưng · Gia hạn gói tập để tiếp tục.'
                                      : 'Coach cá nhân · ${relationship.statusLabel}',
                                  action: relationship == null
                                      ? 'Xem danh sách'
                                      : 'Xem gói Coach',
                                  onTap: () => _open(
                                    relationship == null
                                        ? const CoachSelectionPage()
                                        : const MemberCoachingPage(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 20),
                      const _SectionTitle('Công cụ tập luyện', accent: true),
                      const SizedBox(height: 10),
                      _FeatureRow(
                        icon: Icons.menu_book_outlined,
                        iconColor: const Color(0xFFFF8A32),
                        locked: !hasGym || !hasCoach,
                        title: 'Giáo trình của Coach',
                        detail: _loading || _error != null
                            ? 'Kế hoạch tập luyện và ăn uống từ Coach'
                            : !hasGym
                            ? 'Cần gói tập và gói Coach'
                            : !hasCoach
                            ? 'Cần gói Coach'
                            : 'Kế hoạch tập luyện và ăn uống từ Coach',
                        actionLabel: _error != null
                            ? 'Thử lại'
                            : hasGym && hasCoach
                            ? 'Mở'
                            : 'Đăng ký',
                        onTap: _openPlan,
                      ),
                      const SizedBox(height: 10),
                      _FeatureRow(
                        icon: Icons.event_note_rounded,
                        iconColor: const Color(0xFF5CBEFF),
                        locked: false,
                        title: 'Lịch tập của tôi',
                        detail: 'Tự lên lịch theo tuần hoặc tháng',
                        actionLabel: 'Mở',
                        onTap: () => _open(const MemberSelfTrainingPage()),
                      ),
                      const SizedBox(height: 10),
                      _FeatureRow(
                        icon: Icons.calendar_month_outlined,
                        iconColor: const Color(0xFF25DE76),
                        locked: !hasGym,
                        title: 'Nhật ký tập luyện',
                        detail: _loading || _error != null
                            ? 'Ghi thành tích, ảnh và số đo theo ngày'
                            : !hasGym
                            ? _hadGym
                                  ? 'Chỉ xem · Gia hạn gói tập để ghi thêm'
                                  : 'Cần gói tập để ghi nhật ký'
                            : 'Ghi thành tích, ảnh và số đo theo ngày',
                        actionLabel: _error != null
                            ? 'Thử lại'
                            : hasGym
                            ? 'Mở'
                            : _hadGym
                            ? 'Gia hạn'
                            : 'Đăng ký',
                        onTap: _openJournal,
                      ),
                      const SizedBox(height: 10),
                      _FeatureRow(
                        icon: Icons.history_rounded,
                        iconColor: const Color(0xFF28AFFF),
                        locked: false,
                        title: 'Lịch sử tập luyện',
                        detail: 'Xem các ngày và lượt đến phòng gym',
                        actionLabel: 'Xem',
                        onTap: () => _open(const TrainingHistoryPage()),
                      ),
                      const SizedBox(height: 10),
                      _FeatureRow(
                        icon: Icons.sports_gymnastics_outlined,
                        iconColor: const Color(0xFFFFB923),
                        locked: false,
                        title: 'Thư viện bài tập',
                        detail: 'Tìm bài theo nhóm cơ và xem cách thực hiện',
                        actionLabel: 'Xem',
                        onTap: () => _open(const ExerciseLibraryPage()),
                      ),
                      const SizedBox(height: 10),
                      _FeatureRow(
                        icon: Icons.fitness_center_outlined,
                        iconColor: const Color(0xFFB45CFF),
                        locked: false,
                        title: 'Phòng gym & thiết bị',
                        detail: 'Nội quy và hướng dẫn dùng máy',
                        actionLabel: 'Xem',
                        onTap: () => _open(const GymEquipmentPage()),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
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
          height: 18,
          decoration: BoxDecoration(
            color: MetaGymTheme.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 9),
      ],
      Text(
        label,
        style: const TextStyle(
          color: MetaGymTheme.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}

class _TrainingGlassBlur extends StatelessWidget {
  const _TrainingGlassBlur({required this.radius, required this.child});

  final double radius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context) ||
        MetaGymTheme.isFlutterTestEnvironment) {
      return child;
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter.grouped(
        filter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
        child: child,
      ),
    );
  }
}

class _PackageTile extends StatelessWidget {
  const _PackageTile({
    required this.title,
    required this.icon,
    required this.headline,
    required this.detail,
    required this.action,
    required this.onTap,
    this.coachInitials,
  });
  final String title, headline, detail, action;
  final IconData icon;
  final VoidCallback onTap;
  final String? coachInitials;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(22),
      boxShadow: const [
        BoxShadow(
          color: Color(0x35FF842F),
          blurRadius: 16,
          offset: Offset(0, 5),
        ),
      ],
    ),
    child: _TrainingGlassBlur(
      radius: 22,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Ink(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xD6493122), Color(0xE02A221E)],
              ),
              border: Border.all(color: const Color(0xC2C89463), width: 1.1),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Stack(
              children: [
                const Positioned(
                  left: 20,
                  right: 20,
                  top: 0,
                  child: SizedBox(
                    height: 1,
                    child: ColoredBox(color: Color(0xAFFFCA8D)),
                  ),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 132),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 11, 11, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: const Color(0xFF4A332A),
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: coachInitials == null
                                  ? Icon(
                                      icon,
                                      color: const Color(0xFFFFAE98),
                                      size: 18,
                                    )
                                  : Container(
                                      alignment: Alignment.center,
                                      decoration: const BoxDecoration(
                                        color:
                                            MetaGymTheme.coachAvatarBackground,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Text(
                                        coachInitials!,
                                        style: const TextStyle(
                                          color: MetaGymTheme
                                              .coachAvatarForeground,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                            ),
                            const SizedBox(width: 7),
                            Flexible(
                              child: Text(
                                title,
                                style: const TextStyle(
                                  color: MetaGymTheme.textPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          headline,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: MetaGymTheme.textPrimary,
                            fontSize: 15,
                            height: 1.25,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          detail,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFE2D8CE),
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
                                maxLines: 2,
                                style: const TextStyle(
                                  color: Color(0xFFFFAE98),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 3),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: Color(0xFFFFAE98),
                              size: 16,
                            ),
                          ],
                        ),
                      ],
                    ),
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

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.icon,
    required this.iconColor,
    required this.locked,
    required this.title,
    required this.detail,
    required this.actionLabel,
    required this.onTap,
  });
  final IconData icon;
  final Color iconColor;
  final bool locked;
  final String title, detail, actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(18),
      boxShadow: const [
        BoxShadow(
          color: Color(0x24F18639),
          blurRadius: 13,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: _TrainingGlassBlur(
      radius: 18,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xDA39312C),
                  Color(0xD52A2522),
                  Color(0xD93B2E27),
                ],
              ),
              border: Border.all(color: const Color(0xB6B9A18E), width: 1),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Stack(
              children: [
                const Positioned(
                  left: 18,
                  right: 18,
                  top: 0,
                  child: SizedBox(
                    height: 1,
                    child: ColoredBox(color: Color(0x93FFE9D3)),
                  ),
                ),
                Container(
                  constraints: const BoxConstraints(minHeight: 76),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color.lerp(
                                iconColor,
                                const Color(0xFF181411),
                                locked ? 0.68 : 0.62,
                              )!,
                              Color.lerp(
                                iconColor,
                                const Color(0xFF181411),
                                locked ? 0.83 : 0.78,
                              )!,
                            ],
                          ),
                          border: Border.all(
                            color: iconColor.withValues(
                              alpha: locked ? 0.65 : 0.9,
                            ),
                          ),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Stack(
                          children: [
                            Align(
                              alignment: Alignment.center,
                              child: Padding(
                                padding: EdgeInsets.only(
                                  right: locked ? 5 : 0,
                                  bottom: locked ? 4 : 0,
                                ),
                                child: Icon(
                                  icon,
                                  size: 22,
                                  color: iconColor.withValues(
                                    alpha: locked ? 0.8 : 1,
                                  ),
                                ),
                              ),
                            ),
                            if (locked)
                              Positioned(
                                right: 1,
                                bottom: 1,
                                child: Container(
                                  width: 18,
                                  height: 18,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF322B29),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0xFFE5C1AE),
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.lock_rounded,
                                    size: 11,
                                    color: Color(0xFFFFE7DA),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                color: MetaGymTheme.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              detail,
                              style: const TextStyle(
                                color: Color(0xFFBDB8B4),
                                fontSize: 10.5,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 7),
                      OutlinedButton(
                        onPressed: onTap,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(60, 38),
                          tapTargetSize: MaterialTapTargetSize.padded,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          backgroundColor: locked
                              ? MetaGymTheme.primary
                              : const Color(0xA13C2C24),
                          foregroundColor: locked
                              ? MetaGymTheme.onPrimary
                              : MetaGymTheme.textPrimary,
                          side: BorderSide(
                            color: locked
                                ? MetaGymTheme.primary
                                : const Color(0xC0C9895C),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        child: Text(actionLabel),
                      ),
                    ],
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

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(
    height: 168,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: MetaGymTheme.cardSurface,
      border: Border.all(color: MetaGymTheme.cardBorder),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          message,
          style: const TextStyle(color: MetaGymTheme.textSecondary),
        ),
        const Spacer(),
        TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Thử lại'),
        ),
      ],
    ),
  );
}
