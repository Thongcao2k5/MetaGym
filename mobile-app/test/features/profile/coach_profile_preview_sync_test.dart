import 'dart:typed_data' show Uint8List;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_gym_app/core/storage/token_storage.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/theme/meta_gym_icons.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_icon.dart';
import 'package:meta_gym_app/features/auth/domain/auth_models.dart';
import 'package:meta_gym_app/features/auth/presentation/session_controller.dart';
import 'package:meta_gym_app/features/coaching/data/coach_members_service.dart';
import 'package:meta_gym_app/features/coaching/domain/coach_member_models.dart';
import 'package:meta_gym_app/features/profile/data/profile_service.dart';
import 'package:meta_gym_app/features/profile/presentation/profile_controller.dart';
import 'package:meta_gym_app/features/profile/presentation/profile_page.dart';
import 'package:meta_gym_app/features/profile/presentation/widgets/profile_secondary_pages.dart';
import 'package:meta_gym_app/features/profile/presentation/widgets/profile_shared_widgets.dart';
import 'package:provider/provider.dart';

void main() {
  const coachUser = AuthUser(
    id: 'coach-1',
    email: 'coach.nam@metagym.vn',
    fullName: 'Lê Hoàng Nam',
    phone: '0912 345 678',
    role: UserRole.coach,
    status: 'ACTIVE',
    profile: {
      'biography':
          'Chuyên gia Hypertrophy và tái cấu trúc hình thể với hơn 6 năm kinh nghiệm.',
      'specialties': ['Hypertrophy', 'Sức mạnh', 'Giảm mỡ bền vững'],
      'qualifications': 'NASM-CPT · Precision Nutrition Level 1',
      'experienceYears': 6,
      'availabilityNote': 'Thứ 2 – Thứ 7 · 06:00 – 20:00',
    },
  );

  group('6.1 ProfilePage (Coach) & 6.2 CoachProfileDetailPage sync', () {
    testWidgets(
      '6.1 ProfilePage Coach matches preview 6.1, Spatial Glass background, Member cards, and opens 6.2 Hero',
      (tester) async {
        tester.view.physicalSize = const Size(393, 852);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final session = await _createSession(coachUser);
        final service = _FakeCoachProfileService(coachUser);
        final controller = ProfileController(service, session);
        final membersService = _FakeCoachMembersService(activeCount: 6);

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<SessionController>.value(value: session),
              ChangeNotifierProvider<ProfileController>.value(
                value: controller,
              ),
              Provider<CoachMembersService>.value(value: membersService),
            ],
            child: MaterialApp(
              theme: MetaGymTheme.dark,
              home: const ProfilePage(coachMode: true),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Preview Background & Brand Header
        expect(find.byType(MetaGymBackground), findsOneWidget);
        expect(find.text('META GYM · COACH'), findsOneWidget);
        expect(find.text('Hồ sơ cá nhân'), findsOneWidget);
        expect(
          find.text('Tài khoản & thiết lập huấn luyện viên'),
          findsOneWidget,
        );

        // Hero Card (Warm Smoked Glass + Avatar LN vàng #F5B041 + Đang nhận lịch)
        expect(find.byType(MetaGymHeroGlassCard), findsOneWidget);
        expect(find.text('LN'), findsOneWidget);
        expect(find.text('Lê Hoàng Nam'), findsOneWidget);
        expect(find.text('Huấn luyện viên'), findsOneWidget);
        expect(find.text('● Đang nhận lịch'), findsOneWidget);
        expect(find.text('coach.nam@metagym.vn'), findsOneWidget);
        expect(find.text('0912 345 678'), findsOneWidget);

        // Verify Member-style Warm Smoked Card fill on accordion cards
        final accordionFinder = find.byType(ProfileAccordionCard).first;
        final accordionContainer = tester.widget<Container>(
          find
              .descendant(
                of: accordionFinder,
                matching: find.byType(Container),
              )
              .first,
        );
        final decoration = accordionContainer.decoration as BoxDecoration;
        expect(decoration.color, MetaGymWarmGlassTokens.cardFill);

        // Verify Coach SVG icons
        final iconAssets = tester
            .widgetList<MetaGymIcon>(find.byType(MetaGymIcon))
            .map((e) => e.asset)
            .toList();
        expect(iconAssets, contains(MetaGymIcons.settingPersonalInfo));
        expect(iconAssets, contains(MetaGymIcons.coachAchievement));
        expect(iconAssets, contains(MetaGymIcons.settingSecurityShield));
        expect(iconAssets, contains(MetaGymIcons.settingLogout));

        // Group 1: Cá nhân & chuyên môn (1 mục theo preview 6.1)
        await tester.tap(find.text('Cá nhân & chuyên môn'));
        await tester.pumpAndSettle();
        expect(find.text('Thông tin cá nhân'), findsNothing);
        expect(find.text('Chuyên môn, Bằng cấp & Liên hệ'), findsOneWidget);
        expect(find.text('6 năm'), findsOneWidget);

        // Group 2: Công việc & giảng dạy (6 real Coach destinations + 6/8 live badge)
        await tester.tap(find.text('Công việc & giảng dạy'));
        await tester.pumpAndSettle();
        expect(find.text('Hội viên đang phụ trách'), findsOneWidget);
        expect(find.text('6/8'), findsOneWidget);
        expect(find.text('Lịch dạy & buổi hẹn'), findsOneWidget);
        expect(find.text('Giáo án tập luyện'), findsOneWidget);
        expect(find.text('Thực đơn 7 ngày'), findsOneWidget);
        expect(find.text('Cuộc gọi 1:1 học viên'), findsOneWidget);
        expect(find.text('Phòng gym & Thiết bị'), findsOneWidget);

        // Group 3: Tài khoản & bảo mật (no Member-only Quyền riêng tư)
        await tester.scrollUntilVisible(
          find.text('Tài khoản & bảo mật'),
          200,
        );
        await tester.ensureVisible(find.text('Tài khoản & bảo mật'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Tài khoản & bảo mật'));
        await tester.pumpAndSettle();
        expect(find.text('Thông báo Coach'), findsOneWidget);
        expect(find.text('Bảo mật & Đổi mật khẩu'), findsOneWidget);
        expect(find.text('Cài đặt ứng dụng'), findsOneWidget);
        expect(find.text('Phòng tập & Hỗ trợ'), findsOneWidget);
        expect(find.text('Quyền riêng tư & Chia sẻ'), findsNothing);

        // Coach Sign-out confirmation modal matches preview 6.1
        await tester.scrollUntilVisible(
          find.byKey(const Key('profile-sign-out-btn')),
          250,
        );
        await tester.tap(find.byKey(const Key('profile-sign-out-btn')));
        await tester.pumpAndSettle();
        expect(find.text('Đăng xuất tài khoản Coach?'), findsOneWidget);
        expect(
          find.text(
            'Bạn sẽ cần đăng nhập lại để điểm danh ca dạy, cập nhật giáo án và nhận thông báo từ học viên.',
          ),
          findsOneWidget,
        );
        await tester.tap(find.text('Hủy'));
        await tester.pumpAndSettle();

        // Tapping Hero Card opens CoachProfileDetailPage (6.2)
        await tester.scrollUntilVisible(
          find.byKey(const Key('profile-hero-card')),
          -300,
        );
        await tester.tap(find.byKey(const Key('profile-hero-card')));
        await tester.pumpAndSettle();
        expect(find.byType(CoachProfileDetailPage), findsOneWidget);
        expect(find.text('Hồ sơ công khai với Hội viên'), findsOneWidget);
        expect(find.text('● Đã xác thực'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '6.2 CoachProfileDetailPage toggles specialty chips, validates name, and patches /users/me',
      (tester) async {
        tester.view.physicalSize = const Size(393, 852);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final session = await _createSession(coachUser);
        final service = _FakeCoachProfileService(coachUser);
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
              home: const ProfilePage(coachMode: true),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('profile-hero-card')));
        await tester.pumpAndSettle();

        expect(find.byType(CoachProfileDetailPage), findsOneWidget);
        expect(find.byType(MetaGymHeroGlassCard), findsOneWidget);
        expect(find.byType(MetaGymMetricPanel), findsNWidgets(3));
        expect(find.text('6 năm'), findsNWidgets(2));
        expect(
          find.descendant(
            of: find.byKey(const Key('coach-pro-years-pill')),
            matching: find.text('6 năm'),
          ),
          findsOneWidget,
        );
        expect(find.text('3 mục'), findsOneWidget);
        expect(find.text('90 phút'), findsOneWidget);

        // Toggle Powerbuilding pill ON -> updates count pill to 4 mục
        await tester.ensureVisible(find.text('Powerbuilding'));
        await tester.tap(find.text('Powerbuilding'));
        await tester.pumpAndSettle();
        expect(find.text('4 mục'), findsOneWidget);

        // Validation: clearing name below 2 chars blocks pop & shows error toast
        final nameField = find.descendant(
          of: find.byKey(const Key('coach-pro-name-field')),
          matching: find.byType(TextField),
        );
        await tester.ensureVisible(nameField);
        await tester.enterText(nameField, 'A');
        await tester.tap(find.byKey(const Key('coach-pro-save-btn')));
        await tester.pumpAndSettle();
        expect(find.byType(CoachProfileDetailPage), findsOneWidget);
        expect(find.text('Họ và tên cần ít nhất 2 ký tự'), findsOneWidget);

        // Valid name & schedule preset update
        await tester.enterText(nameField, 'Lê Hoàng Nam Pro');
        final bioField = find.descendant(
          of: find.byKey(const Key('coach-pro-bio-field')),
          matching: find.byType(TextField),
        );
        await tester.ensureVisible(bioField);
        await tester.enterText(bioField, 'Chuyên gia Hypertrophy & Sức mạnh');

        await tester.ensureVisible(
          find.text('Thứ 2 – Thứ 6 · 14:00 – 21:00'),
        );
        await tester.tap(find.text('Thứ 2 – Thứ 6 · 14:00 – 21:00'));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('coach-pro-save-btn')));
        await tester.pumpAndSettle();

        expect(find.byType(CoachProfileDetailPage), findsNothing);
        expect(service.lastUpdate?['fullName'], 'Lê Hoàng Nam Pro');
        expect(
          service.lastUpdate?['biography'],
          'Chuyên gia Hypertrophy & Sức mạnh',
        );
        expect(
          service.lastUpdate?['availabilityNote'],
          'Thứ 2 – Thứ 6 · 14:00 – 21:00',
        );
        expect(
          service.lastUpdate?['specialties'],
          contains('Powerbuilding'),
        );
        expect(tester.takeException(), isNull);
      },
    );

    for (final brightness in [Brightness.dark, Brightness.light]) {
      for (final width in [375.0, 768.0]) {
        testWidgets(
          'Coach 6.1 & 6.2 render cleanly at width=$width brightness=$brightness scale=1.3',
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
                home: const ProfilePage(coachMode: true),
              ),
            );
            await tester.pumpAndSettle();
            expect(find.byType(BackdropFilter), findsNothing);
            expect(tester.takeException(), isNull);

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
                home: CoachProfileDetailPage(
                  initialFullName: 'Lê Hoàng Nam',
                  initialPhone: '0912 345 678',
                  biography: 'Huấn luyện viên Hypertrophy & Phục hồi',
                  specialties: const ['Hypertrophy', 'Sức mạnh'],
                  qualifications: 'NASM-CPT · Precision Nutrition Level 1',
                  experienceYears: 6,
                  availabilityNote: 'Thứ 2 – Thứ 7 · 06:00 – 20:00',
                  onSave: (_, _, _, _, _) async => true,
                  onSaveProfilePatch: (_) async => true,
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

class _FakeCoachProfileService implements ProfileService {
  _FakeCoachProfileService(this.user);

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
  Future<String> requestPasswordReset(String email) async => 'req-coach';

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

class _FakeCoachMembersService implements CoachMembersService {
  _FakeCoachMembersService({required this.activeCount});

  final int activeCount;

  @override
  Future<List<CoachMemberSummary>> getMembers() async => List.generate(
    activeCount,
    (index) => CoachMemberSummary(
      relationshipId: 'rel-$index',
      memberId: 'member-$index',
      memberFullName: 'Học viên $index',
      status: 'ACTIVE',
    ),
  );

  @override
  Future<CoachMemberDetail> getMember(String memberId) {
    throw UnimplementedError();
  }

  @override
  Future<List<CoachTerminationRequest>> getTerminationRequests() async =>
      const [];

  @override
  Future<void> requestTermination(String relationshipId, String reason) async {}

  @override
  Future<CoachTerminationRequest> respondTermination(
    String requestId, {
    required String decision,
    String? reason,
  }) {
    throw UnimplementedError();
  }
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
