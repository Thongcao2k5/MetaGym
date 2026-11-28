import 'package:meta_gym_app/core/widgets/meta_gym_tap.dart';
import 'package:meta_gym_app/core/navigation/meta_gym_navigation.dart';
import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/features/catalog/data/catalog_service.dart';
import 'package:meta_gym_app/features/catalog/domain/catalog_models.dart';
import 'package:meta_gym_app/features/catalog/presentation/equipment_detail_page.dart';
import 'package:meta_gym_app/features/catalog/presentation/exercise_video_player.dart';
import 'package:provider/provider.dart';
import 'package:meta_gym_app/core/theme/meta_gym_icons.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_svg_icon.dart';

/// Maps a catalog exercise [CatalogItem] to the closest duotone SVG asset.
String exerciseIconAssetFor(CatalogItem item) {
  final mapped7 = catalog7GroupIconFor(item);
  if (mapped7 != null) return mapped7;

  final normalized = '${item.name} ${item.category ?? ''}'.toLowerCase();

  if (normalized.contains('reverse machine fly') ||
      normalized.contains('reverse fly') ||
      normalized.contains('mở vai sau')) {
    return MetaGymIcons.equipVideoReverseMachineFly;
  }
  if (normalized.contains('pec deck') || normalized.contains('ép ngực')) {
    return MetaGymIcons.equipVideoPecDeckFly;
  }
  if (normalized.contains('seated leg curl') ||
      normalized.contains('cuốn đùi sau')) {
    return MetaGymIcons.equipVideoSeatedLegCurl;
  }
  if (normalized.contains('assisted pull') ||
      normalized.contains('kéo xà trợ lực')) {
    return MetaGymIcons.equipVideoAssistedPullUp;
  }

  if (normalized.contains('barbell') ||
      normalized.contains('tạ đòn') ||
      normalized.contains('squat') ||
      normalized.contains('bench press')) {
    return MetaGymIcons.equipBarbell;
  }
  if (normalized.contains('dumbbell') || normalized.contains('tạ đơn')) {
    return MetaGymIcons.equipDumbbell;
  }
  if (normalized.contains('cable') || normalized.contains('cáp')) {
    return MetaGymIcons.equipCable;
  }
  if (normalized.contains('pulldown') ||
      normalized.contains('kéo xô') ||
      normalized.contains('machine') ||
      normalized.contains('máy')) {
    return MetaGymIcons.equipMachine;
  }
  if (normalized.contains('plank') || normalized.contains('bodyweight')) {
    return MetaGymIcons.equipBodyweight;
  }
  return MetaGymIcons.equipBodyweight;
}

class ExerciseLibraryPage extends StatefulWidget {
  const ExerciseLibraryPage({this.service, super.key});

  final CatalogService? service;

  @override
  State<ExerciseLibraryPage> createState() => _ExerciseLibraryPageState();
}

