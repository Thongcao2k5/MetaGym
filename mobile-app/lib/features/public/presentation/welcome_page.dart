import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:meta_gym_app/app/app_router.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.fitness_center, size: 56),
              const SizedBox(height: 16),
              Text(
                'Meta Gym',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              const Text('Đồng hành cùng hành trình luyện tập của bạn.'),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.go(AppRoutes.login),
                child: const Text('Đăng nhập'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => context.go(AppRoutes.register),
                child: const Text('Đăng ký Member'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
