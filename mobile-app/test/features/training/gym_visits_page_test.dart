import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/features/training/data/gym_visits_service.dart';
import 'package:meta_gym_app/features/training/presentation/gym_visits_page.dart';

void main() {
  final fixedToday = DateTime(2026, 11, 22);

  testWidgets(
    'shows unchecked-in today alert, month stats, visit card, and opens QR check-in modal',
    (tester) async {
      final api = _FakeGymVisitsApi({
        '2026-11': GymVisitMonth(
          visitedDays: 16,
          eligibleDays: 22,
          entryCount: 18,
          visits: [
            GymVisit(
              day: DateTime(2026, 11, 21),
              checkedInAt: DateTime(2026, 11, 21, 18, 10),
              gymName: 'Meta Gym Flagship — Q1',
              gymAddress: 'Cổng vào chính',
            ),
          ],
        ),
      });

      await tester.pumpWidget(
        MaterialApp(
          home: GymVisitsPage(api: api, todayOverride: fixedToday),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('gym-visits-checkin-alert')), findsOneWidget);
      expect(find.text('Hôm nay chưa điểm danh'), findsOneWidget);
      expect(find.text('16'), findsWidgets);

      await tester.tap(find.byKey(const Key('gym-visits-open-qr-btn')));
      await tester.pumpAndSettle();

      expect(find.text('QR Check-in Phòng Tập'), findsOneWidget);

      await tester.tap(find.text('Đóng'));
      await tester.pumpAndSettle();

      await tester.drag(find.byType(ListView).first, const Offset(0, -320));
      await tester.pumpAndSettle();

      expect(find.text('18 lượt quét'), findsOneWidget);
      expect(find.text('Meta Gym Flagship — Q1'), findsOneWidget);
    },
  );

  testWidgets('shows checked-in banner and today pill when visited today', (
    tester,
  ) async {
    final api = _FakeGymVisitsApi({
      '2026-11': GymVisitMonth(
        visitedDays: 17,
        eligibleDays: 22,
        entryCount: 19,
        visits: [
          GymVisit(
            day: DateTime(2026, 11, 22),
            checkedInAt: DateTime(2026, 11, 22, 17, 54),
            gymName: 'Meta Gym Flagship — Q1',
            gymAddress: 'Cổng vào chính',
          ),
        ],
      ),
    });

    await tester.pumpWidget(
      MaterialApp(
        home: GymVisitsPage(api: api, todayOverride: fixedToday),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('gym-visits-checked-in-banner')),
      findsOneWidget,
    );
    expect(find.text('Hôm nay đã điểm danh'), findsOneWidget);
    expect(find.text('Hôm nay'), findsOneWidget);
  });

  testWidgets('navigates to previous month and renders empty state', (
    tester,
  ) async {
    final api = _FakeGymVisitsApi({
      '2026-11': const GymVisitMonth(
        visitedDays: 2,
        eligibleDays: 22,
        entryCount: 2,
        visits: [],
      ),
      '2026-10': const GymVisitMonth(
        visitedDays: 0,
        eligibleDays: 31,
        entryCount: 0,
        visits: [],
      ),
    });

    await tester.pumpWidget(
      MaterialApp(
        home: GymVisitsPage(api: api, todayOverride: fixedToday),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Tháng trước'));
    await tester.pumpAndSettle();

    expect(find.text('10/2026'), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, -320));
    await tester.pumpAndSettle();
    expect(
      find.text('Chưa có lượt đến gym trong tháng này.'),
      findsOneWidget,
    );
  });
}

class _FakeGymVisitsApi implements GymVisitsApi {
  _FakeGymVisitsApi(this.months);

  final Map<String, GymVisitMonth> months;

  @override
  ApiClient get client => throw UnimplementedError();

  @override
  Future<GymVisitMonth> getMonth(DateTime month) async {
    final key = '${month.year}-${month.month.toString().padLeft(2, '0')}';
    return months[key] ??
        const GymVisitMonth(
          visitedDays: 0,
          eligibleDays: 0,
          entryCount: 0,
          visits: [],
        );
  }

  @override
  Future<GymVisit> checkIn(String code) => throw UnimplementedError();
}
