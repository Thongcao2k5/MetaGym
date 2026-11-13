import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
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
  Widget build(BuildContext context) =>
      widget.structured && _service is MemberNutritionApi
      ? const MealPlansPage()
      : Scaffold(
          appBar: AppBar(title: const Text('Dinh dưỡng')),
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (_error != null) ...[
                        Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                        TextButton(
                          onPressed: _load,
                          child: const Text('Thử lại'),
                        ),
                      ] else ...[
                        Text(
                          'Hiện hành',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (_active == null)
                          const ListTile(
                            title: Text('Bạn chưa có hướng dẫn dinh dưỡng.'),
                          )
                        else ...[
                          Text(
                            _active!.title,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Text(
                            '${_active!.statusLabel} · Phiên bản ${_active!.version}',
                          ),
                          Text(_active!.publicationLabel),
                          const SizedBox(height: 8),
                          Text(_active!.content),
                        ],
                        const SizedBox(height: 24),
                        Text(
                          'Lịch sử',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (_history.isEmpty)
                          const ListTile(title: Text('Chưa có hướng dẫn cũ.')),
                        for (final guide in _history)
                          ExpansionTile(
                            title: Text(guide.title),
                            subtitle: Text(
                              '${guide.statusLabel} · ${guide.publicationLabel}',
                            ),
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(guide.content),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ],
                  ),
                ),
        );
}
