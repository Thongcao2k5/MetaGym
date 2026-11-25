import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_gym_app/core/config/api_config.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/features/training/presentation/meal_plans_page.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets(
    'Coach edits structured 7-day meal plan, adds dish via sheet, and saves at 375x812',
    (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final adapter = _MealPlanAdapter();
      final api = ApiClient.withAdapter(
        config: ApiConfig.fromValues(environment: 'local'),
        adapter: adapter,
      );

      await tester.pumpWidget(
        Provider<ApiClient>.value(
          value: api,
          child: const MaterialApp(
            home: MealPlansPage(memberId: 'member-1', editable: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Thiết kế thực đơn'), findsOneWidget);
      expect(find.text('Chế độ Coach'), findsOneWidget);

      await tester.tap(find.text('T2'));
      await tester.pumpAndSettle();
      expect(find.text('Ức gà áp chảo'), findsOneWidget);

      await tester.tap(find.textContaining('Thêm món ('));
      await tester.pumpAndSettle();
      expect(find.text('Thêm món vào thực đơn'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).last, '200');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Thêm món'));
      await tester.pumpAndSettle();

      expect(find.text('Ức gà áp chảo'), findsNWidgets(2));

      await tester.tap(find.text('Lưu thực đơn'));
      await tester.pumpAndSettle();

      expect(adapter.savedCount, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Member views structured 7-day meal plan cleanly at 375x812', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final api = ApiClient.withAdapter(
      config: ApiConfig.fromValues(environment: 'local'),
      adapter: _MealPlanAdapter(),
    );

    await tester.pumpWidget(
      Provider<ApiClient>.value(
        value: api,
        child: const MaterialApp(home: MealPlansPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Thực đơn 7 ngày'), findsOneWidget);
    expect(find.text('Đang áp dụng'), findsOneWidget);
    await tester.tap(find.text('T2'));
    await tester.pumpAndSettle();
    expect(find.text('Ức gà áp chảo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _MealPlanAdapter implements HttpClientAdapter {
  int savedCount = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.method == 'PUT' &&
        options.path == '/coach/meal-plans/member-1') {
      savedCount++;
      return _json({'id': 'mp-1', 'title': 'Thực đơn tăng cơ', 'items': []});
    }
    final Object data = switch (options.path) {
      '/coach/meal-plans/member-1' => {
        'id': 'mp-1',
        'title': 'Thực đơn tăng cơ',
        'status': 'ACTIVE',
        'items': [
          {
            'day': 1,
            'meal': 'LUNCH',
            'foodId': 'f-1',
            'foodName': 'Ức gà áp chảo',
            'kcalPer100g': 165,
            'grams': 150,
          },
        ],
      },
      '/meal-plans/me' => [
        {
          'id': 'mp-1',
          'title': 'Thực đơn tăng cơ',
          'status': 'ACTIVE',
          'items': [
            {
              'day': 1,
              'meal': 'LUNCH',
              'foodId': 'f-1',
              'foodName': 'Ức gà áp chảo',
              'kcalPer100g': 165,
              'grams': 150,
            },
          ],
        },
      ],
      '/nutrition-foods' => [
        {'id': 'f-1', 'name': 'Ức gà áp chảo', 'kcalPer100g': 165},
      ],
      _ => <Object>[],
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
