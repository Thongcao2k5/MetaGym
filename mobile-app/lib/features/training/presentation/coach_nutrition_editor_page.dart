import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/features/coaching/presentation/coaching_ui.dart';
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
      barrierColor: const Color(0xB8040609),
      builder: (dialogContext) => AlertDialog(
        backgroundColor: MetaGymTheme.cardSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MetaGymTheme.radiusGlassDock),
          side: const BorderSide(color: MetaGymTheme.cardBorder),
        ),
        title: const Text(
          'Công bố hướng dẫn?',
          style: TextStyle(
            color: MetaGymTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: const Text(
          'Member sẽ thấy hướng dẫn này; bản cũ chuyển vào lịch sử.',
          style: TextStyle(
            color: MetaGymTheme.textSecondary,
            fontSize: 14,
            height: 1.45,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            style: TextButton.styleFrom(
              foregroundColor: MetaGymTheme.textSecondary,
              minimumSize: const Size(48, 44),
            ),
            child: const Text('Quay lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: MetaGymTheme.primary,
              foregroundColor: MetaGymTheme.onPrimary,
              minimumSize: const Size(48, 44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
              ),
            ),
            child: const Text('Xác nhận công bố'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) await _save(publish: true);
  }

  CoachingPillTone _guideTone(String status) => switch (status) {
    'ACTIVE' => CoachingPillTone.green,
    'DRAFT' => CoachingPillTone.amber,
    _ => CoachingPillTone.neutral,
  };

  IconData _guideIcon(String status) => switch (status) {
    'ACTIVE' => Icons.eco_outlined,
    'DRAFT' => Icons.edit_note_rounded,
    _ => Icons.history_rounded,
  };

  Color _guideAccent(String status) => switch (status) {
    'ACTIVE' => MetaGymTheme.success,
    'DRAFT' => MetaGymTheme.warning,
    _ => MetaGymTheme.reflectionBlue,
  };

  InputDecoration _darkInputDecoration({
    required String labelText,
    String? hintText,
    required bool enabled,
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
      borderSide: BorderSide(
        color: enabled
            ? MetaGymTheme.darkBorderStrong
            : MetaGymTheme.cardBorder,
      ),
    );
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      filled: true,
      fillColor: enabled
          ? MetaGymTheme.elevatedSurface
          : MetaGymTheme.cardSurface,
      labelStyle: const TextStyle(
        color: MetaGymTheme.textSecondary,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      floatingLabelStyle: const TextStyle(
        color: MetaGymTheme.reflectionBlue,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      hintStyle: TextStyle(
        color: MetaGymTheme.textSecondary.withValues(alpha: 0.65),
        fontSize: 13.5,
      ),
      counterStyle: const TextStyle(
        color: MetaGymTheme.textSecondary,
        fontSize: 11,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: border,
      enabledBorder: border,
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
        borderSide: const BorderSide(color: MetaGymTheme.cardBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
        borderSide: const BorderSide(color: MetaGymTheme.focusBlue, width: 1.8),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editable = _guide == null || _guide?.status == 'DRAFT';
    final media = MediaQuery.paddingOf(context);
    final canPop = Navigator.of(context).canPop();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: MetaGymTheme.scaffoldBackground,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leadingWidth: 72,
          leading: canPop
              ? Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: MetaGymCircleIconButton(
                      icon: Icons.arrow_back_ios_new_rounded,
                      tooltip: 'Quay lại',
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                )
              : null,
          titleSpacing: canPop ? 8 : 16,
          title: const Text(
            'Hướng dẫn dinh dưỡng',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: MetaGymTheme.textPrimary,
              fontSize: 19,
              fontWeight: FontWeight.w700,
            ),
          ),
          backgroundColor: Colors.transparent,
          foregroundColor: MetaGymTheme.textPrimary,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            const MetaGymBackground(),
            ListView(
              padding: EdgeInsets.fromLTRB(
                16,
                media.top + kToolbarHeight + 12,
                16,
                media.bottom + 32,
              ),
              children: [
                if (_guide != null)
                  CoachingGraphiteCard(
                    margin: const EdgeInsets.only(bottom: 14),
                    borderColor: _guide!.status == 'ACTIVE'
                        ? MetaGymTheme.success.withValues(alpha: 0.40)
                        : null,
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: _guideAccent(_guide!.status)
                                .withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(13),
                            border: Border.all(
                              color: _guideAccent(_guide!.status)
                                  .withValues(alpha: 0.35),
                            ),
                          ),
                          child: Icon(
                            _guideIcon(_guide!.status),
                            color: _guideAccent(_guide!.status),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CoachingPill(
                                label:
                                    '${_guide!.statusLabel} · Phiên bản ${_guide!.version}',
                                tone: _guideTone(_guide!.status),
                                icon: _guideIcon(_guide!.status),
                              ),
                              if (_guide!.publishedAt != null) ...[
                                const SizedBox(height: 6),
                                Text(
                                  _guide!.publicationLabel,
                                  style: const TextStyle(
                                    color: MetaGymTheme.textSecondary,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_error != null) CoachingErrorBanner(message: _error!),
                CoachingGraphiteCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.restaurant_menu_rounded,
                            color: MetaGymTheme.success,
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Nội dung hướng dẫn',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: MetaGymTheme.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        key: const Key('guide-title'),
                        controller: _title,
                        enabled: editable && !_busy,
                        maxLength: 150,
                        style: TextStyle(
                          color: editable
                              ? MetaGymTheme.textPrimary
                              : MetaGymTheme.textSecondary,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: _darkInputDecoration(
                          labelText: 'Tiêu đề',
                          hintText: 'VD: Thực đơn tăng cơ tuần 1',
                          enabled: editable && !_busy,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        key: const Key('guide-content'),
                        controller: _content,
                        enabled: editable && !_busy,
                        maxLength: 20000,
                        minLines: 5,
                        maxLines: 12,
                        style: TextStyle(
                          color: editable
                              ? MetaGymTheme.textPrimary
                              : MetaGymTheme.textSecondary,
                          fontSize: 14.5,
                          height: 1.5,
                        ),
                        decoration: _darkInputDecoration(
                          labelText: 'Nội dung',
                          hintText: 'Nhập khẩu phần, lượng đạm, giờ ăn và lưu ý dinh dưỡng...',
                          enabled: editable && !_busy,
                        ),
                      ),
                    ],
                  ),
                ),
                if (editable) ...[
                  const SizedBox(height: 16),
                  if (_guide?.status == 'DRAFT')
                    Row(
                      children: [
                        Expanded(
                          child: CoachingSecondaryButton(
                            label: 'Lưu bản nháp',
                            onPressed: _busy ? null : _save,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: CoachingPrimaryButton(
                            label: 'Công bố',
                            loading: _busy,
                            onPressed: _busy ? null : _confirmPublish,
                          ),
                        ),
                      ],
                    )
                  else
                    CoachingPrimaryButton(
                      label: 'Lưu bản nháp',
                      loading: _busy,
                      onPressed: _busy ? null : _save,
                    ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
