import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/navigation/meta_gym_navigation.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/features/coaching/domain/coach_member_models.dart';
import 'package:meta_gym_app/features/coaching/presentation/coaching_ui.dart';

typedef EarlyTerminationRespondCallback =
    Future<void> Function(String decision, String? reason);

class EarlyTerminationCard extends StatelessWidget {
  const EarlyTerminationCard({
    required this.request,
    required this.viewerRole,
    this.busy = false,
    this.onRespond,
    this.title,
    super.key,
  });

  final CoachTerminationRequest request;
  final String viewerRole;
  final bool busy;
  final EarlyTerminationRespondCallback? onRespond;
  final String? title;

  Future<void> _confirmAndRespond(
    BuildContext context, {
    required String decision,
  }) async {
    final handler = onRespond;
    if (handler == null || busy) return;
    final result = await MetaGymNavigation.showDialogOnce<_RespondResult>(
      context: context,
      builder: (_) => EarlyTerminationRespondDialog(decision: decision),
    );
    if (result == null) return;
    await handler(decision, result.reason);
  }

  @override
  Widget build(BuildContext context) {
    final tone = switch (request.status) {
      'PENDING_COUNTERPARTY' || 'PENDING' => CoachingPillTone.amber,
      'DISPUTED' => CoachingPillTone.coral,
      'ACCEPTED' || 'ADMIN_APPROVED' || 'APPROVED' => CoachingPillTone.green,
      'ADMIN_REJECTED' || 'REJECTED' => CoachingPillTone.coral,
      _ => CoachingPillTone.neutral,
    };
    final canRespond = request.canRespondAsRole(viewerRole) && onRespond != null;
    final canWithdraw =
        request.canWithdrawAsRole(viewerRole) && onRespond != null;
    final requesterText = request.requestedByName?.isNotEmpty == true
        ? '${request.requesterRoleLabel} · ${request.requestedByName}'
        : request.requesterRoleLabel;
    final escalationLabel = request.escalationLabel;

    return CoachingGraphiteCard(
      key: Key('early-termination-card-${request.id}'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      borderColor: request.isDisputed
          ? MetaGymTheme.dangerCoral.withValues(alpha: 0.55)
          : request.isPendingCounterparty
          ? MetaGymTheme.warning.withValues(alpha: 0.50)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              CoachingPill(
                label: request.statusLabel,
                tone: tone,
                icon: request.isDisputed
                    ? Icons.gavel_rounded
                    : request.isPendingCounterparty
                    ? Icons.hourglass_top_rounded
                    : null,
              ),
              if (request.requestedByRole != null)
                Text(
                  'Gửi bởi: $requesterText',
                  style: const TextStyle(
                    color: MetaGymTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
          if (title != null && title!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              title!,
              style: const TextStyle(
                color: MetaGymTheme.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            request.reason,
            style: const TextStyle(
              color: MetaGymTheme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.45,
            ),
          ),
          if (request.isPendingCounterparty &&
              request.responseDeadlineAt != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.schedule_rounded,
                  size: 15,
                  color: MetaGymTheme.warning,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Hạn phản hồi 72h: ${formatVietnamTime(request.responseDeadlineAt)}',
                    style: const TextStyle(
                      color: Color(0xFFFFC573),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      fontFeatures: MetaGymTheme.tabularFigures,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (request.isDisputed) ...[
            const SizedBox(height: 8),
            Text(
              escalationLabel != null
                  ? '$escalationLabel. Yêu cầu đã chuyển Admin phân xử.'
                  : 'Yêu cầu đang ở trạng thái tranh chấp và chờ Admin phân xử.',
              style: const TextStyle(
                color: Color(0xFFFF987E),
                fontSize: 12.5,
                height: 1.45,
              ),
            ),
          ],
          if (request.counterpartyReason?.isNotEmpty == true) ...[
            const SizedBox(height: 6),
            Text(
              'Phản hồi đối tác: ${request.counterpartyReason}',
              style: const TextStyle(
                color: MetaGymTheme.textSecondary,
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
          ],
          if (request.adminNote?.isNotEmpty == true) ...[
            const SizedBox(height: 6),
            Text(
              'Ghi chú quản trị: ${request.adminNote}',
              style: const TextStyle(
                color: MetaGymTheme.textSecondary,
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
          ],
          if (canRespond) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    key: Key('termination-accept-${request.id}'),
                    onPressed: busy
                        ? null
                        : () => _confirmAndRespond(context, decision: 'ACCEPT'),
                    style: FilledButton.styleFrom(
                      backgroundColor: MetaGymTheme.primary,
                      foregroundColor: MetaGymTheme.onPrimary,
                      minimumSize: const Size(0, 48),
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
                    child: const Text('Chấp nhận'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    key: Key('termination-reject-${request.id}'),
                    onPressed: busy
                        ? null
                        : () => _confirmAndRespond(context, decision: 'REJECT'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFFF987E),
                      side: const BorderSide(color: Color(0xFFA54E36)),
                      minimumSize: const Size(0, 48),
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
                    child: const Text('Từ chối'),
                  ),
                ),
              ],
            ),
          ] else if (canWithdraw) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                key: Key('termination-withdraw-${request.id}'),
                onPressed: busy
                    ? null
                    : () => _confirmAndRespond(context, decision: 'WITHDRAW'),
                style: TextButton.styleFrom(
                  foregroundColor: MetaGymTheme.textSecondary,
                  minimumSize: const Size(48, 48),
                ),
                child: const Text('Rút yêu cầu'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RespondResult {
  const _RespondResult({this.reason});

  final String? reason;
}

class EarlyTerminationRespondDialog extends StatefulWidget {
  const EarlyTerminationRespondDialog({required this.decision, super.key});

  final String decision;

  @override
  State<EarlyTerminationRespondDialog> createState() =>
      _EarlyTerminationRespondDialogState();
}

class _EarlyTerminationRespondDialogState
    extends State<EarlyTerminationRespondDialog> {
  final _reasonController = TextEditingController();
  bool _showValidation = false;

  bool get _isAccept => widget.decision == 'ACCEPT';
  bool get _isReject => widget.decision == 'REJECT';

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = _isAccept
        ? 'Chấp nhận kết thúc sớm?'
        : _isReject
        ? 'Từ chối & chuyển Admin phân xử?'
        : 'Rút yêu cầu kết thúc sớm?';
    final description = _isAccept
        ? 'Quan hệ Coach sẽ kết thúc ngay lập tức. Toàn bộ buổi chưa dùng của gói hiện tại và gói chờ (nếu có) sẽ mất hiệu lực và không được hoàn tiền.'
        : _isReject
        ? 'Yêu cầu sẽ chuyển sang trạng thái tranh chấp (DISPUTED) để Admin xem xét và phán quyết. Vui lòng nhập lý do từ chối.'
        : 'Yêu cầu kết thúc sớm đang chờ sẽ bị hủy và quan hệ tiếp tục bình thường.';
    final confirmLabel = _isAccept
        ? 'Xác nhận chấp nhận'
        : _isReject
        ? 'Từ chối (Chuyển Admin)'
        : 'Xác nhận rút';

    return AlertDialog(
      backgroundColor: MetaGymTheme.darkSurface,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MetaGymTheme.radiusGlassDock),
        side: const BorderSide(color: MetaGymTheme.cardBorder, width: 1.1),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: MetaGymTheme.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            description,
            style: const TextStyle(
              color: Color(0xFFE4DAD1),
              fontSize: 13.5,
              height: 1.5,
            ),
          ),
          if (_isAccept || _isReject) ...[
            const SizedBox(height: 14),
            TextField(
              key: const Key('termination-respond-reason'),
              controller: _reasonController,
              cursorColor: MetaGymTheme.brandOrange,
              maxLength: 1000,
              maxLines: 3,
              style: const TextStyle(color: MetaGymTheme.textPrimary),
              decoration: InputDecoration(
                labelText: _isReject
                    ? 'Lý do từ chối (bắt buộc)'
                    : 'Ghi chú phản hồi (không bắt buộc)',
                labelStyle: const TextStyle(color: MetaGymTheme.textSecondary),
                errorText: _showValidation ? 'Vui lòng nhập lý do từ chối.' : null,
                filled: true,
                fillColor: MetaGymTheme.darkCanvas,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
                  borderSide: const BorderSide(color: MetaGymTheme.cardBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
                  borderSide: const BorderSide(color: MetaGymTheme.cardBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
                  borderSide: const BorderSide(color: MetaGymTheme.primary),
                ),
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(
            foregroundColor: MetaGymTheme.textSecondary,
            minimumSize: const Size(48, 48),
          ),
          child: const Text('Quay lại'),
        ),
        FilledButton(
          key: const Key('termination-respond-confirm'),
          onPressed: () {
            final reason = _reasonController.text.trim();
            if (_isReject && reason.isEmpty) {
              setState(() => _showValidation = true);
              return;
            }
            Navigator.pop(
              context,
              _RespondResult(reason: reason.isEmpty ? null : reason),
            );
          },
          style: FilledButton.styleFrom(
            backgroundColor: _isReject
                ? MetaGymTheme.dangerCoral
                : MetaGymTheme.primary,
            foregroundColor: MetaGymTheme.onPrimary,
            minimumSize: const Size(48, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
            ),
          ),
          child: Text(confirmLabel),
        ),
      ],
    );
  }
}
