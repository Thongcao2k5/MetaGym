import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/features/progress/data/member_measurement_service.dart';
import 'package:meta_gym_app/features/progress/domain/body_measurement.dart';
import 'package:meta_gym_app/features/progress/domain/progress_time.dart';
import 'package:provider/provider.dart';

AppBar _buildMeasurementAppBar(BuildContext context, String title) => AppBar(
  automaticallyImplyLeading: false,
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
  titleSpacing: Navigator.of(context).canPop() ? 8 : 16,
  title: Text(
    title,
    style: const TextStyle(
      color: MetaGymTheme.textPrimary,
      fontSize: 20,
      fontWeight: FontWeight.w700,
    ),
  ),
  backgroundColor: Colors.transparent,
  surfaceTintColor: Colors.transparent,
  elevation: 0,
);

InputDecoration _warmMeasurementInputDecoration(String label) =>
    InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xFFB8B0A8)),
      counterStyle: const TextStyle(color: Color(0xFFB8B0A8)),
      filled: true,
      fillColor: const Color(0x80211E1C),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
        borderSide: const BorderSide(color: Color(0x9A8C8176)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
        borderSide: const BorderSide(color: Color(0x9A8C8176)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
        borderSide: const BorderSide(
          color: MetaGymTheme.brandOrange,
          width: 1.4,
        ),
      ),
    );

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
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            _MeasurementFormPage(service: _service!, measurement: measurement),
      ),
    );
    if (saved == true && mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top + kToolbarHeight + 12;
    return Scaffold(
      backgroundColor: MetaGymTheme.darkCanvas,
      extendBodyBehindAppBar: true,
      appBar: _buildMeasurementAppBar(context, 'Số đo cơ thể'),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: MetaGymTheme.brandOrange,
        foregroundColor: Colors.white,
        onPressed: () => _edit(),
        icon: const Icon(Icons.add),
        label: const Text(
          'Thêm số đo',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const MetaGymBackground(),
          RefreshIndicator(
            color: MetaGymTheme.brandOrange,
            backgroundColor: const Color(0xFF282320),
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(16, topInset, 16, 96),
              children: [
                if (_loading && _items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: MetaGymTheme.brandOrange,
                      ),
                    ),
                  ),
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF24161A),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF642B32)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: MetaGymTheme.dangerCoral,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: const TextStyle(color: Color(0xFFFFB2B6)),
                          ),
                        ),
                        TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: MetaGymTheme.brandOrange,
                            minimumSize: const Size(48, 48),
                          ),
                          onPressed: () => _load(more: _items.isNotEmpty),
                          child: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (!_loading && _error == null && _items.isEmpty)
                  const MetaGymGlassCard(
                    padding: EdgeInsets.all(20),
                    child: ListTile(
                      leading: Icon(
                        Icons.monitor_weight_outlined,
                        color: MetaGymTheme.brandOrange,
                      ),
                      title: Text(
                        'Bạn chưa có số đo nào.',
                        style: TextStyle(
                          color: MetaGymTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                for (final item in _items)
                  MetaGymGlassCard(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: EdgeInsets.zero,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0x80211E1C),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0x9A8C8176)),
                        ),
                        child: const Icon(
                          Icons.monitor_weight_outlined,
                          color: MetaGymTheme.brandOrange,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        '${item.weightKg} kg · ${formatProgressTime(item.measuredAt)}',
                        style: const TextStyle(
                          color: MetaGymTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontFeatures: MetaGymTheme.tabularFigures,
                        ),
                      ),
                      subtitle: Text(
                        item.waistCm == null
                            ? 'Chạm để xem và sửa'
                            : 'Vòng eo: ${item.waistCm} cm',
                        style: const TextStyle(
                          color: Color(0xFFC8C2BC),
                          fontSize: 12.5,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.edit_outlined,
                        color: Color(0xFFC8C2BC),
                      ),
                      onTap: () => _edit(item),
                    ),
                  ),
                if (_loading && _items.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: MetaGymTheme.brandOrange,
                      ),
                    ),
                  ),
                if (_hasMore && !_loading)
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: MetaGymTheme.brandOrange,
                      minimumSize: const Size(48, 48),
                    ),
                    onPressed: () => _load(more: true),
                    child: const Text('Tải thêm'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
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
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      key: key,
      controller: controller,
      style: const TextStyle(
        color: MetaGymTheme.textPrimary,
        fontFeatures: MetaGymTheme.tabularFigures,
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: _warmMeasurementInputDecoration(label),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top + kToolbarHeight + 12;
    return Scaffold(
      backgroundColor: MetaGymTheme.darkCanvas,
      extendBodyBehindAppBar: true,
      appBar: _buildMeasurementAppBar(
        context,
        widget.measurement == null ? 'Thêm số đo' : 'Sửa số đo',
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const MetaGymBackground(),
          ListView(
            padding: EdgeInsets.fromLTRB(16, topInset, 16, 32),
            children: [
              MetaGymGlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextField(
                        key: const Key('measurement-date'),
                        controller: _date,
                        style: const TextStyle(
                          color: MetaGymTheme.textPrimary,
                          fontFeatures: MetaGymTheme.tabularFigures,
                        ),
                        keyboardType: TextInputType.datetime,
                        decoration: _warmMeasurementInputDecoration(
                          'Ngày đo (dd/MM/yyyy HH:mm)',
                        ),
                      ),
                    ),
                    _numberField(
                      'Cân nặng (kg)',
                      _weight,
                      key: const Key('measurement-weight'),
                    ),
                    _numberField(
                      'Mỡ cơ thể (%)',
                      _fat,
                      key: const Key('measurement-fat'),
                    ),
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
                      style: const TextStyle(color: MetaGymTheme.textPrimary),
                      decoration: _warmMeasurementInputDecoration('Ghi chú'),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF24161A),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFF642B32)),
                        ),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Color(0xFFFFB2B6)),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: MetaGymTheme.brandOrange,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            MetaGymTheme.radiusInput,
                          ),
                        ),
                      ),
                      onPressed: _saving ? null : _save,
                      child: Text(
                        _saving ? 'Đang lưu…' : 'Lưu',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
