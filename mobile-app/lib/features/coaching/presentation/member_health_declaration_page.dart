import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/theme/meta_gym_icons.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_icon.dart';
import 'package:meta_gym_app/features/coaching/presentation/coaching_ui.dart';
import 'package:meta_gym_app/features/profile/presentation/widgets/body_metric_pickers.dart';
import 'package:meta_gym_app/features/progress/data/member_measurement_service.dart';
import 'package:provider/provider.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_svg_icon.dart';

/// Màn hình **5.4 Khai báo thể trạng** khớp sát bố cục preview `tab5-profile.js`
/// (`member-health-declaration`) trên nền & thẻ Warm Smoked Liquid Glass:
/// 1. Hero `Tóm tắt thể trạng` (`health_shield.svg` + pill BMI + 3 ô chỉ số chạm đo)
/// 2. Thẻ `Chỉ số cơ thể hiện tại` (`Chiều cao · cm`, `Cân nặng · kg`, `Tỷ lệ mỡ · % · tùy chọn`)
/// 3. Thẻ gộp `Bệnh nền & Chấn thương` (`Tiền sử chấn thương`, `Bệnh nền / Lưu ý y tế`)
/// 4. Thanh CTA đáy `.bottom-cta-dock`: `Lưu khai báo thể trạng`.
class MemberHealthDeclarationPage extends StatefulWidget {
  const MemberHealthDeclarationPage({
    this.submitLabel = 'Lưu khai báo thể trạng',
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
  String? _loadedFitnessGoal;
  bool? _hasCondition;
  bool? _hasInjury;
  bool _loading = true;
  bool _saving = false;
  String? _loadError;
  String? _error;

  @override
  void initState() {
    super.initState();
    for (final c in [_height, _weight, _bodyFat]) {
      c.addListener(_onMetricEdited);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  void _onMetricEdited() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
      _error = null;
    });
    try {
      final api = optionalProvider<ApiClient>(context);
      if (api == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      final user = (await api.get<Map<String, dynamic>>(
        '/users/me',
        decode: (data) => Map<String, dynamic>.from(data as Map),
      )).data;
      if (!mounted) return;
      final profile = Map<String, dynamic>.from(user['profile'] as Map? ?? {});
      _height.text = _cleanNumericString(profile['heightCm']);
      _weight.text = _cleanNumericString(profile['weightKg']);
      _bodyFat.text = _cleanNumericString(profile['bodyFatPercent']);
      _conditionDetails.text = (profile['healthNotes'] as String? ?? '').trim();
      _injuryDetails.text = (profile['injuryNotes'] as String? ?? '').trim();
      _loadedFitnessGoal = (profile['fitnessGoal'] as String?)?.trim();
      if (profile['healthDeclarationCompletedAt'] != null) {
        _hasCondition = _conditionDetails.text.isNotEmpty;
        _hasInjury = _injuryDetails.text.isNotEmpty;
      }

      if (_weight.text.trim().isEmpty) {
        final measurementService = optionalProvider<MemberMeasurementService>(
          context,
        );
        if (measurementService != null) {
          try {
            final recent = await measurementService.getPage(1);
            if (mounted && recent.isNotEmpty && recent.first.weightKg > 0) {
              _weight.text = _cleanNumericString(recent.first.weightKg);
            }
          } catch (_) {}
        }
      }
    } on ApiException catch (error) {
      if (mounted) _loadError = error.message;
    } catch (_) {
      if (mounted) _loadError = 'Không tải được hồ sơ. Hãy thử lại.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _cleanNumericString(Object? raw) {
    if (raw == null) return '';
    if (raw is num) {
      return raw == raw.roundToDouble() ? raw.toStringAsFixed(0) : '$raw';
    }
    return raw.toString().trim();
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
    if (bmi < 18.5) {
      return (
        '● BMI ${bmi.toStringAsFixed(1)} · Thiếu cân',
        CoachingPillTone.info,
      );
    }
    if (bmi < 25.0) {
      return (
        '● BMI ${bmi.toStringAsFixed(1)} · Bình thường',
        CoachingPillTone.green,
      );
    }
    if (bmi < 30.0) {
      return (
        '● BMI ${bmi.toStringAsFixed(1)} · Thừa cân',
        CoachingPillTone.amber,
      );
    }
    return (
      '● BMI ${bmi.toStringAsFixed(1)} · Béo phì',
      CoachingPillTone.coral,
    );
  }

  String? _requiredNumber(String? value, double max, String label) {
    final number = _parseDecimal(value);
    if (number == null || !number.isFinite || number <= 0 || number > max) {
      return 'Nhập $label hợp lệ';
    }
    return null;
  }

  Future<void> _openHeightPicker() async {
    final currentH = _parseDecimal(_height.text) ?? 174.0;
    final currentW = _parseDecimal(_weight.text) ?? 72.4;
    final picked = await showHeightStadiometerPicker(
      context,
      initialHeightCm: currentH,
      referenceWeightKg: currentW,
    );
    if (picked != null && mounted) {
      _height.text = picked.round().toString();
    }
  }

  Future<void> _openWeightPicker() async {
    final currentH = _parseDecimal(_height.text) ?? 174.0;
    final currentW = _parseDecimal(_weight.text) ?? 72.4;
    final picked = await showWeightBarbellDialPicker(
      context,
      initialWeightKg: currentW,
      referenceHeightCm: currentH,
    );
    if (picked != null && mounted) {
      _weight.text = picked.toStringAsFixed(1);
    }
  }

  InputDecoration _inputDecoration(
    MetaGymColors colors, {
    required String hint,
    String? suffixText,
  }) => InputDecoration(
    hintText: hint,
    suffixText: suffixText,
    errorMaxLines: 2,
    hintStyle: TextStyle(color: colors.textSecondary, fontSize: 13),
    suffixStyle: TextStyle(
      color: colors.textSecondary,
      fontSize: 12.5,
      fontWeight: FontWeight.w500,
    ),
    filled: true,
    fillColor: colors.metricPanelBg,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
      borderSide: BorderSide(color: colors.metricPanelBorder),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
      borderSide: BorderSide(color: colors.metricPanelBorder),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
      borderSide: BorderSide(color: colors.focus, width: 1.4),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
      borderSide: BorderSide(color: colors.error),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
      borderSide: BorderSide(color: colors.error, width: 1.4),
    ),
  );

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    if (_hasCondition == null || _hasInjury == null) {
      setState(
        () => _error = 'Hãy chọn Có hoặc Không cho bệnh nền và chấn thương.',
      );
      return;
    }
    if ((_hasCondition! && _conditionDetails.text.trim().isEmpty) ||
        (_hasInjury! && _injuryDetails.text.trim().isEmpty)) {
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
          'fitnessGoal': _loadedFitnessGoal?.isNotEmpty == true
              ? _loadedFitnessGoal
              : null,
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

  Widget _buildHeader(BuildContext context, MetaGymColors colors) {
    final canPop = Navigator.of(context).canPop();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Row(
        children: [
          if (canPop) ...[
            MetaGymCircleIconButton(
              svgAsset: MetaGymIcons.commonBack,
              tooltip: 'Quay lại',
              onTap: _saving ? null : () => Navigator.of(context).maybePop(),
            ),
            const SizedBox(width: 11),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'HỒ SƠ SỨC KHỎE & THỂ TRẠNG',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.primaryText,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Khai báo thể trạng',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 19,
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

  Widget _buildHeroSummaryCard(MetaGymColors colors) {
    final h = _parseDecimal(_height.text);
    final w = _parseDecimal(_weight.text);
    final fat = _parseDecimal(_bodyFat.text);
    final (bmiLabel, bmiTone) = _bmiStatus;

    return MetaGymHeroGlassCard(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: MetaGymTheme.brandOrange.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: MetaGymTheme.brandOrange.withValues(alpha: 0.34),
                  ),
                ),
                alignment: Alignment.center,
                child: const MetaGymIcon(
                  MetaGymIcons.healthShield,
                  size: MetaGymIconSize.md,
                  excludeFromSemantics: true,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tóm tắt thể trạng',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Đồng bộ trực tiếp với Huấn luyện viên phụ trách',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textWarmMuted,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          CoachingPill(label: bmiLabel, tone: bmiTone),
          const SizedBox(height: 10),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: MetaGymMetricPanel(
                    onTap: _openHeightPicker,
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Chiều cao',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          h != null ? '${h.toStringAsFixed(0)} cm' : '-- cm',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 15,
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
                    onTap: _openWeightPicker,
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cân nặng',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          w != null ? '${w.toStringAsFixed(1)} kg' : '-- kg',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 15,
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
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tỷ lệ mỡ',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          fat != null ? '${fat.toStringAsFixed(1)}%' : '--',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: fat != null
                                ? colors.textPrimary
                                : colors.textSecondary,
                            fontSize: 15,
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

  Widget _buildNoteFieldBlock(
    MetaGymColors colors, {
    required String label,
    required bool? toggleValue,
    required ValueChanged<bool> onToggle,
    required Key fieldKey,
    required TextEditingController controller,
    required String hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.textWarmMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            _InlineYesNoPills(value: toggleValue, onChanged: onToggle),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          key: fieldKey,
          controller: controller,
          cursorColor: MetaGymTheme.brandOrange,
          onChanged: (text) {
            if (text.trim().isNotEmpty && toggleValue != true) {
              onToggle(true);
            } else if (_error != null) {
              setState(() => _error = null);
            }
          },
          style: TextStyle(
            color: toggleValue == false
                ? colors.textSecondary
                : colors.textPrimary,
            fontSize: 13,
            height: 1.4,
          ),
          minLines: 1,
          maxLines: 3,
          decoration: _inputDecoration(colors, hint: hint),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = MetaGymColors.of(context);
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Scaffold(
      backgroundColor: colors.canvas,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const MetaGymBackground(),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _buildHeader(context, colors),
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
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (_loadError != null) ...[
                                  CoachingErrorBanner(message: _loadError!),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: TextButton.icon(
                                      onPressed: _load,
                                      icon: const MetaGymSvgIcon(MetaGymIcons.commonRefresh, size: 18, fallbackIcon: Icons.refresh_rounded),
                                      label: const Text('Tải lại hồ sơ'),
                                    ),
                                  ),
                                ],
                                _buildHeroSummaryCard(colors),
                                const SizedBox(height: 11),
                                Text(
                                  'Cung cấp chỉ số cơ thể và lưu ý về bệnh nền hoặc chấn thương để Coach lên giáo án an toàn, phù hợp nhất.',
                                  style: TextStyle(
                                    color: colors.textWarmMuted,
                                    fontSize: 12,
                                    height: 1.45,
                                  ),
                                ),
                                const SizedBox(height: 11),
                                // Card 2: Chỉ số cơ thể hiện tại
                                MetaGymGlassCard(
                                  solid: false,
                                  padding: const EdgeInsets.all(15),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const MetaGymIcon(
                                            MetaGymIcons.bodyMeasureTape,
                                            size: MetaGymIconSize.sm,
                                            excludeFromSemantics: true,
                                          ),
                                          const SizedBox(width: 7),
                                          Expanded(
                                            child: Text(
                                              'Chỉ số cơ thể hiện tại',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: colors.textPrimary,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          InkWell(
                                            onTap: _openHeightPicker,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 4,
                                                    vertical: 2,
                                                  ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    'Chạm để đo',
                                                    style: TextStyle(
                                                      color: colors.primaryText,
                                                      fontSize: 11.5,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 2),
                                                  MetaGymSvgIcon(MetaGymIcons.commonChevronRight, size: 13, fallbackIcon: Icons.north_east_rounded),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Chiều cao · cm',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    color: colors.textWarmMuted,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                TextFormField(
                                                  key: const Key(
                                                    'health-height',
                                                  ),
                                                  controller: _height,
                                                  cursorColor:
                                                      MetaGymTheme.brandOrange,
                                                  style: TextStyle(
                                                    color: colors.textPrimary,
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
                                                    colors,
                                                    hint: '174',
                                                    suffixText: 'cm',
                                                  ),
                                                  validator: (value) =>
                                                      _requiredNumber(
                                                        value,
                                                        300,
                                                        'chiều cao',
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Cân nặng · kg',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    color: colors.textWarmMuted,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                TextFormField(
                                                  key: const Key(
                                                    'health-weight',
                                                  ),
                                                  controller: _weight,
                                                  cursorColor:
                                                      MetaGymTheme.brandOrange,
                                                  style: TextStyle(
                                                    color: colors.textPrimary,
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
                                                    colors,
                                                    hint: '72.4',
                                                    suffixText: 'kg',
                                                  ),
                                                  validator: (value) =>
                                                      _requiredNumber(
                                                        value,
                                                        999.99,
                                                        'cân nặng',
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        'Tỷ lệ mỡ · % · tùy chọn',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: colors.textWarmMuted,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      TextFormField(
                                        key: const Key('health-body-fat'),
                                        controller: _bodyFat,
                                        cursorColor: MetaGymTheme.brandOrange,
                                        style: TextStyle(
                                          color: colors.textPrimary,
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
                                          colors,
                                          hint: '16.8',
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
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                // Card 3: Bệnh nền & Chấn thương (1 thẻ gọn đồng bộ preview 5.4)
                                MetaGymGlassCard(
                                  solid: false,
                                  padding: const EdgeInsets.all(15),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const MetaGymIcon(
                                            MetaGymIcons.healthMedical,
                                            size: MetaGymIconSize.sm,
                                            excludeFromSemantics: true,
                                          ),
                                          const SizedBox(width: 7),
                                          Expanded(
                                            child: Text(
                                              'Bệnh nền & Chấn thương',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: colors.textPrimary,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      _buildNoteFieldBlock(
                                        colors,
                                        label: 'Tiền sử chấn thương',
                                        toggleValue: _hasInjury,
                                        onToggle: (next) => setState(() {
                                          _hasInjury = next;
                                          if (!next) _injuryDetails.clear();
                                          _error = null;
                                        }),
                                        fieldKey: const Key(
                                          'health-injury-details',
                                        ),
                                        controller: _injuryDetails,
                                        hint: 'Không có chấn thương đáng lưu ý',
                                      ),
                                      const SizedBox(height: 12),
                                      _buildNoteFieldBlock(
                                        colors,
                                        label: 'Bệnh nền / Lưu ý y tế',
                                        toggleValue: _hasCondition,
                                        onToggle: (next) => setState(() {
                                          _hasCondition = next;
                                          if (!next) _conditionDetails.clear();
                                          _error = null;
                                        }),
                                        fieldKey: const Key(
                                          'health-condition-details',
                                        ),
                                        controller: _conditionDetails,
                                        hint: 'Không có bệnh nền tim mạch hay huyết áp',
                                      ),
                                    ],
                                  ),
                                ),
                                if (_error != null) ...[
                                  const SizedBox(height: 12),
                                  CoachingErrorBanner(message: _error!),
                                ],
                              ],
                            ),
                          ),
                        ),
                ),
                if (!_loading)
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: isLight
                          ? colors.overlayGlass
                          : const Color(0xF0181513),
                      border: Border(
                        top: BorderSide(
                          color: colors.liquidGlassBorder.withValues(
                            alpha: 0.65,
                          ),
                        ),
                      ),
                    ),
                    child: SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                        child: SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: MetaGymTheme.brandOrange,
                              foregroundColor: MetaGymTheme.onPrimary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  MetaGymTheme.radiusInput,
                                ),
                              ),
                            ),
                            onPressed: _saving ? null : _save,
                            child: Text(
                              _saving ? 'Đang lưu...' : widget.submitLabel,
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
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
}

class _InlineYesNoPills extends StatelessWidget {
  const _InlineYesNoPills({required this.value, required this.onChanged});

  final bool? value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = MetaGymColors.of(context);
    Widget buildChip(String label, bool optionValue) {
      final selected = value == optionValue;
      return Semantics(
        button: true,
        selected: selected,
        child: Material(
          color: selected
              ? MetaGymTheme.brandOrange.withValues(alpha: 0.20)
              : colors.metricPanelBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
            side: BorderSide(
              color: selected
                  ? MetaGymTheme.brandOrange
                  : colors.metricPanelBorder,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => onChanged(optionValue),
            borderRadius: BorderRadius.circular(999),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? colors.primaryText : colors.textSecondary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  height: 1.15,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        buildChip('Không', false),
        const SizedBox(width: 6),
        buildChip('Có', true),
      ],
    );
  }
}
