import 'package:flutter_test/flutter_test.dart';
import 'package:meta_gym_app/features/coaching/domain/coach_models.dart';

void main() {
  test('decodes coach availability and request response', () {
    final coach = CoachProfile.fromJson({
      'id': 'coach-1',
      'fullName': 'Coach Linh',
      'biography': 'Huấn luyện viên Yoga',
      'specialties': ['Yoga'],
      'qualifications': 'Chứng chỉ Yoga',
      'experienceYears': 4,
      'availabilityNote': 'Buổi sáng',
      'memberLimit': 5,
      'usedSlots': 3,
      'availableSlots': 2,
    });
    final request = CoachRequest.fromJson({
      'id': 'request-1',
      'status': 'PENDING',
    });

    expect(coach.fullName, 'Coach Linh');
    expect(coach.specialties, ['Yoga']);
    expect(coach.availableSlots, 2);
    expect(request.status, 'PENDING');
  });
}
