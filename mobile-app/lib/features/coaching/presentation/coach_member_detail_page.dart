import 'package:meta_gym_app/core/navigation/meta_gym_navigation.dart';
import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/features/coaching/data/coach_members_service.dart';
import 'package:meta_gym_app/features/coaching/data/coach_outcome_service.dart';
import 'package:meta_gym_app/features/coaching/domain/coach_member_models.dart';
import 'package:meta_gym_app/features/coaching/domain/coach_outcome_models.dart';
import 'package:meta_gym_app/features/coaching/presentation/coaching_ui.dart';
import 'package:meta_gym_app/features/coaching/presentation/early_termination_widgets.dart';
import 'package:meta_gym_app/features/progress/data/member_photo_service.dart';

class CoachMemberDetailPage extends StatefulWidget {
  const CoachMemberDetailPage({
    required this.memberId,
    required this.service,
    super.key,
  });

  final String memberId;
  final CoachMembersService service;

  @override
  State<CoachMemberDetailPage> createState() => _CoachMemberDetailPageState();
}

class _CoachMemberDetailPageState extends State<CoachMemberDetailPage> {
  CoachMemberDetail? _member;
  List<CoachTerminationRequest> _requests = const [];
  List<CoachOutcomeCase> _outcomes = const [];
  String? _error;
  String? _actionError;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _member = null;
      _requests = const [];
      _outcomes = const [];
      _error = null;
      _actionError = null;
    });
    try {
      final member = await widget.service.getMember(widget.memberId);
      final requests = await widget.service.getTerminationRequests();
      List<CoachOutcomeCase> outcomes = const [];
      if (mounted) {
        final apiClient = optionalProvider<ApiClient>(context);
        if (apiClient != null) {
          try {
            outcomes = await CoachOutcomeApi(apiClient)
                .getCoachMemberOutcomes(widget.memberId);
          } catch (_) {}
        }
      }
      if (!mounted) return;
      setState(() {
        _member = member;
        _requests = requests;
        _outcomes = outcomes;
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không tải được hồ sơ hội viên.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _requestTermination() async {
    final member = _member;
    if (_busy || member == null) return;
    final reason = await MetaGymNavigation.showDialogOnce<String>(
      context: context,
      builder: (_) => const _TerminationRequestDialog(),
    );
    if (reason == null ||
        !mounted ||
        _member?.relationshipId != member.relationshipId) {
      return;
    }
    setState(() {
      _busy = true;
      _actionError = null;
    });
    try {
      await widget.service.requestTermination(member.relationshipId, reason);
      if (mounted) await _load();
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          if (error.statusCode == 404 || error.statusCode == 403) {
            _member = null;
            _requests = const [];
            _error = error.message;
          } else {
            _actionError = error.message;
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _actionError = 'Không gửi được yêu cầu.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _respondTermination(
    CoachTerminationRequest request,
    String decision,
    String? reason,
  ) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _actionError = null;
    });
    try {
      await widget.service.respondTermination(
        request.id,
        decision: decision,
        reason: reason,
      );
      if (!mounted) return;
      if (decision == 'ACCEPT') {
        showCoachingSnackBar(context, 'Đã chấp nhận kết thúc sớm quan hệ.');
        await Navigator.of(context).maybePop();
        return;
      }
      await _load();
      if (!mounted) return;
      showCoachingSnackBar(
        context,
        decision == 'REJECT'
            ? 'Đã từ chối và chuyển yêu cầu sang Admin phân xử.'
            : 'Đã rút yêu cầu ngừng phụ trách.',
      );
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          if (error.statusCode == 404 || error.statusCode == 403) {
            _member = null;
            _requests = const [];
            _error = error.message;
          } else {
            _actionError = error.message;
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _actionError = 'Không xử lý được phản hồi yêu cầu.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submitOutcome() async {
    final apiClient = optionalProvider<ApiClient>(context);
    if (_busy || apiClient == null) return;
    final api = CoachOutcomeApi(apiClient);
    final created = await MetaGymNavigation.showDialogOnce<CoachOutcomeCase>(
      context: context,
      builder: (_) => _CreateOutcomeDialog(
        memberId: widget.memberId,
        api: api,
        picker: DeviceProgressPhotoPicker(),
      ),
    );
    if (created != null && mounted) {
      await _load();
      if (mounted) {
        showCoachingSnackBar(
          context,
          'Đã gửi thành quả để học viên duyệt công khai',
        );
      }
    }
  }

  Future<void> _deleteOutcome(CoachOutcomeCase outcome) async {
    final apiClient = optionalProvider<ApiClient>(context);
    if (_busy || apiClient == null) return;
    setState(() {
      _busy = true;
      _actionError = null;
    });
    try {
      await CoachOutcomeApi(apiClient).deleteCoachOutcome(outcome.id);
      if (mounted) await _load();
    } on ApiException catch (error) {
      if (mounted) setState(() => _actionError = error.message);
    } catch (_) {
      if (mounted) setState(() => _actionError = 'Không xóa được thành quả.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = MetaGymTheme.paletteOf(context);
    final isLight = MetaGymTheme.isLightPalette(context);
    final canPop = Navigator.of(context).canPop();
    final member = _member;
    final hasApiClient = optionalProvider<ApiClient>(context) != null;
    final openTermination = member == null
        ? null
        : _requests
              .where(
                (request) =>
                    request.relationshipId == member.relationshipId &&
                    request.isOpen,
              )
              .firstOrNull;
    final canRequestTermination =
        member != null &&
        openTermination == null &&
        (member.status == 'ACTIVE' ||
            (member.status == 'PAUSED' &&
                (member.pauseReason == null ||
                    member.pauseReason == 'MEMBERSHIP_EXPIRED')));
    final showHealth =
        member != null &&
        member.status == 'ACTIVE' &&
        (member.healthDeclarationCompletedAt != null ||
            member.healthNotes?.isNotEmpty == true ||
            member.injuryNotes?.isNotEmpty == true);

    return Scaffold(
      backgroundColor: palette.canvas,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leadingWidth: canPop ? 72 : null,
        leading: canPop
            ? Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: MetaGymCircleIconButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip: 'Quay lại',
                    onTap: _busy ? null : () => Navigator.of(context).maybePop(),
                  ),
                ),
              )
            : null,
        title: Text(
          'Hồ sơ hội viên',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: palette.textPrimary,
            fontSize: 19,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: MetaGymCircleIconButton(
                icon: Icons.refresh_rounded,
                tooltip: 'Tải lại',
                onTap: _busy ? null : _load,
              ),
            ),
          ),
        ],
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: palette.textPrimary),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const MetaGymBackground(),
          SafeArea(
            child: _loading && member == null
                ? const Center(
                    child: CircularProgressIndicator(
                      color: MetaGymTheme.brandOrange,
                    ),
                  )
                : RefreshIndicator(
                    color: MetaGymTheme.brandOrange,
                    backgroundColor: isLight
                        ? palette.surfaceSolid
                        : const Color(0xFF282320),
                    onRefresh: _load,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        16,
                        12,
                        16,
                        MediaQuery.paddingOf(context).bottom + 28,
                      ),
                      children: [
                        if (_error != null) ...[
                          CoachingErrorBanner(message: _error!),
                          CoachingSecondaryButton(
                            label: 'Thử lại',
                            expand: true,
                            onPressed: _load,
                          ),
                        ],
                        if (member != null) ...[
                          _MemberHeroCard(member: member),
                          if (showHealth)
                            _HealthDeclarationCard(member: member),
                          if (openTermination != null)
                            EarlyTerminationCard(
                              request: openTermination,
                              viewerRole: 'COACH',
                              busy: _busy,
                              onRespond: (decision, reason) =>
                                  _respondTermination(
                                    openTermination,
                                    decision,
                                    reason,
                                  ),
                            )
                          else if (canRequestTermination)
                            MetaGymGlassCard(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  CoachingSecondaryButton(
                                    label: 'Xin ngừng phụ trách',
                                    expand: true,
                                    onPressed: _busy
                                        ? null
                                        : _requestTermination,
                                  ),
                                ],
                              ),
                            ),
                          if (_actionError != null) ...[
                            CoachingErrorBanner(message: _actionError!),
                          ],
                          if (hasApiClient && member.status == 'ACTIVE') ...[
                            Padding(
                              padding: const EdgeInsets.only(
                                top: 6,
                                bottom: 12,
                              ),
                              child: Wrap(
                                alignment: WrapAlignment.spaceBetween,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  Text(
                                    'Thành quả học viên',
                                    style: TextStyle(
                                      color: palette.textPrimary,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  FilledButton.icon(
                                    onPressed: _busy ? null : _submitOutcome,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: MetaGymTheme.primary,
                                      foregroundColor: MetaGymTheme.onPrimary,
                                      minimumSize: const Size(48, 48),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 10,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          MetaGymTheme.radiusInput,
                                        ),
                                      ),
                                      textStyle: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    icon: const Icon(
                                      Icons.add_rounded,
                                      size: 18,
                                    ),
                                    label: const Text('Gửi thành quả'),
                                  ),
                                ],
                              ),
                            ),
                            if (_outcomes.isEmpty)
                              MetaGymGlassCard(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.emoji_events_outlined,
                                      color: palette.textWarmMuted,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Chưa có thành quả nào được gửi cho học viên này.',
                                        style: TextStyle(
                                          color: palette.textWarmMuted,
                                          fontSize: 13,
                                          height: 1.45,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              for (final outcome in _outcomes)
                                CoachOutcomeCard(
                                  outcome: outcome,
                                  statusBadge: CoachingPill(
                                    label: outcome.statusLabel,
                                    tone: switch (outcome.status) {
                                      'APPROVED' => CoachingPillTone.green,
                                      'PENDING_MEMBER' =>
                                        CoachingPillTone.amber,
                                      'DECLINED' => CoachingPillTone.coral,
                                      _ => CoachingPillTone.neutral,
                                    },
                                  ),
                                  footer: Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton.icon(
                                      onPressed: _busy
                                          ? null
                                          : () => _deleteOutcome(outcome),
                                      style: TextButton.styleFrom(
                                        foregroundColor: palette.error,
                                        minimumSize: const Size(48, 48),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                        ),
                                      ),
                                      icon: const Icon(
                                        Icons.delete_outline_rounded,
                                        size: 18,
                                      ),
                                      label: const Text('Xóa thành quả'),
                                    ),
                                  ),
                                ),
                          ],
                        ],
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _MemberHeroCard extends StatelessWidget {
  const _MemberHeroCard({required this.member});

  final CoachMemberDetail member;

  @override
  Widget build(BuildContext context) {
    final palette = MetaGymTheme.paletteOf(context);
    final isLight = MetaGymTheme.isLightPalette(context);
    final isActive = member.status == 'ACTIVE';
    return MetaGymHeroGlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CoachingAvatar(
                fullName: member.memberFullName,
                size: 54,
                round: true,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.memberFullName,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      member.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.textWarmMuted,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    CoachingPill(
                      label: member.statusLabel,
                      tone: isActive
                          ? CoachingPillTone.green
                          : CoachingPillTone.amber,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (member.fitnessGoal?.isNotEmpty == true) ...[
            Divider(
              color: isLight ? palette.borderSolid : const Color(0x26FFF5E9),
              height: 24,
            ),
            Text(
              'Mục tiêu: ${member.fitnessGoal}',
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.45,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HealthDeclarationCard extends StatelessWidget {
  const _HealthDeclarationCard({required this.member});

  final CoachMemberDetail member;

  @override
  Widget build(BuildContext context) {
    final palette = MetaGymTheme.paletteOf(context);
    final isLight = MetaGymTheme.isLightPalette(context);
    return MetaGymGlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.monitor_heart_outlined,
                color: palette.primaryText,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Khai báo thể trạng',
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (member.heightCm != null)
            _HealthInfoLine(
              text: 'Chiều cao: ${member.heightCm!.toStringAsFixed(1)} cm',
            ),
          if (member.weightKg != null)
            _HealthInfoLine(
              text: 'Cân nặng: ${member.weightKg!.toStringAsFixed(1)} kg',
            ),
          if (member.bodyFatPercent != null)
            _HealthInfoLine(
              text: 'Tỷ lệ mỡ: ${member.bodyFatPercent!.toStringAsFixed(1)}%',
            ),
          if (member.heightCm != null ||
              member.weightKg != null ||
              member.bodyFatPercent != null)
            Divider(
              color: isLight ? palette.borderSolid : const Color(0x26FFF5E9),
              height: 18,
            ),
          _HealthInfoLine(
            text:
                'Bệnh nền: ${member.healthNotes?.isNotEmpty == true ? member.healthNotes : 'Không'}',
          ),
          _HealthInfoLine(
            text:
                'Chấn thương: ${member.injuryNotes?.isNotEmpty == true ? member.injuryNotes : 'Không'}',
          ),
        ],
      ),
    );
  }
}

class _HealthInfoLine extends StatelessWidget {
  const _HealthInfoLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = MetaGymTheme.paletteOf(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          color: palette.textPrimary,
          fontSize: 13.5,
          height: 1.45,
          fontFeatures: MetaGymTheme.tabularFigures,
        ),
      ),
    );
  }
}

InputDecoration _adaptiveInputDecoration(
  BuildContext context, {
  required String label,
  String? errorText,
}) {
  final palette = MetaGymTheme.paletteOf(context);
  return InputDecoration(
    labelText: label,
    labelStyle: TextStyle(color: palette.textSecondary, fontSize: 13),
    counterStyle: TextStyle(color: palette.textSecondary, fontSize: 11.5),
    filled: true,
    fillColor: palette.metricPanelBg,
    errorText: errorText,
    errorStyle: TextStyle(color: palette.error),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
      borderSide: BorderSide(color: palette.metricPanelBorder),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
      borderSide: BorderSide(color: palette.metricPanelBorder),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
      borderSide: const BorderSide(color: MetaGymTheme.brandOrange, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
      borderSide: BorderSide(color: palette.error),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
      borderSide: BorderSide(color: palette.error, width: 1.5),
    ),
  );
}

class _CreateOutcomeDialog extends StatefulWidget {
  const _CreateOutcomeDialog({
    required this.memberId,
    required this.api,
    required this.picker,
  });

  final String memberId;
  final CoachOutcomeApi api;
  final ProgressPhotoPicker picker;

  @override
  State<_CreateOutcomeDialog> createState() => _CreateOutcomeDialogState();
}

class _CreateOutcomeDialogState extends State<_CreateOutcomeDialog> {
  final _goal = TextEditingController();
  final _weeks = TextEditingController(text: '12');
  final _beforeWeight = TextEditingController();
  final _afterWeight = TextEditingController();
  final _beforeFat = TextEditingController();
  final _afterFat = TextEditingController();
  SelectedProgressImage? _beforePhoto;
  SelectedProgressImage? _afterPhoto;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final controller in [
      _goal,
      _weeks,
      _beforeWeight,
      _afterWeight,
      _beforeFat,
      _afterFat,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  double? _parseNumber(String raw) =>
      double.tryParse(raw.trim().replaceAll(',', '.'));

  Future<void> _pickPhoto(bool isBefore) async {
    try {
      final selected = await widget.picker.pick();
      if (selected == null || !mounted) return;
      final validation = validateProgressImage(selected);
      if (validation != null) {
        setState(() => _error = validation);
        return;
      }
      setState(() {
        _error = null;
        if (isBefore) {
          _beforePhoto = selected;
        } else {
          _afterPhoto = selected;
        }
      });
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không chọn được ảnh.');
    }
  }

  Future<void> _submit() async {
    if (_saving) return;
    final goal = _goal.text.trim();
    final weeks = int.tryParse(_weeks.text.trim());
    final bw = _parseNumber(_beforeWeight.text);
    final aw = _parseNumber(_afterWeight.text);
    final bf = _beforeFat.text.trim().isEmpty
        ? null
        : _parseNumber(_beforeFat.text);
    final af = _afterFat.text.trim().isEmpty
        ? null
        : _parseNumber(_afterFat.text);
    if (goal.isEmpty ||
        weeks == null ||
        weeks <= 0 ||
        bw == null ||
        bw <= 0 ||
        aw == null ||
        aw <= 0) {
      setState(
        () => _error = 'Hãy nhập đủ mục tiêu, số tuần và cân nặng trước/sau.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      String? beforeMediaId;
      String? afterMediaId;
      if (_beforePhoto != null) {
        beforeMediaId = await widget.api.uploadOutcomePhoto(_beforePhoto!);
      }
      if (_afterPhoto != null) {
        afterMediaId = await widget.api.uploadOutcomePhoto(_afterPhoto!);
      }
      final created = await widget.api.submitOutcome(
        widget.memberId,
        goal: goal,
        durationWeeks: weeks,
        beforeWeightKg: bw,
        afterWeightKg: aw,
        beforeBodyFatPercent: bf,
        afterBodyFatPercent: af,
        beforeMediaId: beforeMediaId,
        afterMediaId: afterMediaId,
      );
      if (mounted) Navigator.pop(context, created);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không gửi được thành quả.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = MetaGymTheme.paletteOf(context);
    final isLight = MetaGymTheme.isLightPalette(context);
    return AlertDialog(
      backgroundColor: isLight ? palette.surfaceSolid : const Color(0xF0241F1B),
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MetaGymTheme.radiusGlassDock),
        side: BorderSide(
          color: isLight ? palette.borderSolid : const Color(0xA3A79D92),
          width: 1.1,
        ),
      ),
      title: Text(
        'Gửi thành quả học viên',
        style: TextStyle(
          color: palette.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const Key('outcome-goal'),
              controller: _goal,
              cursorColor: MetaGymTheme.brandOrange,
              style: TextStyle(color: palette.textPrimary),
              decoration: _adaptiveInputDecoration(
                context,
                label: 'Mục tiêu tập luyện',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const Key('outcome-weeks'),
              controller: _weeks,
              cursorColor: MetaGymTheme.brandOrange,
              keyboardType: TextInputType.number,
              style: TextStyle(
                color: palette.textPrimary,
                fontFeatures: MetaGymTheme.tabularFigures,
              ),
              decoration: _adaptiveInputDecoration(
                context,
                label: 'Số tuần đồng hành',
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('outcome-before-weight'),
                    controller: _beforeWeight,
                    cursorColor: MetaGymTheme.brandOrange,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontFeatures: MetaGymTheme.tabularFigures,
                    ),
                    decoration: _adaptiveInputDecoration(
                      context,
                      label: 'Trước (kg)',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    key: const Key('outcome-after-weight'),
                    controller: _afterWeight,
                    cursorColor: MetaGymTheme.brandOrange,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontFeatures: MetaGymTheme.tabularFigures,
                    ),
                    decoration: _adaptiveInputDecoration(
                      context,
                      label: 'Sau (kg)',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('outcome-before-fat'),
                    controller: _beforeFat,
                    cursorColor: MetaGymTheme.brandOrange,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontFeatures: MetaGymTheme.tabularFigures,
                    ),
                    decoration: _adaptiveInputDecoration(
                      context,
                      label: '% mỡ trước · tùy chọn',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    key: const Key('outcome-after-fat'),
                    controller: _afterFat,
                    cursorColor: MetaGymTheme.brandOrange,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontFeatures: MetaGymTheme.tabularFigures,
                    ),
                    decoration: _adaptiveInputDecoration(
                      context,
                      label: '% mỡ sau · tùy chọn',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : () => _pickPhoto(true),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: palette.textPrimary,
                      backgroundColor: palette.metricPanelBg,
                      minimumSize: const Size(48, 48),
                      side: BorderSide(
                        color: _beforePhoto != null
                            ? palette.success
                            : palette.metricPanelBorder,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          MetaGymTheme.radiusInput,
                        ),
                      ),
                    ),
                    child: Text(
                      _beforePhoto == null ? 'Ảnh trước' : 'Đã chọn trước',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : () => _pickPhoto(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: palette.textPrimary,
                      backgroundColor: palette.metricPanelBg,
                      minimumSize: const Size(48, 48),
                      side: BorderSide(
                        color: _afterPhoto != null
                            ? palette.success
                            : palette.metricPanelBorder,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          MetaGymTheme.radiusInput,
                        ),
                      ),
                    ),
                    child: Text(
                      _afterPhoto == null ? 'Ảnh sau' : 'Đã chọn sau',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              CoachingErrorBanner(message: _error!),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          style: TextButton.styleFrom(
            foregroundColor: palette.textWarmMuted,
            minimumSize: const Size(48, 48),
          ),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          style: FilledButton.styleFrom(
            backgroundColor: MetaGymTheme.primary,
            foregroundColor: MetaGymTheme.onPrimary,
            minimumSize: const Size(48, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
            ),
          ),
          child: Text(_saving ? 'Đang gửi...' : 'Gửi học viên duyệt'),
        ),
      ],
    );
  }
}

class _TerminationRequestDialog extends StatefulWidget {
  const _TerminationRequestDialog();

  @override
  State<_TerminationRequestDialog> createState() =>
      _TerminationRequestDialogState();
}

class _TerminationRequestDialogState extends State<_TerminationRequestDialog> {
  final _reason = TextEditingController();
  bool _invalid = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = MetaGymTheme.paletteOf(context);
    final isLight = MetaGymTheme.isLightPalette(context);
    return AlertDialog(
      backgroundColor: isLight ? palette.surfaceSolid : const Color(0xF0241F1B),
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MetaGymTheme.radiusGlassDock),
        side: BorderSide(
          color: isLight ? palette.borderSolid : const Color(0xA3A79D92),
          width: 1.1,
        ),
      ),
      title: Text(
        'Xin ngừng phụ trách?',
        style: TextStyle(
          color: palette.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      content: TextField(
        key: const Key('termination-request-reason'),
        controller: _reason,
        cursorColor: MetaGymTheme.brandOrange,
        maxLength: 1000,
        maxLines: 3,
        style: TextStyle(color: palette.textPrimary),
        decoration: _adaptiveInputDecoration(
          context,
          label: 'Lý do',
          errorText: _invalid ? 'Vui lòng nhập lý do.' : null,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(
            foregroundColor: palette.textWarmMuted,
            minimumSize: const Size(48, 48),
          ),
          child: const Text('Quay lại'),
        ),
        FilledButton(
          onPressed: () {
            final reason = _reason.text.trim();
            if (reason.isEmpty) {
              setState(() => _invalid = true);
              return;
            }
            Navigator.pop(context, reason);
          },
          style: FilledButton.styleFrom(
            backgroundColor: MetaGymTheme.primary,
            foregroundColor: MetaGymTheme.onPrimary,
            minimumSize: const Size(48, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
            ),
          ),
          child: const Text('Gửi yêu cầu'),
        ),
      ],
    );
  }
}
