import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:meta_gym_app/app/app_router.dart';
import 'package:meta_gym_app/features/auth/domain/auth_models.dart';
import 'package:meta_gym_app/features/auth/presentation/session_controller.dart';
import 'package:meta_gym_app/features/profile/presentation/profile_controller.dart';
import 'package:provider/provider.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _roleFieldController = TextEditingController();
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _fillFields(context.read<SessionController>().user!);
    _reloadProfile();
  }

  Future<void> _reloadProfile() async {
    if (!await context.read<ProfileController>().load() || !mounted) return;
    _fillFields(context.read<SessionController>().user!);
    setState(() {});
  }

  void _fillFields(AuthUser user) {
    _nameController.text = user.fullName;
    _phoneController.text = user.phone ?? '';
    _roleFieldController.text = switch (user.role) {
      UserRole.member => user.profile['fitnessGoal'] as String? ?? '',
      UserRole.coach => user.profile['biography'] as String? ?? '',
      UserRole.admin => '',
    };
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _roleFieldController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileController>();
    final user = context.watch<SessionController>().user!;
    return Scaffold(
      appBar: AppBar(title: const Text('Hồ sơ')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(user.email, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Họ và tên'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Số điện thoại'),
          ),
          if (user.role != UserRole.admin) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _roleFieldController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: user.role == UserRole.member
                    ? 'Mục tiêu tập luyện'
                    : 'Giới thiệu huấn luyện viên',
              ),
            ),
          ],
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
                : () => profile.updateProfile(
                    fullName: _nameController.text,
                    phone: _phoneController.text,
                    fitnessGoal: _roleFieldController.text,
                    biography: _roleFieldController.text,
                  ),
            child: Text(profile.isBusy ? 'Đang lưu…' : 'Lưu hồ sơ'),
          ),
          OutlinedButton(
            onPressed: profile.isBusy
                ? null
                : () => context.push(AppRoutes.changePassword),
            child: const Text('Đổi mật khẩu'),
          ),
        ],
      ),
    );
  }
}
