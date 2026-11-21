import 'package:flutter_test/flutter_test.dart';
import 'package:meta_gym_app/features/sessions/domain/training_session.dart';

void main() {
  test('parses API fields and formats a device-local time', () {
    final session = TrainingSession.fromJson({
      'id': 'session-1',
      'title': 'Tập chân',
      'scheduledStartAt': '2026-10-23T08:30:00Z',
      'scheduledEndAt': null,
      'status': 'MEMBER_ABSENT',
      'notes': 'Khởi động kỹ',
    });
    expect(session.statusLabel, 'Hội viên vắng');
    final local = DateTime.parse(session.scheduledStartAt).toLocal();
    expect(
      formatSessionLocalTime(session.scheduledStartAt),
      '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year} '
      '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}',
    );
  });
}
