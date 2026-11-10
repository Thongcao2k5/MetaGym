import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:meta_gym_app/app/app_router.dart';
import 'package:meta_gym_app/app/feature_navigation.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/features/auth/presentation/session_controller.dart';
import 'package:meta_gym_app/features/coaching/data/member_coaching_service.dart';
import 'package:meta_gym_app/features/coaching/domain/member_coaching_models.dart';
import 'package:meta_gym_app/features/member/presentation/member_explore_articles.dart';
import 'package:meta_gym_app/features/membership/data/membership_service.dart';
import 'package:meta_gym_app/features/membership/domain/membership_models.dart';
import 'package:meta_gym_app/features/sessions/data/member_sessions_service.dart';
import 'package:meta_gym_app/features/sessions/domain/training_session.dart';
import 'package:meta_gym_app/features/training/data/member_nutrition_service.dart';
import 'package:meta_gym_app/features/training/domain/nutrition_models.dart';
import 'package:meta_gym_app/features/workbench/flow_workbench_config.dart';
import 'package:provider/provider.dart';

/// Member Home dashboard implementing the "Futuristic Performance Glass"
/// Design System (`DESIGN.md`, `MASTER.md`, `pages/member-home.md`).
class MemberDashboardView extends StatefulWidget {
  const MemberDashboardView({
    required this.onNavigateTab,
    this.bottomPadding = 24.0,
    this.useSolidGlassFallback = false,
    super.key,
  });

  final ValueChanged<int> onNavigateTab;
  final double bottomPadding;
  final bool useSolidGlassFallback;

  @override
  State<MemberDashboardView> createState() => _MemberDashboardViewState();
}

class _MemberDashboardViewState extends State<MemberDashboardView> {
  static const AssetImage _gymBannerAsset = AssetImage(
    'assets/images/gym_banner.png',
  );

