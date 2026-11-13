import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/features/coaching/data/coach_v2_api.dart';
import 'package:provider/provider.dart';

const _meals = {'BREAKFAST': 'Sáng', 'LUNCH': 'Trưa', 'DINNER': 'Tối'};

String _day(int day) => day == 7 ? 'Chủ nhật' : 'Thứ ${day + 1}';

class MealPlansPage extends StatefulWidget {
  const MealPlansPage({this.memberId, this.editable = false, super.key});

  final String? memberId;
  final bool editable;

  @override
  State<MealPlansPage> createState() => _MealPlansPageState();
}

class _MealPlansPageState extends State<MealPlansPage> {
  late final _api = CoachV2Api(context.read<ApiClient>());
  final _title = TextEditingController();
  List<CoachRecord> _plans = [];
  List<CoachRecord> _foods = [];
  List<CoachRecord> _items = [];
  String? _error;
  bool _busy = false;
  bool _loaded = false;

  String get _path => '/coach/meal-plans/${widget.memberId}';

  @override
  void initState() {
    super.initState();
    _run(_load);
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() operation) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await operation();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không xử lý được thực đơn.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _load() async {
    final memberId = widget.memberId;
    final plans = memberId == null
        ? await _api.list('/meal-plans/me')
        : [await _api.get(_path)];
    final foods = widget.editable
        ? await _api.list('/nutrition-foods')
        : <CoachRecord>[];
    if (!mounted) return;
    setState(() {
      _plans = plans.where((plan) => plan['id'] != null).toList();
      _foods = foods;
      if (widget.editable) {
        _title.text = plans.first['title'] as String? ?? '';
        _items = (plans.first['items'] as List).cast<CoachRecord>().toList();
      }
      _loaded = true;
    });
  }

  Future<void> _add() async {
    var day = 1;
    var meal = 'BREAKFAST';
    CoachRecord? food;
    int? grams;
    final item = await showDialog<CoachRecord>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Thêm món'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: day,
                  decoration: const InputDecoration(labelText: 'Ngày'),
                  items: [
                    for (var i = 1; i <= 7; i++)
                      DropdownMenuItem(value: i, child: Text(_day(i))),
                  ],
                  onChanged: (value) => update(() => day = value!),
                ),
                DropdownButtonFormField<String>(
                  initialValue: meal,
                  decoration: const InputDecoration(labelText: 'Bữa'),
                  items: [
                    for (final entry in _meals.entries)
                      DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                  ],
                  onChanged: (value) => update(() => meal = value!),
                ),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Thực phẩm'),
                  items: [
                    for (final entry in _foods)
                      DropdownMenuItem(
                        value: entry['id'] as String,
                        child: Text(
                          entry['name'] as String,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) => update(
                    () => food = _foods.firstWhere((row) => row['id'] == value),
                  ),
                ),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Khối lượng (g)',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) =>
                      update(() => grams = int.tryParse(value)),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog),
              child: const Text('Đóng'),
            ),
            FilledButton(
              onPressed:
                  food == null || grams == null || grams! < 1 || grams! > 10000
                  ? null
                  : () => Navigator.pop(dialog, <String, dynamic>{
                      'day': day,
                      'meal': meal,
                      'foodId': food!['id'],
                      'foodName': food!['name'],
                      'kcalPer100g': food!['kcalPer100g'],
                      'grams': grams,
                    }),
              child: const Text('Thêm'),
            ),
          ],
        ),
      ),
    );
    if (mounted && item != null) setState(() => _items.add(item));
  }

  Future<void> _save() => _run(() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Nhập tên thực đơn.');
      return;
    }
    await _api.put(_path, {
      'title': title,
      'items': [
        for (final item in _items)
          {
            for (final key in ['day', 'meal', 'foodId', 'grams'])
              key: item[key],
          },
      ],
    });
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Đã lưu thực đơn.')));
    }
  });

  String _details(CoachRecord item) {
    final calories =
        (item['grams'] as num) * (item['kcalPer100g'] as num) / 100;
    return '${item['grams']} g · ${calories.toStringAsFixed(0)} kcal';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Thực đơn'),
      actions: [
        IconButton(
          tooltip: 'Tải lại',
          onPressed: _busy ? null : () => _run(_load),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_busy) const LinearProgressIndicator(),
        if (_error != null)
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        if (_loaded && widget.editable) ...[
          TextField(
            controller: _title,
            enabled: !_busy,
            maxLength: 150,
            decoration: const InputDecoration(labelText: 'Tên thực đơn'),
          ),
          if (_foods.isEmpty)
            const Text('Danh mục chưa có thực phẩm đang sử dụng.'),
          for (final (index, item) in _items.indexed)
            ListTile(
              title: Text(item['foodName'] as String),
              subtitle: Text(
                '${_day(item['day'] as int)} · ${_meals[item['meal']]} · ${_details(item)}',
              ),
              trailing: IconButton(
                tooltip: 'Bỏ món',
                icon: const Icon(Icons.delete_outline),
                onPressed: _busy
                    ? null
                    : () => setState(() => _items.removeAt(index)),
              ),
            ),
          OutlinedButton(
            onPressed: _busy || _foods.isEmpty || _items.length >= 210
                ? null
                : _add,
            child: const Text('Thêm món'),
          ),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: const Text('Lưu thực đơn'),
          ),
        ] else if (_loaded) ...[
          if (_plans.isEmpty) const Text('Chưa có thực đơn từ Coach.'),
          for (final plan in _plans)
            ExpansionTile(
              initiallyExpanded: plan['status'] == 'ACTIVE',
              title: Text(plan['title'] as String),
              subtitle: Text(
                plan['status'] == 'ACTIVE' ? 'Hiện tại' : 'Lịch sử',
              ),
              children: _planContent(plan),
            ),
        ],
      ],
    ),
  );

  List<Widget> _planContent(CoachRecord plan) {
    final items = (plan['items'] as List).cast<CoachRecord>();
    if (items.isEmpty) {
      return [
        ListTile(title: Text(plan['content'] as String? ?? 'Chưa có món')),
      ];
    }
    return [
      for (var day = 1; day <= 7; day++)
        ExpansionTile(
          title: Text(_day(day)),
          children: [
            for (final meal in _meals.entries) ...[
              ListTile(title: Text(meal.value)),
              if (!items.any(
                (item) => item['day'] == day && item['meal'] == meal.key,
              ))
                const ListTile(subtitle: Text('Chưa có món')),
              for (final item in items.where(
                (item) => item['day'] == day && item['meal'] == meal.key,
              ))
                ListTile(
                  title: Text(item['foodName'] as String),
                  subtitle: Text(_details(item)),
                ),
            ],
          ],
        ),
    ];
  }
}
