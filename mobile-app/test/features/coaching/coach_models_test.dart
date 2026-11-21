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

  test('decodes custom dynamic CoachPackagePlan with optional description', () {
    final plan = CoachPackagePlan.fromJson({
      'code': 'PRO_40',
      'name': 'Chuyên sâu 40 buổi',
      'description': 'Lộ trình 120 ngày dành cho mục tiêu thi đấu/tăng cơ dài hạn',
      'sessionCount': 40,
      'durationDays': 120,
      'price': 7200000,
      'status': 'ACTIVE',
    });

    expect(plan.code, 'PRO_40');
    expect(plan.name, 'Chuyên sâu 40 buổi');
    expect(
      plan.description,
      'Lộ trình 120 ngày dành cho mục tiêu thi đấu/tăng cơ dài hạn',
    );
    expect(plan.sessionCount, 40);
    expect(plan.durationDays, 120);
    expect(plan.price, 7200000);
    expect(plan.status, 'ACTIVE');
  });
}