  bool _initialized = false;
  bool _isLoading = true;
  String? _loadError;
  List<Membership> _memberships = const [];
  List<MemberCoachRequest> _coachRequests = const [];
  MemberCoachRelationship? _activeRelationship;
  Map<String, String> _coachNames = const {};
  NutritionGuide? _activeNutrition;
  List<TrainingSession> _sessions = const [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!MetaGymTheme.isFlutterTestEnvironment) {
      precacheImage(_gymBannerAsset, context).catchError((_) {});
    }
    if (!_initialized) {
      _initialized = true;
      _loadFrame3Data();
    }
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF162232),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Đăng xuất',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Bạn có chắc chắn muốn đăng xuất khỏi tài khoản không?',
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

    if (confirmed == true && mounted) {
      await context.read<SessionController>().signOut();
    }
  }

  Future<void> _loadFrame3Data() async {
    MemberCoachingService? coachingService;
    MemberNutritionService? nutritionService;
    MemberSessionsService? sessionsService;
    MembershipService? membershipService;

    try {
      coachingService = context.read<MemberCoachingService>();
    } catch (_) {
      try {
        coachingService = MemberCoachingApi(context.read<ApiClient>());
      } catch (_) {}
    }
    try {
      nutritionService = context.read<MemberNutritionService>();
    } catch (_) {}
    try {
      sessionsService = context.read<MemberSessionsService>();
    } catch (_) {}
    try {
      membershipService = context.read<MembershipService>();
    } catch (_) {}

    MemberCoachRelationship? relationship;
    Map<String, String> coachNames = const {};
    NutritionGuide? activeNutrition;
    List<TrainingSession> sessions = const [];
    List<Membership> memberships = const [];
    List<MemberCoachRequest> coachRequests = const [];
    Object? firstError;

    if (coachingService != null) {
      try {
        final current = await coachingService.getCurrentRelationship();
        relationship = current;
      } catch (error) {
        firstError ??= error;
      }
      try {
        coachNames = await coachingService.getCoachNames();
      } catch (_) {}
      try {
        coachRequests = await coachingService.getRequests();
      } catch (_) {}
    }

    if (nutritionService != null) {
      try {
        final guide = await nutritionService.getActive();
        if (guide != null && guide.status == 'ACTIVE') {
          activeNutrition = guide;
        }
      } catch (error) {
        firstError ??= error;
      }
    }

    if (sessionsService != null) {
      try {
        sessions = await sessionsService.getMine();
      } catch (error) {
        firstError ??= error;
      }
    }

    if (membershipService != null) {
      try {
        memberships = await membershipService.getCurrentMemberships();
      } catch (error) {
        firstError ??= error;
      }
    }

    if (!mounted) return;
    setState(() {
      _activeRelationship = relationship;
      _coachNames = coachNames;
      _activeNutrition = activeNutrition;
      _sessions = sessions;
      _memberships = memberships;
      _coachRequests = coachRequests;
      _isLoading = false;
      _loadError = firstError == null
          ? null
          : 'Không thể cập nhật toàn bộ dữ liệu. Kéo xuống để thử lại.';
    });
  }

  bool get _hasCoach {
    return _activeRelationship?.status == 'ACTIVE';
  }

  String get _displayCoachName {
    final coachId = _activeRelationship?.coachId;
    if (coachId != null && _coachNames.containsKey(coachId)) {
      final mapped = _coachNames[coachId]!.trim();
      if (mapped.isNotEmpty) return mapped;
    }
    return 'Coach của bạn';
  }

  Membership? get _activeMembership => _memberships
      .cast<Membership?>()
      .firstWhere((item) => item?.status == 'ACTIVE', orElse: () => null);

  bool get _hasPendingCoachRequest =>
      _coachRequests.any((request) => request.status == 'PENDING');

  TrainingSession? get _todaySession {
    final now = DateTime.now();
    for (final session in _sessions) {
      final parsed = DateTime.tryParse(session.scheduledStartAt)?.toLocal();
      if (parsed != null &&
          parsed.year == now.year &&
          parsed.month == now.month &&
          parsed.day == now.day) {
        return session;
      }
    }
    return null;
  }

  Future<void> _pushAndReload(String route) async {
    await context.push(route);
    if (mounted) {
      await _loadFrame3Data();
    }
  }

  /// Bề mặt nội dung tối giúp chữ rõ trên ảnh nền phòng gym.
  Widget _buildLiquidGlassCard({
    required Widget child,
    BorderRadius? borderRadius,
    Clip clipBehavior = Clip.antiAlias,
  }) {
    final radius =
        borderRadius ?? BorderRadius.circular(MetaGymTheme.radiusCard);

    return Container(
      clipBehavior: clipBehavior,
      decoration: BoxDecoration(
        color: MetaGymTheme.darkSurface.withValues(alpha: 0.94),
        borderRadius: radius,
        border: Border.all(color: MetaGymTheme.cardBorder),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<SessionController>().user;
    final userName = user != null && user.fullName.trim().isNotEmpty
        ? user.fullName.trim()
        : 'Minh Quân';

    return Material(
      color: MetaGymTheme.darkCanvas,
      child: Stack(
        children: [
          // 1. Nền Canvas & Ảnh Gym (Background): Phủ toàn màn hình, scrim nhẹ nhàng và ambient glow để thấy rõ nền gym
          Positioned.fill(
            child: IgnorePointer(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image(
                    image: _gymBannerAsset,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        const ColoredBox(color: MetaGymTheme.darkCanvas),
                  ),
                  // Ambient depth lights: Cool blue top-right, warm orange bottom-left
                  Container(
                    decoration: const BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment(0.85, -0.75),
                        radius: 0.9,
                        colors: [Color(0x2E8EB9E5), Colors.transparent],
                      ),
                    ),
                  ),
                  Container(
                    decoration: const BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment(-0.85, 0.75),
                        radius: 0.8,
                        colors: [Color(0x24FF5A36), Colors.transparent],
                      ),
                    ),
                  ),
                  // Scrim nhẹ nhàng, trong suốt để nền hiển thị rõ rệt
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xB80F1115),
                          Color(0xA60F1115),
                          Color(0xC40F1115),
                        ],
                        stops: [0.0, 0.48, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Main scrollable viewport
          SafeArea(
            bottom: false,
            child: RefreshIndicator(
              color: MetaGymTheme.brandOrange,
              backgroundColor: MetaGymTheme.darkSurface,
              onRefresh: _loadFrame3Data,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  MetaGymTheme.pageGutter,
                  0,
                  MetaGymTheme.pageGutter,
                  widget.bottomPadding + 32,
                ),
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 6),
                      // 1. Header
                      _buildHeader(context, userName),
                      const SizedBox(height: 14),

                      // 2. Quick Action Dock (4 nút squircle đối xứng)
                      _buildQuickActionDock(context),
                      const SizedBox(height: 14),

                      if (_loadError != null) ...[
                        _buildLoadErrorBanner(),
                        const SizedBox(height: 12),
                      ],

                      // 3. Thẻ "Gói tập & Coach" (Bố cục 50/50 đối xứng)
                      _buildMembershipAndCoachCard(context),
                      const SizedBox(height: 14),

                      // 4. Thẻ "Hôm nay [Sắp diễn ra]"
                      _buildTodaySection(context),
                      const SizedBox(height: 14),

                      // 5. Cặp Bento 2 cột (Dinh dưỡng & Tiến độ tuần)
                      _buildBentoSection(context),
                      const SizedBox(height: 14),

                      // 6. Thẻ "Khám phá phòng gym & kiến thức"
                      _buildExploreSection(context),
                      const SizedBox(height: 14),

                      // Collapsible full feature workbench directory
                      _buildFullFeatureSection(context),
                      const SizedBox(height: 24),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 1. HEADER: Obsidian blend, "META GYM" in #A9C7E8, "Chào, <Tên>" in #F7F9FC w700,
  //    Circular glass Search & Avatar with cool reflective border, no orange ring.
  // ===========================================================================
  Widget _buildLoadErrorBanner() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
      decoration: BoxDecoration(
        color: MetaGymTheme.warningAmber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: MetaGymTheme.warningAmber.withValues(alpha: 0.30),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: MetaGymTheme.warningAmber,
            size: 19,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _loadError!,
              style: const TextStyle(
                color: MetaGymTheme.darkTextSecondary,
                fontSize: 11.5,
              ),
            ),
          ),
          IconButton(
            onPressed: _loadFrame3Data,
            tooltip: 'Thử lại',
            icon: const Icon(
              Icons.refresh_rounded,
              color: MetaGymTheme.warningAmber,
              size: 19,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String userName) {
    final cleanName = userName.trim();
    final parts = cleanName
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();
    final initials = parts.length >= 2
        ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
        : (cleanName.isNotEmpty
              ? cleanName
                    .substring(0, cleanName.length >= 2 ? 2 : 1)
                    .toUpperCase()
              : 'MQ');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Squircle "MG" badge
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFF6A42), Color(0xFFFF4520)],
              ),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: const Color(0x40FFFFFF), width: 1.2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x4DFF5A36),
                  blurRadius: 10,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: const Text(
              'MG',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'META GYM',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: MetaGymTheme.brandOrange,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Chào, $userName',
                  style: const TextStyle(
                    color: Color(0xFFF7F9FC),
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    height: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                const Text(
                  'Sẵn sàng bứt phá hôm nay?',
                  style: TextStyle(
                    color: Color(0xFF8E9AA8),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w400,
                    height: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _CircleHeaderGlassButton(
            icon: Icons.search_rounded,
            semanticLabel: 'Tìm kiếm phòng gym và thiết bị',
            onTap: () => context.push('/member/features/gym'),
          ),
          const SizedBox(width: 8),
          Semantics(
            button: true,
            label: 'Mở hồ sơ hội viên $userName',
            child: Tooltip(
              message: 'Hồ sơ',
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => widget.onNavigateTab(4),
                  customBorder: const CircleBorder(),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                    child: Center(
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFFFF7E58), Color(0xFFFF4820)],
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0x40FFFFFF),
                            width: 1.2,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x38FF5A36),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          initials,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
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

  // ===========================================================================
  // 2. QUICK ACTION DOCK (4 SQUIRCLE BUTTONS)
  // ===========================================================================
  Widget _buildQuickActionDock(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildQuickActionButton(
            label: 'Lịch tập',
            icon: Icons.calendar_today_rounded,
            iconColor: MetaGymTheme.brandOrange,
            isActive: true,
            onTap: () => _pushAndReload('/member/features/sessions'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildQuickActionButton(
            label: 'Giáo trình',
            icon: Icons.description_outlined,
            iconColor: MetaGymTheme.infoSteelBlue,
            isActive: false,
            onTap: () => _pushAndReload('/member/features/training'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildQuickActionButton(
            label: 'Dinh dưỡng',
            icon: Icons.spa_outlined,
            iconColor: MetaGymTheme.progressGreen,
            isActive: false,
            onTap: () => _pushAndReload('/member/features/nutrition'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildQuickActionButton(
            label: 'Coach',
            icon: Icons.groups_outlined,
            iconColor: MetaGymTheme.warningAmber,
            isActive: false,
            onTap: () => _pushAndReload(
              _hasCoach || _hasPendingCoachRequest
                  ? '/member/features/my-coach'
                  : '/member/features/coaching',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionButton({
    required String label,
    required IconData icon,
    required Color iconColor,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final buttonBody = Container(
      height: 62,
      decoration: BoxDecoration(
        color: isActive
            ? MetaGymTheme.brandOrange.withValues(alpha: 0.16)
            : MetaGymTheme.darkSurface.withValues(alpha: 0.70),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: isActive ? MetaGymTheme.brandOrange : MetaGymTheme.cardBorder,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 21, color: iconColor),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isActive
                    ? const Color(0xFFF7F9FC)
                    : const Color(0xFFD6E0EC),
                fontSize: 10.5,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );

    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: buttonBody,
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // 4. THẺ "HÔM NAY [SẮP DIỄN RA]" (LIQUID GLASS TRONG SUỐT)
  // ===========================================================================
  Widget _buildTodaySection(BuildContext context) {
    if (_isLoading) {
      return _buildLiquidGlassCard(
        child: Container(
          height: 110,
          alignment: Alignment.center,
          child: const CircularProgressIndicator(
            color: MetaGymTheme.brandOrange,
            strokeWidth: 2.4,
          ),
        ),
      );
    }

    final todaySession = _todaySession;
    final timeText = todaySession != null
        ? _extractTimeHHmm(todaySession.scheduledStartAt)
        : '17:30';
    final titleText = todaySession != null && todaySession.title.isNotEmpty
        ? todaySession.title
        : 'Upper Body & Core';
    final coachName = _hasCoach ? _displayCoachName : 'Lê Hoàng Nam';
    final coachParts = coachName
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();
    final coachInitialStr = coachParts.length >= 2
        ? '${coachParts.first[0]}${coachParts.last[0]}'.toUpperCase()
        : (coachName.isNotEmpty
              ? coachName
                    .substring(0, coachName.length >= 2 ? 2 : 1)
                    .toUpperCase()
              : 'LN');

    return _buildLiquidGlassCard(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => _pushAndReload('/member/features/sessions'),
              borderRadius: BorderRadius.circular(8),
              child: Row(
                children: [
                  const Icon(
                    Icons.access_time_rounded,
                    color: MetaGymTheme.brandOrange,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Hôm nay',
                    style: TextStyle(
                      color: Color(0xFFF7F9FC),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(
                        0x262ECC71,
                      ), // rgba(35, 201, 151, 0.15)
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(
                          0x4D2ECC71,
                        ), // rgba(35, 201, 151, 0.30)
                        width: 0.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: const BoxDecoration(
                            color: MetaGymTheme.progressGreen,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        const Text(
                          'Sắp diễn ra',
                          style: TextStyle(
                            color: MetaGymTheme.progressGreen,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF8E9AA8),
                    size: 20,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Cột trái: Giờ
                Container(
                  width: 56,
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0x2E162232),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0x59DCEBFF),
                      width: 1.0,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        timeText,
                        style: const TextStyle(
                          color: Color(0xFFF7F9FC),
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          height: 1.1,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        "60'",
                        style: TextStyle(
                          color: Color(0xFF9EAAB8),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 9),
                // Giữa: Tiêu đề + HLV
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        titleText,
                        style: const TextStyle(
                          color: Color(0xFFF7F9FC),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 5),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: MetaGymTheme.coachAvatarBackground,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              coachInitialStr,
                              style: const TextStyle(
                                color: MetaGymTheme.coachAvatarForeground,
                                fontSize: 8,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              'HLV $coachName',
                              style: const TextStyle(
                                color: Color(0xFFC8D2DF),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                // Phải: Nút CTA cam
                Semantics(
                  button: true,
                  label: 'Bắt đầu buổi tập',
                  child: Material(
                    color: MetaGymTheme.brandOrange,
                    borderRadius: BorderRadius.circular(24),
                    child: InkWell(
                      onTap: () => _pushAndReload('/member/features/sessions'),
                      borderRadius: BorderRadius.circular(24),
                      child: const SizedBox(
                        height: 48,
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Bắt đầu',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 17,
                              ),
                            ],
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
      ),
    );
  }

  String _extractTimeHHmm(String rawIso) {
    final parsed = DateTime.tryParse(rawIso)?.toLocal();
    if (parsed == null) return '--:--';
    final hh = parsed.hour.toString().padLeft(2, '0');
    final mm = parsed.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  // ===========================================================================
  // 3. THẺ "GÓI TẬP & COACH" (BỐ CỤC 50/50 ĐỐI XỨNG - LIQUID GLASS)
  // ===========================================================================
  Widget _buildMembershipAndCoachCard(BuildContext context) {
    if (_isLoading) {
      return _buildLiquidGlassCard(
        child: Container(
          height: 90,
          alignment: Alignment.center,
          child: const CircularProgressIndicator(
            color: MetaGymTheme.brandOrange,
            strokeWidth: 2.0,
          ),
        ),
      );
    }

    final membership = _activeMembership;
    final endDate = membership == null
        ? null
        : DateTime.tryParse(membership.endDate)?.toLocal();
    final now = DateTime.now();
    final daysRemaining = endDate == null
        ? 112
        : DateTime(endDate.year, endDate.month, endDate.day)
              .difference(DateTime(now.year, now.month, now.day))
              .inDays
              .clamp(0, 99999);
    final displayDays = daysRemaining == 0 ? 112 : daysRemaining;
    final displayCoachName = _hasCoach ? _displayCoachName : 'Lê Hoàng Nam';
    final coachParts = displayCoachName
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();
    final coachInitialStr = coachParts.length >= 2
        ? '${coachParts.first[0]}${coachParts.last[0]}'.toUpperCase()
        : (displayCoachName.isNotEmpty
              ? displayCoachName
                    .substring(0, displayCoachName.length >= 2 ? 2 : 1)
                    .toUpperCase()
              : 'LN');

    return _buildLiquidGlassCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: () => _pushAndReload('/member/features/membership'),
              borderRadius: BorderRadius.circular(6),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.fitness_center_rounded,
                        color: MetaGymTheme.brandOrange,
                        size: 13,
                      ),
                      SizedBox(width: 5),
                      Text(
                        'Gói tập & Coach',
                        style: TextStyle(
                          color: Color(0xFFF7F9FC),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF8E9AA8),
                    size: 16,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Chỉ số ngắn chiếm ít chỗ hơn tên Coach.
                  Expanded(
                    flex: 4,
                    child: InkWell(
                      onTap: () =>
                          _pushAndReload('/member/features/membership'),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '$displayDays',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFFF7F9FC),
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                height: 1.1,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'ngày còn lại',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFF9EAAB8),
                                fontSize: 9.5,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Tên Coach cần đủ khoảng trống để đọc trọn vẹn.
                  Expanded(
                    flex: 6,
                    child: InkWell(
                      onTap: () => _pushAndReload(
                        _hasCoach || _hasPendingCoachRequest
                            ? '/member/features/my-coach'
                            : '/member/features/coaching',
                      ),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: MetaGymTheme.coachAvatarBackground,
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    coachInitialStr,
                                    style: const TextStyle(
                                      color: MetaGymTheme.coachAvatarForeground,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        displayCoachName,
                                        style: const TextStyle(
                                          color: Color(0xFFF7F9FC),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          height: 1.15,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 1),
                                      const Text(
                                        'Coach cá nhân',
                                        style: TextStyle(
                                          color: Color(0xFF9EAAB8),
                                          fontSize: 9,
                                          fontWeight: FontWeight.w400,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // 5. CẶP BENTO 2 CỘT (DINH DƯỠNG & TIẾN ĐỘ TẬP LUYỆN - LIQUID GLASS)
  // ===========================================================================
  Widget _buildBentoSection(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Bento Trái: Dinh dưỡng
          Expanded(
            child: _buildLiquidGlassCard(
              child: InkWell(
                onTap: () => _pushAndReload('/member/features/nutrition'),
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.restaurant_rounded,
                            color: MetaGymTheme.brandOrange,
                            size: 13,
                          ),
                          const SizedBox(width: 4),
                          const Expanded(
                            child: Text(
                              'Dinh dưỡng',
                              style: TextStyle(
                                color: Color(0xFFF7F9FC),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _activeNutrition?.title ?? 'Thực đơn tăng cơ',
                        style: const TextStyle(
                          color: Color(0xFFF7F9FC),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        '1.8–2.0g đạm / kg',
                        style: TextStyle(
                          color: Color(0xFF9EAAB8),
                          fontSize: 10.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Đạm: 140 / 160g',
                              style: TextStyle(
                                color: Color(0xFFF7F9FC),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0x242ECC71),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: const Text(
                              '85%',
                              style: TextStyle(
                                color: MetaGymTheme.progressGreen,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: const LinearProgressIndicator(
                          value: 0.85,
                          minHeight: 3,
                          backgroundColor: Color(0x26FFFFFF),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            MetaGymTheme.progressGreen,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Bento Phải: Tiến độ tuần
          Expanded(
            child: _buildLiquidGlassCard(
              child: InkWell(
                onTap: () => _pushAndReload('/member/features/progress'),
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.show_chart_rounded,
                            color: MetaGymTheme.brandOrange,
                            size: 13,
                          ),
                          const SizedBox(width: 4),
                          const Expanded(
                            child: Text(
                              'Tiến độ',
                              style: TextStyle(
                                color: Color(0xFFF7F9FC),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0x262ECC71),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0x4D2ECC71),
                                width: 0.6,
                              ),
                            ),
                            child: const Text(
                              '3/7 buổi',
                              style: TextStyle(
                                color: MetaGymTheme.progressGreen,
                                fontSize: 8.5,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildDayBubble('T2', isCompleted: true),
                          _buildDayBubble('T3', isCompleted: true),
                          _buildDayBubble(
                            'T4',
                            isCompleted: true,
                            isActive: true,
                          ),
                          _buildDayBubble('T5', isCompleted: false),
                          _buildDayBubble('T6', isCompleted: false),
                          _buildDayBubble('T7', isCompleted: false),
                          _buildDayBubble('CN', isCompleted: false),
                        ],
                      ),
                      const Spacer(),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Chuỗi: 5 ngày 🔥',
                              style: TextStyle(
                                color: Color(0xFFF7F9FC),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0x242ECC71),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: const Text(
                              'Tốt',
                              style: TextStyle(
                                color: MetaGymTheme.progressGreen,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: const LinearProgressIndicator(
                          value: 3 / 7,
                          minHeight: 3,
                          backgroundColor: Color(0x26FFFFFF),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            MetaGymTheme.progressGreen,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayBubble(
    String label, {
    required bool isCompleted,
    bool isActive = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 17,
          height: 17,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCompleted
                ? MetaGymTheme.brandOrange
                : const Color(0x1AFFFFFF),
            border: Border.all(
              color: isActive
                  ? Colors.white
                  : (isCompleted
                        ? MetaGymTheme.brandOrange
                        : const Color(0x33FFFFFF)),
              width: isActive ? 1.4 : 0.8,
            ),
            boxShadow: isActive
                ? const [
                    BoxShadow(
                      color: Color(0x66FF5A36),
                      blurRadius: 5,
                      spreadRadius: 0.5,
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: isCompleted
              ? const Icon(Icons.check_rounded, size: 11, color: Colors.white)
              : null,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: isActive
                ? MetaGymTheme.brandOrange
                : const Color(0xFF9EAAB8),
            fontSize: 9.5,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // 6. THẺ "KHÁM PHÁ META GYM"
  // ===========================================================================
  Widget _buildExploreSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.explore_outlined,
              color: MetaGymTheme.reflectionBlue,
              size: 16,
            ),
            const SizedBox(width: 6),
            const Expanded(
              child: Text(
                'Khám phá Meta Gym',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Color(0xFFF7F9FC),
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            InkWell(
              key: const Key('frame3-explore-see-more'),
              onTap: () {
                Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => const MemberExploreListPage(),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(8),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Xem tất cả >',
                      style: TextStyle(
                        color: MetaGymTheme.brandOrange,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _buildLiquidGlassCard(
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: () {
              Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => const MemberExploreListPage(),
                ),
              );
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image(
                      image: _gymBannerAsset,
                      width: 82,
                      height: 58,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        width: 82,
                        height: 58,
                        color: const Color(0xFF1E2633),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.fitness_center_rounded,
                          color: MetaGymTheme.reflectionBlue,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Khu máy Hack Squat & Hip Thrust',
                          style: TextStyle(
                            color: Color(0xFFF7F9FC),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Chuẩn form tránh chấn thương, tối ưu kích hoạt cơ mông đùi.',
                          style: TextStyle(
                            color: Color(0xFF9EAAB8),
                            fontSize: 11,
                            height: 1.25,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
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
    );
  }

  Widget _buildFullFeatureSection(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          tilePadding: EdgeInsets.zero,
          title: const Text(
            'Không gian dành cho hội viên',
            style: TextStyle(
              color: MetaGymTheme.darkTextPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: const Text(
            'Tất cả danh mục tính năng & kiểm thử',
            style: TextStyle(
              color: MetaGymTheme.darkTextTertiary,
              fontSize: 12,
            ),
          ),
          iconColor: MetaGymTheme.reflectionBlue,
          collapsedIconColor: MetaGymTheme.darkTextTertiary,
          children: [
            _buildLiquidGlassCard(
              borderRadius: BorderRadius.circular(16),
              child: Material(
                color: Colors.transparent,
                child: Column(
                  children: [
                    for (final destination in memberDestinations)
                      ListTile(
                        title: Text(
                          destination.title,
                          style: const TextStyle(
                            color: MetaGymTheme.darkTextPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          '${destination.section} · ${destination.task}',
                          style: const TextStyle(
                            color: MetaGymTheme.darkTextSecondary,
                            fontSize: 11,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.chevron_right_rounded,
                          color: MetaGymTheme.darkTextTertiary,
                          size: 20,
                        ),
                        onTap: () => context.push(destination.path),
                      ),
                    if (FlowWorkbenchConfig.enabled)
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () =>
                                context.push(AppRoutes.memberWorkbench),
                            child: const Text('Kiểm thử các luồng hội viên'),
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFFF6961),
                            side: const BorderSide(color: Color(0x4DFF453A)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _confirmSignOut,
                          icon: const Icon(Icons.logout_rounded, size: 18),
                          label: const Text(
                            'Đăng xuất',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
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
}

class _CircleHeaderGlassButton extends StatelessWidget {
  const _CircleHeaderGlassButton({
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
  });

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
                    color: MetaGymTheme.headerCircleGlass,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: MetaGymTheme.headerCircleBorder,
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    icon,
                    color: MetaGymTheme.darkTextPrimary,
                    size: 20,
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
