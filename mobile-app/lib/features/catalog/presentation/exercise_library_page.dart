import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/features/catalog/data/catalog_service.dart';
import 'package:meta_gym_app/features/catalog/domain/catalog_models.dart';
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
    final muscles =
        _exercises.expand((item) => item.targetMuscles).toSet().toList()
          ..sort();
    final visible = _exercises
        .where(
          (item) => _muscle == null || item.targetMuscles.contains(_muscle),
        )
        .toList();
    return Scaffold(
      backgroundColor: MetaGymTheme.darkCanvas,
      appBar: AppBar(title: const Text('Thư viện bài tập')),
      body: RefreshIndicator(
        color: MetaGymTheme.primary,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _searchExercises(),
              decoration: InputDecoration(
                labelText: 'Tìm bài tập',
                suffixIcon: IconButton(
                  tooltip: 'Tìm bài tập',
                  onPressed: _searchExercises,
                  icon: const Icon(Icons.search_rounded),
                ),
              ),
            ),
            if (muscles.isNotEmpty) ...[
              const SizedBox(height: 14),
              SizedBox(
                height: 42,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _filterChip('Tất cả', null),
                    for (final muscle in muscles) _filterChip(muscle, muscle),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (_loading && _exercises.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(
                  child: CircularProgressIndicator(color: MetaGymTheme.primary),
                ),
              )
            else if (_error != null) ...[
              Text(
                _error!,
                style: const TextStyle(color: MetaGymTheme.textSecondary),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Thử lại'),
                ),
              ),
            ] else if (visible.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 60),
                child: Center(child: Text('Chưa có bài tập phù hợp.')),
              )
            else
              for (final exercise in visible) ...[
                _ExerciseItem(item: exercise),
                const SizedBox(height: 10),
              ],
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String title, String? value) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      label: Text(title),
      selected: _muscle == value,
      onSelected: (_) => setState(() => _muscle = value),
      selectedColor: MetaGymTheme.elevatedSurface,
      side: BorderSide(
        color: _muscle == value
            ? MetaGymTheme.primary
            : MetaGymTheme.cardBorder,
      ),
      labelStyle: TextStyle(
        color: _muscle == value
            ? MetaGymTheme.textPrimary
            : MetaGymTheme.textSecondary,
      ),
    ),
  );
}

class _ExerciseItem extends StatelessWidget {
  const _ExerciseItem({required this.item});
  final CatalogItem item;

  @override
  Widget build(BuildContext context) => Material(
    color: MetaGymTheme.cardSurface,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => _ExerciseDetailPage(item: item),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: MetaGymTheme.cardBorder),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.fitness_center_outlined,
              color: MetaGymTheme.reflectionBlue,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (item.targetMuscles.isNotEmpty || item.category != null)
                    Text(
                      item.targetMuscles.isNotEmpty
                          ? item.targetMuscles.join(' · ')
                          : item.category!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: MetaGymTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: MetaGymTheme.textSecondary,
            ),
          ],
        ),
      ),
    ),
  );
}

class _ExerciseDetailPage extends StatelessWidget {
  const _ExerciseDetailPage({required this.item});
  final CatalogItem item;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: MetaGymTheme.darkCanvas,
    appBar: AppBar(title: Text(item.name)),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (item.targetMuscles.isNotEmpty)
          Text(
            'Nhóm cơ: ${item.targetMuscles.join(', ')}',
            style: const TextStyle(color: MetaGymTheme.textSecondary),
          ),
        if (item.description case final description?) ...[
          const SizedBox(height: 16),
          Text(description),
        ],
        if (item.instructions case final instructions?) ...[
          const SizedBox(height: 20),
          const Text(
            'Cách thực hiện',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(instructions),
        ],
        if (item.usageSteps.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text(
            'Các bước',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < item.usageSteps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('${i + 1}. ${item.usageSteps[i]}'),
            ),
        ],
        if (item.safetyNotes case final notes?) ...[
          const SizedBox(height: 20),
          const Text(
            'Lưu ý an toàn',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(notes),
        ],
        if (item.description?.isNotEmpty != true &&
            item.instructions?.isNotEmpty != true &&
            item.usageSteps.isEmpty &&
            item.safetyNotes?.isNotEmpty != true) ...[
          const SizedBox(height: 16),
          const Text(
            'Hướng dẫn cho bài tập này đang được cập nhật.',
            style: TextStyle(color: MetaGymTheme.textSecondary),
          ),
        ],
      ],
    ),
  );
}
