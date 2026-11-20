import 'package:meta_gym_app/core/navigation/meta_gym_navigation.dart';
import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/features/progress/data/member_measurement_service.dart';
import 'package:meta_gym_app/features/progress/domain/body_measurement.dart';
import 'package:meta_gym_app/features/progress/domain/progress_time.dart';
import 'package:provider/provider.dart';

class MemberMeasurementPage extends StatefulWidget {
  const MemberMeasurementPage({this.service, super.key});
  final MemberMeasurementService? service;
  @override
  State<MemberMeasurementPage> createState() => _MemberMeasurementPageState();
}

class _MemberMeasurementPageState extends State<MemberMeasurementPage> {
  MemberMeasurementService? _service;
  List<BodyMeasurement> _items = const [];
  int _page = 0;
  bool _hasMore = false;
  bool _loading = true;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_service != null) return;
    _service = widget.service ?? context.read<MemberMeasurementService>();
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
        _items = const [];
        _page = 0;
      }
    });
    try {
      final next = await _service!.getPage(_page + 1);
      if (mounted) {
        setState(() {
          _items = [..._items, ...next];
          _page++;
          _hasMore = next.length == 20;
        });
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không tải được số đo.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit([BodyMeasurement? measurement]) async {
    final saved = await MetaGymNavigation.pushOnce<bool>(
      context,
      MetaGymPageRoute(
        builder: (_) =>
            _MeasurementFormPage(service: _service!, measurement: measurement),
      ),
    );
    if (saved == true && mounted) await _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Số đo cơ thể')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => _edit(),
      icon: const Icon(Icons.add),
      label: const Text('Thêm số đo'),
    ),
    body: RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          if (_loading && _items.isEmpty)
            const Center(child: CircularProgressIndicator()),
          if (_error != null) ...[
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            TextButton(
              onPressed: () => _load(more: _items.isNotEmpty),
              child: const Text('Thử lại'),
            ),
          ],
          if (!_loading && _error == null && _items.isEmpty)
            const ListTile(title: Text('Bạn chưa có số đo nào.')),
          for (final item in _items)
            Card(
              child: ListTile(
                title: Text(
                  '${item.weightKg} kg · ${formatProgressTime(item.measuredAt)}',
                ),
                subtitle: Text(
                  item.waistCm == null
                      ? 'Chạm để xem và sửa'
                      : 'Vòng eo: ${item.waistCm} cm',
                ),
                trailing: const Icon(Icons.edit_outlined),
                onTap: () => _edit(item),
              ),
            ),
          if (_loading && _items.isNotEmpty)
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

class _MeasurementFormPage extends StatefulWidget {
  const _MeasurementFormPage({required this.service, this.measurement});
  final MemberMeasurementService service;
  final BodyMeasurement? measurement;
  @override
  State<_MeasurementFormPage> createState() => _MeasurementFormPageState();
}

class _MeasurementFormPageState extends State<_MeasurementFormPage> {
  final _date = TextEditingController();
  final _weight = TextEditingController();
  final _fat = TextEditingController();
  final _chest = TextEditingController();
  final _waist = TextEditingController();
  final _hips = TextEditingController();
  final _arm = TextEditingController();
  final _thigh = TextEditingController();
  final _notes = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final m = widget.measurement;
    if (m != null) {
      _date.text = formatProgressTime(m.measuredAt);
      _weight.text = m.weightKg.toString();
      _fat.text = m.bodyFatPercent?.toString() ?? '';
      _chest.text = m.chestCm?.toString() ?? '';
      _waist.text = m.waistCm?.toString() ?? '';
      _hips.text = m.hipsCm?.toString() ?? '';
      _arm.text = m.armCm?.toString() ?? '';
      _thigh.text = m.thighCm?.toString() ?? '';
      _notes.text = m.notes ?? '';
    }
  }

  @override
  void dispose() {
    for (final c in [
      _date,
      _weight,
      _fat,
      _chest,
      _waist,
      _hips,
      _arm,
      _thigh,
      _notes,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final date = parseProgressTime(_date.text);
    final weight = double.tryParse(_weight.text.trim());
    final fat = _optionalNumber(_fat);
    final lengths = [_chest, _waist, _hips, _arm, _thigh];
    String? validation;
    if (date == null) {
      validation = 'Nhập ngày giờ hợp lệ (dd/MM/yyyy HH:mm).';
    } else if (weight == null ||
        !weight.isFinite ||
        weight <= 0 ||
        weight > 999.99) {
      validation = 'Cân nặng phải lớn hơn 0 và không quá 999.99 kg.';
    } else if (_fat.text.trim().isNotEmpty &&
        (fat == null || !fat.isFinite || fat < 0 || fat > 100)) {
      validation = 'Mỡ cơ thể phải trong khoảng 0–100%.';
    } else if (lengths.any(
      (c) =>
          c.text.trim().isNotEmpty &&
          (_optionalNumber(c) == null ||
              !_optionalNumber(c)!.isFinite ||
              _optionalNumber(c)! <= 0 ||
              _optionalNumber(c)! > 999.99),
    )) {
      validation = 'Số đo vòng phải lớn hơn 0 và không quá 999.99 cm.';
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
      'measuredAt': date!.toUtc().toIso8601String(),
      'weightKg': weight,
      'bodyFatPercent': fat,
      'chestCm': _optionalNumber(_chest),
      'waistCm': _optionalNumber(_waist),
      'hipsCm': _optionalNumber(_hips),
      'armCm': _optionalNumber(_arm),
      'thighCm': _optionalNumber(_thigh),
      'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
    };
    try {
      if (widget.measurement case final m?) {
        await widget.service.update(m.id, payload);
      } else {
        await widget.service.create(payload);
      }
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không lưu được số đo.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  double? _optionalNumber(TextEditingController c) =>
      c.text.trim().isEmpty ? null : double.tryParse(c.text.trim());

  Widget _numberField(
    String label,
    TextEditingController controller, {
    Key? key,
  }) => TextField(
    key: key,
    controller: controller,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(labelText: label),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.measurement == null ? 'Thêm số đo' : 'Sửa số đo'),
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          key: const Key('measurement-date'),
          controller: _date,
          keyboardType: TextInputType.datetime,
          decoration: const InputDecoration(
            labelText: 'Ngày đo (dd/MM/yyyy HH:mm)',
          ),
        ),
        _numberField(
          'Cân nặng (kg)',
          _weight,
          key: const Key('measurement-weight'),
        ),
        _numberField('Mỡ cơ thể (%)', _fat, key: const Key('measurement-fat')),
        _numberField('Vòng ngực (cm)', _chest),
        _numberField(
          'Vòng eo (cm)',
          _waist,
          key: const Key('measurement-waist'),
        ),
        _numberField('Vòng hông (cm)', _hips),
        _numberField('Vòng tay (cm)', _arm),
        _numberField('Vòng đùi (cm)', _thigh),
        TextField(
          controller: _notes,
          maxLength: 5000,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Ghi chú'),
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