class _ExerciseLibraryPageState extends State<ExerciseLibraryPage> {
  final _search = TextEditingController();
  CatalogService? _service;
  List<CatalogItem> _exercises = const [];
  String? _muscle;
  String? _error;
  bool _loading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_service != null) return;
    _service = widget.service ?? context.read<CatalogService>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final exercises = await _service!.getExercises(
        search: _search.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _exercises = exercises
            .where((item) => item.status == 'ACTIVE')
            .toList();
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không tải được bài tập.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _searchExercises() {
    setState(() => _muscle = null);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final palette = MetaGymTheme.paletteOf(context);
    final colors = MetaGymColors.of(context);
    final muscles =
        _exercises.expand((item) => item.targetMuscles).toSet().toList()
          ..sort();
    final visible = _exercises
        .where(
          (item) => _muscle == null || item.targetMuscles.contains(_muscle),
        )
        .toList();
    return Scaffold(
      backgroundColor: palette.canvas,
      extendBodyBehindAppBar: true,
      appBar: _exerciseAppBar(context, 'Thư viện bài tập'),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const MetaGymBackground(),
          RefreshIndicator(
            color: MetaGymTheme.primary,
            backgroundColor: colors.surface,
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                16,
                MediaQuery.paddingOf(context).top + kToolbarHeight + 12,
                16,
                MediaQuery.paddingOf(context).bottom + 24,
              ),
              children: [
                TextField(
                  controller: _search,
                  cursorColor: MetaGymTheme.brandOrange,
                  style: TextStyle(color: palette.textPrimary),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _searchExercises(),
                  decoration: InputDecoration(
                    hintText: 'Tìm tên bài tập',
                    hintStyle: TextStyle(color: palette.textSecondary),
                    prefixIcon: MetaGymSvgIcon(MetaGymIcons.commonSearch, fallbackIcon: Icons.search_rounded),
                    filled: true,
                    fillColor: colors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        MetaGymTheme.radiusInput,
                      ),
                      borderSide: BorderSide(color: palette.borderSolid),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        MetaGymTheme.radiusInput,
                      ),
                      borderSide: BorderSide(color: palette.borderSolid),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        MetaGymTheme.radiusInput,
                      ),
                      borderSide: const BorderSide(
                        color: MetaGymTheme.brandOrange,
                        width: 1.5,
                      ),
                    ),
                    suffixIcon: IconButton(
                      tooltip: 'Tìm bài tập',
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      onPressed: _searchExercises,
                      icon: MetaGymSvgIcon(MetaGymIcons.commonChevronRight, fallbackIcon: Icons.arrow_forward_rounded),
                    ),
                  ),
                ),
                if (muscles.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _filterChip('Tất cả', null),
                          for (final muscle in muscles)
                            _filterChip(muscle, muscle),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                if (!_loading && _error == null) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Bài tập',
                          style: TextStyle(
                            color: palette.textPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        '${visible.length} bài',
                        style: TextStyle(
                          color: palette.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
                if (_loading && _exercises.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 80),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: MetaGymTheme.primary,
                      ),
                    ),
                  )
                else if (_error != null) ...[
                  MetaGymGlassCard(
                    solid: true,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _error!,
                          style: TextStyle(color: palette.textPrimary),
                        ),
                        TextButton.icon(
                          onPressed: _load,
                          style: TextButton.styleFrom(
                            foregroundColor: palette.primaryText,
                            minimumSize: const Size(48, 48),
                          ),
                          icon: const MetaGymSvgIcon(MetaGymIcons.commonRefresh, fallbackIcon: Icons.refresh_rounded),
                          label: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  ),
                ] else if (visible.isEmpty)
                  MetaGymGlassCard(
                    solid: true,
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'Chưa có bài tập phù hợp.',
                      style: TextStyle(color: palette.textPrimary),
                    ),
                  )
                else
                  for (final exercise in visible) ...[
                    _ExerciseItem(item: exercise),
                    const SizedBox(height: 10),
                  ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String title, String? value) {
    final palette = MetaGymTheme.paletteOf(context);
    final colors = MetaGymColors.of(context);
    final isLight = MetaGymTheme.isLightPalette(context);
    final selected = _muscle == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(title),
        selected: selected,
        onSelected: (_) => setState(() => _muscle = value),
        visualDensity: VisualDensity.standard,
        materialTapTargetSize: MaterialTapTargetSize.padded,
        selectedColor: isLight ? palette.chipActiveBg : const Color(0xFF493025),
        backgroundColor: colors.surface,
        showCheckmark: false,
        side: BorderSide(
          color: selected ? MetaGymTheme.primary : palette.borderSolid,
        ),
        labelStyle: TextStyle(
          color: selected ? palette.chipActiveText : palette.textSecondary,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
  }
}

class _ExerciseItem extends StatelessWidget {
  const _ExerciseItem({required this.item});
  final CatalogItem item;

