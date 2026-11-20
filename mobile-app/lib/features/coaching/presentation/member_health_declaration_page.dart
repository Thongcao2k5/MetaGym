import 'package:meta_gym_app/core/widgets/meta_gym_tap.dart';
import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
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

  @override
  void initState() {
    super.initState();
    _load();
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
  }) => InputDecoration(
    hintText: hint,
    helperText: helper,
    errorMaxLines: 2,
    hintStyle: const TextStyle(color: MetaGymTheme.textSecondary, fontSize: 13),
    helperStyle: const TextStyle(
      color: MetaGymTheme.textSecondary,
      fontSize: 11.5,
    ),
    filled: true,
    fillColor: MetaGymTheme.darkCanvasElevated,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
      borderSide: const BorderSide(color: MetaGymTheme.darkBorderStrong),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
      borderSide: const BorderSide(color: MetaGymTheme.reflectionBlue),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
      borderSide: const BorderSide(color: MetaGymTheme.dangerCoral),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
      borderSide: const BorderSide(color: MetaGymTheme.dangerCoral),
    ),
  );

  Widget _labeledField({required String label, required Widget field}) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFD4D8DF),
              fontSize: 12,
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

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: MetaGymTheme.darkCanvas,
    appBar: AppBar(
      title: const Text(
        'Khai báo thể trạng',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
      ),
      backgroundColor: MetaGymTheme.darkCanvas,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      iconTheme: const IconThemeData(color: Colors.white),
    ),
    body: _loading
        ? const Center(
            child: CircularProgressIndicator(color: MetaGymTheme.brandOrange),
          )
        : SafeArea(
            child: Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Trước khi thuê Coach, hãy cung cấp chỉ số cơ thể và những lưu ý về bệnh nền hoặc chấn thương. Coach sẽ dùng thông tin này để lên giáo án phù hợp.',
                      style: TextStyle(
                        color: Color(0xFFD4D8DF),
                        fontSize: 13.5,
                        height: 1.55,
                      ),
                    ),
                    const SizedBox(height: 16),
                    CoachingGraphiteCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Chỉ số cơ thể hiện tại',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _labeledField(
                                  label: 'Chiều cao · cm',
                                  field: TextFormField(
                                    key: const Key('health-height'),
                                    controller: _height,
                                    style: const TextStyle(color: Colors.white),
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    decoration: _inputDecoration(
                                      hint: 'Ví dụ: 170',
                                    ),
                                    validator: (value) => _requiredNumber(
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
                                    style: const TextStyle(color: Colors.white),
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    decoration: _inputDecoration(
                                      hint: 'Ví dụ: 65',
                                    ),
                                    validator: (value) => _requiredNumber(
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
                            label: 'Body fat · % · tùy chọn',
                            field: TextFormField(
                              key: const Key('health-body-fat'),
                              controller: _bodyFat,
                              style: const TextStyle(color: Colors.white),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: _inputDecoration(
                                hint: 'Nếu biết, hãy nhập tỷ lệ mỡ',
                                helper:
                                    'Không biết body fat? Bạn có thể để trống.',
                              ),
                              validator: (value) => (value ?? '').trim().isEmpty
                                  ? null
                                  : _requiredNumber(value, 100, 'body fat'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    CoachingGraphiteCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Bạn có bệnh nền không?',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
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
                                key: const Key('health-condition-details'),
                                controller: _conditionDetails,
                                style: const TextStyle(color: Colors.white),
                                maxLines: 3,
                                maxLength: 1000,
                                decoration: _inputDecoration(
                                  hint: 'Ví dụ: vấn đề tim mạch, huyết áp...',
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    CoachingGraphiteCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Bạn có chấn thương cần lưu ý không?',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
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
                              label: 'Vị trí và tình trạng chấn thương',
                              field: TextField(
                                key: const Key('health-injury-details'),
                                controller: _injuryDetails,
                                style: const TextStyle(color: Colors.white),
                                maxLines: 3,
                                maxLength: 1000,
                                decoration: _inputDecoration(
                                  hint: 'Ví dụ: đầu gối trái, đang phục hồi...',
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _labeledField(
                      label: 'Mục tiêu tập luyện · tùy chọn',
                      field: TextField(
                        key: const Key('health-goal'),
                        controller: _goal,
                        style: const TextStyle(color: Colors.white),
                        maxLength: 500,
                        decoration: _inputDecoration(
                          hint: 'Ví dụ: tăng cơ, cải thiện sức bền',
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Coach phụ trách sẽ xem khai báo này sau khi gói có hiệu lực. Bạn có thể cập nhật nếu thể trạng thay đổi.',
                      style: TextStyle(
                        color: Color(0xFFBAC2CE),
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (_error != null) CoachingErrorBanner(message: _error!),
                    CoachingPrimaryButton(
                      label: _saving ? 'Đang lưu...' : widget.submitLabel,
                      loading: _saving,
                      onPressed: _saving ? null : _save,
                    ),
                  ],
                ),
              ),
            ),
          ),
  );
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
            ? MetaGymTheme.primary.withValues(alpha: 0.16)
            : MetaGymTheme.elevatedSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
          side: BorderSide(
            color: selected
                ? MetaGymTheme.primary
                : MetaGymTheme.darkBorderStrong,
            width: selected ? 1.4 : 1,
          ),
        ),
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
                      ? MetaGymTheme.primary
                      : MetaGymTheme.textSecondary,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: selected
                        ? MetaGymTheme.textPrimary
                        : const Color(0xFFD6DCE6),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
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
