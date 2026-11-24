import 'dart:typed_data' show Uint8List;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_gym_app/core/theme/meta_gym_icons.dart';
import 'package:meta_gym_app/core/storage/token_storage.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_icon.dart';
import 'package:meta_gym_app/features/auth/domain/auth_models.dart';
import 'package:meta_gym_app/features/auth/presentation/session_controller.dart';
import 'package:meta_gym_app/features/profile/data/profile_service.dart';
import 'package:meta_gym_app/features/profile/presentation/profile_controller.dart';
import 'package:meta_gym_app/features/profile/presentation/profile_page.dart';
import 'package:meta_gym_app/features/profile/presentation/widgets/body_metric_pickers.dart';
import 'package:meta_gym_app/features/profile/presentation/widgets/personal_info_page.dart';
import 'package:meta_gym_app/features/profile/presentation/widgets/training_profile_page.dart';
import 'package:meta_gym_app/features/progress/data/member_measurement_service.dart';
import 'package:meta_gym_app/features/progress/domain/body_measurement.dart';
import 'package:provider/provider.dart';

void main() {
  const memberUser = AuthUser(
    id: 'member-1',
    email: 'minhquan@metagym.vn',
    fullName: 'Nguyễn Minh Quân',
    phone: '0909 123 456',
    role: UserRole.member,
    status: 'ACTIVE',
    profile: {
      'dateOfBirth': '1999-05-14',
      'gender': 'MALE',
      'heightCm': 174.0,
      'fitnessGoal': 'Tăng cơ giảm mỡ · Duy trì 4 buổi/tuần',
      'experienceLevel': 'INTERMEDIATE',
      'activityLevel': 'MODERATE',
    },
  );

  group('Body metric helpers', () {
    test('calculates BMI zones and imperial conversions accurately', () {
      final normal = calculateBmiInfo(174, 72.4);
      expect(normal.bmi, 23.9);
      expect(normal.label, 'Bình thường');
      expect(normal.zone, BmiZone.normal);

      expect(calculateBmiInfo(175, 52).zone, BmiZone.underweight);
      expect(calculateBmiInfo(170, 80).zone, BmiZone.overweight);
      expect(calculateBmiInfo(170, 96).zone, BmiZone.obese);

      expect(formatHeightFeetInches(174), "5'9\"");
      expect(formatWeightLbs(72.4), '159.6 lbs');
      expect(
        PersonalInfoDetailPage.formatDobDisplay('1999-05-14'),
        '14/05/1999',
      );
    });
  });

  group('5.1 ProfilePage, 5.2 PersonalInfo & 5.3 TrainingProfile sync', () {
    testWidgets(
      '5.1 ProfilePage matches preview groups, SVG icons, Avatar modal, and Logout modal',
      (tester) async {
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final session = await _createSession(memberUser);
        final service = _FakeProfileService(memberUser);
        final controller = ProfileController(service, session);
        final measurements = _FakeMeasurementService(72.4);

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<SessionController>.value(value: session),
              ChangeNotifierProvider<ProfileController>.value(
                value: controller,
              ),
              Provider<MemberMeasurementService>.value(value: measurements),
            ],
            child: MaterialApp(
              theme: MetaGymTheme.dark,
              home: const ProfilePage(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Hero card uses MetaGymHeroGlassCard + preview SVGs
        expect(find.byType(MetaGymHeroGlassCard), findsOneWidget);
        expect(find.text('Nguyễn Minh Quân'), findsOneWidget);
        expect(find.text('minhquan@metagym.vn'), findsOneWidget);
        expect(find.text('0909 123 456'), findsOneWidget);

        final iconAssets = tester
            .widgetList<MetaGymIcon>(find.byType(MetaGymIcon))
            .map((icon) => icon.asset)
            .toList();
        expect(iconAssets, contains(MetaGymIcons.commEmail));
        expect(iconAssets, contains(MetaGymIcons.callAudioBadge));
        expect(iconAssets, contains(MetaGymIcons.settingPersonalInfo));
        expect(iconAssets, contains(MetaGymIcons.equipDumbbell));
        expect(iconAssets, contains(MetaGymIcons.settingSecurityShield));
        expect(iconAssets, contains(MetaGymIcons.settingLogout));

        // Tapping avatar opens preview Avatar Picker Modal
        await tester.tap(find.byKey(const Key('profile-avatar-btn')));
        await tester.pumpAndSettle();
        expect(find.text('Cập nhật ảnh đại diện'), findsOneWidget);
        expect(find.text('Chụp ảnh mới'), findsOneWidget);
        expect(find.text('Chọn từ thư viện ảnh'), findsOneWidget);
        await tester.tap(find.text('Hủy'));
        await tester.pumpAndSettle();

        // Group 2 matches preview: Nhật ký & Số đo cơ thể · Coach & Lịch hẹn · Gói tập & Ưu đãi
        await tester.tap(find.text('Tập luyện & dịch vụ'));
        await tester.pumpAndSettle();
        expect(find.text('Nhật ký & Số đo cơ thể'), findsOneWidget);
        expect(find.text('Coach & Lịch hẹn'), findsOneWidget);
        expect(find.text('Gói tập & Ưu đãi'), findsOneWidget);

        // Group 3 matches preview (5 items including Thông báo)
        await tester.tap(find.text('Tài khoản & hỗ trợ'));
        await tester.pumpAndSettle();
        expect(find.text('Thông báo'), findsOneWidget);
        expect(find.text('Bảo mật & Tài khoản'), findsOneWidget);
        expect(find.text('Quyền riêng tư & Chia sẻ'), findsOneWidget);
        expect(find.text('Cài đặt ứng dụng'), findsOneWidget);
        expect(find.text('Phòng tập & Hỗ trợ'), findsOneWidget);

        // Logout dialog matches Level 3 Overlay Glass preview
        await tester.scrollUntilVisible(
          find.byKey(const Key('profile-sign-out-btn')),
          250,
        );
        await tester.tap(find.byKey(const Key('profile-sign-out-btn')));
        await tester.pumpAndSettle();
        expect(find.text('Đăng xuất tài khoản?'), findsOneWidget);
        expect(
          find.text('Bạn có chắc chắn muốn đăng xuất khỏi tài khoản không?'),
          findsOneWidget,
        );
        await tester.tap(find.text('Hủy'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '5.2 PersonalInfo displays Vietnamese dd/MM/yyyy date, Warm Glass avatar card, and saves patch',
      (tester) async {
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final session = await _createSession(memberUser);
        final service = _FakeProfileService(memberUser);
        final controller = ProfileController(service, session);

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<SessionController>.value(value: session),
              ChangeNotifierProvider<ProfileController>.value(
                value: controller,
              ),
            ],
            child: MaterialApp(
              theme: MetaGymTheme.dark,
              home: const ProfilePage(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Cá nhân & thể trạng'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Thông tin cá nhân'));
        await tester.pumpAndSettle();

        expect(find.byType(PersonalInfoDetailPage), findsOneWidget);
        expect(find.text('Ảnh đại diện (Avatar)'), findsOneWidget);
        expect(find.text('Tải ảnh từ điện thoại'), findsOneWidget);
        expect(find.text('14/05/1999'), findsOneWidget);
        expect(find.text('Nam'), findsOneWidget);
        expect(find.text('Nữ'), findsOneWidget);

        // Switch gender pill to Nữ and save
        await tester.ensureVisible(find.text('Nữ'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Nữ'));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('personal-info-save-btn')));
        await tester.pumpAndSettle();

        expect(service.lastUpdate?['gender'], 'FEMALE');
        expect(service.lastUpdate?['dateOfBirth'], '1999-05-14');
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '5.3 TrainingProfile opens Laser Stadiometer & Barbell Weight Dial, recalculates BMI, and saves both profile + measurement',
      (tester) async {
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final session = await _createSession(memberUser);
        final service = _FakeProfileService(memberUser);
        final controller = ProfileController(service, session);
        final measurements = _FakeMeasurementService(72.4);

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<SessionController>.value(value: session),
              ChangeNotifierProvider<ProfileController>.value(
                value: controller,
              ),
              Provider<MemberMeasurementService>.value(value: measurements),
            ],
            child: MaterialApp(
              theme: MetaGymTheme.dark,
              home: const ProfilePage(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Cá nhân & thể trạng'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Thể trạng & Mục tiêu'));
        await tester.pumpAndSettle();

        expect(find.byType(TrainingProfileDetailPage), findsOneWidget);
        expect(find.text('Chiều cao & Cân nặng'), findsOneWidget);
        expect(find.text('174 cm'), findsOneWidget);
        expect(find.text('72.4 kg'), findsOneWidget);
        expect(find.text('● BMI 23.9 · Bình thường'), findsOneWidget);

        // Open Laser Stadiometer & increase height by +1 cm -> 175 cm
        await tester.tap(find.byKey(const Key('training-height-card')));
        await tester.pumpAndSettle();
        expect(find.text('Thước đo chiều cao'), findsOneWidget);
        await tester.tap(find.byKey(const Key('height-step-plus')));
        await tester.pumpAndSettle();
        expect(find.text('175 cm'), findsOneWidget);
        await tester.tap(find.byKey(const Key('stadiometer-confirm')));
        await tester.pumpAndSettle();
        expect(find.text('175 cm'), findsOneWidget);

        // Open Barbell Arc Weight Dial & decrease by -1 kg -> 71.4 kg
        await tester.tap(find.byKey(const Key('training-weight-card')));
        await tester.pumpAndSettle();
        expect(find.text('Cân đĩa tạ Meta Gym'), findsOneWidget);
        await tester.tap(find.byKey(const Key('weight-step-minus-1')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('weight-dial-confirm')));
        await tester.pumpAndSettle();
        expect(find.text('71.4 kg'), findsOneWidget);

        // Choose Advanced + High activity
        await tester.ensureVisible(find.text('Vận động cao'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Nâng cao'));
        await tester.tap(find.text('Vận động cao'));
        await tester.pumpAndSettle();

        // Save
        await tester.tap(find.byKey(const Key('training-profile-save-btn')));
        await tester.pumpAndSettle();

        expect(service.lastUpdate?['heightCm'], 175.0);
        expect(service.lastUpdate?['experienceLevel'], 'ADVANCED');
        expect(service.lastUpdate?['activityLevel'], 'HIGH');
        expect(measurements.lastCreatedPayload?['weightKg'], 71.4);
        expect(tester.takeException(), isNull);
      },
    );

    for (final brightness in [Brightness.dark, Brightness.light]) {
      for (final width in [375.0, 768.0]) {
        testWidgets(
          'renders 5.1, 5.2, and 5.3 without overflow at width=$width brightness=$brightness scale=1.3',
          (tester) async {
            tester.view.physicalSize = Size(width, 900);
            tester.view.devicePixelRatio = 1.0;
            addTearDown(tester.view.reset);

            final theme = brightness == Brightness.dark
                ? MetaGymTheme.dark
                : MetaGymTheme.light;

            await tester.pumpWidget(
              MaterialApp(
                theme: theme,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: const TextScaler.linear(1.3),
                    disableAnimations: true,
                  ),
                  child: child!,
                ),
                home: TrainingProfileDetailPage(
                  fitnessGoal: 'Tăng cơ giảm mỡ · Duy trì 4 buổi/tuần',
                  heightCm: 174,
                  weightKg: 72.4,
                  experienceLevel: 'INTERMEDIATE',
                  activityLevel: 'MODERATE',
                  onSave: (_, _, _, _, _) async => true,
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(find.byType(BackdropFilter), findsNothing);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  });
}

Future<SessionController> _createSession(AuthUser user) async {
  final session = SessionController(_MemoryTokenStorage(), (_) async => user);
  await session.authenticate(AuthSession(accessToken: 'token', user: user));
  return session;
}

class _FakeProfileService implements ProfileService {
  _FakeProfileService(this.user);

  final AuthUser user;
  Map<String, Object?>? lastUpdate;

  @override
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async => true;

  @override
  Future<AuthUser> getProfile() async => user;

  @override
  Future<AuthUser> uploadAvatar(Uint8List bytes) async => user;

  @override
  Future<AuthUser> deleteAvatar() async => user;

  @override
  Future<Uint8List?> fetchAvatarBytes(String avatarUrl) async => null;

  @override
  Future<String> requestPasswordReset(String email) async => 'req-1';

  @override
  Future<bool> resetPassword({
    required String requestId,
    required String code,
    required String newPassword,
  }) async => true;

  @override
  Future<AuthUser> updateProfile(Map<String, Object?> fields) async {
    lastUpdate = fields;
    return user;
  }

  @override
  Future<bool> verifyPasswordReset({
    required String requestId,
    required String code,
  }) async => true;
}

class _FakeMeasurementService implements MemberMeasurementService {
  _FakeMeasurementService(this.initialWeightKg);

  final double initialWeightKg;
  Map<String, Object?>? lastCreatedPayload;

  @override
  Future<BodyMeasurement> create(Map<String, Object?> payload) async {
    lastCreatedPayload = payload;
    return BodyMeasurement(
      id: 'm-new',
      measuredAt: '2026-11-23T00:00:00Z',
      weightKg: (payload['weightKg'] as num).toDouble(),
    );
  }

  @override
  Future<List<BodyMeasurement>> getPage(int page) async => [
    BodyMeasurement(
      id: 'm-1',
      measuredAt: '2026-11-22T00:00:00Z',
      weightKg: initialWeightKg,
    ),
  ];

  @override
  Future<BodyMeasurement> update(
    String id,
    Map<String, Object?> payload,
  ) async => BodyMeasurement(
    id: id,
    measuredAt: '2026-11-23T00:00:00Z',
    weightKg: (payload['weightKg'] as num?)?.toDouble() ?? initialWeightKg,
  );
}

class _MemoryTokenStorage implements TokenStorage {
  String? _value;

  @override
  Future<void> delete() async => _value = null;

  @override
  Future<String?> read() async => _value;

  @override
  Future<void> write(String token) async => _value = token;
}
