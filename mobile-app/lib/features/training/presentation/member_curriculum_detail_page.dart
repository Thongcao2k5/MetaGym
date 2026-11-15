import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/features/coaching/data/coach_v2_api.dart';
import 'package:meta_gym_app/features/coaching/data/member_coaching_service.dart';
import 'package:meta_gym_app/features/membership/presentation/membership_page.dart';
import 'package:meta_gym_app/features/training/data/member_training_service.dart';
import 'package:meta_gym_app/features/training/domain/training_models.dart';
import 'package:provider/provider.dart';

/// Read-only Member view of the Coach's training and seven-day meal plan.
class MemberCurriculumDetailPage extends StatefulWidget {
  const MemberCurriculumDetailPage({
    required this.id,
    required this.service,
    super.key,
  });

  final String id;
  final MemberTrainingService service;

  @override
  State<MemberCurriculumDetailPage> createState() =>
      _MemberCurriculumDetailPageState();
}

class _MemberCurriculumDetailPageState
    extends State<MemberCurriculumDetailPage> {
  TrainingPlan? _plan;
  CoachRecord? _mealPlan;
  String? _coachName;
  String? _error;
  String? _mealError;
  bool _loading = true;
  bool _paused = false;
  int _tab = 0;
  int _day = 0;
  int _weekday = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
      _mealError = null;
    });
    try {
      final plan = await widget.service.getPlan(widget.id);
      if (!mounted) return;
      if (plan.status != 'ACTIVE' && plan.status != 'ARCHIVED') {
        setState(() => _error = 'Không tìm thấy giáo trình của bạn.');
        return;
      }
      setState(() {
        _plan = plan;
        _day = plan.days.isEmpty
            ? 0
            : _day.clamp(0, plan.days.length - 1).toInt();
      });

      try {
        final api = CoachV2Api(context.read<ApiClient>());
        final plans = await api.list('/meal-plans/me');
        if (mounted) {
          setState(() {
            _mealPlan = plan.relationshipId == null
                ? null
                : plans
                      .where(
                        (item) =>
                            item['relationshipId'] == plan.relationshipId &&
                            item['status'] == plan.status,
                      )
                      .firstOrNull;
          });
        }
      } on ApiException catch (error) {
        if (mounted) setState(() => _mealError = error.message);
      } catch (_) {
        if (mounted) setState(() => _mealError = 'Không tải được thực đơn.');
      }

      if (!mounted) return;
      try {
        final coaching = context.read<MemberCoachingService>();
        final relationship = await coaching.getCurrentRelationship();
        final names = await coaching.getCoachNames();
        if (mounted) {
          setState(() {
            _paused =
                plan.status == 'ACTIVE' &&
                relationship?.coachId == plan.coachId &&
                relationship?.status == 'PAUSED';
            _coachName = names[plan.coachId];
          });
        }
      } catch (_) {
        // The curriculum remains readable when Coach metadata is unavailable.
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không tải được giáo trình.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<CoachRecord> get _items {
    final raw = _mealPlan?['items'];
    return raw is List
        ? raw.whereType<Map>().map((item) => CoachRecord.from(item)).toList()
        : const [];
  }

  @override
  Widget build(BuildContext context) {
    final plan = _plan;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: MetaGymTheme.scaffoldBackground,
        body: RefreshIndicator(
          color: MetaGymTheme.primary,
          onRefresh: _load,
          child: ListView(
            padding: EdgeInsets.zero,
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              _header(context, plan),
              if (_loading && plan == null)
                const Padding(
                  padding: EdgeInsets.only(top: 64),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: MetaGymTheme.primary,
                    ),
                  ),
                )
              else if (_error != null)
                _message(
                  icon: Icons.error_outline,
                  title: 'Chưa tải được giáo trình',
                  body: _error!,
                  action: TextButton(
                    onPressed: _load,
                    child: const Text('Thử lại'),
                  ),
                )
              else if (plan != null) ...[
                _tabSelector(plan),
                if (_paused) _pausedNotice(),
                if (_tab == 0) _training(plan) else _nutrition(),
              ],
              SizedBox(height: MediaQuery.paddingOf(context).bottom + 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context, TrainingPlan? plan) {
    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            'assets/images/gym_banner.png',
            fit: BoxFit.cover,
            alignment: const Alignment(0, -0.75),
            errorBuilder: (_, _, _) =>
                const ColoredBox(color: MetaGymTheme.scaffoldBackground),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  MetaGymTheme.scaffoldBackground.withValues(alpha: 0.50),
                  MetaGymTheme.scaffoldBackground.withValues(alpha: 0.83),
                  MetaGymTheme.scaffoldBackground,
                ],
              ),
            ),
          ),
        ),
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    _headerButton(
                      icon: Icons.arrow_back_ios_new_rounded,
                      label: 'Quay lại',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Giáo trình',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          fontFamily: MetaGymTheme.fontFamily,
                        ),
                      ),
                    ),
                    _headerButton(
                      icon: Icons.chat_bubble_outline_rounded,
                      label: 'Tin nhắn',
                      onPressed: () =>
                          context.push('/member/features/messages'),
                    ),
                  ],
                ),
                if (plan != null) ...[const SizedBox(height: 8), _hero(plan)],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _headerButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) => OutlinedButton.icon(
    onPressed: onPressed,
    icon: Icon(icon, size: 17),
    label: Text(label),
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(48, 48),
      padding: const EdgeInsets.symmetric(horizontal: 11),
      foregroundColor: Colors.white,
      backgroundColor: const Color(0xD71D1B1B),
      side: const BorderSide(color: Color(0x807C6555)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      textStyle: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        fontFamily: MetaGymTheme.fontFamily,
      ),
    ),
  );

  Widget _hero(TrainingPlan plan) {
    final status = _paused
        ? 'Tạm khóa'
        : plan.status == 'ARCHIVED'
        ? 'Đã lưu trữ'
        : 'Đang áp dụng';
    final statusColor = _paused
        ? MetaGymTheme.warning
        : plan.status == 'ARCHIVED'
        ? MetaGymTheme.reflectionBlue
        : MetaGymTheme.success;
    final coach = _coachName;
    final card = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xE3443025), Color(0xF024201F)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xB8C89463)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _status(status, statusColor),
              const Spacer(),
              if (plan.publishedAt != null)
                Text(
                  _date(plan.publishedAt!),
                  style: const TextStyle(
                    color: Color(0xFFD6C5B8),
                    fontSize: 11,
                    fontFamily: MetaGymTheme.fontFamily,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            plan.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              height: 1.25,
              fontWeight: FontWeight.w700,
              fontFamily: MetaGymTheme.fontFamily,
            ),
          ),
          if (plan.goal?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 5),
            Text(
              plan.goal!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFE4DAD1),
                fontSize: 13,
                height: 1.4,
                fontFamily: MetaGymTheme.fontFamily,
              ),
            ),
          ],
          const SizedBox(height: 8),
          const Divider(color: Color(0x40FFE0C2), height: 1),
          const SizedBox(height: 8),
          Row(
            children: [
              if (coach != null) ...[
                CircleAvatar(
                  radius: 17,
                  backgroundColor: MetaGymTheme.coachAvatarBackground,
                  child: Text(
                    _initials(coach),
                    style: const TextStyle(
                      color: MetaGymTheme.coachAvatarForeground,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    coach,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      fontFamily: MetaGymTheme.fontFamily,
                    ),
                  ),
                ),
              ] else
                const Spacer(),
              _smallChip('${plan.days.length} ngày tập'),
            ],
          ),
        ],
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: MetaGymTheme.isFlutterTestEnvironment
          ? card
          : BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: card,
            ),
    );
  }

  Widget _tabSelector(TrainingPlan plan) {
    final count = _mealPlan == null ? 'Chưa có' : 'T2–CN';
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(5),
      decoration: _box(),
      child: Row(
        children: [
          for (final (index, label, badge) in [
            (0, 'Tập luyện', '${plan.days.length} ngày'),
            (1, 'Dinh dưỡng', count),
          ])
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _tab = index),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 46),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _tab == index ? const Color(0xFF281B18) : null,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _tab == index
                          ? MetaGymTheme.primary
                          : Colors.transparent,
                    ),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            color: _tab == index
                                ? Colors.white
                                : MetaGymTheme.textSecondary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            fontFamily: MetaGymTheme.fontFamily,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          badge,
                          style: const TextStyle(
                            color: MetaGymTheme.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
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

  Widget _pausedNotice() => Container(
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    padding: const EdgeInsets.all(16),
    decoration: _box(border: const Color(0xFF694917)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.lock_clock_outlined, color: MetaGymTheme.warning),
            SizedBox(width: 8),
            Text(
              'Giáo trình đang tạm khóa',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Kế hoạch Coach đã tạo được giữ lại. Gia hạn gói Gym để tiếp tục sử dụng khi quan hệ Coach có hiệu lực.',
          style: TextStyle(
            color: Color(0xFFD6DCE6),
            fontSize: 13,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const MembershipPage())),
          style: FilledButton.styleFrom(
            backgroundColor: MetaGymTheme.primary,
            foregroundColor: MetaGymTheme.onPrimary,
            minimumSize: const Size(150, 48),
          ),
          child: const Text('Gia hạn gói tập'),
        ),
      ],
    ),
  );

  Widget _training(TrainingPlan plan) {
    final days = plan.days;
    if (days.isEmpty) {
      return _message(
        icon: Icons.calendar_today_outlined,
        title: 'Chưa có ngày tập',
        body: 'Coach chưa thêm bài tập vào giáo trình.',
      );
    }
    final day = days[_day];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 54,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: days.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) => _choice(
              title: 'Ngày ${days[index].dayNumber}',
              subtitle: '${days[index].exercises.length} bài tập',
              selected: _day == index,
              onTap: _paused ? null : () => setState(() => _day = index),
            ),
          ),
        ),
        if (_paused)
          const SizedBox.shrink()
        else ...[
          const SizedBox(height: 10),
          _surface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ngày ${day.dayNumber} trong giáo án',
                  style: const TextStyle(
                    color: MetaGymTheme.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  day.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (day.scheduledDate != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Lịch: ${_date(day.scheduledDate!)}',
                    style: const TextStyle(
                      color: MetaGymTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
                if (day.notes?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 12),
                  _note(day.notes!),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (day.exercises.isEmpty)
            _message(
              icon: Icons.fitness_center_outlined,
              title: 'Chưa có bài tập',
              body: 'Coach chưa xếp bài tập cho ngày này.',
            )
          else
            for (final (index, exercise) in day.exercises.indexed)
              _exercise(exercise, index + 1),
        ],
      ],
    );
  }

  Widget _exercise(TrainingExercise exercise, int number) => _surface(
    bottom: 12,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _smallChip(number.toString().padLeft(2, '0')),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                exercise.exerciseName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
        if (exercise.prescription.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            exercise.prescription,
            style: const TextStyle(
              color: MetaGymTheme.primary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        if (exercise.restSeconds != null ||
            exercise.weightGuidance?.isNotEmpty == true) ...[
          const SizedBox(height: 5),
          Text(
            [
              if (exercise.restSeconds != null)
                'Nghỉ ${exercise.restSeconds} giây',
              if (exercise.weightGuidance?.isNotEmpty == true)
                'Mức tạ ${exercise.weightGuidance}',
            ].join(' · '),
            style: const TextStyle(
              color: MetaGymTheme.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
        for (final note in [
          exercise.instructions,
          exercise.safetyNotes,
          exercise.notes,
        ])
          if (note?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 10),
            _note(note!),
          ],
      ],
    ),
  );

  Widget _nutrition() {
    if (_paused) return const SizedBox.shrink();
    if (_mealError != null) {
      return _message(
        icon: Icons.error_outline,
        title: 'Chưa tải được thực đơn',
        body: _mealError!,
        action: TextButton(onPressed: _load, child: const Text('Thử lại')),
      );
    }
    final plan = _mealPlan;
    if (plan == null) {
      return _message(
        icon: Icons.restaurant_menu_outlined,
        title: 'Chưa có thực đơn từ Coach',
        body:
            'Thực đơn 7 ngày sẽ xuất hiện khi Coach lưu hướng dẫn dinh dưỡng.',
      );
    }
    final items = _items.where((item) => item['day'] == _weekday).toList();
    final total = items.fold<double>(0, (sum, item) => sum + _kcal(item));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 46,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: 7,
            separatorBuilder: (_, _) => const SizedBox(width: 7),
            itemBuilder: (context, index) => _choice(
              title: index == 6 ? 'CN' : 'T${index + 2}',
              selected: _weekday == index + 1,
              color: MetaGymTheme.success,
              onTap: () => setState(() => _weekday = index + 1),
            ),
          ),
        ),
        const SizedBox(height: 10),
        _surface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_weekday == 7 ? 'Chủ nhật' : 'Thứ ${_weekday + 1}'} · Lặp lại mỗi tuần',
                      style: const TextStyle(
                        color: MetaGymTheme.success,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (items.isNotEmpty)
                    _status('${total.round()} kcal', MetaGymTheme.success),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                plan['title'] as String? ?? 'Thực đơn của Coach',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (items.isEmpty)
          _message(
            icon: Icons.restaurant_outlined,
            title: 'Chưa có món cho ngày này',
            body:
                'Coach chưa thêm món vào thực đơn ${_weekday == 7 ? 'Chủ nhật' : 'Thứ ${_weekday + 1}'}.',
          )
        else
          for (final meal in const [
            ('BREAKFAST', 'Bữa sáng', Icons.wb_sunny_outlined),
            ('LUNCH', 'Bữa trưa', Icons.light_mode_outlined),
            ('DINNER', 'Bữa tối', Icons.nightlight_outlined),
          ])
            _mealGroup(meal.$1, meal.$2, meal.$3, items),
        if ((plan['content'] as String?)?.trim().isNotEmpty == true)
          _surface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Lưu ý từ Coach',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  plan['content'] as String,
                  style: const TextStyle(
                    color: MetaGymTheme.textSecondary,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _mealGroup(
    String key,
    String title,
    IconData icon,
    List<CoachRecord> items,
  ) {
    final foods = items.where((item) => item['meal'] == key).toList();
    final total = foods.fold<double>(0, (sum, item) => sum + _kcal(item));
    return _surface(
      bottom: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: MetaGymTheme.success, size: 19),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (foods.isNotEmpty)
                Text(
                  '${total.round()} kcal',
                  style: const TextStyle(
                    color: MetaGymTheme.success,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (foods.isEmpty)
            const Text(
              'Chưa có món',
              style: TextStyle(color: MetaGymTheme.textSecondary, fontSize: 13),
            )
          else
            for (final food in foods) ...[
              const Divider(color: MetaGymTheme.cardBorder, height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      food['foodName'] as String? ?? 'Thực phẩm',
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${food['grams']} g · ${_kcal(food).round()} kcal',
                    style: const TextStyle(
                      color: MetaGymTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
        ],
      ),
    );
  }

  Widget _choice({
    required String title,
    String? subtitle,
    required bool selected,
    required VoidCallback? onTap,
    Color color = MetaGymTheme.primary,
  }) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(13),
    child: Container(
      constraints: const BoxConstraints(minWidth: 48, minHeight: 46),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      decoration: _box(
        fill: selected
            ? color.withValues(alpha: 0.10)
            : MetaGymTheme.cardSurface,
        border: selected ? color : MetaGymTheme.cardBorder,
        radius: 13,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: TextStyle(
              color: selected ? Colors.white : MetaGymTheme.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (subtitle != null)
            Text(
              subtitle,
              style: const TextStyle(
                color: MetaGymTheme.textSecondary,
                fontSize: 11,
              ),
            ),
        ],
      ),
    ),
  );

  Widget _surface({required Widget child, double bottom = 0}) => Container(
    margin: EdgeInsets.fromLTRB(16, 0, 16, bottom),
    padding: const EdgeInsets.all(16),
    decoration: _box(),
    child: child,
  );

  Widget _message({
    required IconData icon,
    required String title,
    required String body,
    Widget? action,
  }) => _surface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: MetaGymTheme.reflectionBlue, size: 24),
        const SizedBox(height: 10),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          body,
          style: const TextStyle(
            color: MetaGymTheme.textSecondary,
            fontSize: 13,
            height: 1.45,
          ),
        ),
        if (action != null) ...[const SizedBox(height: 8), action],
      ],
    ),
  );

  Widget _note(String value) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(11),
    decoration: _box(fill: MetaGymTheme.elevatedSurface, radius: 12),
    child: Text(
      value,
      style: const TextStyle(
        color: Color(0xFFD6DCE6),
        fontSize: 12,
        height: 1.45,
      ),
    ),
  );

  Widget _status(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15),
      border: Border.all(color: color.withValues(alpha: 0.45)),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: color,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        fontFamily: MetaGymTheme.fontFamily,
      ),
    ),
  );

  Widget _smallChip(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      border: Border.all(color: const Color(0x806C5A4D)),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  BoxDecoration _box({
    Color fill = MetaGymTheme.cardSurface,
    Color border = MetaGymTheme.cardBorder,
    double radius = 20,
  }) => BoxDecoration(
    color: fill,
    border: Border.all(color: border),
    borderRadius: BorderRadius.circular(radius),
  );

  String _date(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;
    return '${parsed.day.toString().padLeft(2, '0')}/'
        '${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    return parts.length > 1
        ? '${parts.first[0]}${parts.last[0]}'.toUpperCase()
        : name.substring(0, name.length.clamp(0, 2)).toUpperCase();
  }

  double _kcal(CoachRecord food) {
    final grams = food['grams'];
    final per100 = food['kcalPer100g'];
    return grams is num && per100 is num ? grams * per100 / 100 : 0;
  }
}
