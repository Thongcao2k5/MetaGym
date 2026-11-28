import 'package:meta_gym_app/core/widgets/meta_gym_tap.dart';
import 'package:meta_gym_app/core/navigation/meta_gym_navigation.dart';
import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/features/catalog/data/catalog_service.dart';
import 'package:meta_gym_app/features/catalog/domain/catalog_models.dart';
import 'package:meta_gym_app/features/catalog/presentation/exercise_video_player.dart';
import 'package:provider/provider.dart';

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
            backgroundColor: palette.surfaceSolid,
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
                    hintStyle: TextStyle(
                      color: palette.textSecondary,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: MetaGymTheme.brandOrange,
                    ),
                    filled: true,
                    fillColor: palette.surfaceSolid,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        MetaGymTheme.radiusInput,
                      ),
                      borderSide: BorderSide(
                        color: palette.borderSolid,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        MetaGymTheme.radiusInput,
                      ),
                      borderSide: BorderSide(
                        color: palette.borderSolid,
                      ),
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
                      icon: Icon(
                        Icons.arrow_forward_rounded,
                        color: palette.textPrimary,
                      ),
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
                          _filterChip('Tất cả', null, palette),
                          for (final muscle in muscles)
                            _filterChip(muscle, muscle, palette),
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
                          style: TextStyle(
                            color: palette.textPrimary,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _load,
                          style: TextButton.styleFrom(
                            foregroundColor: palette.primaryText,
                            minimumSize: const Size(48, 48),
                          ),
                          icon: const Icon(Icons.refresh_rounded),
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

  Widget _filterChip(String title, String? value, MetaGymPalette palette) =>
      Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(title),
          selected: _muscle == value,
          onSelected: (_) => setState(() => _muscle = value),
          visualDensity: VisualDensity.standard,
          materialTapTargetSize: MaterialTapTargetSize.padded,
          selectedColor: palette.chipActiveBg,
          backgroundColor: palette.surfaceSolid,
          showCheckmark: false,
          side: BorderSide(
            color: _muscle == value
                ? MetaGymTheme.primary
                : palette.borderSolid,
          ),
          labelStyle: TextStyle(
            color: _muscle == value
                ? palette.chipActiveText
                : palette.textWarmMuted,
            fontWeight: _muscle == value ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      );
}

class _ExerciseItem extends StatelessWidget {
  const _ExerciseItem({required this.item});
  final CatalogItem item;

  @override
  Widget build(BuildContext context) {
    final palette = MetaGymTheme.paletteOf(context);
    return MetaGymGlassCard(
      solid: true,
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
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0x33FF5E36),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0x66FF5E36)),
                  ),
                  child: const Icon(
                    Icons.sports_gymnastics_rounded,
                    color: MetaGymTheme.brandOrange,
                    size: 24,
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
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: palette.textPrimary,
                        ),
                      ),
                      if (item.targetMuscles.isNotEmpty ||
                          item.category != null)
                        Text(
                          item.targetMuscles.isNotEmpty
                              ? item.targetMuscles.join(' · ')
                              : item.category!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: palette.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: palette.textSecondary,
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
    final hasGuidance =
        item.description?.isNotEmpty == true ||
        item.instructions?.isNotEmpty == true ||
        item.usageSteps.isNotEmpty ||
        item.safetyNotes?.isNotEmpty == true;
    return Scaffold(
      backgroundColor: palette.canvas,
      extendBodyBehindAppBar: true,
      appBar: _exerciseAppBar(context, item.name, isDetail: true),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const MetaGymBackground(),
          ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              MediaQuery.paddingOf(context).top + 76 + 12,
              16,
              MediaQuery.paddingOf(context).bottom + 24,
            ),
            children: [
              if (item.videoUrl?.trim().isNotEmpty == true) ...[
                ExerciseVideoPlayer(url: item.videoUrl!.trim()),
                const SizedBox(height: 14),
              ],
              if (item.instructions?.isNotEmpty == true ||
                  item.description?.isNotEmpty == true) ...[
                MetaGymHeroGlassCard(
                  child: _DetailSection(
                    title: 'Cách thực hiện',
                    icon: Icons.menu_book_outlined,
                    body: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (item.targetMuscles.isNotEmpty ||
                            item.category != null) ...[
                          Text(
                            item.targetMuscles.isNotEmpty
                                ? item.targetMuscles.join(' · ')
                                : item.category!,
                            style: TextStyle(
                              color: palette.primaryText,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        if (item.description?.isNotEmpty == true) ...[
                          Text(
                            item.description!,
                            style: TextStyle(
                              color: palette.textWarmMuted,
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                          if (item.instructions?.isNotEmpty == true)
                            const SizedBox(height: 10),
                        ],
                        if (item.instructions?.isNotEmpty == true)
                          Text(
                            item.instructions!,
                            style: TextStyle(
                              color: palette.textWarmMuted,
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
              if (item.usageSteps.isNotEmpty) ...[
                const SizedBox(height: 14),
                _ExerciseDetailCard(
                  child: _DetailSection(
                    title: 'Các bước',
                    icon: Icons.format_list_numbered_rounded,
                    body: Column(
                      children: [
                        for (var i = 0; i < item.usageSteps.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${i + 1}.',
                                  style: TextStyle(
                                    color: palette.primaryText,
                                    fontWeight: FontWeight.w700,
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
              if (item.safetyNotes?.isNotEmpty == true) ...[
                const SizedBox(height: 14),
                _ExerciseDetailCard(
                  child: _DetailSection(
                    title: 'Lưu ý an toàn',
                    icon: Icons.shield_outlined,
                    body: Text(
                      item.safetyNotes!,
                      style: TextStyle(
                        color: palette.textWarmMuted,
                        fontSize: 14,
                        height: 1.5,
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
                    style: TextStyle(color: palette.textWarmMuted),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ExerciseDetailCard extends StatelessWidget {
  const _ExerciseDetailCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => MetaGymGlassCard(
    solid: true,
    padding: const EdgeInsets.all(16),
    child: child,
  );
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({
    required this.title,
    required this.icon,
    required this.body,
  });

  final String title;
  final IconData icon;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    final palette = MetaGymTheme.paletteOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: palette.primaryText, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
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
