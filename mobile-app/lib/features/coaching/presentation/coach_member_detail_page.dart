import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/features/coaching/data/coach_members_service.dart';
import 'package:meta_gym_app/features/coaching/data/coach_outcome_service.dart';
import 'package:meta_gym_app/features/coaching/domain/coach_member_models.dart';
import 'package:meta_gym_app/features/coaching/domain/coach_outcome_models.dart';
import 'package:meta_gym_app/features/coaching/presentation/coaching_ui.dart';
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
    final reason = await showDialog<String>(
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

  Future<void> _submitOutcome() async {
    final apiClient = optionalProvider<ApiClient>(context);
    if (_busy || apiClient == null) return;
    final api = CoachOutcomeApi(apiClient);
    final created = await showDialog<CoachOutcomeCase>(
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
    final member = _member;
    final hasApiClient = optionalProvider<ApiClient>(context) != null;
    final pending = _requests.any(
      (request) =>
          request.relationshipId == member?.relationshipId &&
          request.status == 'PENDING',
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Hồ sơ hội viên')),
      body: _loading && member == null
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
                  ],
                  if (member != null) ...[
                    Text(
                      member.memberFullName,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text('Trạng thái: ${member.statusLabel}'),
                    Text('Email: ${member.email}'),
                    if (member.fitnessGoal?.isNotEmpty == true)
                      Text('Mục tiêu: ${member.fitnessGoal}'),
                    if (member.status == 'ACTIVE' &&
                        (member.healthDeclarationCompletedAt != null ||
                            member.healthNotes?.isNotEmpty == true ||
                            member.injuryNotes?.isNotEmpty == true)) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Khai báo thể trạng',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (member.heightCm != null)
                        Text(
                          'Chiều cao: ${member.heightCm!.toStringAsFixed(1)} cm',
                        ),
                      if (member.weightKg != null)
                        Text(
                          'Cân nặng: ${member.weightKg!.toStringAsFixed(1)} kg',
                        ),
                      if (member.bodyFatPercent != null)
                        Text(
                          'Body fat: ${member.bodyFatPercent!.toStringAsFixed(1)}%',
                        ),
                      Text(
                        'Bệnh nền: ${member.healthNotes?.isNotEmpty == true ? member.healthNotes : 'Không'}',
                      ),
                      Text(
                        'Chấn thương: ${member.injuryNotes?.isNotEmpty == true ? member.injuryNotes : 'Không'}',
                      ),
                    ],
                    const SizedBox(height: 16),
                    if (pending)
                      const Text('Yêu cầu đang chờ duyệt')
                    else
                      FilledButton(
                        onPressed: _busy ? null : _requestTermination,
                        child: const Text('Xin ngừng phụ trách'),
                      ),
                    if (_actionError != null)
                      Text(
                        _actionError!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    if (hasApiClient && member.status == 'ACTIVE') ...[
                      const SizedBox(height: 24),
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Text(
                            'Thành quả học viên',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          FilledButton.tonal(
                            onPressed: _busy ? null : _submitOutcome,
                            child: const Text('Gửi thành quả'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_outcomes.isEmpty)
                        const Text(
                          'Chưa có thành quả nào được gửi cho học viên này.',
                        )
                      else
                        for (final outcome in _outcomes)
                          Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${outcome.goal} · ${outcome.durationWeeks} tuần',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          outcome.statusLabel,
                                          textAlign: TextAlign.end,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Cân nặng: ${CoachOutcomeCase.formatNumber(outcome.beforeWeightKg)} → ${CoachOutcomeCase.formatNumber(outcome.afterWeightKg)} kg',
                                  ),
                                  if (outcome.beforeBodyFatPercent != null ||
                                      outcome.afterBodyFatPercent != null)
                                    Text(
                                      'Mỡ cơ thể: ${outcome.beforeBodyFatPercent != null ? CoachOutcomeCase.formatNumber(outcome.beforeBodyFatPercent!) : '--'}% → ${outcome.afterBodyFatPercent != null ? CoachOutcomeCase.formatNumber(outcome.afterBodyFatPercent!) : '--'}%',
                                    ),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: _busy
                                          ? null
                                          : () => _deleteOutcome(outcome),
                                      child: const Text('Xóa thành quả'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                    ],
                  ],
                ],
              ),
            ),
    );
  }
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
    return AlertDialog(
      title: const Text('Gửi thành quả học viên'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const Key('outcome-goal'),
              controller: _goal,
              decoration: const InputDecoration(
                labelText: 'Mục tiêu tập luyện',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('outcome-weeks'),
              controller: _weeks,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Số tuần đồng hành'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('outcome-before-weight'),
                    controller: _beforeWeight,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Trước (kg)'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    key: const Key('outcome-after-weight'),
                    controller: _afterWeight,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Sau (kg)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('outcome-before-fat'),
                    controller: _beforeFat,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: '% mỡ trước · tùy chọn',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    key: const Key('outcome-after-fat'),
                    controller: _afterFat,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: '% mỡ sau · tùy chọn',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : () => _pickPhoto(true),
                    child: Text(
                      _beforePhoto == null ? 'Ảnh trước' : 'Đã chọn trước',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : () => _pickPhoto(false),
                    child: Text(
                      _afterPhoto == null ? 'Ảnh sau' : 'Đã chọn sau',
                    ),
                  ),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
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
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Xin ngừng phụ trách?'),
    content: TextField(
      key: const Key('termination-request-reason'),
      controller: _reason,
      maxLength: 1000,
      maxLines: 3,
      decoration: InputDecoration(
        labelText: 'Lý do',
        errorText: _invalid ? 'Vui lòng nhập lý do.' : null,
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
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
        child: const Text('Gửi yêu cầu'),
      ),
    ],
  );
}
