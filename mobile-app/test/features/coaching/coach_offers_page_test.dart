import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_gym_app/core/config/api_config.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/features/coaching/presentation/coach_offers_page.dart';
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
    expect(find.text('Gói cơ bản'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Giữ suất'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _OffersAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final data = switch (options.path) {
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
      '/coach-payment-holds' => [],
      _ => throw StateError('Path: ${options.path}'),
    };
    return ResponseBody.fromString(
      jsonEncode({'data': data}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
