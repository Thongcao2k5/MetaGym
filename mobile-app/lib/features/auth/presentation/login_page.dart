import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:meta_gym_app/app/app_router.dart';
import 'package:meta_gym_app/features/auth/presentation/auth_controller.dart';
import 'package:provider/provider.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Đăng nhập')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          TextField(
            key: const Key('login-email'),
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: InputDecoration(
              labelText: 'Email',
              errorText: auth.fieldErrors['email'],
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('login-password'),
            controller: _passwordController,
            obscureText: true,
            autofillHints: const [AutofillHints.password],
            decoration: InputDecoration(
              labelText: 'Mật khẩu',
              errorText: auth.fieldErrors['password'],
            ),
          ),
          if (auth.errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              auth.errorMessage!,
              key: const Key('auth-error'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            key: const Key('login-submit'),
            onPressed: auth.isSubmitting
                ? null
                : () => auth.login(
                    email: _emailController.text,
                    password: _passwordController.text,
                  ),
            child: Text(auth.isSubmitting ? 'Đang đăng nhập…' : 'Đăng nhập'),
          ),
          TextButton(
            onPressed: auth.isSubmitting
                ? null
                : () => context.go(AppRoutes.register),
            child: const Text('Chưa có tài khoản? Đăng ký Member'),
          ),
        ],
      ),
    );
  }
}
