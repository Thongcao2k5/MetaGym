import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/features/coaching/domain/coach_member_models.dart';
import 'package:meta_gym_app/features/coaching/presentation/coaching_ui.dart';
import 'package:meta_gym_app/features/training/data/coach_nutrition_service.dart';
import 'package:meta_gym_app/features/training/domain/nutrition_models.dart';
import 'package:meta_gym_app/features/training/presentation/coach_nutrition_editor_page.dart';
import 'package:provider/provider.dart';

import 'meal_plans_page.dart';

class CoachNutritionPage extends StatefulWidget {
  const CoachNutritionPage({this.service, this.structured = false, super.key});

  final CoachNutritionService? service;
  final bool structured;

  @override
  State<CoachNutritionPage> createState() => _CoachNutritionPageState();
}

class _CoachNutritionPageState extends State<CoachNutritionPage> {
  CoachNutritionService? _service;
  List<CoachMemberSummary> _members = const [];
  String? _error;
  bool _loading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_service != null) return;
    _service = widget.service ?? context.read<CoachNutritionService>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _members = const [];
      _error = null;
    });
    try {
      final members = await _service!.getMembers();
      if (mounted) setState(() => _members = members);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không tải được hội viên.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: MetaGymTheme.scaffoldBackground,
        extendBodyBehindAppBar: true,
        appBar: _buildNutritionAppBar(
          context,
          title: 'Dinh dưỡng của Coach',
          onRefresh: _loading ? null : _load,
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            const MetaGymBackground(),
            _loading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: MetaGymTheme.primary,
                    ),
                  )
                : RefreshIndicator(
                    color: MetaGymTheme.primary,
                    onRefresh: _load,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: _nutritionScrollPadding(context),
                      children: [
                        if (_error != null) ...[
                          CoachingErrorBanner(message: _error!),
                          CoachingSecondaryButton(
                            label: 'Thử lại',
                            onPressed: _load,
                            expand: true,
                          ),
                        ] else ...[
                          _NutritionSectionHeader(
                            icon: Icons.restaurant_menu_rounded,
                            title: 'Chọn hội viên',
                            badge: '${_members.length} hội viên',
                          ),
                          const SizedBox(height: 12),
                          if (_members.isEmpty)
                            const _NutritionEmptyCard(
                              icon: Icons.group_outlined,
                              title: 'Chưa có hội viên đang phụ trách.',
                              subtitle: 'Hội viên đang đồng hành sẽ hiển thị tại đây để bạn gửi hướng dẫn dinh dưỡng.',
                            )
                          else
                            for (final member in _members)
                              CoachingGraphiteCard(
                                margin: const EdgeInsets.only(bottom: 12),
                                onTap: () async {
                                  await Navigator.of(context).push<void>(
                                    MaterialPageRoute(
                                      builder: (_) => widget.structured
                                          ? MealPlansPage(
                                              memberId: member.memberId,
                                              editable:
                                                  member.status == 'ACTIVE',
                                            )
                                          : _MemberGuidesPage(
                                              member: member,
                                              service: _service!,
                                            ),
                                    ),
                                  );
                                  if (mounted) await _load();
                                },
                                child: Row(
                                  children: [
                                    CoachingAvatar(
                                      fullName: member.memberFullName,
                                      size: 46,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            member.memberFullName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: MetaGymTheme.textPrimary,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          CoachingPill(
                                            label: member.statusLabel,
                                            tone: member.status == 'ACTIVE'
                                                ? CoachingPillTone.green
                                                : CoachingPillTone.amber,
                                            icon: member.status == 'ACTIVE'
                                                ? Icons.check_circle_outline
                                                : Icons.pause_circle_outline,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(
                                      Icons.chevron_right_rounded,
                                      color: MetaGymTheme.textSecondary,
                                    ),
                                  ],
                                ),
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
}

class _MemberGuidesPage extends StatefulWidget {
  const _MemberGuidesPage({required this.member, required this.service});

  final CoachMemberSummary member;
  final CoachNutritionService service;

  @override
  State<_MemberGuidesPage> createState() => _MemberGuidesPageState();
}

class _MemberGuidesPageState extends State<_MemberGuidesPage> {
  List<NutritionGuide> _guides = const [];
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _guides = const [];
      _error = null;
    });
    try {
      final guides = await widget.service.getGuides(widget.member.memberId);
      if (mounted) setState(() => _guides = guides);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không tải được hướng dẫn.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(NutritionGuide? guide) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => CoachNutritionEditorPage(
          memberId: widget.member.memberId,
          service: widget.service,
          guide: guide,
        ),
      ),
    );
    if (mounted) await _load();
  }

  CoachingPillTone _guideTone(String status) => switch (status) {
    'ACTIVE' => CoachingPillTone.green,
    'DRAFT' => CoachingPillTone.amber,
    _ => CoachingPillTone.neutral,
  };

  IconData _guideIcon(String status) => switch (status) {
    'ACTIVE' => Icons.eco_outlined,
    'DRAFT' => Icons.edit_note_rounded,
    _ => Icons.history_rounded,
  };

  Color _guideAccent(String status) => switch (status) {
    'ACTIVE' => MetaGymTheme.success,
    'DRAFT' => MetaGymTheme.warning,
    _ => MetaGymTheme.reflectionBlue,
  };

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: MetaGymTheme.scaffoldBackground,
        extendBodyBehindAppBar: true,
        appBar: _buildNutritionAppBar(
          context,
          title: 'Dinh dưỡng · ${widget.member.memberFullName}',
          onRefresh: _loading ? null : _load,
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            const MetaGymBackground(),
            _loading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: MetaGymTheme.primary,
                    ),
                  )
                : RefreshIndicator(
                    color: MetaGymTheme.primary,
                    onRefresh: _load,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: _nutritionScrollPadding(context),
                      children: [
                        if (_error != null) ...[
                          CoachingErrorBanner(message: _error!),
                          CoachingSecondaryButton(
                            label: 'Thử lại',
                            onPressed: _load,
                            expand: true,
                          ),
                        ] else ...[
                          CoachingGraphiteCard(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                CoachingAvatar(
                                  fullName: widget.member.memberFullName,
                                  size: 42,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        widget.member.memberFullName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: MetaGymTheme.textPrimary,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '${_guides.length} hướng dẫn dinh dưỡng',
                                        style: const TextStyle(
                                          color: MetaGymTheme.textSecondary,
                                          fontSize: 12.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                CoachingPill(
                                  label: widget.member.statusLabel,
                                  tone: widget.member.status == 'ACTIVE'
                                      ? CoachingPillTone.green
                                      : CoachingPillTone.amber,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          CoachingPrimaryButton(
                            label: 'Tạo hướng dẫn',
                            icon: Icons.add_rounded,
                            onPressed: () => _open(null),
                          ),
                          const SizedBox(height: 18),
                          _NutritionSectionHeader(
                            icon: Icons.menu_book_outlined,
                            title: 'Danh sách hướng dẫn',
                            badge: '${_guides.length} bản',
                          ),
                          const SizedBox(height: 12),
                          if (_guides.isEmpty)
                            const _NutritionEmptyCard(
                              icon: Icons.no_meals_outlined,
                              title: 'Chưa có hướng dẫn nào.',
                              subtitle: 'Nhấn "Tạo hướng dẫn" để soạn thực đơn và nguyên tắc dinh dưỡng cho hội viên.',
                            )
                          else
                            for (final guide in _guides)
                              CoachingGraphiteCard(
                                margin: const EdgeInsets.only(bottom: 12),
                                borderColor: guide.status == 'ACTIVE'
                                    ? MetaGymTheme.success.withValues(
                                        alpha: 0.40,
                                      )
                                    : null,
                                onTap: () => _open(guide),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: _guideAccent(guide.status)
                                            .withValues(alpha: 0.14),
                                        borderRadius: BorderRadius.circular(13),
                                        border: Border.all(
                                          color: _guideAccent(guide.status)
                                              .withValues(alpha: 0.35),
                                        ),
                                      ),
                                      child: Icon(
                                        _guideIcon(guide.status),
                                        color: _guideAccent(guide.status),
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          CoachingPill(
                                            label:
                                                '${guide.statusLabel} · Phiên bản ${guide.version}',
                                            tone: _guideTone(guide.status),
                                            icon: _guideIcon(guide.status),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            guide.title,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: MetaGymTheme.textPrimary,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                              height: 1.3,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            guide.publicationLabel,
                                            style: const TextStyle(
                                              color: MetaGymTheme.textSecondary,
                                              fontSize: 12.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    const Padding(
                                      padding: EdgeInsets.only(top: 10),
                                      child: Icon(
                                        Icons.chevron_right_rounded,
                                        color: MetaGymTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
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
}

PreferredSizeWidget _buildNutritionAppBar(
  BuildContext context, {
  required String title,
  VoidCallback? onRefresh,
}) {
  final canPop = Navigator.of(context).canPop();
  return AppBar(
    automaticallyImplyLeading: false,
    leadingWidth: 72,
    leading: canPop
        ? Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: MetaGymCircleIconButton(
                icon: Icons.arrow_back_ios_new_rounded,
                tooltip: 'Quay lại',
                onTap: () => Navigator.of(context).maybePop(),
              ),
            ),
          )
        : null,
    titleSpacing: canPop ? 8 : 16,
    title: Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: MetaGymTheme.textPrimary,
        fontSize: 19,
        fontWeight: FontWeight.w700,
      ),
    ),
    actions: [
      Padding(
        padding: const EdgeInsets.only(right: 16),
        child: Center(
          child: MetaGymCircleIconButton(
            icon: Icons.refresh_rounded,
            tooltip: 'Tải lại',
            onTap: onRefresh,
          ),
        ),
      ),
    ],
    backgroundColor: Colors.transparent,
    foregroundColor: MetaGymTheme.textPrimary,
    elevation: 0,
    scrolledUnderElevation: 0,
    surfaceTintColor: Colors.transparent,
  );
}

EdgeInsets _nutritionScrollPadding(BuildContext context) {
  final media = MediaQuery.paddingOf(context);
  return EdgeInsets.fromLTRB(
    16,
    media.top + kToolbarHeight + 12,
    16,
    media.bottom + 24,
  );
}

class _NutritionSectionHeader extends StatelessWidget {
  const _NutritionSectionHeader({
    required this.icon,
    required this.title,
    required this.badge,
  });

  final IconData icon;
  final String title;
  final String badge;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: MetaGymTheme.success, size: 19),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: MetaGymTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        CoachingPill(label: badge, tone: CoachingPillTone.neutral),
      ],
    );
  }
}

class _NutritionEmptyCard extends StatelessWidget {
  const _NutritionEmptyCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return CoachingGraphiteCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: MetaGymTheme.elevatedSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: MetaGymTheme.cardBorder),
            ),
            child: Icon(icon, color: MetaGymTheme.success, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: MetaGymTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: MetaGymTheme.textSecondary,
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
