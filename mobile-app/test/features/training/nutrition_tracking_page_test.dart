import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/features/training/data/nutrition_tracking_api.dart';
import 'package:meta_gym_app/features/training/presentation/nutrition_tracking_page.dart';

class Fixture implements NutritionTrackingApi {
  Fixture(this.state);
  final String state;
  final dayCompleter = Completer<NutritionRecord>();
  int saveAttempts = 0;
  NutritionRecord? savedItem;
  final now = DateTime.now().toUtc().add(const Duration(hours: 7));

  @override
  Future<NutritionRecord> day(String date) async {
    if (state == 'error') throw Exception('offline');
    if (state == 'loading') return dayCompleter.future;
    final weekday = DateTime.parse(date).weekday;
    final hasCoach = state == 'coach' || state == 'coach-empty';
    return {
      'date': date,
      'hasActiveMembership': state != 'expired',
      'canWrite': state != 'expired',
      'relationshipStatus': hasCoach ? 'ACTIVE' : 'NONE',
      'plan': hasCoach
          ? {
              'title': 'Thực đơn tăng cơ',
              'items': [
                {
                  'day': weekday,
                  'meal': 'BREAKFAST',
                  'foodId': 'food-oats',
                  'foodName': 'Yến mạch',
                  'grams': 100,
                },
                {
                  'day': weekday,
                  'meal': 'LUNCH',
                  'foodId': 'food-rice',
                  'foodName': 'Cơm gạo lứt',
                  'grams': 150,
                },
              ],
            }
          : null,
      'entries': state == 'empty'
          ? []
          : state == 'coach-empty'
          ? []
          : [
              if (state == 'coach')
                {
                  'id': 'entry-oats',
                  'mealName': 'Yến mạch',
                  'mealType': 'BREAKFAST',
                  'foodId': 'food-oats',
                  'quantity': 80,
                  'unit': 'g',
                  'kcal': 136,
                  'eatenAt': '${date}T07:30:00+07:00',
                }
              else ...[
                {
                  'id': 'entry-rice',
                  'mealName': 'Cơm',
                  'mealType': 'BREAKFAST',
                  'quantity': 150,
                  'unit': 'g',
                  'kcal': 195,
                  'eatenAt': '${date}T08:00:00+07:00',
                },
                {
                  'id': 'entry-chicken-rice',
                  'mealName': 'Cơm gà',
                  'mealType': 'LUNCH',
                  'quantity': 1,
                  'unit': 'phần',
                  'kcal': null,
                  'eatenAt': '${date}T12:00:00+07:00',
                },
              ],
            ],
      if (hasCoach)
        'comparisons': {
          'BREAKFAST': {
            'status': 'DIFFERENCES',
            'message': 'Chênh lệch khẩu phần; không kết luận mức độ tuân thủ.',
            'differences': [
              {
                'foodId': 'food-oats',
                'foodName': 'Yến mạch',
                'suggestedGrams': 100,
                'actualGrams': 80,
                'deltaGrams': -20,
              },
            ],
          },
          'LUNCH': {
            'status': 'INSUFFICIENT',
            'message': 'Chưa đủ dữ liệu để đối chiếu: cần món danh mục, gram thực tế và thực đơn cho cùng bữa.',
            'differences': [],
          },
          'DINNER': {
            'status': 'INSUFFICIENT',
            'message': 'Chưa đủ dữ liệu để đối chiếu: cần món danh mục, gram thực tế và thực đơn cho cùng bữa.',
            'differences': [],
          },
          'SNACK': {
            'status': 'UNREGULATED',
            'message': 'Bữa phụ được ghi riêng.',
            'differences': [],
          },
        },
    };
  }

