import 'package:flutter/material.dart';

class TerminationReasonDialog extends StatefulWidget {
  const TerminationReasonDialog({super.key});

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
    title: const Text('Kết thúc quan hệ Coach?'),
    content: TextField(
      key: const Key('termination-reason'),
      controller: _controller,
      maxLength: 1000,
      maxLines: 3,
      decoration: InputDecoration(
        labelText: 'Lý do kết thúc',
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
        child: const Text('Xác nhận kết thúc'),
      ),
    ],
  );
}
