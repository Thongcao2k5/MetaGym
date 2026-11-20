import 'package:meta_gym_app/core/navigation/meta_gym_navigation.dart';
import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/features/progress/data/member_meal_service.dart';
import 'package:meta_gym_app/features/progress/domain/meal_log.dart';
import 'package:meta_gym_app/features/progress/domain/progress_time.dart';
import 'package:provider/provider.dart';

class MemberMealPage extends StatefulWidget {
  const MemberMealPage({this.service, super.key});
  final MemberMealService? service;
  @override
  State<MemberMealPage> createState() => _MemberMealPageState();
}

class _MemberMealPageState extends State<MemberMealPage> {
  MemberMealService? _service;
  List<MealLog> _meals = const [];
  int _page = 0;
  bool _hasMore = false;
  bool _loading = true;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_service != null) return;
    _service = widget.service ?? context.read<MemberMealService>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load({bool more = false}) async {
    if (more && (!_hasMore || _loading)) return;
    setState(() {
      _loading = true;
      _error = null;
      if (!more) {
        _meals = const [];
        _page = 0;
      }
    });
    try {
      final next = await _service!.getPage(_page + 1);
      if (mounted) {
        setState(() {
          _meals = [..._meals, ...next];
          _page++;
          _hasMore = next.length == 20;
        });
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không tải được nhật ký ăn.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit([MealLog? meal]) async {
    final saved = await MetaGymNavigation.pushOnce<bool>(
      context,
      MetaGymPageRoute(
        builder: (_) => _MealFormPage(service: _service!, meal: meal),
      ),
    );
    if (saved == true && mounted) await _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Nhật ký ăn')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => _edit(),
      icon: const Icon(Icons.add),
      label: const Text('Thêm bữa ăn'),
    ),
    body: RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          if (_loading && _meals.isEmpty)
            const Center(child: CircularProgressIndicator()),
          if (_error != null) ...[
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            TextButton(
              onPressed: () => _load(more: _meals.isNotEmpty),
              child: const Text('Thử lại'),
            ),
          ],
          if (!_loading && _error == null && _meals.isEmpty)
            const ListTile(title: Text('Bạn chưa có nhật ký ăn.')),
          for (final meal in _meals)
            Card(
              child: ListTile(
                title: Text(meal.mealName),
                subtitle: Text(
                  '${meal.typeLabel} · ${formatProgressTime(meal.eatenAt)}${meal.estimatedCalories == null ? '' : ' · ${meal.estimatedCalories} kcal'}',
                ),
                trailing: const Icon(Icons.edit_outlined),
                onTap: () => _edit(meal),
              ),
            ),
          if (_loading && _meals.isNotEmpty)
            const Center(child: CircularProgressIndicator()),
          if (_hasMore && !_loading)
            TextButton(
              onPressed: () => _load(more: true),
              child: const Text('Tải thêm'),
            ),
        ],
      ),
    ),
  );
}

class _MealFormPage extends StatefulWidget {
  const _MealFormPage({required this.service, this.meal});
  final MemberMealService service;
  final MealLog? meal;
  @override
  State<_MealFormPage> createState() => _MealFormPageState();
}

class _MealFormPageState extends State<_MealFormPage> {
  final _date = TextEditingController();
  final _name = TextEditingController();
  final _calories = TextEditingController();
  final _description = TextEditingController();
  String? _type;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final meal = widget.meal;
    _type = meal?.mealType;
    if (meal != null) {
      _date.text = formatProgressTime(meal.eatenAt);
      _name.text = meal.mealName;
      _calories.text = meal.estimatedCalories?.toString() ?? '';
      _description.text = meal.description ?? '';
    }
  }

  @override
  void dispose() {
    _date.dispose();
    _name.dispose();
    _calories.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final date = parseProgressTime(_date.text);
    final calories = _calories.text.trim().isEmpty
        ? null
        : int.tryParse(_calories.text.trim());
    String? validation;
    if (date == null) {
      validation = 'Nhập ngày giờ hợp lệ (dd/MM/yyyy HH:mm).';
    } else if (_name.text.trim().isEmpty || _name.text.trim().length > 150) {
      validation = 'Tên bữa ăn phải có 1–150 ký tự.';
    } else if (_calories.text.trim().isNotEmpty &&
        (calories == null || calories < 0)) {
      validation = 'Calo phải là số nguyên không âm.';
    }
    if (validation != null) {
      setState(() => _error = validation);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final payload = <String, Object?>{
      'eatenAt': date!.toUtc().toIso8601String(),
      'mealName': _name.text.trim(),
      'mealType': _type,
      'estimatedCalories': calories,
      'description': _description.text.trim().isEmpty
          ? null
          : _description.text.trim(),
    };
    try {
      if (widget.meal case final meal?) {
        await widget.service.update(meal.id, payload);
      } else {
        await widget.service.create(payload);
      }
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không lưu được bữa ăn.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.meal == null ? 'Thêm bữa ăn' : 'Sửa bữa ăn'),
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          key: const Key('meal-date'),
          controller: _date,
          keyboardType: TextInputType.datetime,
          decoration: const InputDecoration(
            labelText: 'Thời gian (dd/MM/yyyy HH:mm)',
          ),
        ),
        TextField(
          key: const Key('meal-name'),
          controller: _name,
          maxLength: 150,
          decoration: const InputDecoration(labelText: 'Tên bữa ăn'),
        ),
        DropdownButtonFormField<String>(
          initialValue: _type,
          decoration: const InputDecoration(labelText: 'Loại bữa'),
          items: const [
            DropdownMenuItem(value: 'BREAKFAST', child: Text('Bữa sáng')),
            DropdownMenuItem(value: 'LUNCH', child: Text('Bữa trưa')),
            DropdownMenuItem(value: 'DINNER', child: Text('Bữa tối')),
            DropdownMenuItem(value: 'SNACK', child: Text('Bữa phụ')),
            DropdownMenuItem(value: 'OTHER', child: Text('Khác')),
          ],
          onChanged: (value) => setState(() => _type = value),
        ),
        TextField(
          key: const Key('meal-calories'),
          controller: _calories,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Calo ước tính (tùy chọn)',
          ),
        ),
        TextField(
          controller: _description,
          maxLength: 5000,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Mô tả'),
        ),
        if (_error != null)
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Đang lưu…' : 'Lưu'),
        ),
      ],
    ),
  );
}
