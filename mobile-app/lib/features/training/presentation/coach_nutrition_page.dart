import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:meta_gym_app/core/navigation/meta_gym_navigation.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/theme/meta_gym_icons.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_icon.dart';
import 'package:meta_gym_app/features/coaching/domain/coach_member_models.dart';
import 'package:meta_gym_app/features/coaching/presentation/coaching_ui.dart';
import 'package:meta_gym_app/features/training/data/coach_nutrition_service.dart';
import 'package:meta_gym_app/features/training/domain/nutrition_models.dart';
import 'package:meta_gym_app/features/training/presentation/coach_nutrition_editor_page.dart';
import 'package:meta_gym_app/features/training/presentation/coach_training_page.dart';

class CoachNutritionPage extends StatefulWidget {
  const CoachNutritionPage({
    this.service,
    this.structured = false,
    this.previewMode = false,
    this.initialMembers,
    this.useSolidGlassFallback = false,
    super.key,
  });

  final CoachNutritionService? service;
  final bool structured;
  final bool previewMode;
  final List<CoachMemberSummary>? initialMembers;
  final bool useSolidGlassFallback;

  @override
  State<CoachNutritionPage> createState() => _CoachNutritionPageState();
}

class _CoachNutritionPageState extends State<CoachNutritionPage> {
  CoachNutritionService? _service;
  ApiClient? _apiClient;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _apiClient = optionalProvider<ApiClient>(context);
    _service =
        widget.service ??
        optionalProvider<CoachNutritionService>(context) ??
        (_apiClient == null ? null : CoachNutritionApi(_apiClient!));
  }

  @override
  Widget build(BuildContext context) {
    final service = _service;
    if (widget.structured || widget.previewMode) {
      return CoachMemberPlanningHubView(
        focusNutrition: true,
        previewMode: widget.previewMode,
        initialMembers: widget.initialMembers,
        loadMembersOverride: service?.getMembers,
        useSolidGlassFallback: widget.useSolidGlassFallback,
      );
    }

    return CoachMemberPlanningHubView(
      focusNutrition: true,
      loadMembersOverride: service?.getMembers,
      useSolidGlassFallback: widget.useSolidGlassFallback,
      onOpenPrimaryOverride: service == null
          ? null
          : (member) => MetaGymNavigation.pushOnce<void>(
              context,
              MetaGymPageRoute(
                builder: (_) => _MemberGuidesPage(
                  member: member,
                  service: service,
                  useSolidGlassFallback: widget.useSolidGlassFallback,
                ),
              ),
            ),
    );
  }
}

class _MemberGuidesPage extends StatefulWidget {
  const _MemberGuidesPage({
    required this.member,
    required this.service,
    this.useSolidGlassFallback = false,
  });

