import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/features/coaching/data/coach_outcome_service.dart';
import 'package:meta_gym_app/features/coaching/domain/coach_outcome_models.dart';
import 'package:meta_gym_app/features/coaching/presentation/coaching_ui.dart';
import 'package:provider/provider.dart';

class MemberOutcomeConsentPage extends StatefulWidget {
  const MemberOutcomeConsentPage({super.key});

  @override
  State<MemberOutcomeConsentPage> createState() =>
      _MemberOutcomeConsentPageState();
}

class _MemberOutcomeConsentPageState extends State<MemberOutcomeConsentPage> {
  late final _api = CoachOutcomeApi(context.read<ApiClient>());
  List<CoachOutcomeCase> _outcomes = const [];
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final outcomes = await _api.getMemberOutcomes();
      if (mounted) setState(() => _outcomes = outcomes);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Không tải được danh sách thành quả.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _respond(
    CoachOutcomeCase item, {
    String? decision,
    bool? allowRealName,
    bool removePhotos = false,
  }) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final updated = await _api.updateMemberConsent(
        item.id,
        decision: decision,
        allowRealName: allowRealName,
        removePhotos: removePhotos,
      );
      if (!mounted) return;
      setState(() {
        _outcomes = [
          for (final existing in _outcomes)
            if (existing.id == updated.id) updated else existing,
        ];
      });
      final message = switch (decision) {
        'APPROVED' => 'Đã công khai thành quả trên hồ sơ Coach',
        'DECLINED' => 'Đã từ chối công khai thành quả',
        'WITHDRAWN' => 'Đã thu hồi quyền công khai',
        _ => 'Đã cập nhật hiển thị tên',
      };
      showCoachingSnackBar(context, message);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Không cập nhật được lựa chọn. Hãy thử lại.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
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
              onTap: _busy ? null : () => Navigator.of(context).maybePop(),
            ),
            const SizedBox(width: 12),
          ],
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'HÀNH TRÌNH TẬP LUYỆN',
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
                  'Thành quả của bạn',
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
          const SizedBox(width: 8),
          MetaGymCircleIconButton(
            icon: Icons.refresh_rounded,
            tooltip: 'Tải lại',
            onTap: _loading || _busy ? null : _load,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                      : RefreshIndicator(
                          color: MetaGymTheme.brandOrange,
                          backgroundColor: const Color(0xFF282320),
                          onRefresh: _load,
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: EdgeInsets.fromLTRB(
                              16,
                              8,
                              16,
                              MediaQuery.paddingOf(context).bottom + 28,
                            ),
                            children: [
                              const Text(
                                'Chỉ những thành quả bạn đồng ý mới hiển thị trên hồ sơ Coach. Bạn có thể chọn ẩn danh hoặc thu hồi bất cứ lúc nào.',
                                style: TextStyle(
                                  color: Color(0xFFC8C2BC),
                                  fontSize: 13,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 14),
                              if (_error != null) ...[
                                CoachingErrorBanner(message: _error!),
                                if (_outcomes.isEmpty) ...[
                                  CoachingSecondaryButton(
                                    label: 'Thử lại',
                                    expand: true,
                                    onPressed: _load,
                                  ),
                                  const SizedBox(height: 12),
                                ],
                              ],
                              if (_outcomes.isEmpty && _error == null)
                                CoachingGraphiteCard(
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: const Color(0x80211E1C),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: const Color(0x9A8C8176),
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.verified_outlined,
                                          color: Color(0xFFC8C2BC),
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      const Expanded(
                                        child: Text(
                                          'Chưa có thành quả nào từ Coach.',
                                          style: TextStyle(
                                            color: Color(0xFFC8C2BC),
                                            fontSize: 13.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              for (final item in _outcomes)
                                _ConsentOutcomeItem(
                                  item: item,
                                  busy: _busy,
                                  onApprove: (allowRealName) => _respond(
                                    item,
                                    decision: 'APPROVED',
                                    allowRealName: allowRealName,
                                  ),
                                  onDecline: () => _respond(
                                    item,
                                    decision: 'DECLINED',
                                    removePhotos: true,
                                  ),
                                  onToggleName: (next) =>
                                      _respond(item, allowRealName: next),
                                  onWithdraw: () => _respond(
                                    item,
                                    decision: 'WITHDRAWN',
                                    removePhotos: true,
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
}

class _ConsentOutcomeItem extends StatefulWidget {
  const _ConsentOutcomeItem({
    required this.item,
    required this.busy,
    required this.onApprove,
    required this.onDecline,
    required this.onToggleName,
    required this.onWithdraw,
  });

  final CoachOutcomeCase item;
  final bool busy;
  final ValueChanged<bool> onApprove;
  final VoidCallback onDecline;
  final ValueChanged<bool> onToggleName;
  final VoidCallback onWithdraw;

  @override
  State<_ConsentOutcomeItem> createState() => _ConsentOutcomeItemState();
}

class _ConsentOutcomeItemState extends State<_ConsentOutcomeItem> {
  late bool _allowRealName = widget.item.allowRealName;

  @override
  void didUpdateWidget(covariant _ConsentOutcomeItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.allowRealName != widget.item.allowRealName) {
      _allowRealName = widget.item.allowRealName;
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final status = item.status;
    final previewItem = CoachOutcomeCase(
      id: item.id,
      coachId: item.coachId,
      goal: item.goal,
      durationWeeks: item.durationWeeks,
      beforeWeightKg: item.beforeWeightKg,
      afterWeightKg: item.afterWeightKg,
      beforeBodyFatPercent: item.beforeBodyFatPercent,
      afterBodyFatPercent: item.afterBodyFatPercent,
      beforePhotoUrl: item.beforePhotoUrl,
      afterPhotoUrl: item.afterPhotoUrl,
      allowRealName: _allowRealName,
      studentName: _allowRealName
          ? (item.memberName ?? 'Bạn')
          : 'Học viên ẩn danh',
      studentInitials: _allowRealName ? item.studentInitials : 'HV',
      status: item.status,
      coachName: item.coachName,
    );

    final badgeTone = switch (status) {
      'APPROVED' => CoachingPillTone.green,
      'PENDING_MEMBER' => CoachingPillTone.amber,
      _ => CoachingPillTone.neutral,
    };

    return CoachOutcomeCard(
      outcome: previewItem,
      statusBadge: CoachingPill(label: item.statusLabel, tone: badgeTone),
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (item.coachName != null) ...[
            Text(
              'Gửi bởi: ${item.coachName}',
              style: const TextStyle(color: Color(0xFFC8C2BC), fontSize: 12),
            ),
            const SizedBox(height: 8),
          ],
          if (status == 'PENDING_MEMBER' || status == 'APPROVED')
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _allowRealName,
              activeTrackColor: MetaGymTheme.primary,
              inactiveTrackColor: const Color(0xFF3A322C),
              inactiveThumbColor: const Color(0xFFC8C2BC),
              onChanged: widget.busy
                  ? null
                  : (next) {
                      setState(() => _allowRealName = next);
                      if (status == 'APPROVED') widget.onToggleName(next);
                    },
              title: const Text(
                'Học viên cho phép hiện tên thật',
                style: TextStyle(
                  color: Color(0xFFF7F9FC),
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                _allowRealName
                    ? 'Hiển thị tên thật trên hồ sơ Coach'
                    : 'Đang hiển thị là Học viên ẩn danh',
                style: const TextStyle(color: Color(0xFFC8C2BC), fontSize: 12),
              ),
            ),
          if (status == 'PENDING_MEMBER') ...[
            const SizedBox(height: 8),
            CoachingPrimaryButton(
              label: 'Duyệt công khai',
              loading: widget.busy,
              onPressed: widget.busy
                  ? null
                  : () => widget.onApprove(_allowRealName),
            ),
            const SizedBox(height: 8),
            CoachingSecondaryButton(
              label: 'Từ chối và gỡ ảnh',
              expand: true,
              onPressed: widget.busy ? null : widget.onDecline,
            ),
          ] else if (status == 'APPROVED') ...[
            const SizedBox(height: 8),
            CoachingSecondaryButton(
              label: 'Thu hồi công khai và gỡ ảnh',
              expand: true,
              onPressed: widget.busy ? null : widget.onWithdraw,
            ),
          ],
        ],
      ),
    );
  }
}
