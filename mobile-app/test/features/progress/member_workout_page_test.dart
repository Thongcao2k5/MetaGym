import 'package:flutter_test/flutter_test.dart';
import 'package:meta_gym_app/features/progress/domain/workout_log.dart';

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
}
