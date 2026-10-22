import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:meta_gym_app/features/auth/domain/auth_models.dart';
import 'package:meta_gym_app/features/auth/presentation/session_controller.dart';
import 'package:meta_gym_app/features/coach/presentation/coach_home_page.dart';
import 'package:meta_gym_app/features/member/presentation/member_home_page.dart';
import 'package:meta_gym_app/features/public/presentation/welcome_page.dart';

abstract final class AppRoutes {
  static const welcome = '/';
  static const loading = '/loading';
  static const memberHome = '/member';
  static const coachHome = '/coach';
  static const adminHome = '/admin';
}

GoRouter createAppRouter({
  required SessionController sessionController,
  String initialLocation = AppRoutes.welcome,
}) {
  return GoRouter(
    initialLocation: initialLocation,
    refreshListenable: sessionController,
    redirect: (context, state) {
      if (sessionController.status == SessionStatus.restoring) {
        return state.matchedLocation == AppRoutes.loading
            ? null
            : AppRoutes.loading;
      }
      if (sessionController.status == SessionStatus.unauthenticated) {
        return state.matchedLocation == AppRoutes.welcome
            ? null
            : AppRoutes.welcome;
      }

      final home = _homeForRole(sessionController.user!.role);
      return state.matchedLocation == home ? null : home;
    },
    routes: [
      GoRoute(
        path: AppRoutes.loading,
        builder: (context, state) =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
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
      GoRoute(
        path: AppRoutes.adminHome,
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Không gian dành cho quản trị viên')),
        ),
      ),
    ],
    errorBuilder: (context, state) =>
        const Scaffold(body: Center(child: Text('Không tìm thấy trang.'))),
  );
}

String _homeForRole(UserRole role) => switch (role) {
  UserRole.member => AppRoutes.memberHome,
  UserRole.coach => AppRoutes.coachHome,
  UserRole.admin => AppRoutes.adminHome,
};
