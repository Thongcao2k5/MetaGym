import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_gym_app/core/config/api_config.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/features/coaching/presentation/member_health_declaration_page.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets(
    'body fat may be empty but height, weight and health answers are required',
    (tester) async {
      final adapter = _HealthAdapter();
      final client = ApiClient.withAdapter(
        config: ApiConfig.fromValues(environment: 'local'),
        adapter: adapter,
      );
      await tester.pumpWidget(
        Provider.value(
          value: client,
          child: const MaterialApp(home: MemberHealthDeclarationPage()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('health-height')), '170');
      await tester.enterText(find.byKey(const Key('health-weight')), '65,5');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.widgetWithText(FilledButton, 'Lưu khai báo'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Lưu khai báo'));
      await tester.pump();
      expect(find.textContaining('Hãy chọn Có hoặc Không'), findsOneWidget);
      expect(adapter.saved, isNull);

      await tester.ensureVisible(find.text('Không').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Không').first);
      await tester.ensureVisible(find.text('Không').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Không').last);
      await tester.ensureVisible(
        find.widgetWithText(FilledButton, 'Lưu khai báo'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Lưu khai báo'));
      await tester.pumpAndSettle();
      expect(adapter.saved?['heightCm'], 170);
      expect(adapter.saved?['weightKg'], 65.5);
      expect(adapter.saved?['bodyFatPercent'], isNull);
      expect(adapter.saved?['hasCondition'], false);
      expect(adapter.saved?['hasInjury'], false);
    },
  );
}

class _HealthAdapter implements HttpClientAdapter {
  Map<String, dynamic>? saved;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path == '/users/me/health-declaration') {
      final bytes = await requestStream!.fold<List<int>>(
        <int>[],
        (all, chunk) => all..addAll(chunk),
      );
      saved = Map<String, dynamic>.from(jsonDecode(utf8.decode(bytes)) as Map);
    }
    return ResponseBody.fromString(
      jsonEncode({
        'data': {'profile': {}},
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
