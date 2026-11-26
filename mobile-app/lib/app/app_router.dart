import 'package:meta_gym_app/features/admin/presentation/admin_home_page.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:meta_gym_app/app/feature_navigation.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/features/auth/domain/auth_models.dart';
import 'package:meta_gym_app/features/auth/presentation/auth_controller.dart';
import 'package:meta_gym_app/features/auth/presentation/auth_glass_scaffold.dart';
import 'package:meta_gym_app/features/auth/presentation/login_page.dart';
import 'package:meta_gym_app/features/auth/presentation/register_page.dart';
import 'package:meta_gym_app/features/auth/presentation/session_controller.dart';
import 'package:provider/provider.dart';
import 'package:meta_gym_app/features/catalog/presentation/gym_equipment_page.dart';
import 'package:meta_gym_app/features/coach/presentation/coach_home_page.dart';
import 'package:meta_gym_app/features/coaching/presentation/coach_selection_page.dart';
import 'package:meta_gym_app/features/coaching/presentation/coach_members_page.dart';
import 'package:meta_gym_app/features/coaching/presentation/member_coaching_page.dart';
import 'package:meta_gym_app/features/legal/presentation/privacy_policy_page.dart';
import 'package:meta_gym_app/features/legal/presentation/terms_of_service_page.dart';
import 'package:meta_gym_app/features/member/presentation/member_home_page.dart';
import 'package:meta_gym_app/features/membership/presentation/payment_history_page.dart';
import 'package:meta_gym_app/features/membership/presentation/membership_page.dart';
import 'package:meta_gym_app/features/messaging/presentation/conversations_page.dart';
import 'package:meta_gym_app/features/calls/presentation/calls_page.dart';
import 'package:meta_gym_app/features/ai/presentation/ai_conversations_page.dart';
import 'package:meta_gym_app/features/profile/presentation/forgot_password_page.dart';
import 'package:meta_gym_app/features/profile/presentation/profile_page.dart';
import 'package:meta_gym_app/features/public/presentation/app_loading_page.dart';
import 'package:meta_gym_app/features/sessions/presentation/coach_booking_page.dart';
import 'package:meta_gym_app/features/sessions/presentation/coach_sessions_page.dart';
import 'package:meta_gym_app/features/progress/presentation/member_progress_page.dart';
import 'package:meta_gym_app/features/progress/presentation/member_journal_page.dart';
import 'package:meta_gym_app/features/progress/presentation/member_measurement_page.dart';
import 'package:meta_gym_app/features/progress/presentation/member_photo_page.dart';
import 'package:meta_gym_app/features/training/presentation/member_training_page.dart';
import 'package:meta_gym_app/features/training/presentation/coach_training_page.dart';
import 'package:meta_gym_app/features/training/presentation/member_nutrition_page.dart';
import 'package:meta_gym_app/features/training/presentation/coach_nutrition_page.dart';
import 'package:meta_gym_app/features/workbench/flow_action.dart';
import 'package:meta_gym_app/features/workbench/flow_workbench_page.dart';
import 'package:meta_gym_app/features/workbench/flow_workbench_config.dart';

abstract final class AppRoutes {
  static const loading = '/loading';
  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';
  static const terms = '/terms';
  static const privacyPolicy = '/privacy-policy';
  static const profile = '/profile';
  static const memberHome = '/member';
  static const membership = '/member/features/membership';
  static const coachHome = '/coach';
  static const memberWorkbench = '/member/test-flows';
  static const coachWorkbench = '/coach/test-flows';
  static const adminHome = '/admin';
}

