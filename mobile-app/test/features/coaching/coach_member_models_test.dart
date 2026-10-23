import 'package:flutter_test/flutter_test.dart';
import 'package:meta_gym_app/features/coaching/domain/coach_member_models.dart';

void main() {
  test('decodes the current member profile and termination status', () {
    final detail = CoachMemberDetail.fromJson({
      'id': 'relationship-1',
      'status': 'ACTIVE',
      'member': {
        'id': 'member-1',
        'fullName': 'Nguyễn An',
        'email': 'an@example.com',
        'fitnessGoal': 'Tăng sức bền',
        'healthNotes': 'Hen nhẹ',
        'injuryNotes': null,
      },
    });
    final request = CoachTerminationRequest.fromJson({
      'id': 'request-1',
      'relationship_id': 'relationship-1',
      'reason': 'Đổi lịch',
      'status': 'REJECTED',
      'admin_note': 'Vui lòng trao đổi thêm',
    });

    expect(detail.memberFullName, 'Nguyễn An');
    expect(detail.healthNotes, 'Hen nhẹ');
    expect(request.relationshipId, detail.relationshipId);
    expect(request.statusLabel, 'Đã từ chối');
    expect(request.adminNote, 'Vui lòng trao đổi thêm');
  });
}
