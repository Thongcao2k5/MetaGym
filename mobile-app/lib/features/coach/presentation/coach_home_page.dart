import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:meta_gym_app/app/app_router.dart';

class CoachHomePage extends StatelessWidget {
  const CoachHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Coach')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Không gian dành cho huấn luyện viên'),
            TextButton(
              onPressed: () => context.push(AppRoutes.profile),
              child: const Text('Hồ sơ của tôi'),
            ),
          ],
        ),
      ),
    );
  }
}