  @override
  Future<List<NutritionRecord>> foods() async => [
    {'id': 'food-oats', 'name': 'Yến mạch', 'kcalPer100g': 170},
    {'id': 'food-rice', 'name': 'Cơm gạo lứt', 'kcalPer100g': 110},
  ];
  @override
  Future<void> add(NutritionRecord item) async {
    saveAttempts++;
    if (saveAttempts == 1) throw Exception('save failed');
    savedItem = item;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  for (final state in ['no-coach', 'coach', 'empty', 'error', 'expired']) {
    testWidgets('375px nutrition $state at 1.3 text scale', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: MetaGymTheme.dark,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: RepaintBoundary(
            key: key,
            child: NutritionTrackingPage(api: Fixture(state)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(BottomNavigationBar), findsNothing);
      if (state == 'error') expect(find.text('Thử lại'), findsOneWidget);
      if (state == 'coach') {
        expect(find.textContaining('−20 g'), findsOneWidget);
        expect(
          find.text('Đối chiếu cần món danh mục và khẩu phần gram.'),
          findsOneWidget,
        );
        expect(find.textContaining('tuân thủ'), findsNothing);
        expect(
          find.descendant(
            of: find.byKey(const Key('nutrition-coach-source')),
            matching: find.text(
              'Đối chiếu cần món danh mục và khẩu phần gram.',
            ),
          ),
          findsOneWidget,
        );
        final editButton = find.byKey(
          const Key('nutrition-edit-meal-BREAKFAST'),
        );
        expect(editButton, findsOneWidget);
        expect(tester.getSize(editButton).width, greaterThanOrEqualTo(48));
        expect(tester.getSize(editButton).height, greaterThanOrEqualTo(48));
        expect(
          tester.getTopLeft(editButton).dy,
          lessThan(tester.getTopLeft(find.text('Yến mạch · 80 g')).dy),
        );
      }
      if (state == 'no-coach') {
        expect(find.byKey(const Key('nutrition-coach-source')), findsNothing);
        expect(
          find.text('Bạn có thể tự ghi món, không cần thực đơn.'),
          findsOneWidget,
        );
      }
      if (state == 'empty') {
        expect(find.text('Chưa có bữa ăn nào'), findsOneWidget);
        expect(find.byKey(const Key('nutrition-meal-BREAKFAST')), findsNothing);
        expect(find.byKey(const Key('nutrition-meal-LUNCH')), findsNothing);
        expect(find.byKey(const Key('nutrition-meal-DINNER')), findsNothing);
      }
      if (state == 'expired') {
        expect(
          find.text('Gói Gym không còn hiệu lực · chỉ xem lịch sử.'),
          findsOneWidget,
        );
        expect(find.byKey(const Key('nutrition-log-meal')), findsNothing);
      } else if (state != 'error') {
        expect(find.byKey(const Key('nutrition-log-meal')), findsOneWidget);
        expect(find.text('Ghi lại bữa ăn'), findsOneWidget);
      }
      if (state == 'error') {
        expect(find.byKey(const Key('nutrition-day-summary')), findsNothing);
      } else {
        expect(
          find.byKey(const Key('nutrition-date-selector')),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(const Key('nutrition-day-summary')),
            matching: find.byKey(const Key('nutrition-date-selector')),
          ),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('nutrition-meals-heading')),
          findsOneWidget,
        );
        expect(
          tester.getSize(find.byKey(const Key('nutrition-day-metrics'))).height,
          lessThanOrEqualTo(104),
        );
      }
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final directory = Directory('.tmp')..createSync(recursive: true);
        File('${directory.path}/nutrition-redesign-top.png')
            .writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
      if (state != 'error') {
        await tester.drag(find.byType(ListView).first, const Offset(0, -1500));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.runAsync(() async {
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          File('${Directory('.tmp').path}/nutrition-redesign-bottom.png')
              .writeAsBytesSync(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
    });
  }
  testWidgets('shows a loading state while the selected day is being fetched', (
    tester,
  ) async {
    final fixture = Fixture('loading');
    await tester.pumpWidget(
      MaterialApp(
        theme: MetaGymTheme.dark,
        home: NutritionTrackingPage(api: fixture),
      ),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    fixture.dayCompleter.complete({
      'date': fixture.now.toIso8601String().substring(0, 10),
      'canWrite': true,
      'hasActiveMembership': true,
      'relationshipStatus': 'NONE',
      'entries': [],
    });
    await tester.pumpAndSettle();
    expect(find.text('Chưa có bữa ăn nào'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'save failure preserves form and allows retry with keyboard inset',
    (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      final formKey = GlobalKey();
      final fixture = Fixture('empty');
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpWidget(
        MaterialApp(
          theme: MetaGymTheme.dark,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: RepaintBoundary(
            key: formKey,
            child: NutritionTrackingPage(api: fixture),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('nutrition-log-meal')));
      await tester.pumpAndSettle();
      final mealLabelField = find.byKey(
        const Key('nutrition-meal-label-field'),
      );
      await tester.enterText(mealLabelField, 'Meal trước tập');
      await tester.drag(find.byType(ListView).first, const Offset(0, -350));
      await tester.pumpAndSettle();
      final nameField = find.widgetWithText(TextFormField, 'Tên món');
      await tester.enterText(nameField, 'Cơm nhà');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Lượng thực tế'),
        '1',
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      final saveButton = find.widgetWithText(FilledButton, 'Lưu món');
      expect(saveButton, findsOneWidget);
      expect(saveButton.hitTestable(), findsOneWidget);
      expect(tester.getTopLeft(saveButton).dy, lessThan(500));
      expect(tester.getBottomRight(saveButton).dy, lessThanOrEqualTo(512));
      await tester.ensureVisible(find.text('Lưu món'));
      await tester.tap(find.text('Lưu món'));
      await tester.pumpAndSettle();
      expect(
        find.text('Không lưu được món. Vui lòng thử lại.'),
        findsOneWidget,
      );
      expect(find.text('Cơm nhà'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(fixture.saveAttempts, 1);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();
      expect(fixture.saveAttempts, 2);
      expect(fixture.savedItem?['mealType'], 'SNACK');
      expect(fixture.savedItem?['notes'], '[Bữa: Meal trước tập]');
      expect(fixture.savedItem?['mealName'], 'Cơm nhà');
      expect(fixture.savedItem?['quantity'], 1);
      expect(find.text('Theo dõi dinh dưỡng'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
