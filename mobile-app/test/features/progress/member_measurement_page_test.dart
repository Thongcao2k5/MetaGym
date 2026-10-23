import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_gym_app/features/progress/data/member_measurement_service.dart';
import 'package:meta_gym_app/features/progress/domain/body_measurement.dart';
import 'package:meta_gym_app/features/progress/presentation/member_measurement_page.dart';

void main() {
  test('parses decimal numbers from API', () {
    final measurement = BodyMeasurement.fromJson({
      'id': 'b-1',
      'measuredAt': '2026-10-23T08:00:00Z',
      'weightKg': '72.5',
      'waistCm': '80.2',
    });
    expect(measurement.weightKg, 72.5);
    expect(measurement.waistCm, 80.2);
  });

  testWidgets('creates and edits a measurement', (tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = _MeasurementFixture();
    await tester.pumpWidget(
      MaterialApp(home: MemberMeasurementPage(service: service)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thêm số đo'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('measurement-date')),
      '23/10/2026 08:00',
    );
    await tester.enterText(find.byKey(const Key('measurement-weight')), '72.5');
    await tester.enterText(find.byKey(const Key('measurement-waist')), '80');
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();
    expect(service.created?['weightKg'], 72.5);
    expect(find.textContaining('72.5 kg'), findsOneWidget);
    await tester.tap(find.textContaining('72.5 kg'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('measurement-weight')), '71.8');
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();
    expect(service.updated?['weightKg'], 71.8);
  });

  testWidgets('rejects negative weight and invalid body fat', (tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = _MeasurementFixture();
    await tester.pumpWidget(
      MaterialApp(home: MemberMeasurementPage(service: service)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thêm số đo'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('measurement-date')),
      '23/10/2026 08:00',
    );
    await tester.enterText(find.byKey(const Key('measurement-weight')), '-1');
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();
    expect(
      find.text('Cân nặng phải lớn hơn 0 và không quá 999.99 kg.'),
      findsOneWidget,
    );
    expect(service.created, isNull);
    await tester.enterText(find.byKey(const Key('measurement-weight')), '72');
    await tester.enterText(find.byKey(const Key('measurement-fat')), '101');
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();
    expect(find.text('Mỡ cơ thể phải trong khoảng 0–100%.'), findsOneWidget);
  });
}

class _MeasurementFixture implements MemberMeasurementService {
  Map<String, Object?>? created;
  Map<String, Object?>? updated;
  @override
  Future<List<BodyMeasurement>> getPage(int page) async => [
    if (created != null)
      BodyMeasurement(
        id: 'b-1',
        measuredAt: created!['measuredAt'] as String,
        weightKg: (updated ?? created)!['weightKg'] as double,
        waistCm: created!['waistCm'] as double?,
      ),
  ];
  @override
  Future<BodyMeasurement> create(Map<String, Object?> payload) async {
    created = payload;
    return (await getPage(1)).single;
  }

  @override
  Future<BodyMeasurement> update(
    String id,
    Map<String, Object?> payload,
  ) async {
    updated = payload;
    return (await getPage(1)).single;
  }
}
