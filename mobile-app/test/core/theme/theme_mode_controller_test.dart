import 'dart:typed_data' show Uint8List;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_gym_app/core/storage/token_storage.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/theme/theme_mode_controller.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/features/auth/domain/auth_models.dart';
import 'package:meta_gym_app/features/auth/presentation/session_controller.dart';
import 'package:meta_gym_app/features/profile/data/profile_service.dart';
import 'package:meta_gym_app/features/profile/presentation/profile_controller.dart';
import 'package:meta_gym_app/features/profile/presentation/profile_page.dart';
import 'package:provider/provider.dart';

void main() {
  group('ThemeModeController & Global Preview Backgrounds', () {
    test('defaults to dark mode and toggles cleanly', () async {
      final controller = ThemeModeController();
      var notifyCount = 0;
      controller.addListener(() => notifyCount++);

      expect(controller.themeMode, ThemeMode.dark);
      expect(controller.isDarkMode, isTrue);
      expect(controller.isLightMode, isFalse);

      await controller.setLightMode(true);
      expect(controller.themeMode, ThemeMode.light);
      expect(controller.isLightMode, isTrue);
      expect(notifyCount, 1);

      // Setting the same mode should not notify redundantly.
      await controller.setThemeMode(ThemeMode.light);
      expect(notifyCount, 1);

      await controller.toggle();
      expect(controller.themeMode, ThemeMode.dark);
      expect(controller.isDarkMode, isTrue);
      expect(notifyCount, 2);

      controller.dispose();
    });

    testWidgets(
      'ProfilePage switches global ThemeMode and MetaGymBackground between dark and light preview assets',
      (tester) async {
        tester.view.physicalSize = const Size(393, 852);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        const member = AuthUser(
          id: 'member-theme-1',
          email: 'theme@metagym.vn',
          fullName: 'Nguyễn Minh Quân',
          phone: '0909 123 456',
          role: UserRole.member,
          status: 'ACTIVE',
          profile: {},
        );
        final session = SessionController(
          _MemoryTokenStorage('token-1'),
          (token) async => member,
        );
        await session.restore();
        final profileController = ProfileController(
          _FakeProfileService(member),
          session,
        );
        final themeController = ThemeModeController();
        addTearDown(() {
          session.dispose();
          profileController.dispose();
          themeController.dispose();
        });

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<SessionController>.value(value: session),
              ChangeNotifierProvider<ProfileController>.value(
                value: profileController,
              ),
              ChangeNotifierProvider<ThemeModeController>.value(
                value: themeController,
              ),
            ],
            child: ListenableBuilder(
              listenable: themeController,
              builder: (context, _) => MaterialApp(
                theme: AppTheme.light,
                darkTheme: AppTheme.dark,
                themeMode: themeController.themeMode,
                home: const Scaffold(body: ProfilePage()),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Starts in Dark Mode using bg_app_dark.webp
        expect(find.byKey(const Key('profile-theme-mode-switch')), findsOneWidget);
        expect(find.text('Tối · Performance Glass'), findsOneWidget);
        final darkImages = tester
            .widgetList<Image>(find.byType(Image))
            .map((w) => w.image)
            .toList();
        expect(darkImages, contains(MetaGymBackground.darkAsset));
        expect(darkImages, isNot(contains(MetaGymBackground.lightAsset)));

        // Tap "Sáng" directly on ProfilePage
        await tester.tap(find.byKey(const Key('profile-theme-mode-light')));
        await tester.pumpAndSettle();

        expect(themeController.themeMode, ThemeMode.light);
        expect(find.text('Sáng · Daylight Studio'), findsOneWidget);
        final lightImages = tester
            .widgetList<Image>(find.byType(Image))
            .map((w) => w.image)
            .toList();
        expect(lightImages, contains(MetaGymBackground.lightAsset));
        expect(lightImages, isNot(contains(MetaGymBackground.darkAsset)));

        // Tap "Tối" to switch back
        await tester.tap(find.byKey(const Key('profile-theme-mode-dark')));
        await tester.pumpAndSettle();

        expect(themeController.themeMode, ThemeMode.dark);
        expect(find.text('Tối · Performance Glass'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}

class _MemoryTokenStorage implements TokenStorage {
  _MemoryTokenStorage(this._token);

  String? _token;

  @override
  Future<void> delete() async => _token = null;

  @override
  Future<String?> read() async => _token;

  @override
  Future<void> write(String token) async => _token = token;
}

class _FakeProfileService implements ProfileService {
  _FakeProfileService(this._user);

  final AuthUser _user;

  @override
  Future<AuthUser> getProfile() async => _user;

  @override
  Future<AuthUser> updateProfile(Map<String, Object?> fields) async => _user;

  @override
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async => true;

  @override
  Future<String> requestPasswordReset(String email) async => 'req-1';

  @override
  Future<bool> verifyPasswordReset({
    required String requestId,
    required String code,
  }) async => true;

  @override
  Future<bool> resetPassword({
    required String requestId,
    required String code,
    required String newPassword,
  }) async => true;

  @override
  Future<AuthUser> uploadAvatar(Uint8List bytes) async => _user;

  @override
  Future<AuthUser> deleteAvatar() async => _user;

  @override
  Future<Uint8List?> fetchAvatarBytes(String avatarUrl) async => null;
}
