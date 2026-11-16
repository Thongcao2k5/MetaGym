import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_gym_app/core/config/api_config.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/features/coaching/presentation/coach_offers_page.dart';
import 'package:meta_gym_app/features/coaching/presentation/member_coaching_page.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('explains Gym expiry before a member reserves a Coach package', (
    tester,
  ) async {
    final api = ApiClient.withAdapter(
      config: ApiConfig.fromValues(environment: 'local'),
      adapter: _OffersAdapter(),
    );

    await tester.pumpWidget(
      Provider.value(
        value: api,
        child: const MaterialApp(home: CoachOffersPage(coachId: 'coach-1')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Khi gói Gym hết hạn'), findsOneWidget);
    expect(
      find.textContaining('Thời hạn gói Coach vẫn tiếp tục tính'),
      findsOneWidget,
    );
    expect(find.text('Gói cơ bản'), findsWidgets);
    expect(find.widgetWithText(FilledButton, 'Thanh toán'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'gates checkout behind health declaration then holds and settles payment',
    (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final adapter = _OffersAdapter(fullFlow: true);
      final api = ApiClient.withAdapter(
        config: ApiConfig.fromValues(environment: 'local'),
        adapter: adapter,
      );

      await tester.pumpWidget(
        Provider.value(
          value: api,
          child: const MaterialApp(home: CoachOffersPage(coachId: 'coach-1')),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.widgetWithText(FilledButton, 'Thanh toán'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Thanh toán'));
      await tester.pumpAndSettle();

      expect(find.text('Khai báo thể trạng'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('health-height')), '172');
      await tester.enterText(find.byKey(const Key('health-weight')), '68');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Không').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Không').first);
      await tester.ensureVisible(find.text('Không').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Không').last);
      await tester.ensureVisible(
        find.widgetWithText(FilledButton, 'Lưu và tiếp tục thanh toán'),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(FilledButton, 'Lưu và tiếp tục thanh toán'),
      );
      await tester.pumpAndSettle();

      expect(adapter.holdCreated, isTrue);
      expect(find.text('Đang giữ suất · Chờ thanh toán'), findsOneWidget);
      expect(find.text('Hoàn tất thanh toán'), findsOneWidget);

      await tester.ensureVisible(find.text('Hoàn tất thanh toán'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hoàn tất thanh toán'));
      await tester.pumpAndSettle();

      expect(adapter.confirmedMock, isTrue);
      expect(find.byType(MemberCoachingPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'rotates idempotency key after cancel and resolves Coach avatar URL',
    (tester) async {
      final adapter = _OffersAdapter(withAvatar: true);
      final api = ApiClient.withAdapter(
        config: ApiConfig.fromValues(environment: 'local'),
        adapter: adapter,
      );

      await tester.pumpWidget(
        Provider.value(
          value: api,
          child: const MaterialApp(home: CoachOffersPage(coachId: 'coach-1')),
        ),
      );
      await tester.pumpAndSettle();

      expect(adapter.requestedPaths, contains('/api/v1/users/coach-1/avatar'));
      expect(
        adapter.requestedPaths.any((p) => p.contains('/api/v1/api/v1')),
        isFalse,
      );

      await tester.ensureVisible(
        find.widgetWithText(FilledButton, 'Thanh toán'),
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Thanh toán'));
      await tester.pumpAndSettle();
      expect(adapter.holdKeys.length, 1);

      await tester.ensureVisible(find.text('Hủy giữ suất'));
      await tester.tap(find.text('Hủy giữ suất'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.widgetWithText(FilledButton, 'Thanh toán'),
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Thanh toán'));
      await tester.pumpAndSettle();
      expect(adapter.holdKeys.length, 2);
      expect(adapter.holdKeys[0], isNot(adapter.holdKeys[1]));
      expect(find.text('Đang giữ suất · Chờ thanh toán'), findsOneWidget);
    },
  );
}

class _OffersAdapter implements HttpClientAdapter {
  _OffersAdapter({this.fullFlow = false, this.withAvatar = false});

  final bool fullFlow;
  final bool withAvatar;
  bool healthDeclared = false;
  bool holdCreated = false;
  bool cancelledHold = false;
  bool confirmedMock = false;
  final List<String> requestedPaths = [];
  final List<String?> holdKeys = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestedPaths.add(options.uri.path);
    if (options.uri.path == '/api/v1/users/coach-1/avatar') {
      return ResponseBody.fromString('{}', 404);
    }
    if (options.path == '/users/me/health-declaration') {
      healthDeclared = true;
      return _json({
        'profile': {
          'heightCm': 172,
          'weightKg': 68,
          'healthDeclarationCompletedAt': '2026-11-16T03:00:00Z',
        },
      });
    }
    if (options.path == '/coach-payment-holds' && options.method == 'POST') {
      holdCreated = true;
      cancelledHold = false;
      holdKeys.add(options.headers['idempotency-key'] as String?);
      return _json({
        'id': 'hold-1',
        'coachId': 'coach-1',
        'planCode': 'BASIC',
        'planName': 'Gói cơ bản',
        'sessionCount': 10,
        'durationDays': 30,
        'amount': 500000,
        'status': 'HELD',
        'expiresAt': '2099-01-01T00:15:00Z',
      });
    }
    if (options.path == '/coach-payment-holds/hold-1/cancel') {
      cancelledHold = true;
      return _json({
        'id': 'hold-1',
        'coachId': 'coach-1',
        'planCode': 'BASIC',
        'planName': 'Gói cơ bản',
        'sessionCount': 10,
        'durationDays': 30,
        'amount': 500000,
        'status': 'CANCELLED',
        'expiresAt': '2099-01-01T00:15:00Z',
      });
    }
    if (options.path == '/coach-payment-holds/hold-1/mock-confirmations') {
      confirmedMock = true;
      return _json({
        'hold': {
          'id': 'hold-1',
          'coachId': 'coach-1',
          'planCode': 'BASIC',
          'planName': 'Gói cơ bản',
          'sessionCount': 10,
          'durationDays': 30,
          'amount': 500000,
          'status': 'CONSUMED',
          'expiresAt': '2099-01-01T00:15:00Z',
        },
        'entitlementId': 'ent-1',
      });
    }

    final Object? data = switch (options.path) {
      '/coach-packages' => [
        {
          'code': 'BASIC',
          'name': 'Gói cơ bản',
          'sessionCount': 10,
          'durationDays': 30,
          'price': 500000,
        },
      ],
      '/coaches/coach-1/work-slots' => {'days': []},
      '/coach-payment-holds' =>
        holdCreated && !confirmedMock && !cancelledHold
            ? [
                {
                  'id': 'hold-1',
                  'coachId': 'coach-1',
                  'planCode': 'BASIC',
                  'planName': 'Gói cơ bản',
                  'sessionCount': 10,
                  'durationDays': 30,
                  'amount': 500000,
                  'status': 'HELD',
                  'expiresAt': '2099-01-01T00:15:00Z',
                },
              ]
            : [],
      '/coaches/coach-1' => {
        'id': 'coach-1',
        'fullName': 'Lê Hoàng Nam',
        'avatarUrl': withAvatar ? '/api/v1/users/coach-1/avatar' : null,
        'specialties': ['Tăng cơ'],
        'memberLimit': 8,
        'usedSlots': 6,
        'availableSlots': 2,
      },
      '/coaches' => [
        {
          'id': 'coach-1',
          'fullName': 'Lê Hoàng Nam',
          'specialties': ['Tăng cơ'],
          'memberLimit': 8,
          'usedSlots': 6,
          'availableSlots': 2,
        },
      ],
      '/users/me' => {
        'id': 'member-1',
        'profile': fullFlow && !healthDeclared
            ? <String, dynamic>{}
            : {'healthDeclarationCompletedAt': '2026-11-16T03:00:00Z'},
      },
      '/memberships/me' => [
        {'id': 'mem-1', 'status': 'ACTIVE'},
      ],
      '/relationships/me' =>
        confirmedMock
            ? {
                'id': 'rel-1',
                'memberId': 'member-1',
                'coachId': 'coach-1',
                'coachName': 'Lê Hoàng Nam',
                'status': 'ACTIVE',
              }
            : null,
      '/relationships/me/history' => [],
      '/coach-entitlements' =>
        confirmedMock
            ? [
                {
                  'id': 'ent-1',
                  'coachId': 'coach-1',
                  'planName': 'Gói cơ bản',
                  'status': 'ACTIVE',
                  'relationshipStatus': 'ACTIVE',
                  'remainingSessions': 10,
                  'totalSessions': 10,
                  'startsOn': '2026-11-16',
                  'endsOn': '2026-12-15',
                },
              ]
            : [],
      _ => throw StateError('Path: ${options.path}'),
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
