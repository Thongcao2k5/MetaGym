import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/features/training/data/member_nutrition_service.dart';
import 'package:meta_gym_app/features/training/domain/nutrition_models.dart';
import 'package:provider/provider.dart';

import 'member_coach_nutrition_page.dart';
import 'package:meta_gym_app/core/theme/meta_gym_icons.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_svg_icon.dart';

class MemberNutritionPage extends StatefulWidget {
  const MemberNutritionPage({this.service, this.structured = false, super.key});

  final MemberNutritionService? service;
  final bool structured;

  @override
  State<MemberNutritionPage> createState() => _MemberNutritionPageState();
}

class _MemberNutritionPageState extends State<MemberNutritionPage> {
  MemberNutritionService? _service;
  NutritionGuide? _active;
  List<NutritionGuide> _history = const [];
  String? _error;
  bool _loading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_service != null) return;
    _service = widget.service ?? context.read<MemberNutritionService>();
    if (widget.structured && _service is MemberNutritionApi) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _active = null;
      _history = const [];
      _error = null;
    });
    try {
      final active = await _service!.getActive();
      final history = await _service!.getHistory();
      if (!mounted) return;
      setState(() {
        _active = active?.status == 'ACTIVE' ? active : null;
        _history = history
            .where(
              (guide) => guide.status == 'ARCHIVED' && guide.id != active?.id,
            )
            .toList();
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không tải được dinh dưỡng.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.structured && _service is MemberNutritionApi) {
      return const MemberCoachNutritionPage();
    }
    final palette = MetaGymTheme.paletteOf(context);
    final colors = MetaGymColors.of(context);
    final canPop = Navigator.of(context).canPop();
    return Scaffold(
      backgroundColor: palette.canvas,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leadingWidth: canPop ? 72 : null,
        leading: canPop
            ? Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: MetaGymCircleIconButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip: 'Quay lại',
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                ),
              )
            : null,
        titleSpacing: canPop ? 8 : 16,
        title: Text(
          'Dinh dưỡng',
          style: TextStyle(
            color: palette.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: palette.textPrimary,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const MetaGymBackground(),
          SafeArea(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: MetaGymTheme.primary,
                    ),
                  )
                : RefreshIndicator(
                    color: MetaGymTheme.brandOrange,
                    backgroundColor: colors.surface,
                    onRefresh: _load,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                      children: [
                        if (_error != null) ...[
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: palette.error.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: palette.error.withValues(alpha: 0.42),
                              ),
                            ),
                            child: Row(
                              children: [
                                MetaGymSvgIcon(MetaGymIcons.stateError, size: 20, fallbackIcon: Icons.error_outline_rounded),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _error!,
                                    style: TextStyle(
                                      color: palette.error,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
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
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        ] else ...[
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12, top: 4),
                            child: Row(
                              children: [
                                MetaGymSvgIcon(MetaGymIcons.foodMeal, size: 20, fallbackIcon: Icons.restaurant_menu_rounded),
                                const SizedBox(width: 8),
                                Text(
                                  'Hiện hành',
                                  style: TextStyle(
                                    color: palette.textPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_active == null)
                            MetaGymGlassCard(
                              padding: const EdgeInsets.all(16),
                              child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: MetaGymSvgIcon(MetaGymIcons.emptyNutrition, fallbackIcon: Icons.no_meals_outlined),
                                title: Text(
                                  'Bạn chưa có hướng dẫn dinh dưỡng.',
                                  style: TextStyle(
                                    color: palette.textSecondary,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            )
                          else
                            MetaGymHeroGlassCard(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: palette.success.withValues(
                                            alpha: 0.14,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: palette.success.withValues(
                                              alpha: 0.42,
                                            ),
                                          ),
                                        ),
                                        child: MetaGymSvgIcon(MetaGymIcons.actionNutrition, size: 24, fallbackIcon: Icons.eco_outlined),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _active!.title,
                                              style: TextStyle(
                                                color: palette.textPrimary,
                                                fontSize: 19,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${_active!.statusLabel} · Phiên bản ${_active!.version}',
                                              style: TextStyle(
                                                color: palette.success,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 12,
                                                fontFeatures: MetaGymTheme
                                                    .tabularFigures,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    _active!.publicationLabel,
                                    style: TextStyle(
                                      color: palette.textWarmMuted,
                                      fontSize: 12,
                                      fontFeatures: MetaGymTheme.tabularFigures,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Divider(
                                    color: palette.borderSolid.withValues(
                                      alpha: 0.7,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    _active!.content,
                                    style: TextStyle(
                                      color: palette.textPrimary,
                                      fontSize: 15,
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 24),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              children: [
                                MetaGymSvgIcon(MetaGymIcons.workoutHistory, size: 20, fallbackIcon: Icons.history_rounded),
                                const SizedBox(width: 8),
                                Text(
                                  'Lịch sử',
                                  style: TextStyle(
                                    color: palette.textPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_history.isEmpty)
                            MetaGymGlassCard(
                              padding: const EdgeInsets.all(16),
                              child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: MetaGymSvgIcon(MetaGymIcons.timeClock, fallbackIcon: Icons.history_toggle_off_rounded),
                                title: Text(
                                  'Chưa có hướng dẫn cũ.',
                                  style: TextStyle(
                                    color: palette.textSecondary,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            )
                          else
                            for (final guide in _history)
                              MetaGymGlassCard(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: Theme(
                                  data: Theme.of(
                                    context,
                                  ).copyWith(dividerColor: Colors.transparent),
                                  child: ExpansionTile(
                                    iconColor: palette.primaryText,
                                    collapsedIconColor: palette.textWarmMuted,
                                    title: Text(
                                      guide.title,
                                      style: TextStyle(
                                        color: palette.textPrimary,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                      ),
                                    ),
                                    subtitle: Text(
                                      '${guide.statusLabel} · ${guide.publicationLabel}',
                                      style: TextStyle(
                                        color: palette.textWarmMuted,
                                        fontSize: 12.5,
                                        fontFeatures:
                                            MetaGymTheme.tabularFigures,
                                      ),
                                    ),
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          16,
                                          0,
                                          16,
                                          16,
                                        ),
                                        child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            guide.content,
                                            style: TextStyle(
                                              color: palette.textSecondary,
                                              fontSize: 14,
                                              height: 1.45,
                                            ),
                                          ),
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
          ),
        ],
      ),
    );
  }
}
