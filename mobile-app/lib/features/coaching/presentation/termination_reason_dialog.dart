import 'package:flutter/material.dart';

class TerminationReasonDialog extends StatefulWidget {
  const TerminationReasonDialog({
    this.title = 'Kết thúc quan hệ Coach?',
    this.label = 'Lý do kết thúc',
    this.confirmLabel = 'Xác nhận kết thúc',
    this.maxLength = 1000,
    super.key,
  });

  final String title;
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
    title: Text(widget.title),
    content: TextFormField(
      key: const Key('termination-reason'),
      controller: _controller,
      maxLength: widget.maxLength,
      maxLines: 3,
      decoration: InputDecoration(
        labelText: widget.label,
        errorText: _showValidation ? 'Vui lòng nhập lý do.' : null,
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Quay lại'),
      ),
      FilledButton(
        onPressed: () {
          final reason = _controller.text.trim();
          if (reason.isEmpty) {
            setState(() => _showValidation = true);
            return;
          }
          Navigator.pop(context, reason);
        },
        child: Text(widget.confirmLabel),
      ),
    ],
  );
}
