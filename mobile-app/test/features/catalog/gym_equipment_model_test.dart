import 'package:flutter_test/flutter_test.dart';
import 'package:meta_gym_app/features/catalog/domain/catalog_models.dart';

void main() {
  test('decodes gym hours, rules and equipment instructions', () {
    final gym = GymProfile.fromJson({
      'name': 'Meta Gym',
      'address': 'Quận 1',
      'openingHours': {'monday': '06:00-21:00'},
      'rules': 'Mang khăn tập.',
    });
    final equipment = CatalogItem.fromJson({
      'id': 'equipment-1',
      'name': 'Máy chạy bộ',
      'category': 'Cardio',
      'targetMuscles': ['Chân'],
      'usageSteps': ['Khởi động'],
      'safetyNotes': 'Giữ tay vịn',
      'status': 'ACTIVE',
    });

    expect(gym.openingHours['monday'], '06:00-21:00');
    expect(gym.rules, 'Mang khăn tập.');
    expect(equipment.usageSteps, ['Khởi động']);
    expect(equipment.targetMuscles, ['Chân']);
    expect(equipment.safetyNotes, 'Giữ tay vịn');
  });

  test('decodes string openingHours safely', () {
    final gym = GymProfile.fromJson({
      'name': 'Meta Gym Flagship Center',
      'address': 'Quận 1',
      'openingHours': '05:30 - 22:30 (Hàng ngày)',
    });

    expect(gym.openingHours['Giờ mở cửa'], '05:30 - 22:30 (Hàng ngày)');
  });
}
