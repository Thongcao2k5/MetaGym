import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/features/membership/data/membership_service.dart';
import 'package:meta_gym_app/features/membership/domain/membership_models.dart';
import 'package:meta_gym_app/features/progress/data/member_journal_service.dart';
import 'package:meta_gym_app/features/progress/data/member_photo_service.dart';
import 'package:meta_gym_app/features/progress/data/member_progress_service.dart';
import 'package:meta_gym_app/features/progress/domain/journal_entry.dart';
import 'package:meta_gym_app/features/progress/domain/progress_comment.dart';
import 'package:meta_gym_app/features/progress/domain/progress_models.dart';
import 'package:meta_gym_app/features/progress/domain/progress_photo.dart';
import 'package:meta_gym_app/features/progress/presentation/member_journal_page.dart';

void main() {
  final fixedToday = DateTime(2026, 11, 13);

  testWidgets('expired Member can read the journal but cannot edit it', (
    tester,
  ) async {
    final journal = _JournalFixture()
      ..entry = const JournalEntry(
        id: 'entry-1',
        journalDate: '2026-11-13',
        notes: 'Tập ngực',
        achievements: [JournalAchievement(title: 'Đẩy ngực', result: '50 kg')],
        photoMediaIds: [],
        chestCm: 90,
      );
    await tester.pumpWidget(
      MaterialApp(
        home: MemberJournalPage(
          service: journal,
          membershipService: const _MembershipFixture(false),
          photoService: _PhotoFixture(),
          picker: _PickerFixture(),
          todayOverride: fixedToday,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chỉ xem (hết hạn gói)'), findsOneWidget);
    expect(find.text('Chỉ số cơ thể'), findsOneWidget);
    expect(find.text('90 cm'), findsOneWidget);
    expect(find.text('Đẩy ngực'), findsOneWidget);
    expect(find.text('50 kg'), findsOneWidget);
    expect(find.text('Tập ngực'), findsOneWidget);

    await tester.tap(find.text('Chỉ số cơ thể'));
    await tester.pumpAndSettle();
    expect(find.byType(TextFormField), findsNothing);
    expect(find.text('Lưu thay đổi'), findsNothing);
  });

  testWidgets(
    'active Member creates, edits, switches tabs/calendar and deletes today entry',
    (tester) async {
      final journal = _JournalFixture();
      await tester.pumpWidget(
        MaterialApp(
          home: MemberJournalPage(
            service: journal,
            membershipService: const _MembershipFixture(true),
            photoService: _PhotoFixture(),
            picker: _PickerFixture(),
            todayOverride: fixedToday,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open measurements card inline & enter Vòng ngực (index 2: weight, bodyFat, chest, waist, hips)
      await tester.tap(find.text('Chỉ số cơ thể'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(2), '90,5');
      await tester.pumpAndSettle();

      // Collapse measurements and scroll Thành tích của bạn clearly above sticky save bar
      await tester.tap(find.byTooltip('Thu gọn chỉ số cơ thể'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Thành tích của bạn'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.drag(find.byType(ListView).first, const Offset(0, -180));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Thành tích của bạn'));
      await tester.pumpAndSettle();

      // Enter result for Đẩy ngực (index 0) and notes (last field)
      await tester.enterText(find.byType(TextFormField).at(0), '60 kg');
      await tester.enterText(find.byType(TextFormField).last, 'Tập thân trên');
      tester.testTextInput.hide();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Lưu thay đổi'));
      await tester.pumpAndSettle();

      expect(journal.lastPayload?['chestCm'], 90.5);
      expect(journal.lastPayload?['notes'], 'Tập thân trên');
      expect(journal.lastPayload?['achievements'], [
        {'title': 'Đẩy ngực', 'result': '60 kg'},
      ]);
      expect(find.text('Đã lưu nhật ký hôm nay'), findsOneWidget);

      // Wait for toast timer
      await tester.pump(const Duration(seconds: 3));

      // Edit notes inline
      await tester.scrollUntilVisible(
        find.text('Thành tích của bạn'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.drag(find.byType(ListView).first, const Offset(0, -180));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Thành tích của bạn'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).last, 'Tập xong');
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lưu thay đổi'));
      await tester.pumpAndSettle();
      expect(journal.updated, isTrue);
      await tester.pump(const Duration(seconds: 3));

      // Switch to Progress tab and back
      await tester.tap(find.text('Số đo & biểu đồ'));
      await tester.pumpAndSettle();
      expect(find.text('Biểu đồ cân nặng'), findsOneWidget);
      await tester.tap(find.text('Nhật ký'));
      await tester.pumpAndSettle();

      // Delete today's entry
      await tester.tap(find.byTooltip('Xóa nhật ký hôm nay'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xóa'));
      await tester.pumpAndSettle();
      expect(journal.entry, isNull);
    },
  );

  testWidgets('past day without entry shows locked empty message', (
    tester,
  ) async {
    final journal = _JournalFixture();
    await tester.pumpWidget(
      MaterialApp(
        home: MemberJournalPage(
          service: journal,
          membershipService: const _MembershipFixture(true),
          photoService: _PhotoFixture(),
          picker: _PickerFixture(),
          todayOverride: fixedToday,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Toggle to Month view and tap day 10
    await tester.tap(find.text('Tháng'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('10'));
    await tester.pumpAndSettle();

    expect(find.text('Ngày này chưa có nhật ký và đã khóa.'), findsOneWidget);
  });

  testWidgets('week mode shows only T2..CN labels without combining date numbers', (
    tester,
  ) async {
    final journal = _JournalFixture();
    await tester.pumpWidget(
      MaterialApp(
        home: MemberJournalPage(
          service: journal,
          membershipService: const _MembershipFixture(true),
          photoService: _PhotoFixture(),
          picker: _PickerFixture(),
          todayOverride: fixedToday,
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final weekday in const ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN']) {
      expect(find.text(weekday), findsOneWidget);
    }
    expect(find.textContaining('T2\n'), findsNothing);
    expect(find.text('13'), findsNothing);

    await tester.tap(find.text('T3'));
    await tester.pumpAndSettle();
    expect(find.text('10 tháng 11, 2026'), findsOneWidget);
  });

  testWidgets('active Member opens Olympic weight picker modal and applies metrics', (
    tester,
  ) async {
    final journal = _JournalFixture();
    await tester.pumpWidget(
      MaterialApp(
        home: MemberJournalPage(
          service: journal,
          membershipService: const _MembershipFixture(true),
          photoService: _PhotoFixture(),
          picker: _PickerFixture(),
          todayOverride: fixedToday,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('journal-open-weight-modal')));
    await tester.pumpAndSettle();

    expect(find.text('Cân nặng & Mỡ cơ thể'), findsOneWidget);
    expect(find.text('Đòn tạ 20kg + Đĩa đối xứng'), findsOneWidget);

    await tester.tap(find.byKey(const Key('modal-weight-plus')));
    await tester.pumpAndSettle();
    expect(find.text('72.9 kg'), findsOneWidget);

    await tester.tap(find.byKey(const Key('modal-weight-apply')));
    await tester.pumpAndSettle();

    expect(find.text('72.9 kg'), findsOneWidget);
    expect(find.text('Lưu thay đổi'), findsOneWidget);

    await tester.tap(find.text('Lưu thay đổi'));
    await tester.pumpAndSettle();
    expect(journal.lastPayload, isNotNull);
    expect(find.text('Đã lưu nhật ký hôm nay'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('active Member opens 3-ring tape scanner modal and saves measurements', (
    tester,
  ) async {
    final journal = _JournalFixture();
    await tester.pumpWidget(
      MaterialApp(
        home: MemberJournalPage(
          service: journal,
          membershipService: const _MembershipFixture(true),
          photoService: _PhotoFixture(),
          picker: _PickerFixture(),
          todayOverride: fixedToday,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView).first, const Offset(0, -240));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('journal-open-tape-chest')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('journal-open-tape-chest')));
    await tester.pumpAndSettle();

    expect(find.text('Đo 3 vòng cơ thể'), findsOneWidget);
    await tester.tap(find.byKey(const Key('tape-gender-female')));
    await tester.pumpAndSettle();
    expect(find.text('WHR 0.83'), findsOneWidget);
    await tester.tap(find.byKey(const Key('tape-plus')));
    await tester.pumpAndSettle();
    expect(find.text('99 cm'), findsNWidgets(2));

    await tester.tap(find.byKey(const Key('tape-tab-waist')));
    await tester.pumpAndSettle();
    expect(find.text('Vòng eo'), findsWidgets);

    await tester.tap(find.byKey(const Key('tape-save')));
    await tester.pumpAndSettle();

    expect(find.text('99 cm'), findsOneWidget);
    await tester.tap(find.text('Lưu thay đổi'));
    await tester.pumpAndSettle();

    expect(journal.lastPayload?['chestCm'], 99.0);
    expect(journal.lastPayload?['waistCm'], 78.0);
    expect(journal.lastPayload?['hipsCm'], 94.0);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('active Member adds workout PR via interactive PR calculator sheet', (
    tester,
  ) async {
    final journal = _JournalFixture();
    await tester.pumpWidget(
      MaterialApp(
        home: MemberJournalPage(
          service: journal,
          membershipService: const _MembershipFixture(true),
          photoService: _PhotoFixture(),
          picker: _PickerFixture(),
          todayOverride: fixedToday,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView).first, const Offset(0, -320));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('journal-open-add-pr')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('journal-open-add-pr')));
    await tester.pumpAndSettle();

    expect(find.text('Thêm thành tích buổi tập'), findsOneWidget);
    await tester.tap(find.text('Barbell Bench Press'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pr-kg-plus')));
    await tester.pumpAndSettle();
    expect(find.text('87.5 kg'), findsOneWidget);

    await tester.tap(find.byKey(const Key('pr-save')));
    await tester.pumpAndSettle();

    expect(find.text('Barbell Bench Press'), findsOneWidget);
    expect(find.text('87.5 kg × 6'), findsOneWidget);

    await tester.tap(find.text('Lưu thay đổi'));
    await tester.pumpAndSettle();
    expect(journal.lastPayload?['achievements'], [
      {'title': 'Barbell Bench Press', 'result': '87.5 kg × 6'},
    ]);
    await tester.pump(const Duration(seconds: 3));
  });

  for (final entry in [('dark', AppTheme.dark), ('light', AppTheme.light)]) {
    testWidgets(
      'weight chart time-range selector switches ranges without overflow (${entry.$1}, 375px @ 1.3x)',
      (tester) async {
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final progress = _ProgressFixture();
        await tester.pumpWidget(
          MaterialApp(
            theme: entry.$2,
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(375, 812),
                textScaler: TextScaler.linear(1.3),
              ),
              child: MemberJournalPage(
                service: _JournalFixture(),
                membershipService: const _MembershipFixture(true),
                photoService: _PhotoFixture(),
                progressService: progress,
                picker: _PickerFixture(),
                todayOverride: fixedToday,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Số đo & biểu đồ'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Biểu đồ cân nặng'), findsOneWidget);
        expect(find.text('72.0 → 70.5'), findsOneWidget);
        expect(find.text('8 tuần'), findsOneWidget);
        expect(find.text('30 ngày'), findsOneWidget);
        expect(find.text('Toàn bộ'), findsOneWidget);

        await tester.ensureVisible(
          find.byKey(const Key('journal-chart-range-30 ngày')),
        );
        await tester.tap(find.byKey(const Key('journal-chart-range-30 ngày')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          progress.lastFrom,
          fixedToday.subtract(const Duration(days: 29)),
        );

        await tester.tap(find.byKey(const Key('journal-chart-range-Toàn bộ')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(progress.lastFrom, isNull);

        await tester.tap(find.byKey(const Key('journal-chart-range-8 tuần')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          progress.lastFrom,
          fixedToday.subtract(const Duration(days: 55)),
        );
      },
    );
  }
}

class _JournalFixture implements MemberJournalService {
  JournalEntry? entry;
  Map<String, Object?>? lastPayload;
  bool updated = false;

  @override
  Future<List<JournalEntry>> getPage(int page) async =>
      entry == null ? [] : [entry!];
  @override
  Future<List<JournalChartPoint>> getChart() async => entry?.chestCm == null
      ? []
      : [
          JournalChartPoint(
            journalDate: entry!.journalDate,
            chestCm: entry!.chestCm,
          ),
        ];
  @override
  Future<JournalEntry> create(Map<String, Object?> payload) async {
    lastPayload = payload;
    return entry = _fromPayload(payload);
  }

  @override
  Future<JournalEntry> update(String id, Map<String, Object?> payload) async {
    lastPayload = payload;
    updated = true;
    return entry = _fromPayload(payload);
  }

  JournalEntry _fromPayload(Map<String, Object?> payload) => JournalEntry(
    id: 'entry-1',
    journalDate: '2026-11-13',
    notes: payload['notes'] as String?,
    chestCm: payload['chestCm'] as double?,
    waistCm: payload['waistCm'] as double?,
    hipsCm: payload['hipsCm'] as double?,
    achievements: (payload['achievements'] as List)
        .map(JournalAchievement.fromJson)
        .toList(),
    photoMediaIds: (payload['photoMediaIds'] as List).cast<String>(),
  );
  @override
  Future<void> delete(String id) async {
    entry = null;
  }
}

class _MembershipFixture implements MembershipService {
  @override
  Future<MembershipQuote> getQuote(String planId) async =>
      throw UnimplementedError();

  const _MembershipFixture(this.active);
  final bool active;
  @override
  Future<List<Membership>> getCurrentMemberships() async => active
      ? const [
          Membership(
            id: 'm1',
            startDate: '2026-11-01',
            endDate: '2026-12-01',
            status: 'ACTIVE',
          ),
        ]
      : const [];
  @override
  Future<List<Membership>> getMembershipHistory() async => const [];
  @override
  Future<List<MembershipPlan>> getPlans() async => const [];
  @override
  Future<Payment> createPayment({
    required String planId,
    required String idempotencyKey,
  }) => throw UnimplementedError();
  @override
  Future<PurchaseResult> confirmMockPayment(String paymentId) =>
      throw UnimplementedError();
}

class _PhotoFixture implements MemberPhotoService {
  @override
  Future<List<ProgressPhoto>> getPage(int page) async => const [];
  @override
  Future<String> upload(SelectedProgressImage image) =>
      throw UnimplementedError();
  @override
  Future<ProgressPhoto> create(Map<String, Object?> payload) =>
      throw UnimplementedError();
  @override
  Future<Uri> getAccessUrl(String mediaId) => throw UnimplementedError();
}

class _PickerFixture implements ProgressPhotoPicker {
  @override
  Future<SelectedProgressImage?> pick() async => null;
}

class _ProgressFixture implements MemberProgressService {
  DateTime? lastFrom;
  DateTime? lastTo;

  @override
  Future<ProgressSummary> getSummary() async => const ProgressSummary(
    workoutCount: 12,
    mealCount: 24,
    progressPhotoCount: 2,
    latestMeasurement: WeightPoint(
      measuredAt: '2026-11-13T08:00:00Z',
      weightKg: 70.5,
      bodyFatPercent: 16.2,
    ),
  );

  @override
  Future<List<WeightPoint>> getCharts({DateTime? from, DateTime? to}) async {
    lastFrom = from;
    lastTo = to;
    return const [
      WeightPoint(measuredAt: '2026-10-01T08:00:00Z', weightKg: 72.0),
      WeightPoint(measuredAt: '2026-10-20T08:00:00Z', weightKg: 71.2),
      WeightPoint(measuredAt: '2026-11-13T08:00:00Z', weightKg: 70.5),
    ];
  }

  @override
  Future<List<ProgressComment>> getComments() async => const [];
}
