import 'package:flutter_test/flutter_test.dart';
import 'package:meta_gym_app/features/coaching/domain/member_coaching_models.dart';

void main() {
  test('decodes request and relationship history returned by the API', () {
    final request = MemberCoachRequest.fromJson({
      'id': 'request-1',
      'coachId': 'coach-1',
      'status': 'REJECTED',
      'message': 'Xin hướng dẫn',
      'rejectionReason': 'Lịch kín',
      'requestedAt': '2026-10-23T08:00:00Z',
    });
    final relationship = MemberCoachRelationship.fromJson({
      'id': 'relationship-1',
      'coachId': 'coach-1',
      'status': 'ENDED',
      'startedAt': '2026-10-01T08:00:00Z',
      'endedAt': '2026-10-23T08:00:00Z',
    });

    expect(request.statusLabel, 'Đã từ chối');
    expect(request.rejectionReason, 'Lịch kín');
    expect(relationship.statusLabel, 'Đã kết thúc');
    expect(relationship.endedAt, isNotNull);
  });
}
