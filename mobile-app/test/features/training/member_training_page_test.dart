import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_gym_app/features/training/data/member_training_service.dart';
import 'package:meta_gym_app/features/training/domain/training_models.dart';
import 'package:meta_gym_app/features/training/presentation/member_training_page.dart';

void main() {
  testWidgets(
    'shows published current and history with day and exercise detail',
    (tester) async {
      final service = _TrainingFixture();
      await tester.pumpWidget(
        MaterialApp(home: MemberTrainingPage(service: service)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Sức bền cơ bản'), findsOneWidget);
      expect(find.text('Bản nháp bí mật'), findsNothing);
      expect(find.text('Giáo trình cũ'), findsOneWidget);
      await tester.tap(find.text('Sức bền cơ bản'));
      await tester.pumpAndSettle();
      expect(find.text('Ngày 1: Toàn thân'), findsOneWidget);
      expect(find.text('Squat'), findsOneWidget);
      expect(find.text('3 hiệp · 12 lần'), findsOneWidget);
      expect(find.text('Đã công bố · Phiên bản 2'), findsOneWidget);
    },
  );

  testWidgets('shows no-plan state and can retry a load failure', (
    tester,
  ) async {
    final service = _TrainingFixture(empty: true, failFirst: true);
    await tester.pumpWidget(
      MaterialApp(home: MemberTrainingPage(service: service)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Không tải được giáo trình.'), findsOneWidget);
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('Bạn chưa được giao giáo trình.'), findsOneWidget);
  });

  testWidgets('keeps a paused plan visible with a renewal message', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MemberTrainingPage(service: _TrainingFixture(locked: true)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sức bền cơ bản'), findsOneWidget);
    expect(find.text('Tạm khóa'), findsOneWidget);
    expect(find.textContaining('Gia hạn gói để tiếp tục'), findsOneWidget);
  });
}

class _TrainingFixture implements MemberTrainingService {
  _TrainingFixture({
    this.empty = false,
    this.failFirst = false,
    this.locked = false,
  });

  final bool empty;
  final bool failFirst;
  final bool locked;
  int loads = 0;

  TrainingPlan get active => TrainingPlan(
    id: 'plan-2',
    title: 'Sức bền cơ bản',
    status: 'ACTIVE',
    accessLocked: locked,
    version: 2,
    days: [
      TrainingDay(
        dayNumber: 1,
        title: 'Toàn thân',
        exercises: [
          TrainingExercise(
            exerciseId: 'exercise-1',
            exerciseName: 'Squat',
            displayOrder: 1,
            sets: 3,
            reps: '12',
          ),
        ],
      ),
    ],
  );

  @override
  Future<TrainingPlan?> getActive() async {
    loads++;
    if (failFirst && loads == 1) throw StateError('Không tải được giáo trình.');
    return empty ? null : active;
  }

  @override
  Future<List<TrainingPlan>> getHistory() async => empty
      ? const []
      : [
          active,
          const TrainingPlan(
            id: 'draft-1',
            title: 'Bản nháp bí mật',
            status: 'DRAFT',
            version: 3,
          ),
          const TrainingPlan(
            id: 'plan-1',
            title: 'Giáo trình cũ',
            status: 'ARCHIVED',
            version: 1,
          ),
        ];

  @override
  Future<TrainingPlan> getPlan(String id) async => id == active.id
      ? active
      : const TrainingPlan(
          id: 'plan-1',
          title: 'Giáo trình cũ',
          status: 'ARCHIVED',
          version: 1,
        );
}