  final CoachMemberSummary member;
  final CoachNutritionService service;
  final bool useSolidGlassFallback;

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
    await MetaGymNavigation.pushOnce<void>(
      context,
      MetaGymPageRoute(
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

  Color _guideAccent(MetaGymColors colors, String status) => switch (status) {
    'ACTIVE' => colors.success,
    'DRAFT' => colors.warning,
    _ => colors.reflection,
  };

  Widget _buildHeader(BuildContext context, MetaGymColors colors) {
    final canPop = Navigator.of(context).canPop();
    final gutter = MediaQuery.sizeOf(context).width >= 600
        ? MetaGymTheme.tabletGutter
        : MetaGymTheme.pageGutter;

    return Padding(
      padding: EdgeInsets.fromLTRB(gutter, 8, gutter, 10),
      child: Row(
        children: [
          if (canPop) ...[
            MetaGymCircleIconButton(
              svgAsset: MetaGymIcons.commonBack,
              icon: Icons.arrow_back_ios_new_rounded,
              tooltip: 'Quay lại',
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
                  'DINH DƯỠNG · COACH',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.primaryText,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.member.memberFullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = MetaGymColors.of(context);
    final isLight = Theme.of(context).brightness == Brightness.light;
    final media = MediaQuery.paddingOf(context);
    final gutter = MediaQuery.sizeOf(context).width >= 600
        ? MetaGymTheme.tabletGutter
        : MetaGymTheme.pageGutter;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isLight ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: colors.canvas,
        body: Stack(
          fit: StackFit.expand,
          children: [
            MetaGymBackground(useSolidFallback: widget.useSolidGlassFallback),
            SafeArea(
              bottom: false,
              child: Column(
                children: [
                  _buildHeader(context, colors),
                  Expanded(
                    child: _loading
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: MetaGymTheme.primary,
                            ),
                          )
                        : RefreshIndicator(
                            color: MetaGymTheme.primary,
                            backgroundColor: colors.overlayGlass,
                            onRefresh: _load,
                            child: ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: EdgeInsets.fromLTRB(
                                gutter,
                                4,
                                gutter,
                                media.bottom + 36,
                              ),
                              children: [
                                if (_error != null) ...[
                                  CoachingErrorBanner(message: _error!),
                                  CoachingSecondaryButton(
                                    label: 'Thử lại',
                                    onPressed: _load,
                                    expand: true,
                                  ),
                                ] else ...[
                                  MetaGymHeroGlassCard(
                                    useSolidFallback:
                                        widget.useSolidGlassFallback,
                                    padding: const EdgeInsets.all(14),
                                    child: Row(
                                      children: [
                                        CoachingAvatar(
                                          fullName:
                                              widget.member.memberFullName,
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
                                                style: TextStyle(
                                                  color: colors.textPrimary,
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              const SizedBox(height: 3),
                                              Text(
                                                '${_guides.length} hướng dẫn dinh dưỡng',
                                                style: TextStyle(
                                                  color: colors.textWarmMuted,
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
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.menu_book_outlined,
                                        color: colors.success,
                                        size: 19,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Danh sách hướng dẫn',
                                          style: TextStyle(
                                            color: colors.textPrimary,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      CoachingPill(
                                        label: '${_guides.length} bản',
                                        tone: CoachingPillTone.neutral,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  if (_guides.isEmpty)
                                    MetaGymGlassCard(
                                      solid: widget.useSolidGlassFallback,
                                      padding: const EdgeInsets.all(20),
                                      child: Column(
                                        children: [
                                          Container(
                                            width: 48,
                                            height: 48,
                                            decoration: BoxDecoration(
                                              color: colors.metricPanelBg,
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              border: Border.all(
                                                color: colors.metricPanelBorder,
                                              ),
                                            ),
                                            alignment: Alignment.center,
                                            child: MetaGymIcon(
                                              MetaGymIcons.emptyNutrition,
                                              size: 24,
                                              color: colors.textSecondary,
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            'Chưa có hướng dẫn nào.',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: colors.textPrimary,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            'Nhấn "Tạo hướng dẫn" để soạn thực đơn và nguyên tắc dinh dưỡng cho hội viên.',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: colors.textSecondary,
                                              fontSize: 13,
                                              height: 1.45,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  else
                                    for (final guide in _guides)
                                      MetaGymGlassCard(
                                        solid: widget.useSolidGlassFallback,
                                        margin: const EdgeInsets.only(
                                          bottom: 12,
                                        ),
                                        borderColor: guide.status == 'ACTIVE'
                                            ? colors.success.withValues(
                                                alpha: 0.40,
                                              )
                                            : null,
                                        onTap: () => _open(guide),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Container(
                                              width: 44,
                                              height: 44,
                                              decoration: BoxDecoration(
                                                color: _guideAccent(
                                                  colors,
                                                  guide.status,
                                                ).withValues(alpha: 0.14),
                                                borderRadius:
                                                    BorderRadius.circular(13),
                                                border: Border.all(
                                                  color: _guideAccent(
                                                    colors,
                                                    guide.status,
                                                  ).withValues(alpha: 0.35),
                                                ),
                                              ),
                                              child: Icon(
                                                _guideIcon(guide.status),
                                                color: _guideAccent(
                                                  colors,
                                                  guide.status,
                                                ),
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
                                                    tone: _guideTone(
                                                      guide.status,
                                                    ),
                                                    icon: _guideIcon(
                                                      guide.status,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Text(
                                                    guide.title,
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      color: colors.textPrimary,
                                                      fontSize: 15.5,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      height: 1.3,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    guide.publicationLabel,
                                                    style: TextStyle(
                                                      color:
                                                          colors.textSecondary,
                                                      fontSize: 12.5,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                top: 10,
                                              ),
                                              child: Icon(
                                                Icons.chevron_right_rounded,
                                                color: colors.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                ],
                              ],
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
}
