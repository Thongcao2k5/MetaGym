import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_gym_app/core/theme/meta_gym_icons.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_icon.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_svg_icon.dart';
import 'package:meta_gym_app/features/profile/presentation/widgets/profile_secondary_pages.dart';
import 'package:meta_gym_app/features/profile/presentation/widgets/profile_shared_widgets.dart';

void main() {
  Widget wrapScreen({
    required Widget child,
    Brightness brightness = Brightness.dark,
    double textScale = 1.0,
    bool disableAnimations = false,
  }) {
    final theme = brightness == Brightness.dark
        ? MetaGymTheme.dark
        : MetaGymTheme.light;
    return MaterialApp(
      theme: theme,
      builder: (context, inner) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          disableAnimations: disableAnimations,
        ),
        child: inner!,
      ),
      home: child,
    );
  }

  group('5.11 SecurityAccountDetailPage preview sync & interactions', () {
    testWidgets(
      'matches preview 5.11 cards, SVG icons, biometric modal, password validation, and sign-out',
      (tester) async {
        tester.view.physicalSize = const Size(393, 852);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final toasts = <String>[];
        String? submittedOld;
        String? submittedNew;
        var signOutTapped = false;

        await tester.pumpWidget(
          wrapScreen(
            child: SecurityAccountDetailPage(
              email: 'minhquan@metagym.vn',
              status: 'ACTIVE',
              roleLabel: 'Hội viên',
              onChangePassword: (oldPass, newPass) async {
                submittedOld = oldPass;
                submittedNew = newPass;
                return oldPass == 'MetaGym@2025';
              },
              onSignOut: () => signOutTapped = true,
              onShowToast: (msg, {isError = false}) => toasts.add(msg),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Header + Hero account card + Biometric card + Password card
        expect(find.text('TÀI KHOẢN & THIẾT BỊ'), findsOneWidget);
        expect(find.text('Bảo mật & Tài khoản'), findsOneWidget);
        expect(find.byType(MetaGymHeroGlassCard), findsOneWidget);
        expect(find.text('minhquan@metagym.vn'), findsOneWidget);
        expect(
          find.text('● Tài khoản Hội viên · Đang hoạt động'),
          findsOneWidget,
        );
        expect(find.text('Sinh trắc học'), findsOneWidget);
        expect(find.text('● Chưa bật'), findsOneWidget);
        expect(find.text('Đăng nhập Face ID / Vân tay'), findsOneWidget);
        expect(find.text('Xác thực khi thanh toán'), findsOneWidget);
        expect(find.text('Thiết lập Face ID / Vân tay'), findsOneWidget);
        expect(find.text('Đổi mật khẩu đăng nhập'), findsOneWidget);
        expect(find.text('Cập nhật mật khẩu'), findsOneWidget);

        // Verify MetaGymIcons match tab5-profile-sub.js 5.11
        final iconAssets = <String>[
          ...tester
              .widgetList<MetaGymIcon>(find.byType(MetaGymIcon))
              .map((e) => e.asset),
          ...tester
              .widgetList<MetaGymSvgIcon>(find.byType(MetaGymSvgIcon))
              .map((e) => e.assetPath),
        ];
        expect(iconAssets, contains(MetaGymIcons.commonBack));
        expect(iconAssets, contains(MetaGymIcons.settingSecurityShield));
        expect(iconAssets, contains(MetaGymIcons.authFaceId));
        expect(iconAssets, contains(MetaGymIcons.authFingerprint));
        expect(iconAssets, contains(MetaGymIcons.settingPasswordKey));
        expect(iconAssets, contains(MetaGymIcons.authShowPassword));
        expect(iconAssets, contains(MetaGymIcons.settingLogout));

        // Biometric setup flow via switch -> choose Vân tay -> verify
        await tester.tap(find.byKey(const Key('security-bio-login-toggle')));
        await tester.pumpAndSettle();
        expect(find.text('Kích hoạt Face ID'), findsOneWidget);

        await tester.tap(find.byKey(const Key('bio-modal-method-fingerprint')));
        await tester.pumpAndSettle();
        expect(find.text('Kích hoạt Vân tay'), findsOneWidget);

        await tester.tap(find.byKey(const Key('bio-modal-verify-btn')));
        await tester.pumpAndSettle();
        expect(find.text('● Đang bật (Vân tay)'), findsOneWidget);
        expect(toasts.last, 'Đã bật đăng nhập bằng Vân tay');

        // Turning off biometric switch updates status pill back to Chưa bật
        await tester.tap(find.byKey(const Key('security-bio-login-toggle')));
        await tester.pumpAndSettle();
        expect(find.text('● Chưa bật'), findsOneWidget);
        expect(toasts.last, 'Đã tắt đăng nhập Sinh trắc học');

        // Payment biometric toggle starts ON and can be toggled
        final paySwitchBefore = tester.widget<Switch>(
          find.byKey(const Key('security-bio-payment-toggle')),
        );
        expect(paySwitchBefore.value, isTrue);
        await tester.tap(find.byKey(const Key('security-bio-payment-toggle')));
        await tester.pumpAndSettle();
        final paySwitchAfter = tester.widget<Switch>(
          find.byKey(const Key('security-bio-payment-toggle')),
        );
        expect(paySwitchAfter.value, isFalse);

        // Password validation: empty -> weak -> same as old -> mismatch -> valid
        await tester.tap(find.byKey(const Key('security-update-password-btn')));
        await tester.pumpAndSettle();
        expect(find.text('Vui lòng nhập mật khẩu hiện tại'), findsOneWidget);

        final currentField = find.descendant(
          of: find.byKey(const Key('security-current-pass-field')),
          matching: find.byType(TextField),
        );
        final newField = find.descendant(
          of: find.byKey(const Key('security-new-pass-field')),
          matching: find.byType(TextField),
        );
        final confirmField = find.descendant(
          of: find.byKey(const Key('security-confirm-pass-field')),
          matching: find.byType(TextField),
        );

        await tester.ensureVisible(currentField);
        await tester.enterText(currentField, 'MetaGym@2025');
        await tester.enterText(newField, 'MetaGym@2025');
        await tester.enterText(confirmField, 'MetaGym@2025');
        await tester.tap(find.byKey(const Key('security-update-password-btn')));
        await tester.pumpAndSettle();
        expect(
          find.text('Mật khẩu mới cần khác mật khẩu hiện tại'),
          findsOneWidget,
        );

        // Toggle password visibility eye icon
        await tester.ensureVisible(
          find.byKey(const Key('security-new-pass-eye')),
        );
        await tester.tap(find.byKey(const Key('security-new-pass-eye')));
        await tester.pumpAndSettle();
        expect(tester.widget<TextField>(newField).obscureText, isFalse);

        // Valid change clears error & succeeds
        await tester.enterText(newField, 'MetaGym#2026');
        await tester.enterText(confirmField, 'MetaGym#2026');
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('security-password-error')), findsNothing);

        await tester.tap(find.byKey(const Key('security-update-password-btn')));
        await tester.pumpAndSettle();
        expect(submittedOld, 'MetaGym@2025');
        expect(submittedNew, 'MetaGym#2026');
        expect(
          toasts.last,
          'Đã đổi mật khẩu thành công. Vui lòng đăng nhập lại.',
        );

        // Sign-out button triggers callback
        await tester.ensureVisible(
          find.byKey(const Key('security-sign-out-btn')),
        );
        await tester.tap(find.byKey(const Key('security-sign-out-btn')));
        await tester.pumpAndSettle();
        expect(signOutTapped, isTrue);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('5.12 PrivacySettingsDetailPage preview sync & interactions', () {
    testWidgets(
      'matches preview 5.12 3 toggles, photo permission card, and saves updated state',
      (tester) async {
        tester.view.physicalSize = const Size(393, 852);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        PhotoAccessMode? savedMode;
        bool? savedJournal;
        bool? savedMeasurements;

        await tester.pumpWidget(
          wrapScreen(
            child: PrivacySettingsDetailPage(
              accessMode: PhotoAccessMode.selectedOnly,
              shareJournalWithCoach: true,
              shareMeasurementsWithCoach: true,
              onSave: (mode, journal, measurements) async {
                savedMode = mode;
                savedJournal = journal;
                savedMeasurements = measurements;
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('BẢO VỆ DỮ LIỆU'), findsOneWidget);
        expect(find.text('Quyền riêng tư & Chia sẻ'), findsOneWidget);
        expect(find.text('Chia sẻ chỉ số & Ảnh tiến độ'), findsOneWidget);
        expect(find.text('Chia sẻ nhật ký dinh dưỡng'), findsOneWidget);
        expect(
          find.text('Coach đối chiếu khẩu phần ăn hàng ngày'),
          findsOneWidget,
        );
        expect(find.text('Cho phép hiển thị ảnh thành quả'), findsOneWidget);
        expect(
          find.text('Chỉ khi bạn xác nhận trong mục Duyệt thành quả'),
          findsOneWidget,
        );
        expect(find.text('Quyền thư viện ảnh thiết bị'), findsOneWidget);
        expect(find.text('Đang cho phép truy cập ảnh đã chọn'), findsOneWidget);

        // Toggle 3rd switch (achievement photos) ON and journal switch OFF
        final achSwitch = find.byKey(
          const Key('privacy-allow-achievement-toggle'),
        );
        expect(tester.widget<Switch>(achSwitch).value, isFalse);
        await tester.tap(achSwitch);
        await tester.tap(find.byKey(const Key('privacy-share-journal-toggle')));
        await tester.pumpAndSettle();
        expect(tester.widget<Switch>(achSwitch).value, isTrue);

        // Switch photo mode to full and verify summary text updates
        await tester.ensureVisible(
          find.byKey(const Key('privacy-photo-mode-full')),
        );
        await tester.tap(find.byKey(const Key('privacy-photo-mode-full')));
        await tester.pumpAndSettle();
        expect(
          find.text('Đang cho phép truy cập đầy đủ thư viện ảnh'),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const Key('privacy-save-btn')));
        await tester.pumpAndSettle();

        expect(savedMode, PhotoAccessMode.full);
        expect(savedJournal, isFalse);
        expect(savedMeasurements, isTrue);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('5.13 AppSettingsDetailPage preview sync & interactions', () {
    testWidgets(
      'matches preview 5.13 theme switch, unit pill, reminder times, reduce blur, and saves',
      (tester) async {
        tester.view.physicalSize = const Size(393, 852);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        String? savedUnit;
        bool? savedReminder;
        String? savedTime;
        ThemeMode? selectedThemeMode;

        await tester.pumpWidget(
          wrapScreen(
            child: AppSettingsDetailPage(
              unitSystem: 'cm / kg',
              workoutReminderEnabled: true,
              reminderTime: '18:00',
              onThemeModeChanged: (m) => selectedThemeMode = m,
              onSave: (unit, reminder, time) {
                savedUnit = unit;
                savedReminder = reminder;
                savedTime = time;
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('TÙY CHỈNH TRẢI NGHIỆM'), findsOneWidget);
        expect(find.text('Cài đặt ứng dụng'), findsOneWidget);
        expect(find.text('Giao diện hiển thị'), findsOneWidget);
        expect(find.text('Tối · Futuristic Performance Glass'), findsOneWidget);
        expect(find.text('Đơn vị đo lường'), findsOneWidget);
        expect(find.text('Hệ mét chuẩn quốc tế'), findsOneWidget);
        expect(find.text('kg · cm'), findsOneWidget);
        expect(find.text('Nhắc lịch tập & Dinh dưỡng'), findsOneWidget);
        expect(find.text('Thông báo trước buổi tập 30 phút'), findsOneWidget);
        expect(find.text('Giảm hiệu ứng mờ (Pin yếu)'), findsOneWidget);
        expect(find.text('Chuyển sang bề mặt đặc mượt hơn'), findsOneWidget);

        // Verify SVG icons match tab5-profile-sub.js 5.13
        final iconAssets = tester
            .widgetList<MetaGymIcon>(find.byType(MetaGymIcon))
            .map((e) => e.asset)
            .toList();
        expect(iconAssets, contains(MetaGymIcons.settingThemeAppearance));
        expect(iconAssets, contains(MetaGymIcons.settingUnitMeasurement));
        expect(iconAssets, contains(MetaGymIcons.settingNotificationsBell));
        expect(iconAssets, contains(MetaGymIcons.settingAccessibility));

        // Switch theme to Light -> updates description & callback
        await tester.tap(find.byKey(const Key('app-settings-theme-light')));
        await tester.pumpAndSettle();
        expect(find.text('Sáng · Crisp Daylight Glass'), findsOneWidget);
        expect(selectedThemeMode, ThemeMode.light);

        // Toggle unit system -> imperial (lbs · in)
        await tester.tap(find.byKey(const Key('app-settings-unit-row')));
        await tester.pumpAndSettle();
        expect(find.text('lbs · in'), findsOneWidget);
        expect(find.text('Hệ đo lường Anh – Mỹ'), findsOneWidget);

        // Pick reminder time 06:30
        await tester.tap(find.byKey(const Key('app-settings-time-06:30')));
        await tester.pumpAndSettle();

        // Toggle reduce blur ON
        await tester.tap(
          find.byKey(const Key('app-settings-reduce-blur-toggle')),
        );
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<Switch>(
                find.byKey(const Key('app-settings-reduce-blur-toggle')),
              )
              .value,
          isTrue,
        );

        // Save
        await tester.tap(find.byKey(const Key('app-settings-save-btn')));
        await tester.pumpAndSettle();
        expect(savedUnit, 'inch / lbs');
        expect(savedReminder, isTrue);
        expect(savedTime, '06:30');
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('5.14 SupportInfoDetailPage preview sync & interactions', () {
    testWidgets(
      'matches preview 5.14 studio hero, 5 info rows, and 3-channel contact modal',
      (tester) async {
        tester.view.physicalSize = const Size(393, 852);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final toasts = <String>[];

        await tester.pumpWidget(
          wrapScreen(child: SupportInfoDetailPage(onShowToast: toasts.add)),
        );
        await tester.pumpAndSettle();

        expect(find.text('META GYM CENTER'), findsOneWidget);
        expect(find.text('Phòng tập & Hỗ trợ'), findsOneWidget);
        expect(find.byType(MetaGymHeroGlassCard), findsOneWidget);
        expect(find.text('MG'), findsOneWidget);
        expect(find.text('Meta Gym Flagship Studio'), findsOneWidget);
        expect(find.text('Không gian tập luyện hiệu suất cao'), findsOneWidget);
        expect(find.text('05:30 – 22:00 (Hàng ngày)'), findsOneWidget);
        expect(find.text('1900 6868'), findsOneWidget);
        expect(find.text('cskh@metagym.vn'), findsOneWidget);
        expect(find.text('128 Nguyễn Huệ, Q.1, TP.HCM'), findsOneWidget);
        expect(find.text('v1.0.0 · Build 2026.11'), findsOneWidget);
        expect(find.text('Liên hệ hỗ trợ ngay'), findsOneWidget);

        // All 5 key-value rows align flush to the exact same right edge.
        final rightEdges = [
          tester.getTopRight(find.text('05:30 – 22:00 (Hàng ngày)')).dx,
          tester.getTopRight(find.text('1900 6868')).dx,
          tester.getTopRight(find.text('cskh@metagym.vn')).dx,
          tester.getTopRight(find.text('128 Nguyễn Huệ, Q.1, TP.HCM')).dx,
          tester.getTopRight(find.text('v1.0.0 · Build 2026.11')).dx,
        ];
        for (final dx in rightEdges) {
          expect(dx, closeTo(rightEdges.first, 0.5));
        }

        // Open support contact modal & test Chat channel
        await tester.tap(find.byKey(const Key('support-contact-btn')));
        await tester.pumpAndSettle();
        expect(find.text('Liên hệ Hỗ trợ Meta Gym'), findsOneWidget);
        expect(find.text('● Trực tuyến'), findsOneWidget);
        expect(find.text('Chat trực tuyến với CSKH'), findsOneWidget);
        expect(find.text('Gọi Hotline 1900 6868'), findsOneWidget);
        expect(find.text('Gửi Email CSKH'), findsOneWidget);

        await tester.tap(find.byKey(const Key('support-channel-chat')));
        await tester.pumpAndSettle();
        expect(toasts.last, 'Đã mở phòng chat Hỗ trợ Meta Gym');

        // Re-open and test Hotline channel
        await tester.tap(find.byKey(const Key('support-contact-btn')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('support-channel-call')));
        await tester.pumpAndSettle();
        expect(toasts.last, 'Đang kết nối tổng đài Meta Gym 1900 6868...');

        // Re-open and test Email channel
        await tester.tap(find.byKey(const Key('support-contact-btn')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('support-channel-email')));
        await tester.pumpAndSettle();
        expect(toasts.last, 'Đã mở soạn email tới cskh@metagym.vn');

        expect(tester.takeException(), isNull);
      },
    );
  });

  group('5.11–5.14 responsive matrix (Dark/Light, 375px/768px, 1.3x scale)', () {
    final screenBuilders = <String, Widget Function()>{
      '5.11 SecurityAccountDetailPage': () => SecurityAccountDetailPage(
        email: 'minhquan@metagym.vn',
        status: 'ACTIVE',
        roleLabel: 'Hội viên',
        onChangePassword: (_, _) async => true,
        onSignOut: () {},
        onShowToast: (_, {isError = false}) {},
      ),
      '5.12 PrivacySettingsDetailPage': () => PrivacySettingsDetailPage(
        accessMode: PhotoAccessMode.selectedOnly,
        shareJournalWithCoach: true,
        shareMeasurementsWithCoach: true,
        onSave: (_, _, _) async {},
      ),
      '5.13 AppSettingsDetailPage': () => AppSettingsDetailPage(
        unitSystem: 'cm / kg',
        workoutReminderEnabled: true,
        reminderTime: '18:00',
        onSave: (_, _, _) {},
      ),
      '5.14 SupportInfoDetailPage': () =>
          SupportInfoDetailPage(onShowToast: (_) {}),
    };

    for (final entry in screenBuilders.entries) {
      for (final brightness in [Brightness.dark, Brightness.light]) {
        for (final width in [375.0, 768.0]) {
          testWidgets(
            '${entry.key} renders without overflow at width=$width brightness=$brightness scale=1.3',
            (tester) async {
              tester.view.physicalSize = Size(width, 900);
              tester.view.devicePixelRatio = 1.0;
              addTearDown(tester.view.reset);

              await tester.pumpWidget(
                wrapScreen(
                  brightness: brightness,
                  textScale: 1.3,
                  disableAnimations: true,
                  child: entry.value(),
                ),
              );
              await tester.pumpAndSettle();

              expect(find.byType(BackdropFilter), findsNothing);
              expect(tester.takeException(), isNull);
            },
          );
        }
      }
    }
    for (final brightness in [Brightness.dark, Brightness.light]) {
      testWidgets(
        '5.11 biometric setup modal & 5.14 support modal render without overflow at 375px brightness=$brightness scale=1.3',
        (tester) async {
          tester.view.physicalSize = const Size(375, 812);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(
            wrapScreen(
              brightness: brightness,
              textScale: 1.3,
              disableAnimations: true,
              child: SecurityAccountDetailPage(
                email: 'minhquan@metagym.vn',
                status: 'ACTIVE',
                roleLabel: 'Hội viên',
                onChangePassword: (_, _) async => false,
                onSignOut: () {},
                onShowToast: (_, {isError = false}) {},
              ),
            ),
          );
          await tester.pumpAndSettle();

          await tester.ensureVisible(
            find.byKey(const Key('security-bio-setup-btn')),
          );
          await tester.tap(find.byKey(const Key('security-bio-setup-btn')));
          await tester.pumpAndSettle();
          expect(find.text('Kích hoạt Face ID'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.tap(find.byKey(const Key('bio-modal-cancel-btn')));
          await tester.pumpAndSettle();

          await tester.pumpWidget(
            wrapScreen(
              brightness: brightness,
              textScale: 1.3,
              disableAnimations: true,
              child: SupportInfoDetailPage(onShowToast: (_) {}),
            ),
          );
          await tester.pumpAndSettle();

          await tester.tap(find.byKey(const Key('support-contact-btn')));
          await tester.pumpAndSettle();
          expect(find.text('Liên hệ Hỗ trợ Meta Gym'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.tap(find.byKey(const Key('support-modal-close-btn')));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      '5.11 password change error recovery & 5.13 reminder toggle hide/show time pills',
      (tester) async {
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          wrapScreen(
            child: SecurityAccountDetailPage(
              email: 'minhquan@metagym.vn',
              status: 'PENDING',
              roleLabel: 'Hội viên',
              onChangePassword: (_, _) async => throw Exception('network'),
              onSignOut: () {},
              onShowToast: (_, {isError = false}) {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('● Tài khoản Hội viên · Chờ kích hoạt'),
          findsOneWidget,
        );

        final currentField = find.descendant(
          of: find.byKey(const Key('security-current-pass-field')),
          matching: find.byType(TextField),
        );
        final newField = find.descendant(
          of: find.byKey(const Key('security-new-pass-field')),
          matching: find.byType(TextField),
        );
        final confirmField = find.descendant(
          of: find.byKey(const Key('security-confirm-pass-field')),
          matching: find.byType(TextField),
        );

        await tester.ensureVisible(currentField);
        await tester.enterText(currentField, 'OldPass123');
        await tester.enterText(newField, 'NewPass456');
        await tester.enterText(confirmField, 'NewPass456');
        await tester.tap(find.byKey(const Key('security-update-password-btn')));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('security-password-error')),
          findsOneWidget,
        );
        expect(find.text('Cập nhật mật khẩu'), findsOneWidget);

        bool? savedReminder;
        await tester.pumpWidget(
          wrapScreen(
            child: AppSettingsDetailPage(
              unitSystem: 'cm / kg',
              workoutReminderEnabled: true,
              reminderTime: '18:00',
              onSave: (_, reminder, _) => savedReminder = reminder,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Khung giờ nhắc'), findsOneWidget);
        await tester.tap(find.byKey(const Key('app-settings-reminder-toggle')));
        await tester.pumpAndSettle();
        expect(find.text('Khung giờ nhắc'), findsNothing);

        await tester.tap(find.byKey(const Key('app-settings-save-btn')));
        await tester.pumpAndSettle();
        expect(savedReminder, isFalse);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