GoRouter createAppRouter({
  required SessionController sessionController,
  GlobalKey<NavigatorState>? navigatorKey,
  String initialLocation = AppRoutes.login,
}) {
  String? pendingPaymentReturn;
  final paymentIdPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );
  return GoRouter(
    navigatorKey: navigatorKey,
    initialLocation: initialLocation,
    refreshListenable: sessionController,
    redirect: (context, state) {
      final query = state.uri.queryParameters;
      final key = query.containsKey('momoPaymentId')
          ? 'momoPaymentId'
          : 'vnpayPaymentId';
      final paymentId = query[key];
      if (sessionController.status != SessionStatus.authenticated &&
          state.uri.path == AppRoutes.membership &&
          paymentId != null &&
          paymentIdPattern.hasMatch(paymentId)) {
        pendingPaymentReturn = Uri(
          path: AppRoutes.membership,
          queryParameters: {key: paymentId},
        ).toString();
      }
      if (sessionController.status == SessionStatus.restoring) {
        return state.matchedLocation == AppRoutes.loading
            ? null
            : AppRoutes.loading;
      }
      if (sessionController.status == SessionStatus.unauthenticated) {
        const publicRoutes = {
          AppRoutes.login,
          AppRoutes.register,
          AppRoutes.forgotPassword,
          AppRoutes.terms,
          AppRoutes.privacyPolicy,
        };
        return publicRoutes.contains(state.matchedLocation)
            ? null
            : AppRoutes.login;
      }

      final home = _homeForRole(sessionController.user!.role);
      final returnLocation = pendingPaymentReturn;
      pendingPaymentReturn = null;
      if (home == AppRoutes.memberHome &&
          returnLocation != null &&
          state.uri.toString() != returnLocation) {
        return returnLocation;
      }
      const sharedProtectedRoutes = {AppRoutes.profile};
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
          (home != AppRoutes.adminHome &&
              sharedProtectedRoutes.contains(state.matchedLocation))) {
        return null;
      }
      return home;
    },
    routes: [
      GoRoute(
        path: AppRoutes.loading,
        pageBuilder: (context, state) => _smoothAuthTransitionPage(
          key: state.pageKey,
          child: const AppLoadingPage(),
        ),
      ),
      ShellRoute(
        builder: (context, state, child) {
          final isLogin = state.matchedLocation != AppRoutes.register;
          final auth = context.watch<AuthController>();
          return AuthModeShell(
            isLogin: isLogin,
            onBack: isLogin || auth.isSubmitting
                ? null
                : () {
                    auth.clearErrors();
                    context.go(AppRoutes.login);
                  },
            onSelectLogin: isLogin || auth.isSubmitting
                ? null
                : () {
                    auth.clearErrors();
                    context.go(AppRoutes.login);
                  },
            onSelectRegister: !isLogin || auth.isSubmitting
                ? null
                : () {
                    auth.clearErrors();
                    context.go(AppRoutes.register);
                  },
            child: child,
          );
        },
        routes: [
          GoRoute(
            path: AppRoutes.login,
            pageBuilder: (context, state) =>
                NoTransitionPage<void>(key: state.pageKey, child: const LoginPage()),
          ),
          GoRoute(
            path: AppRoutes.register,
            pageBuilder: (context, state) => NoTransitionPage<void>(
              key: state.pageKey,
              child: const RegisterPage(),
            ),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        pageBuilder: (context, state) => _smoothAuthTransitionPage(
          key: state.pageKey,
          child: const ForgotPasswordPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.terms,
        pageBuilder: (context, state) => _featureTransitionPage(
          key: state.pageKey,
          context: context,
          child: const TermsOfServicePage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.privacyPolicy,
        pageBuilder: (context, state) => _featureTransitionPage(
          key: state.pageKey,
          context: context,
          child: const PrivacyPolicyPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.profile,
        pageBuilder: (context, state) => _featureTransitionPage(
          key: state.pageKey,
          context: context,
          child: const ProfilePage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.memberHome,
        pageBuilder: (context, state) => _smoothAuthTransitionPage(
          key: state.pageKey,
          child: const MemberHomePage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.coachHome,
        pageBuilder: (context, state) => _smoothAuthTransitionPage(
          key: state.pageKey,
          child: const CoachHomePage(),
        ),
      ),
      for (final destination in memberDestinations)
        GoRoute(
          path: destination.path,
          pageBuilder: (context, state) => _featureTransitionPage(
            key: state.pageKey,
            context: context,
            child: destination.path == AppRoutes.membership
                ? MembershipPage(
                    key: ValueKey(state.uri.query),
                    paymentReturnId:
                        state.uri.queryParameters['momoPaymentId'] ??
                        state.uri.queryParameters['vnpayPaymentId'],
                    paymentReturnMethod:
                        state.uri.queryParameters.containsKey('momoPaymentId')
                        ? 'MOMO'
                        : 'VNPAY',
                  )
                : destination.path == '/member/features/payments'
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
                ? const MemberNutritionPage(structured: true)
                : destination.path == '/member/features/sessions'
                ? const CoachBookingPage()
                : destination.path == '/member/features/progress'
                ? const MemberProgressPage()
                : destination.path == '/member/features/workouts'
                ? const MemberJournalPage()
                : destination.path == '/member/features/measurements'
                ? const MemberMeasurementPage()
                : destination.path == '/member/features/photos'
                ? const MemberPhotoPage()
                : destination.path == '/member/features/messages'
                ? ConversationsPage(currentUserId: sessionController.user!.id)
                : destination.path == '/member/features/calls'
                ? CallsPage(currentUserId: sessionController.user!.id)
                : destination.path == '/member/features/ai'
                ? const AiConversationsPage()
                : throw StateError('Thiếu trang Member: ${destination.path}'),
          ),
        ),
      for (final destination in coachDestinations)
        GoRoute(
          path: destination.path,
          pageBuilder: (context, state) => _featureTransitionPage(
            key: state.pageKey,
            context: context,
            child: destination.path == '/coach/features/gym'
                ? const GymEquipmentPage()
                : destination.path == '/coach/features/members'
                ? const CoachMembersPage()
                : destination.path == '/coach/features/training'
                ? const CoachTrainingPage()
                : destination.path == '/coach/features/nutrition'
                ? const CoachNutritionPage(structured: true)
                : destination.path == '/coach/features/sessions'
                ? CoachSessionsPage(
                    coachId: sessionController.user!.id,
                  )
                : destination.path == '/coach/features/messages'
                ? ConversationsPage(
                    currentUserId: sessionController.user!.id,
                    coachMode: true,
                  )
                : destination.path == '/coach/features/calls'
                ? CallsPage(
                    currentUserId: sessionController.user!.id,
                    coachMode: true,
                  )
                : destination.path == '/coach/features/ai'
                ? const AiConversationsPage(coachMode: true)
                : throw StateError('Thiếu trang Coach: ${destination.path}'),
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
        pageBuilder: (context, state) => _smoothAuthTransitionPage(
          key: state.pageKey,
          child: const AdminHomePage(),
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

CustomTransitionPage<void> _smoothAuthTransitionPage({
  required LocalKey key,
  required Widget child,
  double slideDirection = 1.0,
}) {
  return CustomTransitionPage<void>(
    key: key,
    transitionDuration: const Duration(milliseconds: 240),
    reverseTransitionDuration: const Duration(milliseconds: 200),
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (MediaQuery.disableAnimationsOf(context)) {
        return child;
      }
      final incoming = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: incoming,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: Offset(0.04 * slideDirection, 0),
            end: Offset.zero,
          ).animate(incoming),
          child: child,
        ),
      );
    },
  );
}

CustomTransitionPage<void> _featureTransitionPage({
  required LocalKey key,
  required BuildContext context,
  required Widget child,
}) {
  final disableAnimations = MediaQuery.disableAnimationsOf(context);
  final duration = disableAnimations
      ? Duration.zero
      : MetaGymTheme.pageTransitionDuration;
  return CustomTransitionPage<void>(
    key: key,
    transitionDuration: duration,
    reverseTransitionDuration: disableAnimations
        ? Duration.zero
        : const Duration(milliseconds: 240),
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (MediaQuery.disableAnimationsOf(context)) return child;
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.018),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}
