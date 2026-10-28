import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:meta_gym_app/app/app_router.dart';
import 'package:meta_gym_app/app/feature_navigation.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/features/auth/presentation/session_controller.dart';
import 'package:meta_gym_app/features/coaching/data/member_coaching_service.dart';
import 'package:meta_gym_app/features/coaching/domain/member_coaching_models.dart';
import 'package:meta_gym_app/features/member/presentation/member_explore_articles.dart';
import 'package:meta_gym_app/features/progress/data/member_meal_service.dart';
import 'package:meta_gym_app/features/progress/data/member_workout_service.dart';
import 'package:meta_gym_app/features/progress/domain/meal_log.dart';
import 'package:meta_gym_app/features/progress/domain/progress_time.dart';
import 'package:meta_gym_app/features/progress/domain/workout_log.dart';
import 'package:meta_gym_app/features/sessions/data/member_sessions_service.dart';
import 'package:meta_gym_app/features/sessions/domain/training_session.dart';
import 'package:meta_gym_app/features/training/data/member_nutrition_service.dart';
import 'package:meta_gym_app/features/training/data/member_training_service.dart';
import 'package:meta_gym_app/features/training/domain/nutrition_models.dart';
import 'package:meta_gym_app/features/training/domain/training_models.dart';
import 'package:meta_gym_app/features/workbench/flow_workbench_config.dart';
import 'package:provider/provider.dart';

/// Member dashboard implementing:
/// - Khung 1: Header Bar, Hero Banner Carousel, Quick Access PageView
/// - Khung 2: Compact Membership Card, Weekly Progress Card
/// - Khung 3: "Hôm nay của bạn" (Coach Training Plan & Coach Nutrition Guide when
///   Member has Coach & published content, "Nhật ký của bạn" 2-row section for
///   Workout Log & Meal Log, and "Khám phá" compact 2-item editorial list).
class MemberDashboardView extends StatefulWidget {
  const MemberDashboardView({
    required this.onNavigateTab,
    this.bottomPadding = 24.0,
    super.key,
  });

  final ValueChanged<int> onNavigateTab;
  final double bottomPadding;

  @override
  State<MemberDashboardView> createState() => _MemberDashboardViewState();
}

class _MemberDashboardViewState extends State<MemberDashboardView> {
  // Design System Tokens — Titanium Slate Palette (Dark Graphite & Sunset Coral)
  static const Color _bgDark = Color(0xFF11151C);
  static const Color _cardTop = Color(0xFF222B38);
  static const Color _cardBottom = Color(0xFF1B232E);
  static const Color _cardBorder = Color(0x1FFFFFFF);
  static const Color _cardTitle = Color(0xFFF3F6FA);
  static const Color _cardSub = Color(0xFF94A3B8);
  static const Color _cardDivider = Color(0x1AFFFFFF);
  static const Color _subBoxBg = Color(0xFF293444);
  static const Color _coralPrimary = Color(0xFFFF5E3A);
  static const Color _coralLight = Color(0xFFFF7E58);

  // Interactive State — Hero Banner (Khung 1)
  int _bannerIndex = 0;
  static const List<_BannerSlideData> _bannerSlides = [
    _BannerSlideData(
      tag: 'CƠ SỞ VẬT CHẤT 5 SAO',
      hours: '05:30 - 22:00',
      title: 'Không gian tập luyện chuẩn Quốc tế',
      subtitle: 'Hơn 60+ thiết bị Technogym & Free Weights',
    ),
    _BannerSlideData(
      tag: 'HUẤN LUYỆN VIÊN CÁ NHÂN',
      hours: '1 KÈM 1',
      title: 'Đồng hành cùng Coach chuyên nghiệp',
      subtitle: 'Giáo trình cá nhân hóa & theo dõi sát sao',
    ),
    _BannerSlideData(
      tag: 'TRỢ LÝ AI META GYM',
      hours: '24/7 ONLINE',
      title: 'Tối ưu dinh dưỡng & kỹ thuật tập',
      subtitle: 'Phân tích calo bữa ăn và giải đáp tức thì',
    ),
  ];

  // Interactive State — Weekly Progress Days (Khung 2)
  final List<_MockDayProgress> _weekDays = [
    _MockDayProgress(day: 'T2', isCompleted: true),
    _MockDayProgress(day: 'T3', isCompleted: true),
    _MockDayProgress(day: 'T4', isCompleted: true),
    _MockDayProgress(day: 'T5', isCompleted: false, isToday: true),
    _MockDayProgress(day: 'T6', isCompleted: false),
  ];

