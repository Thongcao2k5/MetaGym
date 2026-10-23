import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/features/training/data/coach_nutrition_service.dart';
import 'package:meta_gym_app/features/training/domain/nutrition_models.dart';

class CoachNutritionEditorPage extends StatefulWidget {
  const CoachNutritionEditorPage({
    required this.memberId,
    required this.service,
    this.guide,
    super.key,
  });

  final String memberId;
  final CoachNutritionService service;
  final NutritionGuide? guide;

  @override
  State<CoachNutritionEditorPage> createState() =>
      _CoachNutritionEditorPageState();
}

class _CoachNutritionEditorPageState extends State<CoachNutritionEditorPage> {
  late final TextEditingController _title;
  late final TextEditingController _content;
  NutritionGuide? _guide;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _guide = widget.guide;
    _title = TextEditingController(text: widget.guide?.title);
    _content = TextEditingController(text: widget.guide?.content);
  }

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  bool _validate() {
    if (_title.text.trim().isNotEmpty && _content.text.trim().isNotEmpty) {
      return true;
    }
    setState(() => _error = 'Vui lòng nhập tiêu đề và nội dung.');
    return false;
  }

  Future<void> _save({bool publish = false}) async {
    if (_busy || !_validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final title = _title.text.trim();
      final content = _content.text.trim();
      final guide = _guide == null
          ? await widget.service.create(widget.memberId, title, content)
          : await widget.service.update(
              _guide!.id,
              title,
              content,
              publish: publish,
            );
      if (mounted) {
        setState(() {
          _guide = guide;
          _title.text = guide.title;
          _content.text = guide.content;
        });
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không lưu được hướng dẫn.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmPublish() async {
    if (_guide?.status != 'DRAFT' || _busy || !_validate()) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Công bố hướng dẫn?'),
        content: const Text(
          'Member sẽ thấy hướng dẫn này; bản cũ chuyển vào lịch sử.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Quay lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Xác nhận công bố'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) await _save(publish: true);
  }

  @override
  Widget build(BuildContext context) {
    final editable = _guide == null || _guide?.status == 'DRAFT';
    return Scaffold(
      appBar: AppBar(title: const Text('Hướng dẫn dinh dưỡng')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_guide != null) ...[
            Text('${_guide!.statusLabel} · Phiên bản ${_guide!.version}'),
            if (_guide!.publishedAt != null) Text(_guide!.publicationLabel),
            const SizedBox(height: 16),
          ],
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          TextField(
            key: const Key('guide-title'),
            controller: _title,
            enabled: editable && !_busy,
            maxLength: 150,
            decoration: const InputDecoration(labelText: 'Tiêu đề'),
          ),
          TextField(
            key: const Key('guide-content'),
            controller: _content,
            enabled: editable && !_busy,
            maxLength: 20000,
            minLines: 5,
            maxLines: 12,
            decoration: const InputDecoration(labelText: 'Nội dung'),
          ),
          if (editable) ...[
            FilledButton(
              onPressed: _busy ? null : _save,
              child: const Text('Lưu bản nháp'),
            ),
            if (_guide?.status == 'DRAFT')
              OutlinedButton(
                onPressed: _busy ? null : _confirmPublish,
                child: const Text('Công bố'),
              ),
          ],
        ],
      ),
    );
  }
}
