import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:meta_gym_app/features/coach/presentation/coach_home_page.dart';
import 'package:meta_gym_app/features/member/presentation/member_home_page.dart';
import 'package:meta_gym_app/features/public/presentation/welcome_page.dart';

abstract final class AppRoutes {
  static const welcome = '/';
  static const memberHome = '/member';
  static const coachHome = '/coach';
}

GoRouter createAppRouter({String initialLocation = AppRoutes.welcome}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: AppRoutes.welcome,
        builder: (context, state) => const WelcomePage(),
      ),
      GoRoute(
        path: AppRoutes.memberHome,
        builder: (context, state) => const MemberHomePage(),
      ),
      GoRoute(
        path: AppRoutes.coachHome,
        builder: (context, state) => const CoachHomePage(),
      ),
    ],
    errorBuilder: (context, state) => const Scaffold(
      body: Center(child: Text('Không tìm thấy trang.')),
    ),
  );
}
