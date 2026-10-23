import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_gym_app/features/training/data/member_nutrition_service.dart';
import 'package:meta_gym_app/features/training/domain/nutrition_models.dart';
import 'package:meta_gym_app/features/training/presentation/member_nutrition_page.dart';

void main() {
  testWidgets('shows current guide and published history without drafts', (
    tester,
  ) async {
    final service = _NutritionFixture();
    await tester.pumpWidget(
      MaterialApp(home: MemberNutritionPage(service: service)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ăn uống cân bằng'), findsOneWidget);
    expect(find.text('Ưu tiên rau và protein'), findsOneWidget);
    expect(find.textContaining('Công bố: 2026-10-20'), findsOneWidget);
    expect(find.text('Bản nháp bí mật'), findsNothing);
    await tester.tap(find.text('Hướng dẫn cũ'));
    await tester.pumpAndSettle();
    expect(find.text('Uống đủ nước'), findsOneWidget);
  });

  testWidgets('shows empty state and retry after loading failure', (
    tester,
  ) async {
    final service = _NutritionFixture(empty: true, failFirst: true);
    await tester.pumpWidget(
      MaterialApp(home: MemberNutritionPage(service: service)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Không tải được dinh dưỡng.'), findsOneWidget);
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('Bạn chưa có hướng dẫn dinh dưỡng.'), findsOneWidget);
  });
}

class _NutritionFixture implements MemberNutritionService {
  _NutritionFixture({this.empty = false, this.failFirst = false});

  final bool empty;
  final bool failFirst;
  int loads = 0;

  @override
  Future<NutritionGuide?> getActive() async {
    loads++;
    if (failFirst && loads == 1) throw StateError('failed');
    return empty
        ? null
        : const NutritionGuide(
            id: 'guide-2',
            title: 'Ăn uống cân bằng',
            content: 'Ưu tiên rau và protein',
            status: 'ACTIVE',
            version: 2,
            publishedAt: '2026-10-20T08:00:00Z',
          );
  }

  @override
  Future<List<NutritionGuide>> getHistory() async => empty
      ? const []
      : const [
          NutritionGuide(
            id: 'guide-2',
            title: 'Ăn uống cân bằng',
            content: 'Ưu tiên rau và protein',
            status: 'ACTIVE',
            version: 2,
          ),
          NutritionGuide(
            id: 'draft-1',
            title: 'Bản nháp bí mật',
            content: 'Bí mật',
            status: 'DRAFT',
            version: 3,
          ),
          NutritionGuide(
            id: 'guide-1',
            title: 'Hướng dẫn cũ',
            content: 'Uống đủ nước',
            status: 'ARCHIVED',
            version: 1,
            publishedAt: '2026-09-01T08:00:00Z',
          ),
        ];
}
