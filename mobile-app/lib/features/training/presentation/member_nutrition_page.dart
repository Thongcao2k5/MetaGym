import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/features/training/data/member_nutrition_service.dart';
import 'package:meta_gym_app/features/training/domain/nutrition_models.dart';
import 'package:provider/provider.dart';

import 'meal_plans_page.dart';

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
      return const MealPlansPage();
    }
    final canPop = Navigator.of(context).canPop();
    return Scaffold(
      backgroundColor: MetaGymTheme.paletteOf(context).canvas,
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
        title: const Text(
          'Dinh dưỡng',
          style: TextStyle(
            color: Color(0xFFF7F9FC),
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: const Color(0xFFF7F9FC),
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
                    backgroundColor: const Color(0xFF282320),
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
                              color: const Color(0xFF24161A),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFF642B32),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.error_outline_rounded,
                                  color: MetaGymTheme.dangerCoral,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _error!,
                                    style: const TextStyle(
                                      color: Color(0xFFFFB2B6),
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
                              icon: const Icon(Icons.refresh_rounded, size: 18),
                              label: const Text(
                                'Thử lại',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        ] else ...[
                          const Padding(
                            padding: EdgeInsets.only(bottom: 12, top: 4),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.restaurant_menu_rounded,
                                  color: MetaGymTheme.brandOrange,
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Hiện hành',
                                  style: TextStyle(
                                    color: Color(0xFFF7F9FC),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_active == null)
                            const MetaGymGlassCard(
                              padding: EdgeInsets.all(16),
                              child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(
                                  Icons.no_meals_outlined,
                                  color: Color(0xFFC8C2BC),
                                ),
                                title: Text(
                                  'Bạn chưa có hướng dẫn dinh dưỡng.',
                                  style: TextStyle(
                                    color: Color(0xFFE4DAD1),
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
                                          color: MetaGymTheme.success
                                              .withValues(alpha: 0.18),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: MetaGymTheme.success
                                                .withValues(alpha: 0.42),
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.eco_outlined,
                                          color: MetaGymTheme.success,
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _active!.title,
                                              style: const TextStyle(
                                                color: Color(0xFFF7F9FC),
                                                fontSize: 19,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${_active!.statusLabel} · Phiên bản ${_active!.version}',
                                              style: const TextStyle(
                                                color: MetaGymTheme.success,
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
                                    style: const TextStyle(
                                      color: Color(0xFFC8C2BC),
                                      fontSize: 12,
                                      fontFeatures: MetaGymTheme.tabularFigures,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  const Divider(color: Color(0x40A79D92)),
                                  const SizedBox(height: 10),
                                  Text(
                                    _active!.content,
                                    style: const TextStyle(
                                      color: Color(0xFFF7F9FC),
                                      fontSize: 15,
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 24),
                          const Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.history_rounded,
                                  color: MetaGymTheme.reflectionBlue,
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Lịch sử',
                                  style: TextStyle(
                                    color: Color(0xFFF7F9FC),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_history.isEmpty)
                            const MetaGymGlassCard(
                              padding: EdgeInsets.all(16),
                              child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(
                                  Icons.history_toggle_off_rounded,
                                  color: Color(0xFFC8C2BC),
                                ),
                                title: Text(
                                  'Chưa có hướng dẫn cũ.',
                                  style: TextStyle(
                                    color: Color(0xFFE4DAD1),
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
                                    iconColor: MetaGymTheme.brandOrange,
                                    collapsedIconColor: const Color(0xFFC8C2BC),
                                    title: Text(
                                      guide.title,
                                      style: const TextStyle(
                                        color: Color(0xFFF7F9FC),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                      ),
                                    ),
                                    subtitle: Text(
                                      '${guide.statusLabel} · ${guide.publicationLabel}',
                                      style: const TextStyle(
                                        color: Color(0xFFC8C2BC),
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
                                            style: const TextStyle(
                                              color: Color(0xFFE4DAD1),
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
