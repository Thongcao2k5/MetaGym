import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:meta_gym_app/app/feature_navigation.dart';
import 'package:meta_gym_app/app/feature_placeholder_page.dart';
import 'package:meta_gym_app/features/auth/domain/auth_models.dart';
import 'package:meta_gym_app/features/auth/presentation/login_page.dart';
import 'package:meta_gym_app/features/auth/presentation/register_page.dart';
import 'package:meta_gym_app/features/auth/presentation/session_controller.dart';
import 'package:meta_gym_app/features/catalog/presentation/gym_equipment_page.dart';
import 'package:meta_gym_app/features/coach/presentation/coach_home_page.dart';
import 'package:meta_gym_app/features/coaching/presentation/coach_selection_page.dart';
import 'package:meta_gym_app/features/coaching/presentation/coach_requests_page.dart';
import 'package:meta_gym_app/features/coaching/presentation/coach_members_page.dart';
import 'package:meta_gym_app/features/coaching/presentation/member_coaching_page.dart';
import 'package:meta_gym_app/features/member/presentation/member_home_page.dart';
import 'package:meta_gym_app/features/membership/presentation/payment_history_page.dart';
import 'package:meta_gym_app/features/profile/presentation/change_password_page.dart';
import 'package:meta_gym_app/features/profile/presentation/forgot_password_page.dart';
import 'package:meta_gym_app/features/profile/presentation/profile_page.dart';
import 'package:meta_gym_app/features/public/presentation/welcome_page.dart';
import 'package:meta_gym_app/features/sessions/presentation/member_sessions_page.dart';
import 'package:meta_gym_app/features/sessions/presentation/coach_sessions_page.dart';
import 'package:meta_gym_app/features/progress/presentation/member_progress_page.dart';
import 'package:meta_gym_app/features/progress/presentation/member_workout_page.dart';
import 'package:meta_gym_app/features/training/presentation/member_training_page.dart';
import 'package:meta_gym_app/features/training/presentation/coach_training_page.dart';
import 'package:meta_gym_app/features/training/presentation/member_nutrition_page.dart';
import 'package:meta_gym_app/features/training/presentation/coach_nutrition_page.dart';
import 'package:meta_gym_app/features/workbench/flow_action.dart';
import 'package:meta_gym_app/features/workbench/flow_workbench_page.dart';
import 'package:meta_gym_app/features/workbench/flow_workbench_config.dart';

abstract final class AppRoutes {
  static const welcome = '/';
  static const loading = '/loading';
  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';
  static const profile = '/profile';
  static const changePassword = '/profile/change-password';
  static const memberHome = '/member';
  static const coachHome = '/coach';
  static const memberWorkbench = '/member/test-flows';
  static const coachWorkbench = '/coach/test-flows';
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
        const publicRoutes = {
          AppRoutes.welcome,
          AppRoutes.login,
          AppRoutes.register,
          AppRoutes.forgotPassword,
        };
        return publicRoutes.contains(state.matchedLocation)
            ? null
            : AppRoutes.welcome;
      }

      final home = _homeForRole(sessionController.user!.role);
      const sharedProtectedRoutes = {
        AppRoutes.profile,
        AppRoutes.changePassword,
      };
      if (state.matchedLocation == home ||
          (home == AppRoutes.memberHome &&
              memberDestinations.any(
                (item) => item.path == state.matchedLocation,
              )) ||
          (home == AppRoutes.coachHome &&
              coachDestinations.any(
                (item) => item.path == state.matchedLocation,
              )) ||
          (FlowWorkbenchConfig.enabled &&
              home == AppRoutes.memberHome &&
              state.matchedLocation == AppRoutes.memberWorkbench) ||
          (FlowWorkbenchConfig.enabled &&
              home == AppRoutes.coachHome &&
              state.matchedLocation == AppRoutes.coachWorkbench) ||
          sharedProtectedRoutes.contains(state.matchedLocation)) {
        return null;
      }
      return home;
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
        path: AppRoutes.login,
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (context, state) => const ForgotPasswordPage(),
      ),
      GoRoute(
        path: AppRoutes.profile,
        builder: (context, state) => const ProfilePage(),
      ),
      GoRoute(
        path: AppRoutes.changePassword,
        builder: (context, state) => const ChangePasswordPage(),
      ),
      GoRoute(
        path: AppRoutes.memberHome,
        builder: (context, state) => const MemberHomePage(),
      ),
      GoRoute(
        path: AppRoutes.coachHome,
        builder: (context, state) => const CoachHomePage(),
      ),
      for (final destination in memberDestinations)
        GoRoute(
          path: destination.path,
          builder: (context, state) =>
              destination.path == '/member/features/payments'
              ? const PaymentHistoryPage()
              : destination.path == '/member/features/gym'
              ? const GymEquipmentPage()
              : destination.path == '/member/features/coaching'
              ? const CoachSelectionPage()
              : destination.path == '/member/features/my-coach'
              ? const MemberCoachingPage()
              : destination.path == '/member/features/training'
              ? const MemberTrainingPage()
              : destination.path == '/member/features/nutrition'
              ? const MemberNutritionPage()
              : destination.path == '/member/features/sessions'
              ? const MemberSessionsPage()
              : destination.path == '/member/features/progress'
              ? const MemberProgressPage()
              : destination.path == '/member/features/workouts'
              ? const MemberWorkoutPage()
              : FeaturePlaceholderPage(
                  destination: destination,
                  homePath: AppRoutes.memberHome,
                ),
        ),
      for (final destination in coachDestinations)
        GoRoute(
          path: destination.path,
          builder: (context, state) => destination.path == '/coach/features/gym'
              ? const GymEquipmentPage()
              : destination.path == '/coach/features/requests'
              ? CoachRequestsPage(coachId: sessionController.user!.id)
              : destination.path == '/coach/features/members'
              ? const CoachMembersPage()
              : destination.path == '/coach/features/training'
              ? const CoachTrainingPage()
              : destination.path == '/coach/features/nutrition'
              ? const CoachNutritionPage()
              : destination.path == '/coach/features/sessions'
              ? const CoachSessionsPage()
              : FeaturePlaceholderPage(
                  destination: destination,
                  homePath: AppRoutes.coachHome,
                ),
        ),
      GoRoute(
        path: AppRoutes.memberWorkbench,
        builder: (context, state) =>
            const FlowWorkbenchPage(role: FlowRole.member),
      ),
      GoRoute(
        path: AppRoutes.coachWorkbench,
        builder: (context, state) =>
            const FlowWorkbenchPage(role: FlowRole.coach),
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
