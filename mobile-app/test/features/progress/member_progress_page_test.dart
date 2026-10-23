import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_gym_app/features/progress/data/member_progress_service.dart';
import 'package:meta_gym_app/features/progress/domain/progress_models.dart';
import 'package:meta_gym_app/features/progress/presentation/member_progress_page.dart';

void main() {
  test('parses numeric chart points from API response', () {
    final point = WeightPoint.fromJson({
      'measuredAt': '2026-10-23T08:00:00Z',
      'weightKg': '72.5',
      'bodyFatPercent': null,
    });
    expect(point.weightKg, 72.5);
  });

  testWidgets('shows summary and a weight chart with date filtering', (
    tester,
  ) async {
    final service = _ProgressFixture();
    await tester.pumpWidget(
      MaterialApp(home: MemberProgressPage(service: service)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Buổi tập: 2'), findsOneWidget);
    expect(find.text('Cân nặng mới nhất: 72.5 kg'), findsOneWidget);
    expect(find.text('Biểu đồ cân nặng'), findsOneWidget);
    await tester.tap(find.text('7 ngày'));
    await tester.pumpAndSettle();
    expect(service.from, isNotNull);
    expect(service.to, isNotNull);
  });

  testWidgets('shows empty state and retry after failure', (tester) async {
    final service = _ProgressFixture(empty: true, failFirst: true);
    await tester.pumpWidget(
      MaterialApp(home: MemberProgressPage(service: service)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Không tải được tiến độ.'), findsOneWidget);
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('Chưa có số đo để vẽ biểu đồ.'), findsOneWidget);
  });

  testWidgets('renders a chart with one measurement', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MemberProgressPage(service: _ProgressFixture(singlePoint: true)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('73.0 kg'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _ProgressFixture implements MemberProgressService {
  _ProgressFixture({
    this.empty = false,
    this.failFirst = false,
    this.singlePoint = false,
  });
  final bool empty;
  final bool failFirst;
  final bool singlePoint;
  int loads = 0;
  DateTime? from;
  DateTime? to;

  @override
  Future<ProgressSummary> getSummary() async {
    loads++;
    if (failFirst && loads == 1) throw StateError('failed');
    return ProgressSummary(
      workoutCount: empty ? 0 : 2,
      mealCount: 1,
      progressPhotoCount: 0,
      latestMeasurement: empty
          ? null
          : const WeightPoint(
              measuredAt: '2026-10-23T08:00:00Z',
              weightKg: 72.5,
            ),
    );
  }

  @override
  Future<List<WeightPoint>> getCharts({DateTime? from, DateTime? to}) async {
    this.from = from;
    this.to = to;
    if (singlePoint) {
      return const [
        WeightPoint(measuredAt: '2026-10-20T08:00:00Z', weightKg: 73),
      ];
    }
    return empty
        ? []
        : const [
            WeightPoint(measuredAt: '2026-10-20T08:00:00Z', weightKg: 73),
            WeightPoint(measuredAt: '2026-10-23T08:00:00Z', weightKg: 72.5),
          ];
  }
}
