import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:meta_gym_app/app/app_router.dart';
import 'package:meta_gym_app/features/auth/presentation/auth_controller.dart';
import 'package:provider/provider.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Đăng ký Member')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          TextField(
            key: const Key('register-name'),
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Họ và tên',
              errorText: auth.fieldErrors['fullName'],
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('register-email'),
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'Email',
              errorText: auth.fieldErrors['email'],
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('register-password'),
            controller: _passwordController,
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'Mật khẩu',
              helperText: 'Ít nhất 8 ký tự, có chữ hoa, chữ thường và chữ số',
              errorText: auth.fieldErrors['password'],
            ),
          ),
          if (auth.errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              auth.errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            key: const Key('register-submit'),
            onPressed: auth.isSubmitting
                ? null
                : () => auth.register(
                    fullName: _nameController.text,
                    email: _emailController.text,
                    password: _passwordController.text,
                  ),
            child: Text(auth.isSubmitting ? 'Đang đăng ký…' : 'Đăng ký'),
          ),
          TextButton(
            onPressed: auth.isSubmitting
                ? null
                : () => context.go(AppRoutes.login),
            child: const Text('Đã có tài khoản? Đăng nhập'),
          ),
        ],
      ),
    );
  }
}
