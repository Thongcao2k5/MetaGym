import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_gym_app/core/config/api_config.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/features/coaching/data/coach_members_service.dart';
import 'package:meta_gym_app/features/coaching/data/coach_selection_service.dart';
import 'package:meta_gym_app/features/coaching/domain/coach_member_models.dart';
import 'package:meta_gym_app/features/coaching/domain/coach_models.dart';
import 'package:meta_gym_app/features/coaching/presentation/coach_detail_page.dart';
import 'package:meta_gym_app/features/coaching/presentation/coach_member_detail_page.dart';
import 'package:meta_gym_app/features/coaching/presentation/member_coaching_page.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets(
    'Coach submits outcome, Member approves anonymously then toggles name or withdraws, CoachDetail shows approved case',
    (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final adapter = _OutcomeAdapter();
      final api = ApiClient.withAdapter(
        config: ApiConfig.fromValues(environment: 'local'),
        adapter: adapter,
      );

      // 1. Coach creates an outcome for an active Member.
      await tester.pumpWidget(
        Provider<ApiClient>.value(
          value: api,
          child: MaterialApp(
            theme: AppTheme.dark,
            home: CoachMemberDetailPage(
              memberId: 'member-1',
              service: _SingleMemberFixture(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Gửi thành quả'));
      await tester.tap(find.text('Gửi thành quả'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('outcome-goal')), 'Tăng cơ');
      await tester.enterText(find.byKey(const Key('outcome-weeks')), '12');
      await tester.enterText(
        find.byKey(const Key('outcome-before-weight')),
        '68',
      );
      await tester.enterText(
        find.byKey(const Key('outcome-after-weight')),
        '73',
      );
      await tester.enterText(find.byKey(const Key('outcome-before-fat')), '22');
      await tester.enterText(find.byKey(const Key('outcome-after-fat')), '17');
      await tester.tap(find.text('Gửi học viên duyệt'));
      await tester.pumpAndSettle();

      expect(adapter.cases.length, 1);
      expect(tester.takeException(), isNull);
      expect(adapter.cases.first['status'], 'PENDING_MEMBER');
      expect(find.text('Chờ học viên duyệt'), findsOneWidget);

      // 2. Member opens MemberCoachingPage -> Duyệt thành quả học viên -> approves anonymously -> enables real name -> withdraws.
      await tester.pumpWidget(
        Provider<ApiClient>.value(
          value: api,
          child: MaterialApp(
            theme: AppTheme.dark,
            home: const MemberCoachingPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Kết thúc quan hệ'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Duyệt thành quả học viên'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Duyệt thành quả học viên'));
      await tester.pumpAndSettle();

      expect(find.text('Học viên ẩn danh'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Duyệt công khai'));
      await tester.tap(find.text('Duyệt công khai'));
      await tester.pumpAndSettle();
      expect(adapter.cases.first['status'], 'APPROVED');
      expect(tester.takeException(), isNull);
      expect(adapter.cases.first['allowRealName'], isFalse);

      // 3. CoachDetailPage renders approved anonymous case.
      await tester.pumpWidget(
        Provider<ApiClient>.value(
          value: api,
          child: MaterialApp(
            theme: AppTheme.dark,
            home: CoachDetailPage(
              coachId: 'coach-1',
              service: _SingleCoachFixture(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Thành quả học viên'), findsOneWidget);
      expect(find.text('Học viên ẩn danh'), findsOneWidget);
      expect(find.text('Mục tiêu: Tăng cơ'), findsOneWidget);
      expect(find.text('12 tuần'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

class _SingleMemberFixture implements CoachMembersService {
  @override
  Future<List<CoachMemberSummary>> getMembers() async => const [];

  @override
  Future<CoachMemberDetail> getMember(String memberId) async =>
      const CoachMemberDetail(
        relationshipId: 'rel-1',
        memberId: 'member-1',
        status: 'ACTIVE',
        memberFullName: 'Trần Gia Huy',
        email: 'huy@example.com',
      );

  @override
  Future<List<CoachTerminationRequest>> getTerminationRequests() async =>
      const [];

  @override
  Future<void> requestTermination(String relationshipId, String reason) async {}
}

class _SingleCoachFixture implements CoachSelectionService {
  @override
  Future<List<CoachProfile>> getCoaches() async => const [];

  @override
  Future<CoachProfile> getCoach(String id) async => const CoachProfile(
    id: 'coach-1',
    fullName: 'Lê Hoàng Nam',
    specialties: ['Tăng cơ'],
    memberLimit: 8,
    usedSlots: 6,
    availableSlots: 2,
  );

  @override
  Future<CoachRequest> sendRequest(String coachId, String? message) async =>
      throw UnimplementedError();
}

class _OutcomeAdapter implements HttpClientAdapter {
  final List<Map<String, dynamic>> cases = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    Object? body;
    if (requestStream != null) {
      final raw = await requestStream.fold<List<int>>(
        <int>[],
        (acc, chunk) => acc..addAll(chunk),
      );
      if (raw.isNotEmpty) body = jsonDecode(utf8.decode(raw));
    }
    final path = options.path;
    final method = options.method;
    if (method == 'GET' && path == '/coach/members/member-1/outcomes') {
      return _json(cases);
    }
    if (method == 'POST' && path == '/coach/members/member-1/outcomes') {
      final map = Map<String, dynamic>.from(body as Map);
      final saved = {
        'id': 'outcome-1',
        'coachId': 'coach-1',
        'coachName': 'Lê Hoàng Nam',
        'memberId': 'member-1',
        'memberName': 'Trần Gia Huy',
        'relationshipId': 'rel-1',
        'goal': map['goal'],
        'durationWeeks': map['durationWeeks'],
        'beforeWeightKg': map['beforeWeightKg'],
        'afterWeightKg': map['afterWeightKg'],
        'beforeBodyFatPercent': map['beforeBodyFatPercent'],
        'afterBodyFatPercent': map['afterBodyFatPercent'],
        'status': 'PENDING_MEMBER',
        'allowRealName': false,
      };
      cases
        ..clear()
        ..add(saved);
      return _json(saved);
    }
    if (method == 'GET' && path == '/member/coach-outcomes') {
      return _json(cases);
    }
    if (method == 'PATCH' && path == '/member/coach-outcomes/outcome-1') {
      final map = Map<String, dynamic>.from(body as Map);
      final current = cases.first;
      current['status'] = map['decision'] ?? current['status'];
      current['allowRealName'] =
          map['allowRealName'] ?? current['allowRealName'];
      return _json(current);
    }
    if (method == 'GET' && path == '/coaches/coach-1/outcomes') {
      return _json([
        for (final item in cases)
          if (item['status'] == 'APPROVED')
            {
              ...item,
              'studentName': item['allowRealName'] == true
                  ? 'Trần Gia Huy'
                  : 'Học viên ẩn danh',
              'studentInitials': item['allowRealName'] == true ? 'TH' : 'HV',
            },
      ]);
    }
    final Object data = switch (path) {
      '/relationships/me' => {
        'id': 'rel-1',
        'memberId': 'member-1',
        'coachId': 'coach-1',
        'coachName': 'Lê Hoàng Nam',
        'status': 'ACTIVE',
      },
      '/relationships/me/history' => [],
      '/coach-requests/me' => [],
      '/coaches' => [],
      '/coach-entitlements' => [],
      '/coach-payment-holds' => [],
      '/coaches/coach-1/work-slots' => {'days': []},
      _ => throw StateError('Unhandled path: $method $path'),
    };
    return _json(data);
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
