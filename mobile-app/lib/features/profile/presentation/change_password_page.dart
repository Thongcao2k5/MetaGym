import 'package:flutter/material.dart';
import 'package:meta_gym_app/features/profile/presentation/profile_controller.dart';
import 'package:provider/provider.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Đổi mật khẩu')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          TextField(
            controller: _currentController,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Mật khẩu hiện tại'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _newController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Mật khẩu mới',
              helperText: 'Ít nhất 8 ký tự, có chữ hoa, chữ thường và chữ số',
            ),
          ),
          if (profile.errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              profile.errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: profile.isBusy
                ? null
                : () => profile.changePassword(
                    currentPassword: _currentController.text,
                    newPassword: _newController.text,
                  ),
            child: Text(profile.isBusy ? 'Đang đổi…' : 'Đổi mật khẩu'),
          ),
        ],
      ),
    );
  }
}
