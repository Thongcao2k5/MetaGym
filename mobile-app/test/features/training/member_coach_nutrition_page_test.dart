import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_gym_app/core/config/api_config.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/features/training/presentation/member_coach_nutrition_page.dart';

void main() {
  for (final theme in [MetaGymTheme.dark, MetaGymTheme.light]) {
    final modeLabel = theme.brightness == Brightness.dark ? 'dark' : 'light';
    testWidgets(
      'renders dedicated Coach nutrition page with shared Week/Month calendar ($modeLabel, 1.3x)',
      (tester) async {
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final api = ApiClient.withAdapter(
          config: ApiConfig.fromValues(environment: 'local'),
          adapter: _CoachNutritionAdapter(),
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.3)),
              child: child!,
            ),
            home: MemberCoachNutritionPage(apiClient: api),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Thực đơn & Dinh dưỡng'), findsOneWidget);
        expect(find.text('Thực đơn Tăng Cơ 2.400 kcal'), findsOneWidget);
        expect(find.text('Tuần'), findsOneWidget);
        expect(find.text('Tháng'), findsOneWidget);
        expect(find.text('Bữa sáng'), findsOneWidget);
        expect(find.text('Bữa trưa'), findsOneWidget);
        expect(find.text('Bữa tối'), findsOneWidget);
        expect(find.text('Yến mạch nguyên cám'), findsOneWidget);
        expect(find.text('Ức gà áp chảo'), findsOneWidget);

        // Toggle calendar to Month view without overflow or exceptions
        await tester.tap(find.text('Tháng'));
        await tester.pumpAndSettle();
        expect(find.text('THEO THÁNG'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('handles empty and error states with retry cleanly', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final adapter = _CoachNutritionAdapter(empty: true, failFirst: true);
    final api = ApiClient.withAdapter(
      config: ApiConfig.fromValues(environment: 'local'),
      adapter: adapter,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: MetaGymTheme.dark,
        home: MemberCoachNutritionPage(apiClient: api),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    expect(find.text('Thử lại'), findsOneWidget);
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('Chưa có thực đơn từ Coach'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _CoachNutritionAdapter implements HttpClientAdapter {
  _CoachNutritionAdapter({this.empty = false, this.failFirst = false});

  final bool empty;
  final bool failFirst;
  int requests = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path == '/meal-plans/me') {
      requests++;
      if (failFirst && requests == 1) {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          message: 'offline',
        );
      }
      final Object data = empty
          ? <Object>[]
          : [
              {
                'id': 'mp-coach-1',
                'title': 'Thực đơn Tăng Cơ 2.400 kcal',
                'status': 'ACTIVE',
                'content': 'Uống đủ 3 lít nước mỗi ngày.',
                'items': [
                  for (var day = 1; day <= 7; day++) ...[
                    {
                      'day': day,
                      'meal': 'BREAKFAST',
                      'foodId': 'f-oats',
                      'foodName': 'Yến mạch nguyên cám',
                      'kcalPer100g': 380,
                      'grams': 100,
                    },
                    {
                      'day': day,
                      'meal': 'LUNCH',
                      'foodId': 'f-chicken',
                      'foodName': 'Ức gà áp chảo',
                      'kcalPer100g': 165,
                      'grams': 200,
                    },
                    {
                      'day': day,
                      'meal': 'DINNER',
                      'foodId': 'f-salmon',
                      'foodName': 'Cá hồi áp chảo',
                      'kcalPer100g': 208,
                      'grams': 150,
                    },
                  ],
                ],
              },
            ];
      return ResponseBody.fromString(
        jsonEncode({'data': data}),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    return ResponseBody.fromString(
      jsonEncode({'data': <Object>[]}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
