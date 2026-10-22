import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:meta_gym_app/app/app_router.dart';
import 'package:meta_gym_app/features/profile/presentation/password_reset_controller.dart';
import 'package:provider/provider.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _inputController = TextEditingController();

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reset = context.watch<PasswordResetController>();
    final (title, label, action) = switch (reset.step) {
      PasswordResetStep.requestCode => (
        'Quên mật khẩu',
        'Email',
        () => reset.requestCode(_inputController.text),
      ),
      PasswordResetStep.verifyCode => (
        'Xác minh mã',
        'Mã gồm 6 chữ số',
        () => reset.verifyCode(_inputController.text),
      ),
      PasswordResetStep.setPassword => (
        'Đặt mật khẩu mới',
        'Mật khẩu mới',
        () => reset.resetPassword(_inputController.text),
      ),
      PasswordResetStep.completed => (
        'Đã đổi mật khẩu',
        '',
        () async {
          context.go(AppRoutes.login);
          return false;
        },
      ),
    };
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (reset.step != PasswordResetStep.completed)
            TextField(
              controller: _inputController,
              obscureText: reset.step == PasswordResetStep.setPassword,
              keyboardType: reset.step == PasswordResetStep.verifyCode
                  ? TextInputType.number
                  : null,
              decoration: InputDecoration(labelText: label),
            )
          else
            const Text('Mật khẩu đã được cập nhật. Hãy đăng nhập lại.'),
          if (reset.errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              reset.errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: reset.isBusy
                ? null
                : () async {
                    final previousStep = reset.step;
                    final succeeded = await action();
                    if (succeeded && previousStep != reset.step) {
                      _inputController.clear();
                    }
                  },
            child: Text(
              reset.step == PasswordResetStep.completed
                  ? 'Về đăng nhập'
                  : reset.isBusy
                  ? 'Đang xử lý…'
                  : 'Tiếp tục',
            ),
          ),
        ],
      ),
    );
  }
}
