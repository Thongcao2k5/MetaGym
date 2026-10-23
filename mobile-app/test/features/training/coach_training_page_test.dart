import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_gym_app/features/catalog/domain/catalog_models.dart';
import 'package:meta_gym_app/features/coaching/domain/coach_member_models.dart';
import 'package:meta_gym_app/features/training/data/coach_training_service.dart';
import 'package:meta_gym_app/features/training/domain/training_models.dart';
import 'package:meta_gym_app/features/training/presentation/coach_training_page.dart';
import 'package:meta_gym_app/features/training/presentation/coach_plan_form_page.dart';

void main() {
  testWidgets('creates and edits a draft with a day and catalog exercise', (
    tester,
  ) async {
    final service = _CoachTrainingFixture();
    await tester.pumpWidget(
      MaterialApp(home: CoachTrainingPage(service: service)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nguyễn An'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tạo giáo trình'));
    await tester.pumpAndSettle();
    final formScroll = find
        .descendant(
          of: find.byKey(const Key('coach-plan-form-list')),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.text('Lưu bản nháp'),
      250,
      scrollable: formScroll,
    );
    await tester.tap(find.text('Lưu bản nháp'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Vui lòng nhập tiêu đề.'),
      -250,
      scrollable: formScroll,
    );
    expect(find.text('Vui lòng nhập tiêu đề.'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('plan-title')),
      -250,
      scrollable: formScroll,
    );
    await tester.enterText(
      find.byKey(const Key('plan-title')),
      '  Sức mạnh cơ bản  ',
    );
    await tester.enterText(find.byKey(const Key('plan-goal')), 'Tăng cơ');
    await tester.scrollUntilVisible(
      find.byKey(const Key('day-title-0')),
      250,
      scrollable: formScroll,
    );
    await tester.enterText(find.byKey(const Key('day-title-0')), 'Toàn thân');
    await tester.scrollUntilVisible(
      find.byKey(const Key('exercise-choice-0-0')),
      250,
      scrollable: formScroll,
    );
    await tester.tap(find.byKey(const Key('exercise-choice-0-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Squat').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('exercise-reps-0-0')), '12');
    await tester.scrollUntilVisible(
      find.text('Xem trước'),
      250,
      scrollable: formScroll,
    );
    await tester.tap(find.text('Xem trước'));
    await tester.pumpAndSettle();
    expect(find.text('Xem trước giáo trình'), findsOneWidget);
    expect(find.text('Ngày 1: Toàn thân'), findsOneWidget);
    await tester.tap(find.text('Đóng'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Lưu bản nháp'),
      250,
      scrollable: formScroll,
    );
    await tester.tap(find.text('Lưu bản nháp'));
    await tester.pumpAndSettle();
    expect(service.lastPayload?['title'], 'Sức mạnh cơ bản');
    expect(find.text('Sức mạnh cơ bản'), findsOneWidget);
    expect(find.text('Ngày 1: Toàn thân'), findsOneWidget);
    await tester.tap(find.text('Sửa bản nháp'));
    await tester.pumpAndSettle();
    expect(find.text('Sức mạnh cơ bản'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('plan-title')),
      'Phiên bản đã sửa',
    );
    await tester.scrollUntilVisible(
      find.text('Lưu bản nháp'),
      250,
      scrollable: formScroll,
    );
    await tester.tap(find.text('Lưu bản nháp'));
    await tester.pumpAndSettle();
    expect(service.updated, true);
    expect(find.text('Phiên bản đã sửa'), findsOneWidget);
  });

  testWidgets('requires replacement for an exercise removed from catalog', (
    tester,
  ) async {
    final service = _CoachTrainingFixture();
    const plan = TrainingPlan(
      id: 'plan-old',
      title: 'Bản nháp cũ',
      status: 'DRAFT',
      version: 1,
      days: [
        TrainingDay(
          dayNumber: 1,
          title: 'Ngày một',
          exercises: [
            TrainingExercise(
              exerciseId: 'removed-id',
              exerciseName: 'Bài cũ',
              displayOrder: 1,
              reps: '10',
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CoachPlanFormPage(
          memberId: 'member-1',
          service: service,
          plan: plan,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final formScroll = find
        .descendant(
          of: find.byKey(const Key('coach-plan-form-list')),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.text('Lưu bản nháp'),
      250,
      scrollable: formScroll,
    );
    await tester.tap(find.text('Lưu bản nháp'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Bài tập không còn trong danh mục.'),
      -250,
      scrollable: formScroll,
    );
    expect(find.text('Bài tập không còn trong danh mục.'), findsOneWidget);
    expect(service.updated, false);
  });
}

class _CoachTrainingFixture implements CoachTrainingService {
  TrainingPlan? plan;
  Map<String, Object?>? lastPayload;
  bool updated = false;

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
  Future<List<CatalogItem>> getExercises() async => const [
    CatalogItem(id: 'exercise-1', name: 'Squat'),
  ];

  @override
  Future<List<TrainingPlan>> getPlans(String memberId) async =>
      plan == null ? const [] : [plan!];

  @override
  Future<TrainingPlan> getPlan(String id) async => plan!;

  @override
  Future<TrainingPlan> create(
    String memberId,
    Map<String, Object?> payload,
  ) async {
    lastPayload = payload;
    plan = _fromPayload(payload);
    return plan!;
  }

  @override
  Future<TrainingPlan> update(String id, Map<String, Object?> payload) async {
    updated = true;
    lastPayload = payload;
    plan = _fromPayload(payload);
    return plan!;
  }

  TrainingPlan _fromPayload(Map<String, Object?> payload) {
    final day = (payload['days'] as List).first as Map;
    final exercise = (day['exercises'] as List).first as Map;
    return TrainingPlan(
      id: 'plan-1',
      title: payload['title'] as String,
      goal: payload['goal'] as String?,
      status: 'DRAFT',
      version: 1,
      days: [
        TrainingDay(
          dayNumber: 1,
          title: day['title'] as String,
          exercises: [
            TrainingExercise(
              exerciseId: exercise['exerciseId'] as String,
              exerciseName: 'Squat',
              displayOrder: 1,
              reps: exercise['reps'] as String?,
            ),
          ],
        ),
      ],
    );
  }
}