  // Khung 3 Data State
  bool _initialized = false;
  MemberCoachRelationship? _activeRelationship;
  TrainingPlan? _activePlan;
  NutritionGuide? _activeNutrition;
  List<TrainingSession> _sessions = const [];
  WorkoutLog? _latestWorkout;
  MealLog? _latestMeal;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _loadFrame3Data();
    }
  }

  Future<void> _loadFrame3Data() async {
    MemberCoachingService? coachingService;
    MemberTrainingService? trainingService;
    MemberNutritionService? nutritionService;
    MemberSessionsService? sessionsService;
    MemberWorkoutService? workoutService;
    MemberMealService? mealService;

    try {
      coachingService = context.read<MemberCoachingService>();
    } catch (_) {
      try {
        coachingService = MemberCoachingApi(context.read<ApiClient>());
      } catch (_) {}
    }
    try {
      trainingService = context.read<MemberTrainingService>();
    } catch (_) {}
    try {
      nutritionService = context.read<MemberNutritionService>();
    } catch (_) {}
    try {
      sessionsService = context.read<MemberSessionsService>();
    } catch (_) {}
    try {
      workoutService = context.read<MemberWorkoutService>();
    } catch (_) {}
    try {
      mealService = context.read<MemberMealService>();
    } catch (_) {}

    MemberCoachRelationship? relationship;
    TrainingPlan? activePlan;
    NutritionGuide? activeNutrition;
    List<TrainingSession> sessions = const [];
    WorkoutLog? latestWorkout;
    MealLog? latestMeal;

    if (coachingService != null) {
      try {
        final current = await coachingService.getCurrentRelationship();
        if (current != null && current.status == 'ACTIVE') {
          relationship = current;
        }
      } catch (_) {}
    }

    if (trainingService != null) {
      try {
        final plan = await trainingService.getActive();
        if (plan != null && plan.status == 'ACTIVE') {
          activePlan = plan;
        }
      } catch (_) {}
    }

    if (nutritionService != null) {
      try {
        final guide = await nutritionService.getActive();
        if (guide != null && guide.status == 'ACTIVE') {
          activeNutrition = guide;
        }
      } catch (_) {}
    }

    if (sessionsService != null) {
      try {
        sessions = await sessionsService.getMine();
      } catch (_) {}
    }

    if (workoutService != null) {
      try {
        final page = await workoutService.getPage(1);
        if (page.isNotEmpty) {
          latestWorkout = page.first;
        }
      } catch (_) {}
    }

    if (mealService != null) {
      try {
        final page = await mealService.getPage(1);
        if (page.isNotEmpty) {
          latestMeal = page.first;
        }
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      _activeRelationship = relationship;
      _activePlan = activePlan;
      _activeNutrition = activeNutrition;
      _sessions = sessions;
      _latestWorkout = latestWorkout;
      _latestMeal = latestMeal;
    });
  }

  /// Member được xác nhận có Coach khi có quan hệ ACTIVE, hoặc khi hệ thống trả về
  /// giáo trình/hướng dẫn dinh dưỡng ACTIVE do Coach đã công bố cho Member.
  bool get _hasCoach {
    if (_activeRelationship != null) {
      return _activeRelationship!.status == 'ACTIVE';
    }
    return _activePlan != null || _activeNutrition != null;
  }

  /// Chỉ gọi nội dung là "hôm nay" khi có buổi tập `TrainingSession` gắn với
  /// ngày hiện tại một cách đáng tin cậy. Tuyệt đối không coi `dayNumber` là thứ trong tuần.
  TrainingSession? get _todayScheduledSession {
    final now = DateTime.now();
    for (final session in _sessions) {
      if (session.status != 'SCHEDULED' && session.status != 'COMPLETED') {
        continue;
      }
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

  int get _completedDaysCount =>
      _weekDays.where((d) => d.isCompleted).length;

  void _cycleBanner() {
    setState(() {
      _bannerIndex = (_bannerIndex + 1) % _bannerSlides.length;
    });
  }

  void _toggleDay(int index) {
    setState(() {
      _weekDays[index].isCompleted = !_weekDays[index].isCompleted;
    });
  }

  Future<void> _pushAndReload(String route) async {
    await context.push(route);
    if (mounted) {
      await _loadFrame3Data();
    }
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [_cardTop, _cardBottom],
      ),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _cardBorder, width: 1),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.42),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  Widget _buildIconBadge(
    IconData icon, {
    double size = 40,
    double iconSize = 20,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _coralPrimary.withValues(alpha: 0.24),
            _coralLight.withValues(alpha: 0.10),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _coralLight.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Icon(
        icon,
        color: const Color(0xFFFF6B4A),
        size: iconSize,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<SessionController>().user;
    final userName = user != null && user.fullName.isNotEmpty
        ? user.fullName
        : 'Minh';

    return Container(
      color: _bgDark,
      child: RefreshIndicator(
        onRefresh: _loadFrame3Data,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(16, 0, 16, widget.bottomPadding),
          children: [
            const SizedBox(height: 10),
            // =================================================================
            // KHUNG 1: Header Bar + Hero Banner + Truy cập nhanh
            // =================================================================
            _buildHeader(context, userName),
            const SizedBox(height: 16),
            _buildHeroBanner(context),
            const SizedBox(height: 18),
            _QuickAccessSection(onNavigateTab: widget.onNavigateTab),
            const SizedBox(height: 18),

            // =================================================================
            // KHUNG 2: Gói tập của bạn + Tiến độ tuần
            // =================================================================
            _buildMembershipCard(context),
            const SizedBox(height: 18),
            _buildWeeklyProgressCard(context),
            const SizedBox(height: 22),

            // =================================================================
            // KHUNG 3: Hôm nay của bạn (Giáo trình/Dinh dưỡng Coach gửi,
            //          Nhật ký của bạn, Khám phá)
            // =================================================================
            _buildFrame3Section(context),
            const SizedBox(height: 20),

            // Danh mục tính năng đầy đủ & kiểm thử (thu gọn mặc định)
            _buildFullFeatureSection(context),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // KHUNG 1.1: HEADER BAR
  // ===========================================================================
  Widget _buildHeader(BuildContext context, String userName) {
    final initial = userName.trim().isNotEmpty
        ? userName.trim()[0].toUpperCase()
        : 'M';

    return SafeArea(
      bottom: false,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'META GYM',
                      style: TextStyle(
                        color: Color(0xFFFF6B4A),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _coralPrimary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _coralPrimary.withValues(alpha: 0.32),
                        ),
                      ),
                      child: const Text(
                        '🔥 5 ngày',
                        style: TextStyle(
                          color: Color(0xFFFF8A6B),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'Chào $userName',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          _CircleHeaderButton(
            icon: Icons.search_rounded,
            tooltip: 'Tìm kiếm phòng gym & thiết bị',
            onTap: () => context.push('/member/features/gym'),
          ),
          const SizedBox(width: 10),
          Tooltip(
            message: 'Hồ sơ',
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => widget.onNavigateTab(4),
                borderRadius: BorderRadius.circular(22),
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Stack(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [_coralLight, _coralPrimary],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Color(0xFF1B222D),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            initial,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: const Color(0xFF34D399),
                            shape: BoxShape.circle,
                            border: Border.all(color: _bgDark, width: 2),
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

  // ===========================================================================
  // KHUNG 1.2: HERO BANNER CAROUSEL
  // ===========================================================================
  Widget _buildHeroBanner(BuildContext context) {
    final slide = _bannerSlides[_bannerIndex];

    return GestureDetector(
      onTap: _cycleBanner,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: 168,
          decoration: BoxDecoration(
            color: const Color(0xFF1E2633),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0x26FFFFFF)),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                'assets/images/gym_banner.png',
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFF2B3748),
                        Color(0xFF1E2633),
                        Color(0xFF141A24),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: -30,
                right: 16,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _coralPrimary.withValues(alpha: 0.22),
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha: 0.45),
                      Colors.transparent,
                      const Color(0xFF0D1117).withValues(alpha: 0.88),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
              Positioned(
                top: 12,
                left: 14,
                right: 14,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: _coralPrimary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            slide.tag,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        slide.hours,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                bottom: 12,
                left: 14,
                right: 14,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            slide.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              height: 1.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            slide.subtitle,
                            style: const TextStyle(
                              color: Color(0xFFCBD5E1),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(_bannerSlides.length, (idx) {
                        final isActive = idx == _bannerIndex;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          margin: const EdgeInsets.only(left: 5),
                          width: isActive ? 16 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: isActive
                                ? _coralPrimary
                                : Colors.white.withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // KHUNG 2.1: GÓI TẬP CỦA BẠN (COMPACT, SINGLE-LINE, ZERO-WRAP)
  // ===========================================================================
  Widget _buildMembershipCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Gói tập của bạn',
                style: TextStyle(
                  color: _cardTitle,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0x2610B981),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0x4D10B981)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF34D399),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Hiệu lực',
                      style: TextStyle(
                        color: Color(0xFF34D399),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: () => context.push('/member/features/payments'),
                borderRadius: BorderRadius.circular(8),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text(
                          'Xem gói tập',
                          style: TextStyle(
                            color: _coralLight,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(width: 2),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 16,
                          color: _coralLight,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    _buildIconBadge(Icons.access_time_rounded),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: const [
                              Text(
                                '18',
                                style: TextStyle(
                                  color: _cardTitle,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  height: 1.0,
                                ),
                              ),
                              SizedBox(width: 3),
                              Text(
                                '/30',
                                style: TextStyle(
                                  color: _coralLight,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          const Text(
                            'ngày còn lại',
                            style: TextStyle(
                              color: _cardSub,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 36,
                color: _cardDivider,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  children: [
                    _buildIconBadge(Icons.fitness_center_rounded),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: const [
                              Text(
                                '8',
                                style: TextStyle(
                                  color: _cardTitle,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  height: 1.0,
                                ),
                              ),
                              SizedBox(width: 3),
                              Text(
                                '/12',
                                style: TextStyle(
                                  color: _coralLight,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          const Text(
                            'buổi còn lại',
                            style: TextStyle(
                              color: _cardSub,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // KHUNG 2.2: TIẾN ĐỘ TUẦN (WEEKLY PROGRESS CARD)
  // ===========================================================================
  Widget _buildWeeklyProgressCard(BuildContext context) {
    final completed = _completedDaysCount;
    final total = _weekDays.length;
    final ratio = total > 0 ? completed / total : 0.0;
    final percentText = '${(ratio * 100).round()}%';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Tiến độ tuần',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            InkWell(
              onTap: () => context.push('/member/features/progress'),
              borderRadius: BorderRadius.circular(8),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text(
                        'Xem chi tiết',
                        style: TextStyle(
                          color: _cardSub,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(width: 2),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: _cardSub,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: _cardDecoration(),
          child: Column(
            children: [
              Row(
                children: [
                  _buildIconBadge(Icons.bar_chart_rounded),
                  const SizedBox(width: 12),
                  Text(
                    '$completed/$total',
                    style: const TextStyle(
                      color: _cardTitle,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'buổi',
                    style: TextStyle(
                      color: _cardSub,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        height: 8,
                        color: const Color(0xFF141A23),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: ratio.clamp(0.0, 1.0),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [_coralLight, _coralPrimary],
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    percentText,
                    style: const TextStyle(
                      color: _coralLight,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(_weekDays.length, (idx) {
                  final item = _weekDays[idx];
                  return _DayProgressItem(
                    day: item.day,
                    isCompleted: item.isCompleted,
                    isToday: item.isToday,
                    onTap: () => _toggleDay(idx),
                  );
                }),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // KHUNG 3: HÔM NAY CỦA BẠN
  // 1. Tiêu đề "Hôm nay của bạn"
  // 2. Nếu có Coach và đã nhận nội dung được công bố:
  //    - Thẻ giáo trình (tên buổi/nhóm cơ, số bài, thông tin ngắn; chạm mở giáo trình)
  //    - Thẻ dinh dưỡng Coach gửi (tên, đoạn xem trước; chạm mở hướng dẫn đầy đủ)
  //    - Chỉ gọi là "hôm nay" khi có lịch gắn với ngày hiện tại đáng tin cậy.
  //      Nếu chưa xác định được ngày -> dùng nhãn "Giáo trình hiện hành" / "Dinh dưỡng Coach gửi".
  //    - Ẩn hoàn toàn nếu không có Coach hoặc chưa có nội dung công bố.
  // 3. Mục "Nhật ký của bạn" LUÔN hiển thị 2 hàng:
  //    - "Nhật ký tập luyện"
  //    - "Nhật ký ăn uống"
  // 4. Cuối khung: mục "Khám phá" dạng danh sách gọn 2 bài + "Xem thêm".
  // ===========================================================================
  Widget _buildFrame3Section(BuildContext context) {
    final showTrainingCard = _hasCoach && _activePlan != null;
    final showNutritionCard = _hasCoach && _activeNutrition != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Tiêu đề Khung 3: "Hôm nay của bạn"
        const Text(
          'Hôm nay của bạn',
          style: TextStyle(
            color: Colors.white,
            fontSize: 19,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 12),

        // 2. Thẻ Giáo trình & Thẻ Dinh dưỡng Coach gửi (chỉ hiển thị khi có Coach & nội dung ACTIVE)
        if (showTrainingCard) ...[
          _buildCoachTrainingCard(context, _activePlan!),
          const SizedBox(height: 12),
        ],
        if (showNutritionCard) ...[
          _buildCoachNutritionCard(context, _activeNutrition!),
          const SizedBox(height: 16),
        ],

        // 3. Mục "Nhật ký của bạn" (LUÔN hiển thị 2 hàng dễ quét)
        _buildMemberLogsSection(context),
        const SizedBox(height: 20),

        // 4. Mục "Khám phá" (Danh sách gọn 2 bài, không cuộn lồng)
        _buildExploreSection(context),
      ],
    );
  }

  Widget _buildCoachTrainingCard(BuildContext context, TrainingPlan plan) {
    final todaySession = _todayScheduledSession;
    final hasReliableTodaySchedule = todaySession != null;

    // Không tự coi dayNumber là ngày trong tuần.
    final badgeLabel = hasReliableTodaySchedule
        ? 'Lịch tập hôm nay'
        : 'Giáo trình hiện hành';

    final firstDay = plan.days.isNotEmpty ? plan.days.first : null;
    final totalExercises = plan.days.fold<int>(
      0,
      (sum, d) => sum + d.exercises.length,
    );

    final primaryTitle = hasReliableTodaySchedule
        ? todaySession.title
        : (firstDay != null && firstDay.title.trim().isNotEmpty
              ? '${plan.title} · ${firstDay.title}'
              : plan.title);

    final exerciseCountLabel = firstDay != null && plan.days.length == 1
        ? '${firstDay.exercises.length} bài tập'
        : '$totalExercises bài tập · ${plan.days.length} buổi';

    final shortInfoParts = <String>[
      exerciseCountLabel,
      if (plan.goal != null && plan.goal!.trim().isNotEmpty)
        plan.goal!.trim()
      else if (firstDay?.notes != null && firstDay!.notes!.trim().isNotEmpty)
        firstDay.notes!.trim()
      else
        'Phiên bản ${plan.version}',
    ];

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const Key('frame3-coach-training-card'),
        onTap: () => _pushAndReload('/member/features/training'),
        borderRadius: BorderRadius.circular(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: _cardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _coralPrimary.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _coralPrimary.withValues(alpha: 0.38),
                        ),
                      ),
                      child: Text(
                        badgeLabel,
                        style: const TextStyle(
                          color: _coralLight,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const Spacer(),
                    const Text(
                      'Mở giáo trình',
                      style: TextStyle(
                        color: _coralLight,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: _coralLight,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildIconBadge(
                      Icons.description_outlined,
                      size: 44,
                      iconSize: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            primaryTitle,
                            style: const TextStyle(
                              color: _cardTitle,
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                              height: 1.25,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            shortInfoParts.join(' · '),
                            style: const TextStyle(
                              color: _cardSub,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              height: 1.35,
                            ),
                            maxLines: 2,
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
    );
  }

  Widget _buildCoachNutritionCard(BuildContext context, NutritionGuide guide) {
    // Không tự tách bữa ăn từ văn bản tự do; dùng nhãn "Dinh dưỡng Coach gửi"
    final cleanPreview = guide.content
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const Key('frame3-coach-nutrition-card'),
        onTap: () => _pushAndReload('/member/features/nutrition'),
        borderRadius: BorderRadius.circular(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: _cardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF10B981).withValues(alpha: 0.38),
                        ),
                      ),
                      child: const Text(
                        'Dinh dưỡng Coach gửi',
                        style: TextStyle(
                          color: Color(0xFF34D399),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const Spacer(),
                    const Text(
                      'Xem hướng dẫn',
                      style: TextStyle(
                        color: _coralLight,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: _coralLight,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildIconBadge(
                      Icons.menu_book_rounded,
                      size: 44,
                      iconSize: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            guide.title,
                            style: const TextStyle(
                              color: _cardTitle,
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                              height: 1.25,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            cleanPreview.isNotEmpty
                                ? cleanPreview
                                : 'Hướng dẫn dinh dưỡng từ Coach của bạn.',
                            style: const TextStyle(
                              color: _cardSub,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              height: 1.35,
                            ),
                            maxLines: 2,
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
    );
  }

  // ===========================================================================
  // KHUNG 3.3: MỤC "NHẬT KÝ CỦA BẠN" (LUÔN HIỂN THỊ 2 HÀNG DỄ QUÉT)
  // ===========================================================================
  Widget _buildMemberLogsSection(BuildContext context) {
    final workout = _latestWorkout;
    final meal = _latestMeal;

    String workoutSubtitle;
    String workoutActionLabel;
    if (workout != null) {
      final dateStr = _safeFormatDate(workout.performedAt);
      final parts = <String>[
        dateStr,
        if (workout.durationMinutes != null) '${workout.durationMinutes} phút',
        if (workout.exercises.isNotEmpty) '${workout.exercises.length} bài tập',
      ];
      workoutSubtitle = parts.join(' · ');
      workoutActionLabel = 'Mở nhật ký';
    } else {
      workoutSubtitle = 'Bắt đầu ghi lại quá trình tập luyện';
      workoutActionLabel = 'Ghi buổi đầu tiên';
    }

    String mealSubtitle;
    String mealActionLabel;
    if (meal != null) {
      final dateStr = _safeFormatDate(meal.eatenAt);
      mealSubtitle = '$dateStr · ${meal.mealName}';
      mealActionLabel = 'Mở nhật ký';
    } else {
      mealSubtitle = 'Ghi bữa ăn đầu tiên';
      mealActionLabel = 'Ghi bữa ăn đầu tiên';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Text(
              'Nhật ký của bạn',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                '· Tự ghi hằng ngày',
                style: TextStyle(
                  color: _cardSub,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          decoration: _cardDecoration(),
          child: Column(
            children: [
              // Hàng 1: Nhật ký tập luyện
              _buildLogRow(
                rowKey: const Key('frame3-workout-log-row'),
                icon: Icons.fitness_center_rounded,
                title: 'Nhật ký tập luyện',
                subtitle: workoutSubtitle,
                actionLabel: workoutActionLabel,
                hasData: workout != null,
                onTap: () => _pushAndReload('/member/features/workouts'),
              ),
              const Divider(
                height: 1,
                thickness: 1,
                color: _cardDivider,
                indent: 16,
                endIndent: 16,
              ),
              // Hàng 2: Nhật ký ăn uống (do Member tự ghi, phân biệt rõ với Dinh dưỡng Coach gửi)
              _buildLogRow(
                rowKey: const Key('frame3-meal-log-row'),
                icon: Icons.restaurant_menu_rounded,
                title: 'Nhật ký ăn uống',
                subtitle: mealSubtitle,
                actionLabel: mealActionLabel,
                hasData: meal != null,
                onTap: () => _pushAndReload('/member/features/meals'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLogRow({
    required Key rowKey,
    required IconData icon,
    required String title,
    required String subtitle,
    required String actionLabel,
    required bool hasData,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: rowKey,
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 68),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                _buildIconBadge(icon, size: 42, iconSize: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: _cardTitle,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: hasData ? const Color(0xFFCBD5E1) : _cardSub,
                          fontSize: 12.5,
                          fontWeight:
                              hasData ? FontWeight.w600 : FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  constraints: const BoxConstraints(minHeight: 36),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: hasData
                        ? _subBoxBg
                        : _coralPrimary.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: hasData
                          ? const Color(0x22FFFFFF)
                          : _coralPrimary.withValues(alpha: 0.45),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        actionLabel,
                        style: TextStyle(
                          color: hasData ? _cardTitle : _coralLight,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 15,
                        color: hasData ? _cardSub : _coralLight,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _safeFormatDate(String rawIso) {
    try {
      return formatProgressTime(rawIso);
    } catch (_) {
      return rawIso.split('T').first;
    }
  }

  // ===========================================================================
  // KHUNG 3.4: MỤC "KHÁM PHÁ" (DANH SÁCH GỌN 2 BÀI TRÊN HOME, KHÔNG CUỘN LỒNG)
  // ===========================================================================
  Widget _buildExploreSection(BuildContext context) {
    final homeArticles = kMemberExploreArticles.take(2).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Khám phá',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16.5,
                fontWeight: FontWeight.w800,
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
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text(
                        'Xem thêm',
                        style: TextStyle(
                          color: _coralLight,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(width: 2),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: _coralLight,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          decoration: _cardDecoration(),
          child: Column(
            children: [
              for (var i = 0; i < homeArticles.length; i++) ...[
                if (i > 0)
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: _cardDivider,
                    indent: 14,
                    endIndent: 14,
                  ),
                _buildExploreArticleRow(context, homeArticles[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildExploreArticleRow(
    BuildContext context,
    ExploreArticleItem article,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('frame3-explore-item-${article.id}'),
        onTap: () {
          Navigator.of(context).push<void>(
            MaterialPageRoute(
              builder: (_) => MemberExploreArticleDetailPage(article: article),
            ),
          );
        },
        borderRadius: BorderRadius.circular(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 76),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 56,
                    height: 56,
                    child: Image.asset(
                      article.imageAsset,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        color: _subBoxBg,
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.article_outlined,
                          color: _coralLight,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        article.title,
                        style: const TextStyle(
                          color: _cardTitle,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        article.shortDescription,
                        style: const TextStyle(
                          color: _cardSub,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: _cardSub,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // DANH MỤC TÍNH NĂNG ĐẦY ĐỦ & KIỂM THỬ (THU GỌN MẶC ĐỊNH)
  // ===========================================================================
  Widget _buildFullFeatureSection(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        dividerColor: Colors.transparent,
      ),
      child: ExpansionTile(
        initiallyExpanded: false,
        tilePadding: EdgeInsets.zero,
        title: const Text(
          'Không gian dành cho hội viên',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: const Text(
          'Tất cả danh mục tính năng & kiểm thử',
          style: TextStyle(
            color: _cardSub,
            fontSize: 12,
          ),
        ),
        iconColor: _coralPrimary,
        collapsedIconColor: _cardSub,
        children: [
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1A222D),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF283242)),
            ),
            child: Column(
              children: [
                for (final destination in memberDestinations)
                  ListTile(
                    title: Text(
                      destination.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      '${destination.section} · ${destination.task}',
                      style: const TextStyle(
                        color: _cardSub,
                        fontSize: 11,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                      color: _cardSub,
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
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _coralPrimary,
                          side: const BorderSide(color: _coralPrimary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () =>
                            context.push(AppRoutes.memberWorkbench),
                        child: const Text('Kiểm thử các luồng hội viên'),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BannerSlideData {
  const _BannerSlideData({
    required this.tag,
    required this.hours,
    required this.title,
    required this.subtitle,
  });

  final String tag;
  final String hours;
  final String title;
  final String subtitle;
}

class _MockDayProgress {
  _MockDayProgress({
    required this.day,
    required this.isCompleted,
    this.isToday = false,
  });

  final String day;
  bool isCompleted;
  final bool isToday;
}

class _CircleHeaderButton extends StatelessWidget {
  const _CircleHeaderButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF222B38),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0x26FFFFFF), width: 1),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// KHUNG 1.3: TRUY CẬP NHANH (HIGH-CONTRAST ELEVATED TILES)
// ===========================================================================
class _QuickAccessSection extends StatefulWidget {
  const _QuickAccessSection({
    required this.onNavigateTab,
  });

  final ValueChanged<int> onNavigateTab;

  @override
  State<_QuickAccessSection> createState() => _QuickAccessSectionState();
}

class _QuickAccessSectionState extends State<_QuickAccessSection> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    final next = (_currentPage + 1) % 3;
    _pageController.animateToPage(
      next,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Text(
                  'Truy cập nhanh',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '· ${_currentPage + 1}/3',
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            InkWell(
              onTap: _nextPage,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF232C3B),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0x26FFFFFF)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Đổi trang',
                      style: TextStyle(
                        color: Color(0xFFFF8566),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 6),
                    _buildPageDot(isActive: _currentPage == 0),
                    const SizedBox(width: 4),
                    _buildPageDot(isActive: _currentPage == 1),
                    const SizedBox(width: 4),
                    _buildPageDot(isActive: _currentPage == 2),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 92,
          child: PageView(
            controller: _pageController,
            onPageChanged: (page) => setState(() => _currentPage = page),
            children: [
              // Trang 1: Lịch tập · Giáo trình · Dinh dưỡng · Coach
              Row(
                children: [
                  Expanded(
                    child: _QuickAccessItem(
                      icon: Icons.calendar_today_outlined,
                      label: 'Lịch tập',
                      onTap: () => context.push('/member/features/sessions'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _QuickAccessItem(
                      icon: Icons.description_outlined,
                      label: 'Giáo trình',
                      onTap: () => context.push('/member/features/training'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _QuickAccessItem(
                      icon: Icons.restaurant_outlined,
                      label: 'Dinh dưỡng',
                      onTap: () => context.push('/member/features/nutrition'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _QuickAccessItem(
                      icon: Icons.person_outline_rounded,
                      label: 'Coach',
                      onTap: () => context.push('/member/features/coaching'),
                    ),
                  ),
                ],
              ),
              // Trang 2: Gói tập · Nhật ký tập · Tiến độ · Phòng gym
              Row(
                children: [
                  Expanded(
                    child: _QuickAccessItem(
                      icon: Icons.card_membership_outlined,
                      label: 'Gói tập',
                      onTap: () => context.push('/member/features/payments'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _QuickAccessItem(
                      icon: Icons.assignment_outlined,
                      label: 'Nhật ký tập',
                      onTap: () => context.push('/member/features/workouts'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _QuickAccessItem(
                      icon: Icons.bar_chart_rounded,
                      label: 'Tiến độ',
                      onTap: () => context.push('/member/features/progress'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _QuickAccessItem(
                      icon: Icons.storefront_outlined,
                      label: 'Phòng gym',
                      onTap: () => context.push('/member/features/gym'),
                    ),
                  ),
                ],
              ),
              // Trang 3: Nhật ký ăn · Số đo · Ảnh vóc dáng · Cuộc gọi
              Row(
                children: [
                  Expanded(
                    child: _QuickAccessItem(
                      icon: Icons.restaurant_menu_rounded,
                      label: 'Nhật ký ăn',
                      onTap: () => context.push('/member/features/meals'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _QuickAccessItem(
                      icon: Icons.straighten_rounded,
                      label: 'Số đo',
                      onTap: () =>
                          context.push('/member/features/measurements'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _QuickAccessItem(
                      icon: Icons.camera_alt_outlined,
                      label: 'Ảnh vóc dáng',
                      onTap: () => context.push('/member/features/photos'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _QuickAccessItem(
                      icon: Icons.call_outlined,
                      label: 'Cuộc gọi',
                      onTap: () => context.push('/member/features/calls'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPageDot({required bool isActive}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      width: isActive ? 12 : 5,
      height: 5,
      decoration: BoxDecoration(
        color: isActive
            ? const Color(0xFFFF5E3A)
            : Colors.white.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}

class _QuickAccessItem extends StatelessWidget {
  const _QuickAccessItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: const Color(0xFFFF5E3A).withValues(alpha: 0.2),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF283344), Color(0xFF1F2836)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0x47FF8C69),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFFFEAE4), Color(0xFFFFD5C8)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: const Color(0xFFE64420),
                    size: 20,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFF8FAFC),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DayProgressItem extends StatelessWidget {
  const _DayProgressItem({
    required this.day,
    required this.isCompleted,
    required this.onTap,
    this.isToday = false,
  });

  final String day;
  final bool isCompleted;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 44, minHeight: 48),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: isCompleted
                      ? const LinearGradient(
                          colors: [Color(0xFFFF7E58), Color(0xFFFF5E3A)],
                        )
                      : null,
                  color: isCompleted ? null : const Color(0xFF293444),
                  border: Border.all(
                    color: isCompleted
                        ? const Color(0xFFFF7E58)
                        : isToday
                            ? const Color(0xFFFF7E58)
                            : const Color(0x33FFFFFF),
                    width: isToday && !isCompleted ? 1.8 : 1.2,
                  ),
                ),
                child: isCompleted
                    ? const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 15,
                      )
                    : Center(
                        child: Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isToday
                                ? const Color(0xFFFF7E58)
                                : const Color(0x6694A3B8),
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: 5),
              Text(
                isToday ? '$day*' : day,
                style: TextStyle(
                  color: isCompleted || isToday
                      ? const Color(0xFFF3F6FA)
                      : const Color(0xFF94A3B8),
                  fontSize: 12,
                  fontWeight:
                      isCompleted || isToday ? FontWeight.w800 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
