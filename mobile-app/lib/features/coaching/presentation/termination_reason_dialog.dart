import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';

class TerminationReasonDialog extends StatefulWidget {
  const TerminationReasonDialog({
    this.title = 'Yêu cầu kết thúc sớm?',
    this.description =
        'Yêu cầu sẽ gửi tới đối tác với thời hạn phản hồi 72 giờ. Nếu đối tác từ chối hoặc quá hạn, yêu cầu sẽ tự chuyển Admin phân xử.',
    this.label = 'Lý do kết thúc sớm',
    this.confirmLabel = 'Xác nhận kết thúc',
    this.maxLength = 1000,
    super.key,
  });

  final String title;
  final String? description;
  final String label;
  final String confirmLabel;
  final int maxLength;

  @override
  State<TerminationReasonDialog> createState() =>
      _TerminationReasonDialogState();
}

class _TerminationReasonDialogState extends State<TerminationReasonDialog> {
  final _controller = TextEditingController();
  bool _showValidation = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: MetaGymTheme.darkSurface,
    surfaceTintColor: Colors.transparent,
    insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(MetaGymTheme.radiusGlassDock),
      side: const BorderSide(color: MetaGymTheme.cardBorder, width: 1.1),
    ),
    title: Text(
      widget.title,
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
        if (widget.description != null) ...[
          Text(
            widget.description!,
            style: const TextStyle(
              color: Color(0xFFE4DAD1),
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
        ],
        TextFormField(
          key: const Key('termination-reason'),
          controller: _controller,
          cursorColor: MetaGymTheme.brandOrange,
          maxLength: widget.maxLength,
          maxLines: 3,
          style: const TextStyle(color: MetaGymTheme.textPrimary),
          decoration: InputDecoration(
            labelText: widget.label,
            labelStyle: const TextStyle(color: MetaGymTheme.textSecondary),
            errorText: _showValidation ? 'Vui lòng nhập lý do.' : null,
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
        key: const Key('termination-submit-btn'),
        onPressed: () {
          final reason = _controller.text.trim();
          if (reason.isEmpty) {
            setState(() => _showValidation = true);
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
        child: Text(widget.confirmLabel),
      ),
    ],
  );
}
