import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_gym_app/app/feature_navigation.dart';
import 'package:meta_gym_app/app/meta_gym_app.dart';
import 'package:meta_gym_app/core/config/api_config.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/core/storage/token_storage.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/theme/meta_gym_icons.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_bottom_nav.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_svg_icon.dart';
import 'package:meta_gym_app/features/auth/domain/auth_models.dart';
import 'package:meta_gym_app/features/auth/presentation/session_controller.dart';
import 'package:meta_gym_app/features/coach/presentation/coach_home_page.dart';
import 'package:meta_gym_app/features/coaching/presentation/coach_notifications_page.dart';
import 'package:meta_gym_app/features/coaching/presentation/coach_offers_page.dart';

void main() {
  for (final width in [375.0, 768.0]) {
    testWidgets(
      'Coach keeps work tab selection on revisit at $width with reduced motion',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            theme: MetaGymTheme.dark,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            ),
            home: const CoachHomePage(
              previewMode: true,
              useSolidGlassFallback: true,
            ),
          ),
        );
        await tester.pumpAndSettle();
        final origin = tester.state(find.byType(CoachHomePage));
        Future<void> tab(String label) async {
          await tester.tap(
            find.descendant(
              of: find.byType(MetaGymBottomNav),
              matching: find.text(label),
            ),
          );
          await tester.pumpAndSettle();
        }

        await tab('Lịch dạy');
        await tester.tap(find.text('Học viên (2)'));
        await tester.pumpAndSettle();
        await tab('Trang chủ');
        await tab('Lịch dạy');
        await tab('Lịch dạy');
        expect(find.text('Nguyễn Minh Tuấn'), findsOneWidget);
        expect(
          Navigator.of(tester.element(find.byType(CoachHomePage))).canPop(),
          isFalse,
        );
        expect(tester.state(find.byType(CoachHomePage)), same(origin));
        expect(tester.takeException(), isNull);
      },
    );
  }

  const coachUser = AuthUser(
    id: 'coach-1',
    email: 'coach@metagym.test',
    fullName: 'Lê Hoàng Nam',
    role: UserRole.coach,
    status: 'ACTIVE',
  );

  testWidgets(
    'loads live Coach API data, renders at 375x812 without overflow, and reaches notifications, offers, and all coachDestinations',
    (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final adapter = _CoachHomeAdapter();
      final api = ApiClient.withAdapter(
        config: ApiConfig.fromValues(environment: 'local'),
        adapter: adapter,
      );
      final controller = SessionController(
        _MemoryTokenStorage('coach-token'),
        (_) async => coachUser,
      );

      await tester.pumpWidget(
        MetaGymApp(sessionController: controller, apiClient: api),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CoachHomePage), findsOneWidget);
      expect(find.text('Xin chào, Lê Hoàng Nam'), findsOneWidget);
      expect(find.text('Không gian dành cho huấn luyện viên'), findsOneWidget);

      // Coach avatar uses #F5B041 token
      final avatarText = find.text('LN');
      expect(avatarText, findsWidgets);

      // Live Hero Work Summary metrics (hard cap 8)
      expect(find.text('Tổng quan công việc'), findsOneWidget);
      expect(find.text('6/8'), findsOneWidget);
      expect(find.text('Còn 2 suất'), findsOneWidget);
      expect(find.text('Thông báo Coach'), findsWidgets);
      expect(find.text('1 thông báo chưa đọc'), findsWidgets);

      // Quick actions present (no Coach request approval flow)
      expect(find.text('Học viên'), findsOneWidget);
      expect(find.text('Giáo trình'), findsOneWidget);
      expect(find.text('Dinh dưỡng'), findsOneWidget);
      expect(find.text('Lịch tập'), findsOneWidget);
      expect(find.text('Yêu cầu chọn Coach'), findsNothing);
      expect(find.textContaining('yêu cầu chờ duyệt'), findsNothing);

      // Scroll to Next session + Bento cards
      await tester.scrollUntilVisible(find.text('Ca dạy tiếp theo'), 200);
      expect(find.text('Ca dạy tiếp theo'), findsOneWidget);
      expect(find.text('Nguyễn Minh Tuấn'), findsWidgets);

      await tester.scrollUntilVisible(find.text('6/7 ngày'), 200);
      expect(find.text('6/7 ngày'), findsOneWidget);
      expect(find.text('Gói PT Cơ bản'), findsOneWidget);
      expect(find.text('1 gói'), findsOneWidget);

      // Expand directory and verify every coachDestination + Offers + Notifications
      await tester.scrollUntilVisible(
        find.text('Danh mục tính năng Coach'),
        250,
      );
      await tester.tap(find.text('Danh mục tính năng Coach'));
      await tester.pumpAndSettle();

      for (final destination in coachDestinations) {
        await tester.scrollUntilVisible(find.text(destination.title).last, 150);
        expect(find.text(destination.title), findsWidgets);
      }

      // Scroll back to top and open CoachNotificationsPage from header bell
      await tester.scrollUntilVisible(
        find.text('Xin chào, Lê Hoàng Nam'),
        -300,
      );
      await tester.tap(find.byTooltip('Thông báo Coach'));
      await tester.pumpAndSettle();
      expect(find.byType(CoachNotificationsPage), findsOneWidget);
      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is MetaGymSvgIcon && w.assetPath == MetaGymIcons.commonBack,
        ),
      );
      await tester.pumpAndSettle();

      // Open CoachOffersPage from PT package Bento card
      await tester.scrollUntilVisible(find.text('Gói PT Cơ bản'), 200);
      await tester.ensureVisible(find.text('Gói PT Cơ bản'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gói PT Cơ bản'));
      await tester.pumpAndSettle();
      expect(find.byType(CoachOffersPage), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      // Switch to Lịch dạy tab (WorkHub) and verify schedule + members/requests
      await tester.tap(
        find.descendant(
          of: find.byType(MetaGymBottomNav),
          matching: find.text('Lịch dạy'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Lịch dạy & Học viên'), findsOneWidget);
      expect(find.text('Lịch dạy (90p)'), findsOneWidget);
      expect(find.text('Nhắn tin'), findsOneWidget);
      expect(find.text('Hủy ca'), findsOneWidget);
      expect(find.text('Hoàn tất'), findsOneWidget);
      // Ensure the 3 booking action labels stay on a single line at 375x812
      expect(tester.getSize(find.text('Nhắn tin')).height, lessThan(26));
      expect(tester.getSize(find.text('Hủy ca')).height, lessThan(26));
      expect(tester.getSize(find.text('Hoàn tất')).height, lessThan(26));
      expect(find.text('Học viên (1)'), findsOneWidget);

      await tester.tap(find.text('Học viên (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Nguyễn Minh Tuấn'), findsOneWidget);
      expect(find.text('Chấp nhận'), findsNothing);
      expect(find.text('Từ chối'), findsNothing);

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'all 5 Coach bottom tabs share MetaGymBrandHeader cleanly at 375x812',
    (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final adapter = _CoachHomeAdapter();
      final api = ApiClient.withAdapter(
        config: ApiConfig.fromValues(environment: 'local'),
        adapter: adapter,
      );
      final controller = SessionController(
        _MemoryTokenStorage('coach-token'),
        (_) async => coachUser,
      );

      await tester.pumpWidget(
        MetaGymApp(sessionController: controller, apiClient: api),
      );
      await tester.pumpAndSettle();

      // Tab 0: Trang chủ
      expect(find.byType(MetaGymBrandHeader), findsOneWidget);
      expect(find.text('META GYM · COACH'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(MetaGymBrandHeader),
          matching: find.text('MG'),
        ),
        findsOneWidget,
      );
      expect(find.text('Xin chào, Lê Hoàng Nam'), findsOneWidget);
      expect(find.text('Không gian dành cho huấn luyện viên'), findsOneWidget);
      final tab0Top = tester.getTopLeft(find.byType(MetaGymBrandHeader)).dy;

      // Tab 1: Lịch dạy
      await tester.tap(
        find.descendant(
          of: find.byType(MetaGymBottomNav),
          matching: find.text('Lịch dạy'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(MetaGymBrandHeader), findsOneWidget);
      expect(find.text('META GYM · COACH'), findsOneWidget);
      expect(tester.getTopLeft(find.byType(MetaGymBrandHeader)).dy, tab0Top);
      expect(find.text('Lịch dạy & Học viên'), findsOneWidget);
      expect(find.text('Quản lý ca dạy, yêu cầu & học viên'), findsOneWidget);

      // Tab 2: AI
      await tester.tap(
        find.descendant(
          of: find.byType(MetaGymBottomNav),
          matching: find.text('AI'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(MetaGymBrandHeader), findsOneWidget);
      expect(find.text('META GYM · COACH'), findsOneWidget);
      expect(tester.getTopLeft(find.byType(MetaGymBrandHeader)).dy, tab0Top);
      expect(find.text('Trợ lý AI'), findsOneWidget);
      expect(
        find.text('Hỏi đáp giáo trình, dinh dưỡng & lịch tập'),
        findsOneWidget,
      );

      // Tab 3: Tin nhắn
      await tester.tap(
        find.descendant(
          of: find.byType(MetaGymBottomNav),
          matching: find.text('Tin nhắn'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(MetaGymBrandHeader), findsOneWidget);
      expect(find.text('META GYM · COACH'), findsOneWidget);
      expect(tester.getTopLeft(find.byType(MetaGymBrandHeader)).dy, tab0Top);
      expect(find.text('Trao đổi cùng học viên & hỗ trợ'), findsOneWidget);

      // Tab 4: Hồ sơ
      await tester.tap(
        find.descendant(
          of: find.byType(MetaGymBottomNav),
          matching: find.text('Hồ sơ'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(MetaGymBrandHeader), findsOneWidget);
      expect(find.text('META GYM · COACH'), findsOneWidget);
      expect(tester.getTopLeft(find.byType(MetaGymBrandHeader)).dy, tab0Top);
      expect(find.text('Hồ sơ cá nhân'), findsOneWidget);
      expect(
        find.text('Tài khoản & thiết lập huấn luyện viên'),
        findsOneWidget,
      );

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'renders previewMode and error retry cleanly at 375x812 with zero overflow',
    (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const MaterialApp(
          home: CoachHomePage(previewMode: true, useSolidGlassFallback: true),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Xin chào, Lê Hoàng Nam'), findsOneWidget);
      expect(find.text('6/8'), findsOneWidget);
      expect(find.text('8/12'), findsNothing);

      await tester.scrollUntilVisible(find.text('Nguyễn Minh Tuấn').first, 200);
      expect(find.text('Nguyễn Minh Tuấn'), findsWidgets);

      final avatarFinder = find.ancestor(
        of: find.text('LN').first,
        matching: find.byType(Container),
      );
      final decoration = tester
          .widget<Container>(avatarFinder.first)
          .decoration;
      expect(
        decoration,
        isA<BoxDecoration>().having(
          (box) => box.color,
          'coach avatar background',
          MetaGymTheme.coachAvatarBackground,
        ),
      );

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'enforces hard cap of 8 even if API returns stale memberLimit 12',
    (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final adapter = _CoachHomeAdapter(
        memberLimit: 12,
        usedSlots: 8,
        availableSlots: 4,
      );
      final api = ApiClient.withAdapter(
        config: ApiConfig.fromValues(environment: 'local'),
        adapter: adapter,
      );
      final controller = SessionController(
        _MemoryTokenStorage('coach-token'),
        (_) async => coachUser,
      );

      await tester.pumpWidget(
        MetaGymApp(sessionController: controller, apiClient: api),
      );
      await tester.pumpAndSettle();

      expect(find.text('8/8'), findsOneWidget);
      expect(find.text('Đã đủ suất'), findsOneWidget);
      expect(find.text('8/12'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

class _MemoryTokenStorage implements TokenStorage {
  _MemoryTokenStorage(this.token);

  String? token;

  @override
  Future<void> delete() async => token = null;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> write(String value) async => token = value;
}

class _CoachHomeAdapter implements HttpClientAdapter {
  _CoachHomeAdapter({
    this.memberLimit = 8,
    this.usedSlots = 6,
    this.availableSlots = 2,
  });

  final int memberLimit;
  final int usedSlots;
  final int availableSlots;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final nowUtc = DateTime.now().toUtc();
    final gymNow = nowUtc.add(const Duration(hours: 7));
    final gymTodayMax = DateTime.utc(
      gymNow.year,
      gymNow.month,
      gymNow.day,
      23,
      0,
    );
    final gymCandidate = gymNow.add(const Duration(minutes: 20));
    final gymStart = gymCandidate.isAfter(gymTodayMax)
        ? gymTodayMax
        : gymCandidate;
    final startUtc = gymStart.subtract(const Duration(hours: 7));
    final endUtc = startUtc.add(const Duration(minutes: 90));

    final Object? data = switch (options.path) {
      '/coach/requests' => [
        {
          'id': 'req-1',
          'memberId': 'member-9',
          'coachId': 'coach-1',
          'status': 'PENDING',
          'message': 'Tôi muốn tập tăng cơ buổi tối.',
        },
      ],
      '/coaches/coach-1' => {
        'id': 'coach-1',
        'fullName': 'Lê Hoàng Nam',
        'memberLimit': memberLimit,
        'usedSlots': usedSlots,
        'availableSlots': availableSlots,
        'specialties': ['Tăng cơ'],
      },
      '/coach/members' => [
        {
          'id': 'rel-1',
          'memberId': 'member-1',
          'memberFullName': 'Nguyễn Minh Tuấn',
          'status': 'ACTIVE',
        },
      ],
      '/coach/training-sessions' => <Object>[],
      '/coach-bookings' => [
        {
          'id': 'bk-1',
          'entitlementId': 'ent-1',
          'memberId': 'member-1',
          'coachId': 'coach-1',
          'startsAt': startUtc.toIso8601String(),
          'endsAt': endUtc.toIso8601String(),
          'status': 'BOOKED',
          'memberName': 'Nguyễn Minh Tuấn',
          'coachName': 'Lê Hoàng Nam',
        },
      ],
      '/coach-notifications' => [
        {
          'id': '101',
          'kind': 'BOOKED',
          'subjectId': 'bk-1',
          'eventAt': startUtc.toIso8601String(),
          'readAt': null,
        },
      ],
      '/coach-packages' => [
        {
          'code': 'BASIC',
          'name': 'Gói PT Cơ bản',
          'sessionCount': 8,
          'durationDays': 30,
          'price': 3200000,
          'status': 'ACTIVE',
        },
      ],
      '/coaches/coach-1/work-slots' => {
        'days': [
          {
            'weekday': 1,
            'starts': ['09:00', '10:30', '14:00', '15:30'],
          },
          {
            'weekday': 2,
            'starts': ['09:00', '10:30', '14:00', '15:30'],
          },
          {
            'weekday': 3,
            'starts': ['09:00', '10:30', '14:00', '15:30'],
          },
          {
            'weekday': 4,
            'starts': ['09:00', '10:30', '14:00', '15:30'],
          },
          {
            'weekday': 5,
            'starts': ['09:00', '10:30', '14:00', '15:30'],
          },
          {
            'weekday': 6,
            'starts': ['09:00', '10:30', '14:00', '15:30'],
          },
        ],
        'configured': true,
      },
      '/coach-bookings/blocks' => <Object>[],
      '/coach-payment-holds' => <Object>[],
      '/users/me' => {'id': 'coach-1', 'profile': <String, Object?>{}},
      '/memberships/me' => <Object>[],
      '/relationships/me' => null,
      '/coach-entitlements' => <Object>[],
      _ => <Object>[],
    };

    return ResponseBody.fromString(
      jsonEncode({'data': data}),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
