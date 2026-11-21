import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:meta_gym_app/app/app_router.dart';
import 'package:meta_gym_app/app/meta_gym_app.dart';
import 'package:meta_gym_app/core/storage/token_storage.dart';
import 'package:meta_gym_app/features/admin/presentation/admin_home_page.dart';
import 'package:meta_gym_app/features/auth/domain/auth_models.dart';
import 'package:meta_gym_app/features/auth/presentation/login_page.dart';
import 'package:meta_gym_app/features/auth/presentation/session_controller.dart';

void main() {
  const adminUser = AuthUser(
    id: 'admin-1',
    email: 'admin@metagym.vn',
    fullName: 'Meta Gym Admin',
    role: UserRole.admin,
    status: 'ACTIVE',
  );

  testWidgets(
    'gates UserRole.admin onto the Web Admin notice screen with zero legacy CRUD and supports sign out',
    (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final storage = _MemoryTokenStorage('admin-jwt');
      final controller = SessionController(storage, (_) async => adminUser);

      await tester.pumpWidget(MetaGymApp(sessionController: controller));
      await tester.pumpAndSettle();

      expect(find.byType(AdminHomePage), findsOneWidget);
      expect(
        find.text('Tài khoản Quản trị viên chỉ sử dụng trên Web Admin'),
        findsOneWidget,
      );
      expect(find.text('Meta Gym Admin'), findsOneWidget);
      expect(find.text('admin@metagym.vn'), findsOneWidget);

      // Legacy CRUD controls must be completely removed.
      expect(find.byType(TabBar), findsNothing);
      expect(find.text('Thêm Huấn luyện viên mới'), findsNothing);
      expect(find.text('Thêm gói tập mới'), findsNothing);
      expect(find.text('Người dùng'), findsNothing);
      expect(find.text('Gói tập'), findsNothing);
      expect(find.text('Hệ thống'), findsNothing);
      expect(find.text('Khóa tài khoản'), findsNothing);

      // Attempting to navigate to /profile or /member redirects back to /admin.
      final router = GoRouter.of(tester.element(find.byType(AdminHomePage)));
      router.go(AppRoutes.profile);
      await tester.pumpAndSettle();
      expect(find.byType(AdminHomePage), findsOneWidget);

      router.go(AppRoutes.memberHome);
      await tester.pumpAndSettle();
      expect(find.byType(AdminHomePage), findsOneWidget);

      // Sign Out button meets >= 48dp touch target and signs out cleanly.
      final signOutButton = find.byKey(const Key('admin-sign-out-button'));
      expect(signOutButton, findsOneWidget);
      expect(
        tester.getSize(signOutButton).height,
        greaterThanOrEqualTo(48.0),
      );

      await tester.tap(signOutButton);
      await tester.pumpAndSettle();

      expect(controller.status, SessionStatus.unauthenticated);
      expect(await storage.read(), isNull);
      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.byType(AdminHomePage), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final viewport in const <Size>[
    Size(360, 640),
    Size(375, 812),
    Size(812, 375),
  ]) {
    testWidgets(
      'renders AdminHomePage cleanly without overflow at ${viewport.width.toInt()}x${viewport.height.toInt()}',
      (tester) async {
        tester.view.physicalSize = viewport;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final controller = SessionController(
          _MemoryTokenStorage('admin-jwt'),
          (_) async => adminUser,
        );

        await tester.pumpWidget(MetaGymApp(sessionController: controller));
        await tester.pumpAndSettle();

        expect(find.byType(AdminHomePage), findsOneWidget);
        expect(
          find.text('Tài khoản Quản trị viên chỉ sử dụng trên Web Admin'),
          findsOneWidget,
        );
        expect(find.byKey(const Key('admin-sign-out-button')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

class _MemoryTokenStorage implements TokenStorage {
  _MemoryTokenStorage([this._token]);

  String? _token;

  @override
  Future<void> delete() async => _token = null;

  @override
  Future<String?> read() async => _token;

  @override
  Future<void> write(String value) async => _token = value;
}
