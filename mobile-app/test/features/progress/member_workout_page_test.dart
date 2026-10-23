import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_gym_app/features/progress/data/member_workout_service.dart';
import 'package:meta_gym_app/features/progress/domain/workout_log.dart';
import 'package:meta_gym_app/features/progress/presentation/member_workout_page.dart';

void main() {
  test('parses workout exercises and summary fields', () {
    final log = WorkoutLog.fromJson({
      'id': 'log-1',
      'performedAt': '2026-10-23T08:00:00Z',
      'durationMinutes': 45,
      'completionLevel': 80,
      'notes': 'Tốt',
      'exercises': [
        {'exerciseName': 'Squat', 'displayOrder': 1, 'setsCompleted': 3},
      ],
    });
    expect(log.exercises.single.name, 'Squat');
    expect(log.durationMinutes, 45);
  });

  testWidgets('creates and edits a workout log', (tester) async {
    final service = _WorkoutFixture();
    await tester.pumpWidget(
      MaterialApp(home: MemberWorkoutPage(service: service)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thêm nhật ký tập'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('workout-date')),
      '23/10/2026 08:00',
    );
    await tester.enterText(find.byKey(const Key('workout-duration')), '45');
    await tester.enterText(
      find.byKey(const Key('workout-exercises')),
      'Squat\nDeadlift',
    );
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();
    expect(service.created?['durationMinutes'], 45);
    expect((service.created?['exercises'] as List).length, 2);
    expect(find.textContaining('45 phút'), findsOneWidget);
    await tester.tap(find.textContaining('45 phút'));
    await tester.pumpAndSettle();
    expect(find.text('Squat'), findsWidgets);
    await tester.tap(find.text('Sửa'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('workout-duration')), '50');
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();
    expect(service.updated?['durationMinutes'], 50);
  });

  testWidgets('rejects invalid duration and shows API error', (tester) async {
    final service = _WorkoutFixture(failSave: true);
    await tester.pumpWidget(
      MaterialApp(home: MemberWorkoutPage(service: service)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thêm nhật ký tập'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('workout-date')),
      '23/10/2026 08:00',
    );
    await tester.enterText(find.byKey(const Key('workout-duration')), '0');
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();
    expect(find.text('Thời lượng phải lớn hơn 0 phút.'), findsOneWidget);
    expect(service.created, isNull);
    await tester.enterText(find.byKey(const Key('workout-duration')), '30');
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();
    expect(find.text('Không lưu được nhật ký tập.'), findsOneWidget);
  });
}

class _WorkoutFixture implements MemberWorkoutService {
  _WorkoutFixture({this.failSave = false});
  final bool failSave;
  Map<String, Object?>? created;
  Map<String, Object?>? updated;

  @override
  Future<List<WorkoutLog>> getPage(int page) async => [
    if (created != null)
      WorkoutLog(
        id: 'log-1',
        performedAt: created!['performedAt'] as String,
        durationMinutes: (updated ?? created)!['durationMinutes'] as int?,
        exercises: const [
          WorkoutExercise(name: 'Squat'),
          WorkoutExercise(name: 'Deadlift'),
        ],
      ),
  ];
  @override
  Future<WorkoutLog> create(Map<String, Object?> payload) async {
    if (failSave) throw StateError('membership required');
    created = payload;
    return (await getPage(1)).single;
  }

  @override
  Future<WorkoutLog> update(String id, Map<String, Object?> payload) async {
    updated = payload;
    return (await getPage(1)).single;
  }
}
