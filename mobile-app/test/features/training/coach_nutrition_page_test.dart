import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/features/coaching/domain/coach_member_models.dart';
import 'package:meta_gym_app/features/training/data/coach_nutrition_service.dart';
import 'package:meta_gym_app/features/training/data/member_nutrition_service.dart';
import 'package:meta_gym_app/features/training/domain/nutrition_models.dart';
import 'package:meta_gym_app/features/training/presentation/coach_nutrition_page.dart';
import 'package:meta_gym_app/features/training/presentation/member_nutrition_page.dart';

void main() {
  testWidgets('Coach creates, edits and publishes a guide visible to Member', (
    tester,
  ) async {
    final service = _CoachNutritionFixture();
    await tester.pumpWidget(
      MaterialApp(home: CoachNutritionPage(service: service)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nguyễn An'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tạo hướng dẫn'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lưu bản nháp'));
    await tester.pumpAndSettle();
    expect(find.text('Vui lòng nhập tiêu đề và nội dung.'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('guide-title')),
      'Thực đơn tuần đầu',
    );
    await tester.enterText(
      find.byKey(const Key('guide-content')),
      'Ăn đủ rau.',
    );
    await tester.tap(find.text('Lưu bản nháp'));
    await tester.pumpAndSettle();
    expect(service.guide?.status, 'DRAFT');
    expect(find.text('Bản nháp · Phiên bản 1'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('guide-content')),
      'Ăn đủ rau và đạm.',
    );
    await tester.tap(find.text('Lưu bản nháp'));
    await tester.pumpAndSettle();
    expect(service.guide?.content, 'Ăn đủ rau và đạm.');
    await tester.tap(find.text('Công bố'));
    await tester.pumpAndSettle();
    expect(find.text('Xác nhận công bố'), findsOneWidget);
    await tester.tap(find.text('Xác nhận công bố'));
    await tester.pumpAndSettle();
    expect(service.guide?.status, 'ACTIVE');
    expect(find.text('Đã công bố · Phiên bản 1'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(home: MemberNutritionPage(service: service)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Thực đơn tuần đầu'), findsOneWidget);
    expect(find.text('Ăn đủ rau và đạm.'), findsOneWidget);
  });

  testWidgets('shows relationship-expired error when saving a guide', (
    tester,
  ) async {
    final service = _CoachNutritionFixture(expired: true);
    await tester.pumpWidget(
      MaterialApp(home: CoachNutritionPage(service: service)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nguyễn An'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tạo hướng dẫn'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('guide-title')), 'Thực đơn');
    await tester.enterText(find.byKey(const Key('guide-content')), 'Ăn đủ rau');
    await tester.tap(find.text('Lưu bản nháp'));
    await tester.pumpAndSettle();
    expect(find.text('Quan hệ Coach–Member không hoạt động'), findsOneWidget);
  });
}

class _CoachNutritionFixture
    implements CoachNutritionService, MemberNutritionService {
  _CoachNutritionFixture({this.expired = false});

  final bool expired;
  NutritionGuide? guide;

  @override
  Future<List<CoachMemberSummary>> getMembers() async => const [
    CoachMemberSummary(
      relationshipId: 'rel-1',
      memberId: 'member-1',
      memberFullName: 'Nguyễn An',
      status: 'ACTIVE',
    ),
  ];

  @override
  Future<List<NutritionGuide>> getGuides(String memberId) async =>
      guide == null ? const [] : [guide!];

  @override
  Future<NutritionGuide> create(
    String memberId,
    String title,
    String content,
  ) async {
    if (expired) {
      throw const ApiException(
        kind: ApiExceptionKind.forbidden,
        statusCode: 403,
        code: 'RELATIONSHIP_REQUIRED',
        message: 'Quan hệ Coach–Member không hoạt động',
      );
    }
    guide = NutritionGuide(
      id: 'guide-1',
      title: title,
      content: content,
      status: 'DRAFT',
      version: 1,
    );
    return guide!;
  }

  @override
  Future<NutritionGuide> update(
    String id,
    String title,
    String content, {
    bool publish = false,
  }) async {
    guide = NutritionGuide(
      id: id,
      title: title,
      content: content,
      status: publish ? 'ACTIVE' : 'DRAFT',
      version: 1,
      publishedAt: publish ? '2026-10-23T08:00:00Z' : null,
    );
    return guide!;
  }

  @override
  Future<NutritionGuide?> getActive() async =>
      guide?.status == 'ACTIVE' ? guide : null;

  @override
  Future<List<NutritionGuide>> getHistory() async =>
      guide?.status == 'ACTIVE' ? [guide!] : const [];
}
