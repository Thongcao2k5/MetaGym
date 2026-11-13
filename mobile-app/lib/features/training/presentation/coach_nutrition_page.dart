import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/features/coaching/domain/coach_member_models.dart';
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
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Dinh dưỡng của Coach')),
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
                  TextButton(onPressed: _load, child: const Text('Thử lại')),
                ] else ...[
                  Text(
                    'Chọn hội viên',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (_members.isEmpty)
                    const ListTile(
                      title: Text('Chưa có hội viên đang phụ trách.'),
                    ),
                  for (final member in _members)
                    ListTile(
                      title: Text(member.memberFullName),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        await Navigator.of(context).push<void>(
                          MaterialPageRoute(
                            builder: (_) => widget.structured
                                ? MealPlansPage(
                                    memberId: member.memberId,
                                    editable: member.status == 'ACTIVE',
                                  )
                                : _MemberGuidesPage(
                                    member: member,
                                    service: _service!,
                                  ),
                          ),
                        );
                        if (mounted) await _load();
                      },
                    ),
                ],
              ],
            ),
          ),
  );
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

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Dinh dưỡng · ${widget.member.memberFullName}')),
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
                  TextButton(onPressed: _load, child: const Text('Thử lại')),
                ] else ...[
                  FilledButton(
                    onPressed: () => _open(null),
                    child: const Text('Tạo hướng dẫn'),
                  ),
                  if (_guides.isEmpty)
                    const ListTile(title: Text('Chưa có hướng dẫn nào.')),
                  for (final guide in _guides)
                    ListTile(
                      title: Text(guide.title),
                      subtitle: Text(
                        '${guide.statusLabel} · Phiên bản ${guide.version}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _open(guide),
                    ),
                ],
              ],
            ),
          ),
  );
}
