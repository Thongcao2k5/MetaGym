import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_gym_app/core/config/api_config.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_icon.dart';
import 'package:meta_gym_app/features/coach/presentation/coach_home_page.dart';
import 'package:meta_gym_app/features/coaching/data/coach_members_service.dart';
import 'package:meta_gym_app/features/coaching/domain/coach_member_models.dart';
import 'package:meta_gym_app/features/coaching/presentation/coach_member_detail_page.dart';
import 'package:meta_gym_app/features/coaching/presentation/coach_members_page.dart';
import 'package:meta_gym_app/features/coaching/presentation/coach_notifications_page.dart';
import 'package:provider/provider.dart';

void main() {
  DateTime fixedNow() => DateTime.utc(2026, 11, 23, 11, 2);

  Widget wrapScreen(
    Widget child, {
    required ThemeData theme,
    double textScale = 1.3,
    bool disableAnimations = false,
  }) {
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

  Future<void> pumpViewportMatrix(
    WidgetTester tester,
    Widget Function() build, {
    required String label,
    FutureOr<void> Function(bool isDark)? verifyPerViewport,
  }) async {
    const viewports = <Size>[Size(375, 812), Size(768, 1024), Size(812, 375)];
    for (final size in viewports) {
      for (final (theme, isDark, disableAnim) in [
        (MetaGymTheme.dark, true, false),
        (MetaGymTheme.light, false, true),
      ]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          KeyedSubtree(
            key: ValueKey('$size-$isDark'),
            child: wrapScreen(
              build(),
              theme: theme,
              textScale: 1.3,
              disableAnimations: disableAnim,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          tester.takeException(),
          isNull,
          reason: '$label threw at ${size.width}x${size.height} dark=$isDark',
        );
        expect(find.byType(MetaGymBackground), findsWidgets);
        expect(find.byType(MetaGymIcon), findsWidgets);
        await verifyPerViewport?.call(isDark);
      }
    }
  }

  group(
    'Coach Group 1 (1.1 - 1.4) Preview Sync, Member Cards & Dark/Light',
    () {
      testWidgets(
        '1.1 CoachHomePage matches Member layout order, Warm Smoked/Daylight cards & LN token at 375/768/landscape',
        (tester) async {
          await pumpViewportMatrix(
            tester,
            () => const CoachHomePage(previewMode: true),
            label: '1.1 CoachHomePage',
            verifyPerViewport: (isDark) {
              expect(find.byType(MetaGymHeroGlassCard), findsOneWidget);
              expect(find.text('META GYM · COACH'), findsOneWidget);
              expect(find.text('Học viên'), findsOneWidget);
              expect(find.text('Giáo trình'), findsOneWidget);
              expect(find.text('Dinh dưỡng'), findsOneWidget);
              expect(find.text('Lịch dạy'), findsNWidgets(2));
              expect(find.text('Tổng quan công việc'), findsOneWidget);
              expect(find.text('Ca dạy tiếp theo'), findsOneWidget);
              expect(find.text('Danh mục tính năng Coach'), findsNothing);
              expect(find.text('Đăng xuất'), findsNothing);

              // Layout order matches Member Home: QuickDock < Hero < NextSession < Bento
              final dockY = tester.getTopLeft(find.text('Học viên')).dy;
              final heroY = tester
                  .getTopLeft(find.text('Tổng quan công việc'))
                  .dy;
              final nextY = tester.getTopLeft(find.text('Ca dạy tiếp theo')).dy;
              expect(dockY, lessThan(heroY));
              expect(heroY, lessThan(nextY));

              // Member card surface color parity in Dark & Light
              final firstGlassCard = find.byType(MetaGymGlassCard).first;
              final container = tester.widget<Container>(
                find
                    .descendant(
                      of: firstGlassCard,
                      matching: find.byType(Container),
                    )
                    .first,
              );
              final decoration = container.decoration as BoxDecoration;
              if (isDark) {
                expect(decoration.color, MetaGymWarmGlassTokens.cardFill);
              } else {
                expect(decoration.color, MetaGymPalette.light.surfaceSolid);
              }
            },
          );
        },
      );

      testWidgets(
        '1.2 CoachMembersPage syncs Preview 1.2 Hero, filters & Dark/Light without overflow',
        (tester) async {
          final service = _Group1MembersFixture();
          await pumpViewportMatrix(
            tester,
            () => CoachMembersPage(service: service),
            label: '1.2 CoachMembersPage',
            verifyPerViewport: (isDark) async {
              expect(find.text('META GYM · COACH'), findsOneWidget);
              expect(find.text('Hội viên của tôi'), findsOneWidget);
              expect(find.text('Công suất phụ trách 1:1'), findsOneWidget);
              expect(find.text('Hiệu lực'), findsOneWidget);
              expect(find.text('Chờ xử lý'), findsOneWidget);
              expect(find.text('Suất trống'), findsOneWidget);

              await tester.scrollUntilVisible(
                find.text('Nguyễn Minh Quân'),
                120,
              );
              await tester.pumpAndSettle();
              expect(find.text('Nguyễn Minh Quân'), findsOneWidget);

              final card = find.byType(MetaGymGlassCard).first;
              final container = tester.widget<Container>(
                find
                    .descendant(of: card, matching: find.byType(Container))
                    .first,
              );
              final decoration = container.decoration as BoxDecoration;
              if (isDark) {
                expect(decoration.color, MetaGymWarmGlassTokens.cardFill);
              } else {
                expect(decoration.color, MetaGymPalette.light.surfaceSolid);
              }

              await tester.scrollUntilVisible(find.text('Phạm Quốc Bảo'), 120);
              await tester.pumpAndSettle();
              expect(find.text('Phạm Quốc Bảo'), findsOneWidget);
            },
          );

          // Filter interactions
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(
            wrapScreen(
              CoachMembersPage(service: service),
              theme: MetaGymTheme.dark,
              textScale: 1.0,
            ),
          );
          await tester.pumpAndSettle();

          await tester.tap(find.byKey(const Key('members-filter-paused')));
          await tester.pumpAndSettle();
          expect(find.text('Nguyễn Minh Quân'), findsNothing);
          expect(find.text('Phạm Quốc Bảo'), findsOneWidget);

          await tester.tap(find.byKey(const Key('members-filter-pending')));
          await tester.pumpAndSettle();
          expect(find.text('Phạm Quốc Bảo'), findsNothing);
          expect(find.text('Yêu cầu ngừng phụ trách'), findsOneWidget);
          expect(find.text('Đỗ Khánh Linh'), findsOneWidget);

          await tester.tap(find.byKey(const Key('members-filter-all')));
          await tester.pumpAndSettle();
          expect(find.text('Nguyễn Minh Quân'), findsOneWidget);
          expect(find.text('Phạm Quốc Bảo'), findsOneWidget);
        },
      );

      testWidgets(
        '1.3 CoachMemberDetailPage syncs Preview 1.3 Hero, BMI, Health & Dark/Light cards',
        (tester) async {
          final service = _Group1MembersFixture();
          await pumpViewportMatrix(
            tester,
            () => CoachMemberDetailPage(memberId: 'm-1', service: service),
            label: '1.3 CoachMemberDetailPage',
            verifyPerViewport: (isDark) {
              expect(find.text('HỒ SƠ HỘI VIÊN'), findsOneWidget);
              expect(find.text('Nguyễn Minh Quân'), findsWidgets);
              expect(find.text('Giáo trình'), findsOneWidget);
              expect(find.text('Thực đơn'), findsOneWidget);
              expect(find.text('Nhắn tin'), findsOneWidget);
              expect(find.text('Khai báo thể trạng & Y tế'), findsOneWidget);
              expect(find.text('BMI 23.9'), findsOneWidget);
              expect(find.text('174.0 cm'), findsOneWidget);
              expect(find.text('72.4 kg'), findsOneWidget);
              expect(find.text('16.8%'), findsOneWidget);
              expect(find.text('Lưu ý chấn thương'), findsOneWidget);
              expect(find.byType(MetaGymHeroGlassCard), findsOneWidget);
            },
          );
        },
      );

      testWidgets(
        '1.4 CoachNotificationsPage (coachMode: true) renders Coach header, filters & copy across Dark/Light',
        (tester) async {
          final adapter = _CoachNotificationsAdapter();
          final api = ApiClient.withAdapter(
            config: ApiConfig.fromValues(environment: 'local'),
            adapter: adapter,
          );

          await pumpViewportMatrix(
            tester,
            () => Provider<ApiClient>.value(
              value: api,
              child: CoachNotificationsPage(coachMode: true, now: fixedNow),
            ),
            label: '1.4 CoachNotificationsPage (Coach)',
            verifyPerViewport: (isDark) {
              expect(find.text('META GYM · COACH'), findsOneWidget);
              expect(find.text('Thông báo'), findsOneWidget);
              expect(find.text('Lịch dạy'), findsOneWidget);
              expect(find.text('Học viên'), findsOneWidget);
              expect(find.text('Lịch tập 1:1 mới được đặt'), findsOneWidget);

              // Member-only filter labels must not appear in Coach mode
              expect(find.text('Lịch tập'), findsNothing);
              expect(find.text('Gói Coach'), findsNothing);

              final card = find.byKey(const Key('notification-card-cn-1'));
              final container = tester.widget<Container>(
                find
                    .descendant(of: card, matching: find.byType(Container))
                    .first,
              );
              final decoration = container.decoration as BoxDecoration;
              if (isDark) {
                expect(decoration.color, MetaGymWarmGlassTokens.cardFill);
              } else {
                expect(decoration.color, MetaGymPalette.light.surfaceSolid);
              }
            },
          );

          // Verify Coach cards below the fold & filter pill interaction at 390x844
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(
            Provider<ApiClient>.value(
              value: api,
              child: wrapScreen(
                CoachNotificationsPage(coachMode: true, now: fixedNow),
                theme: MetaGymTheme.dark,
                textScale: 1.0,
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('Yêu cầu ngừng phụ trách (72h)'), findsOneWidget);
          expect(find.text('Học viên đã duyệt thành quả'), findsOneWidget);

          final packagePill = find.byKey(const Key('notif-filter-package'));
          await tester.ensureVisible(packagePill);
          await tester.pumpAndSettle();
          await tester.tap(packagePill);
          await tester.pumpAndSettle();
          expect(find.text('Lịch tập 1:1 mới được đặt'), findsNothing);
          expect(find.text('Yêu cầu ngừng phụ trách (72h)'), findsOneWidget);
          expect(find.text('Học viên đã duyệt thành quả'), findsOneWidget);

          final sessionPill = find.byKey(const Key('notif-filter-session'));
          await tester.ensureVisible(sessionPill);
          await tester.pumpAndSettle();
          await tester.tap(sessionPill);
          await tester.pumpAndSettle();
          expect(find.text('Lịch tập 1:1 mới được đặt'), findsOneWidget);
          expect(find.text('Yêu cầu ngừng phụ trách (72h)'), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    },
  );
}

class _Group1MembersFixture implements CoachMembersService {
  @override
  Future<List<CoachMemberSummary>> getMembers() async => const [
    CoachMemberSummary(
      relationshipId: 'rel-1',
      memberId: 'm-1',
      memberFullName: 'Nguyễn Minh Quân',
      status: 'ACTIVE',
    ),
    CoachMemberSummary(
      relationshipId: 'rel-2',
      memberId: 'm-2',
      memberFullName: 'Phạm Quốc Bảo',
      status: 'PAUSED',
      pauseReason: 'MEMBERSHIP_EXPIRED',
    ),
  ];

  @override
  Future<CoachMemberDetail> getMember(String memberId) async =>
      const CoachMemberDetail(
        relationshipId: 'rel-1',
        memberId: 'm-1',
        memberFullName: 'Nguyễn Minh Quân',
        status: 'ACTIVE',
        email: 'quan.nguyen@metagym.vn',
        fitnessGoal: 'Tăng cơ giảm mỡ · 4 buổi/tuần',
        heightCm: 174.0,
        weightKg: 72.4,
        bodyFatPercent: 16.8,
        healthNotes: 'Không có bệnh nền tim mạch.',
        injuryNotes: 'Đau nhẹ khớp vai phải khi đẩy tạ nặng trên 80 kg.',
      );

  @override
  Future<List<CoachTerminationRequest>> getTerminationRequests() async =>
      const [
        CoachTerminationRequest(
          id: 'term-1',
          relationshipId: 'rel-3',
          memberName: 'Đỗ Khánh Linh',
          requestedByRole: 'MEMBER',
          requestedByName: 'Đỗ Khánh Linh',
          reason: 'Đi công tác dài ngày 2 tháng',
          status: 'PENDING_COUNTERPARTY',
          responseDeadlineAt: '2026-11-28T09:00:00.000Z',
        ),
      ];

  @override
  Future<void> requestTermination(String relationshipId, String reason) async {}

  @override
  Future<CoachTerminationRequest> respondTermination(
    String requestId, {
    required String decision,
    String? reason,
  }) => throw UnimplementedError();
}

class _CoachNotificationsAdapter implements HttpClientAdapter {
  final List<Map<String, dynamic>> _items = [
    {
      'id': 'cn-1',
      'kind': 'BOOKED',
      'readAt': null,
      'createdAt': '2026-11-23T10:52:00Z',
    },
    {
      'id': 'cn-2',
      'kind': 'TERMINATION_REQUESTED',
      'readAt': null,
      'eventAt': '2026-11-23T10:02:00Z',
    },
    {
      'id': 'cn-3',
      'kind': 'OUTCOME_APPROVED',
      'readAt': null,
      'eventAt': '2026-11-23T08:02:00Z',
    },
    {
      'id': 'cn-4',
      'kind': 'PACKAGE_ACTIVE',
      'readAt': '2026-11-22T05:00:00Z',
      'eventAt': '2026-11-22T04:00:00Z',
    },
  ];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.method == 'GET' && options.path == '/coach-notifications') {
      return _json(_items);
    }
    if (options.method == 'PATCH' && options.path.endsWith('/read')) {
      return _json(_items.first);
    }
    throw StateError('Unhandled ${options.method} ${options.path}');
  }

  ResponseBody _json(Object? data) => ResponseBody.fromString(
    jsonEncode({'data': data}),
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}
