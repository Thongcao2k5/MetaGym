import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_gym_app/features/progress/data/member_meal_service.dart';
import 'package:meta_gym_app/features/progress/domain/meal_log.dart';
import 'package:meta_gym_app/features/progress/presentation/member_meal_page.dart';

void main() {
  test('parses meal calories and type from API data', () {
    final meal = MealLog.fromJson({
      'id': 'm-1',
      'eatenAt': '2026-10-23T12:00:00Z',
      'mealName': 'Cơm gà',
      'mealType': 'LUNCH',
      'estimatedCalories': 600,
    });
    expect(meal.typeLabel, 'Bữa trưa');
    expect(meal.estimatedCalories, 600);
  });

  testWidgets('creates and edits a meal', (tester) async {
    final service = _MealFixture();
    await tester.pumpWidget(
      MaterialApp(home: MemberMealPage(service: service)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thêm bữa ăn'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('meal-date')),
      '23/10/2026 12:00',
    );
    await tester.enterText(find.byKey(const Key('meal-name')), 'Cơm gà');
    await tester.enterText(find.byKey(const Key('meal-calories')), '600');
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();
    expect(service.created?['mealName'], 'Cơm gà');
    expect(service.created?['estimatedCalories'], 600);
    await tester.tap(find.text('Cơm gà'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('meal-name')), 'Cơm gà xé');
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();
    expect(service.updated?['mealName'], 'Cơm gà xé');
  });

  testWidgets('rejects invalid calories and handles empty list', (
    tester,
  ) async {
    final service = _MealFixture();
    await tester.pumpWidget(
      MaterialApp(home: MemberMealPage(service: service)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Bạn chưa có nhật ký ăn.'), findsOneWidget);
    await tester.tap(find.text('Thêm bữa ăn'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('meal-date')),
      '23/10/2026 12:00',
    );
    await tester.enterText(find.byKey(const Key('meal-name')), 'Cơm gà');
    await tester.enterText(find.byKey(const Key('meal-calories')), '-1');
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();
    expect(find.text('Calo phải là số nguyên không âm.'), findsOneWidget);
    expect(service.created, isNull);
  });
}

class _MealFixture implements MemberMealService {
  Map<String, Object?>? created;
  Map<String, Object?>? updated;
  @override
  Future<List<MealLog>> getPage(int page) async => [
    if (created != null)
      MealLog(
        id: 'm-1',
        eatenAt: created!['eatenAt'] as String,
        mealName: (updated ?? created)!['mealName'] as String,
        mealType: created!['mealType'] as String?,
        estimatedCalories: created!['estimatedCalories'] as int?,
      ),
  ];
  @override
  Future<MealLog> create(Map<String, Object?> payload) async {
    created = payload;
    return (await getPage(1)).single;
  }

  @override
  Future<MealLog> update(String id, Map<String, Object?> payload) async {
    updated = payload;
    return (await getPage(1)).single;
  }
}