  @override
  Widget build(BuildContext context) {
    final palette = MetaGymTheme.paletteOf(context);
    final hasVideo = item.videoUrl?.trim().isNotEmpty == true;
    return MetaGymGlassCard(
      solid: false,
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: MetaGymTap(
          borderRadius: BorderRadius.circular(MetaGymTheme.radiusCard),
          onTap: () => MetaGymNavigation.pushOnce(
            context,
            MetaGymPageRoute<void>(
              builder: (_) => ExerciseDetailPage(item: item),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: palette.chipActiveBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: MetaGymTheme.primary.withValues(alpha: 0.36),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: MetaGymSvgIcon(
                    exerciseIconAssetFor(item),
                    size: 30,
                    fallbackIcon: Icons.sports_gymnastics_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: palette.textPrimary,
                        ),
                      ),
                      if (item.targetMuscles.isNotEmpty ||
                          item.category?.trim().isNotEmpty == true) ...[
                        const SizedBox(height: 3),
                        Text(
                          item.targetMuscles.isNotEmpty
                              ? item.targetMuscles.join(' · ')
                              : item.category!.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: palette.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (hasVideo) ...[
                  const SizedBox(width: 8),
                  MetaGymSvgIcon(
                    MetaGymIcons.exerciseVideoPlay,
                    size: 19,
                    fallbackIcon: Icons.play_circle_outline_rounded,
                  ),
                ],
                const SizedBox(width: 4),
                MetaGymSvgIcon(
                  MetaGymIcons.commonChevronRight,
                  size: 18,
                  fallbackIcon: Icons.chevron_right_rounded,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ExerciseDetailPage extends StatelessWidget {
  const ExerciseDetailPage({required this.item, super.key});
  final CatalogItem item;

  @override
  Widget build(BuildContext context) {
    final palette = MetaGymTheme.paletteOf(context);
    final hasVideo = item.videoUrl?.trim().isNotEmpty == true;
    final hasCategory = item.category?.trim().isNotEmpty == true;
    final hasDescription = item.description?.trim().isNotEmpty == true;
    final hasInstructions = item.instructions?.trim().isNotEmpty == true;
    final hasSafetyNotes = item.safetyNotes?.trim().isNotEmpty == true;
    final hasGuidance =
        hasDescription ||
        hasInstructions ||
        item.usageSteps.isNotEmpty ||
        hasSafetyNotes;

    return Scaffold(
      backgroundColor: palette.canvas,
      extendBodyBehindAppBar: true,
      appBar: _exerciseAppBar(context, item.name, isDetail: true),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const MetaGymBackground(),
          ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              MetaGymTheme.pageGutter,
              MediaQuery.paddingOf(context).top + 76 + 12,
              MetaGymTheme.pageGutter,
              MediaQuery.paddingOf(context).bottom + 24,
            ),
            children: [
              if (hasVideo) ...[
                ExerciseVideoPlayer(
                  url: item.videoUrl!.trim(),
                  loop: true,
                  autoPlay: true,
                ),
                const SizedBox(height: 14),
              ],
              _buildHeroSummaryCard(
                palette,
                hasVideo: hasVideo,
                hasCategory: hasCategory,
                hasDescription: hasDescription,
                hasInstructions: hasInstructions,
              ),
              if (item.usageSteps.isNotEmpty) ...[
                const SizedBox(height: 14),
                _ExerciseDetailCard(
                  child: _DetailSection(
                    title: 'Các bước',
                    svgAsset: MetaGymIcons.exerciseStepGuide,
                    icon: Icons.format_list_numbered_rounded,
                    body: Column(
                      children: [
                        for (var i = 0; i < item.usageSteps.length; i++)
                          Container(
                            margin: EdgeInsets.only(
                              bottom: i < item.usageSteps.length - 1 ? 8 : 0,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 11,
                            ),
                            decoration: BoxDecoration(
                              color: palette.metricPanelBg,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: palette.metricPanelBorder,
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: palette.chipActiveBg,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: MetaGymTheme.brandOrange
                                          .withValues(alpha: 0.35),
                                    ),
                                  ),
                                  child: Text(
                                    '${i + 1}.',
                                    style: TextStyle(
                                      color: palette.primaryText,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      fontFeatures: MetaGymTheme.tabularFigures,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    item.usageSteps[i],
                                    style: TextStyle(
                                      color: palette.textPrimary,
                                      fontSize: 14,
                                      height: 1.5,
                                    ),
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
              if (hasSafetyNotes) ...[
                const SizedBox(height: 14),
                MetaGymGlassCard(
                  solid: false,
                  borderColor: palette.warning.withValues(alpha: 0.4),
                  padding: const EdgeInsets.all(16),
                  child: _DetailSection(
                    title: 'Lưu ý an toàn',
                    svgAsset: MetaGymIcons.exerciseSafetyShield,
                    icon: Icons.shield_outlined,
                    body: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: palette.warning.withValues(alpha: 0.09),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: palette.warning.withValues(alpha: 0.28),
                        ),
                      ),
                      child: Text(
                        item.safetyNotes!.trim(),
                        style: TextStyle(
                          color: palette.textSecondary,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              if (!hasGuidance) ...[
                const SizedBox(height: 14),
                _ExerciseDetailCard(
                  child: Text(
                    'Hướng dẫn cho bài tập này đang được cập nhật.',
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSummaryCard(
    MetaGymPalette palette, {
    required bool hasVideo,
    required bool hasCategory,
    required bool hasDescription,
    required bool hasInstructions,
  }) {
    return MetaGymHeroGlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: palette.chipActiveBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: MetaGymTheme.primary.withValues(alpha: 0.34),
                  ),
                ),
                alignment: Alignment.center,
                child: MetaGymSvgIcon(
                  exerciseIconAssetFor(item),
                  size: 36,
                  fallbackIcon: Icons.sports_gymnastics_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (hasCategory) ...[
                      const SizedBox(height: 3),
                      Text(
                        item.category!.trim(),
                        style: TextStyle(
                          color: palette.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (hasVideo) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: palette.chipActiveBg,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: MetaGymTheme.primary.withValues(alpha: 0.38),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const MetaGymSvgIcon(
                              MetaGymIcons.exerciseVideoPlay,
                              size: 14,
                              fallbackIcon: Icons.play_circle_outline_rounded,
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                'Có video minh họa',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: palette.primaryText,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
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
          if (item.targetMuscles.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var i = 0; i < item.targetMuscles.length; i++)
                  _ExerciseMusclePill(
                    label: item.targetMuscles[i],
                    highlighted: i == 0,
                  ),
              ],
            ),
          ],
          if (hasDescription || hasInstructions) ...[
            const SizedBox(height: 14),
            Divider(height: 1, color: palette.metricPanelBorder),
            const SizedBox(height: 12),
            _DetailSection(
              title: 'Cách thực hiện',
              icon: Icons.menu_book_outlined,
              body: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasDescription) ...[
                    Text(
                      item.description!.trim(),
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                    if (hasInstructions) const SizedBox(height: 10),
                  ],
                  if (hasInstructions)
                    Text(
                      item.instructions!.trim(),
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ExerciseMusclePill extends StatelessWidget {
  const _ExerciseMusclePill({required this.label, required this.highlighted});

  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final palette = MetaGymTheme.paletteOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: highlighted ? palette.chipActiveBg : palette.metricPanelBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: highlighted
              ? MetaGymTheme.brandOrange.withValues(alpha: 0.45)
              : palette.metricPanelBorder,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: highlighted ? palette.primaryText : palette.textSecondary,
          fontSize: 12,
          fontWeight: highlighted ? FontWeight.w700 : FontWeight.w600,
        ),
      ),
    );
  }
}

class _ExerciseDetailCard extends StatelessWidget {
  const _ExerciseDetailCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => MetaGymGlassCard(
    solid: false,
    padding: const EdgeInsets.all(16),
    child: child,
  );
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({
    required this.title,
    required this.icon,
    required this.body,
    this.svgAsset,
  });

  final String title;
  final IconData icon;
  final String? svgAsset;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    final palette = MetaGymTheme.paletteOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (svgAsset != null)
              MetaGymSvgIcon(svgAsset!, size: 20, fallbackIcon: icon)
            else
              MetaGymResolvedIcon(
                icon,
                size: 20,
                fallbackColor: palette.primaryText,
              ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        body,
      ],
    );
  }
}

AppBar _exerciseAppBar(
  BuildContext context,
  String title, {
  bool isDetail = false,
}) {
  final palette = MetaGymTheme.paletteOf(context);
  return AppBar(
    automaticallyImplyLeading: false,
    toolbarHeight: isDetail ? 76 : kToolbarHeight,
    leadingWidth: 72,
    leading: Navigator.of(context).canPop()
        ? Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: MetaGymCircleIconButton(
                icon: Icons.arrow_back_rounded,
                svgAsset: MetaGymIcons.commonBack,
                tooltip: 'Quay lại',
                onTap: () => Navigator.of(context).maybePop(),
              ),
            ),
          )
        : null,
    title: Text(
      title,
      maxLines: isDetail ? 2 : 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: palette.textPrimary,
        fontSize: isDetail ? 18 : 20,
        fontWeight: FontWeight.w700,
      ),
    ),
    titleSpacing: Navigator.of(context).canPop() ? 8 : 16,
    backgroundColor: Colors.transparent,
    foregroundColor: palette.textPrimary,
    surfaceTintColor: Colors.transparent,
  );
}
