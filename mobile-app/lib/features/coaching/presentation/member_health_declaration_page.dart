import 'package:meta_gym_app/core/widgets/meta_gym_tap.dart';
import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/features/coaching/presentation/coaching_ui.dart';
import 'package:provider/provider.dart';

class MemberHealthDeclarationPage extends StatefulWidget {
  const MemberHealthDeclarationPage({
    this.submitLabel = 'Lưu khai báo',
    super.key,
  });

  final String submitLabel;

  @override
  State<MemberHealthDeclarationPage> createState() =>
      _MemberHealthDeclarationPageState();
}

class _MemberHealthDeclarationPageState
    extends State<MemberHealthDeclarationPage> {
  final _formKey = GlobalKey<FormState>();
  final _height = TextEditingController();
  final _weight = TextEditingController();
  final _bodyFat = TextEditingController();
  final _conditionDetails = TextEditingController();
  final _injuryDetails = TextEditingController();
  final _goal = TextEditingController();
  bool? _hasCondition;
  bool? _hasInjury;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  static const List<String> _goalPresets = [
    'Tăng cơ giảm mỡ',
    'Giảm mỡ siết cơ',
    'Tăng sức mạnh tối đa',
    'Phục hồi vận động & sức bền',
  ];

  @override
  void initState() {
    super.initState();
    for (final c in [_height, _weight, _bodyFat]) {
      c.addListener(_onMetricEdited);
    }
    _load();
  }

  void _onMetricEdited() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    try {
      final user = (await context.read<ApiClient>().get<Map<String, dynamic>>(
        '/users/me',
        decode: (data) => Map<String, dynamic>.from(data as Map),
      )).data;
      if (!mounted) return;
      final profile = Map<String, dynamic>.from(user['profile'] as Map? ?? {});
      _height.text = profile['heightCm']?.toString() ?? '';
      _weight.text = profile['weightKg']?.toString() ?? '';
      _bodyFat.text = profile['bodyFatPercent']?.toString() ?? '';
      _conditionDetails.text = profile['healthNotes'] as String? ?? '';
      _injuryDetails.text = profile['injuryNotes'] as String? ?? '';
      _goal.text = profile['fitnessGoal'] as String? ?? '';
      if (profile['healthDeclarationCompletedAt'] != null) {
        _hasCondition = _conditionDetails.text.trim().isNotEmpty;
        _hasInjury = _injuryDetails.text.trim().isNotEmpty;
      }
    } on ApiException catch (error) {
      if (mounted) _error = error.message;
    } catch (_) {
      if (mounted) _error = 'Không tải được hồ sơ. Hãy thử lại.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    for (final c in [_height, _weight, _bodyFat]) {
      c.removeListener(_onMetricEdited);
    }
    for (final controller in [
      _height,
      _weight,
      _bodyFat,
      _conditionDetails,
      _injuryDetails,
      _goal,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  double? _parseDecimal(String? value) =>
      double.tryParse((value ?? '').trim().replaceAll(',', '.'));

  double? get _bmiValue {
    final h = _parseDecimal(_height.text);
    final w = _parseDecimal(_weight.text);
    if (h == null || w == null || h < 80 || h > 300 || w <= 0 || w > 999.99) {
      return null;
    }
    final meters = h / 100.0;
    return w / (meters * meters);
  }

  (String, CoachingPillTone) get _bmiStatus {
    final bmi = _bmiValue;
    if (bmi == null) {
      return ('Chờ nhập chỉ số', CoachingPillTone.neutral);
    }
    if (bmi < 18.5) return ('BMI ${bmi.toStringAsFixed(1)} · Thiếu cân', CoachingPillTone.amber);
    if (bmi < 25.0) return ('BMI ${bmi.toStringAsFixed(1)} · Cân đối', CoachingPillTone.green);
    return ('BMI ${bmi.toStringAsFixed(1)} · Thừa cân', CoachingPillTone.coral);
  }

  String? _requiredNumber(String? value, double max, String label) {
    final number = _parseDecimal(value);
    if (number == null || number <= 0 || number > max) {
      return 'Nhập $label hợp lệ';
    }
    return null;
  }

  InputDecoration _inputDecoration({
    required String hint,
    String? helper,
    String? suffixText,
  }) => InputDecoration(
    hintText: hint,
    helperText: helper,
    suffixText: suffixText,
    helperMaxLines: 2,
    errorMaxLines: 2,
    hintStyle: const TextStyle(color: Color(0xFFB8B0A8), fontSize: 13),
    helperStyle: const TextStyle(
      color: Color(0xFFC8C2BC),
      fontSize: 11.5,
      height: 1.35,
    ),
    suffixStyle: const TextStyle(
      color: Color(0xFFC8C2BC),
      fontSize: 12.5,
      fontWeight: FontWeight.w600,
    ),
    counterStyle: const TextStyle(color: Color(0xFFB8B0A8), fontSize: 11),
    filled: true,
    fillColor: const Color(0x99211E1C),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
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
      borderSide: const BorderSide(color: MetaGymTheme.brandOrange, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
      borderSide: const BorderSide(color: MetaGymTheme.dangerCoral),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
      borderSide: const BorderSide(color: MetaGymTheme.dangerCoral, width: 1.5),
    ),
  );

  Widget _labeledField({required String label, required Widget field}) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFEAE6E2),
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 7),
          field,
        ],
      );

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    if (_hasCondition == null || _hasInjury == null) {
      setState(
        () => _error = 'Hãy chọn Có hoặc Không cho bệnh nền và chấn thương.',
      );
      return;
    }
    if (_hasCondition! && _conditionDetails.text.trim().isEmpty ||
        _hasInjury! && _injuryDetails.text.trim().isEmpty) {
      setState(() => _error = 'Hãy mô tả bệnh nền hoặc chấn thương đã chọn.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final height = _parseDecimal(_height.text)!;
      final weight = _parseDecimal(_weight.text)!;
      final bodyFat = _bodyFat.text.trim().isEmpty
          ? null
          : _parseDecimal(_bodyFat.text);
      await context.read<ApiClient>().patch<Map<String, dynamic>>(
        '/users/me/health-declaration',
        body: {
          'heightCm': height,
          'weightKg': weight,
          'bodyFatPercent': bodyFat,
          'hasCondition': _hasCondition,
          'conditionDetails': _hasCondition!
              ? _conditionDetails.text.trim()
              : null,
          'hasInjury': _hasInjury,
          'injuryDetails': _hasInjury! ? _injuryDetails.text.trim() : null,
          'fitnessGoal': _goal.text.trim().isEmpty ? null : _goal.text.trim(),
        },
        decode: (data) => Map<String, dynamic>.from(data as Map),
      );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Không lưu được khai báo. Hãy thử lại.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _buildHeader(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Row(
        children: [
          if (canPop) ...[
            MetaGymCircleIconButton(
              icon: Icons.arrow_back_rounded,
              tooltip: 'Quay lại',
              onTap: _saving ? null : () => Navigator.of(context).maybePop(),
            ),
            const SizedBox(width: 12),
          ],
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'HỒ SƠ SỨC KHỎE & THỂ TRẠNG',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: MetaGymTheme.brandOrange,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Khai báo thể trạng',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Color(0xFFF7F9FC),
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSummaryCard() {
    final h = _parseDecimal(_height.text);
    final w = _parseDecimal(_weight.text);
    final fat = _parseDecimal(_bodyFat.text);
    final (bmiLabel, bmiTone) = _bmiStatus;

    return MetaGymHeroGlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0x26FF5E36),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0x52FF5E36)),
                ),
                child: const Icon(
                  Icons.monitor_heart_outlined,
                  color: MetaGymTheme.brandOrange,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tóm tắt thể trạng',
                      style: TextStyle(
                        color: Color(0xFFF7F9FC),
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Đồng bộ trực tiếp với Huấn luyện viên phụ trách',
                      style: TextStyle(
                        color: Color(0xFFC8C2BC),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          CoachingPill(label: bmiLabel, tone: bmiTone),
          const SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: MetaGymMetricPanel(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Chiều cao',
                          style: TextStyle(
                            color: Color(0xFFB8B0A8),
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          h != null ? '${h.toStringAsFixed(0)} cm' : '-- cm',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFF7F9FC),
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            fontFeatures: MetaGymTheme.tabularFigures,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: MetaGymMetricPanel(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Cân nặng',
                          style: TextStyle(
                            color: Color(0xFFB8B0A8),
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          w != null ? '${w.toStringAsFixed(1)} kg' : '-- kg',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFF7F9FC),
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            fontFeatures: MetaGymTheme.tabularFigures,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: MetaGymMetricPanel(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tỷ lệ mỡ',
                          style: TextStyle(
                            color: Color(0xFFB8B0A8),
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          fat != null ? '${fat.toStringAsFixed(1)}%' : 'Tùy chọn',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: fat != null
                                ? const Color(0xFFF7F9FC)
                                : const Color(0xFFB8B0A8),
                            fontSize: fat != null ? 16 : 13,
                            fontWeight: FontWeight.w700,
                            fontFeatures: MetaGymTheme.tabularFigures,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: MetaGymTheme.darkCanvas,
    body: Stack(
      fit: StackFit.expand,
      children: [
        const MetaGymBackground(),
        SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: MetaGymTheme.brandOrange,
                        ),
                      )
                    : Form(
                        key: _formKey,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: EdgeInsets.fromLTRB(
                            16,
                            6,
                            16,
                            MediaQuery.paddingOf(context).bottom + 28,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildHeroSummaryCard(),
                              const SizedBox(height: 12),
                              const Text(
                                'Trước khi thuê Coach, hãy cung cấp chỉ số cơ thể và những lưu ý về bệnh nền hoặc chấn thương. Coach sẽ dùng thông tin này để lên giáo án phù hợp.',
                                style: TextStyle(
                                  color: Color(0xFFC8C2BC),
                                  fontSize: 13,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 14),
                              _SolidFormSectionCard(
                                icon: Icons.straighten_rounded,
                                title: 'Chỉ số cơ thể hiện tại',
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: _labeledField(
                                            label: 'Chiều cao · cm',
                                            field: TextFormField(
                                              key: const Key('health-height'),
                                              controller: _height,
                                              cursorColor:
                                                  MetaGymTheme.brandOrange,
                                              style: const TextStyle(
                                                color: Color(0xFFF7F9FC),
                                                fontSize: 14.5,
                                                fontWeight: FontWeight.w600,
                                                fontFeatures: MetaGymTheme
                                                    .tabularFigures,
                                              ),
                                              keyboardType:
                                                  const TextInputType.numberWithOptions(
                                                    decimal: true,
                                                  ),
                                              decoration: _inputDecoration(
                                                hint: 'Ví dụ: 170',
                                                suffixText: 'cm',
                                              ),
                                              validator: (value) =>
                                                  _requiredNumber(
                                                    value,
                                                    300,
                                                    'chiều cao',
                                                  ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: _labeledField(
                                            label: 'Cân nặng · kg',
                                            field: TextFormField(
                                              key: const Key('health-weight'),
                                              controller: _weight,
                                              cursorColor:
                                                  MetaGymTheme.brandOrange,
                                              style: const TextStyle(
                                                color: Color(0xFFF7F9FC),
                                                fontSize: 14.5,
                                                fontWeight: FontWeight.w600,
                                                fontFeatures: MetaGymTheme
                                                    .tabularFigures,
                                              ),
                                              keyboardType:
                                                  const TextInputType.numberWithOptions(
                                                    decimal: true,
                                                  ),
                                              decoration: _inputDecoration(
                                                hint: 'Ví dụ: 65',
                                                suffixText: 'kg',
                                              ),
                                              validator: (value) =>
                                                  _requiredNumber(
                                                    value,
                                                    999.99,
                                                    'cân nặng',
                                                  ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    _labeledField(
                                      label: 'Tỷ lệ mỡ · % · tùy chọn',
                                      field: TextFormField(
                                        key: const Key('health-body-fat'),
                                        controller: _bodyFat,
                                        cursorColor: MetaGymTheme.brandOrange,
                                        style: const TextStyle(
                                          color: Color(0xFFF7F9FC),
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w600,
                                          fontFeatures:
                                              MetaGymTheme.tabularFigures,
                                        ),
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                        decoration: _inputDecoration(
                                          hint: 'Nếu biết, hãy nhập tỷ lệ mỡ',
                                          helper:
                                              'Không biết tỷ lệ mỡ? Bạn có thể để trống.',
                                          suffixText: '%',
                                        ),
                                        validator: (value) =>
                                            (value ?? '').trim().isEmpty
                                            ? null
                                            : _requiredNumber(
                                                value,
                                                100,
                                                'tỷ lệ mỡ',
                                              ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              _SolidFormSectionCard(
                                icon: Icons.medical_information_outlined,
                                title: 'Bạn có bệnh nền không?',
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _YesNoOptionRow(
                                      value: _hasCondition,
                                      onChanged: (next) => setState(() {
                                        _hasCondition = next;
                                        _error = null;
                                      }),
                                    ),
                                    if (_hasCondition == true) ...[
                                      const SizedBox(height: 12),
                                      _labeledField(
                                        label: 'Thông tin bệnh nền',
                                        field: TextField(
                                          key: const Key(
                                            'health-condition-details',
                                          ),
                                          controller: _conditionDetails,
                                          cursorColor: MetaGymTheme.brandOrange,
                                          style: const TextStyle(
                                            color: Color(0xFFF7F9FC),
                                            fontSize: 14,
                                          ),
                                          maxLines: 3,
                                          maxLength: 1000,
                                          decoration: _inputDecoration(
                                            hint:
                                                'Ví dụ: vấn đề tim mạch, huyết áp...',
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              _SolidFormSectionCard(
                                icon: Icons.healing_outlined,
                                title: 'Bạn có chấn thương cần lưu ý không?',
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _YesNoOptionRow(
                                      value: _hasInjury,
                                      onChanged: (next) => setState(() {
                                        _hasInjury = next;
                                        _error = null;
                                      }),
                                    ),
                                    if (_hasInjury == true) ...[
                                      const SizedBox(height: 12),
                                      _labeledField(
                                        label:
                                            'Vị trí và tình trạng chấn thương',
                                        field: TextField(
                                          key: const Key(
                                            'health-injury-details',
                                          ),
                                          controller: _injuryDetails,
                                          cursorColor: MetaGymTheme.brandOrange,
                                          style: const TextStyle(
                                            color: Color(0xFFF7F9FC),
                                            fontSize: 14,
                                          ),
                                          maxLines: 3,
                                          maxLength: 1000,
                                          decoration: _inputDecoration(
                                            hint:
                                                'Ví dụ: đầu gối trái, đang phục hồi...',
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              _SolidFormSectionCard(
                                icon: Icons.flag_outlined,
                                title: 'Mục tiêu tập luyện · tùy chọn',
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    TextField(
                                      key: const Key('health-goal'),
                                      controller: _goal,
                                      cursorColor: MetaGymTheme.brandOrange,
                                      style: const TextStyle(
                                        color: Color(0xFFF7F9FC),
                                        fontSize: 14,
                                      ),
                                      maxLength: 500,
                                      decoration: _inputDecoration(
                                        hint:
                                            'Ví dụ: tăng cơ, cải thiện sức bền',
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        for (final preset in _goalPresets)
                                          Material(
                                            color: _goal.text.trim() == preset
                                                ? const Color(0x38FF5E36)
                                                : const Color(0x99211E1C),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              side: BorderSide(
                                                color:
                                                    _goal.text.trim() == preset
                                                    ? MetaGymTheme.brandOrange
                                                    : const Color(0x9A8C8176),
                                              ),
                                            ),
                                            clipBehavior: Clip.antiAlias,
                                            child: InkWell(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              onTap: () => setState(
                                                () => _goal.text = preset,
                                              ),
                                              child: ConstrainedBox(
                                                constraints:
                                                    const BoxConstraints(
                                                      minHeight: 48,
                                                    ),
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                        vertical: 10,
                                                      ),
                                                  child: Center(
                                                    widthFactor: 1,
                                                    child: Text(
                                                      preset,
                                                      style: TextStyle(
                                                        color:
                                                            _goal.text.trim() ==
                                                                preset
                                                            ? const Color(
                                                                0xFFF7F9FC,
                                                              )
                                                            : const Color(
                                                                0xFFE4DAD1,
                                                              ),
                                                        fontSize: 12.5,
                                                        fontWeight:
                                                            _goal.text.trim() ==
                                                                preset
                                                            ? FontWeight.w700
                                                            : FontWeight.w500,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0x1F2ECC71),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: const Color(0x4D2ECC71),
                                  ),
                                ),
                                child: const Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.verified_user_outlined,
                                      color: MetaGymTheme.progressGreen,
                                      size: 18,
                                    ),
                                    SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Coach phụ trách sẽ xem khai báo này sau khi gói có hiệu lực. Bạn có thể cập nhật bất cứ lúc nào nếu thể trạng thay đổi.',
                                        style: TextStyle(
                                          color: Color(0xFFD5CCBF),
                                          fontSize: 12,
                                          height: 1.45,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),
                              if (_error != null)
                                CoachingErrorBanner(message: _error!),
                              CoachingPrimaryButton(
                                label: _saving
                                    ? 'Đang lưu...'
                                    : widget.submitLabel,
                                icon: Icons.check_circle_outline_rounded,
                                loading: _saving,
                                onPressed: _saving ? null : _save,
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Level 1 Warm Smoked Surface Card (`featured: false`, no BackdropFilter behind dense forms).
class _SolidFormSectionCard extends StatelessWidget {
  const _SolidFormSectionCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MetaGymGlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: MetaGymTheme.brandOrange, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFFF7F9FC),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _YesNoOptionRow extends StatelessWidget {
  const _YesNoOptionRow({required this.value, required this.onChanged});

  final bool? value;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ChoiceTile(
            label: 'Không',
            selected: value == false,
            onTap: () => onChanged(false),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ChoiceTile(
            label: 'Có',
            selected: value == true,
            onTap: () => onChanged(true),
          ),
        ),
      ],
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      inMutuallyExclusiveGroup: true,
      selected: selected,
      button: true,
      label: label,
      child: Material(
        animationDuration: MetaGymTheme.stateDurationOf(context),
        color: selected
            ? MetaGymTheme.brandOrange.withValues(alpha: 0.22)
            : const Color(0x99211E1C),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
          side: BorderSide(
            color: selected
                ? MetaGymTheme.brandOrange
                : const Color(0x9A8C8176),
            width: selected ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: MetaGymTap(
          onTap: onTap,
          borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  color: selected
                      ? MetaGymTheme.brandOrange
                      : const Color(0xFFB8B0A8),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: selected
                          ? const Color(0xFFF7F9FC)
                          : const Color(0xFFEAE6E2),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
