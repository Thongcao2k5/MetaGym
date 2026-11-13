import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_gym_app/features/membership/data/membership_service.dart';
import 'package:meta_gym_app/features/membership/domain/membership_models.dart';
import 'package:meta_gym_app/features/progress/data/member_journal_service.dart';
import 'package:meta_gym_app/features/progress/data/member_photo_service.dart';
import 'package:meta_gym_app/features/progress/domain/journal_entry.dart';
import 'package:meta_gym_app/features/progress/domain/progress_photo.dart';
import 'package:meta_gym_app/features/progress/presentation/member_journal_page.dart';

void main() {
  testWidgets('expired Member can read the journal but cannot edit it', (tester) async {
    final journal = _JournalFixture()..entry = const JournalEntry(
      id: 'entry-1', journalDate: '2026-11-13', notes: 'Tập ngực',
      achievements: [], photoMediaIds: [], chestCm: 90,
    );
    await tester.pumpWidget(MaterialApp(home: MemberJournalPage(
      service: journal, membershipService: _MembershipFixture(false),
      photoService: _PhotoFixture(), picker: _PickerFixture(),
    )));
    await tester.pumpAndSettle();
    expect(find.text('Tập ngực'), findsOneWidget);
    expect(find.text('13/11/2026'), findsOneWidget);
    expect(find.text('Ba vòng cơ thể'), findsOneWidget);
    expect(find.text('Ghi hôm nay'), findsNothing);
    expect(find.text('Sửa'), findsNothing);
  });

  testWidgets('active Member creates, edits and deletes one journal entry', (tester) async {
    final journal = _JournalFixture();
    await tester.pumpWidget(MaterialApp(home: MemberJournalPage(
      service: journal, membershipService: _MembershipFixture(true),
      photoService: _PhotoFixture(), picker: _PickerFixture(),
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ghi hôm nay'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Tập thân trên');
    await tester.enterText(find.byType(TextField).at(1), '90,5');
    await tester.enterText(find.byType(TextField).at(4), 'Hít đất | 20 lần');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Lưu nhật ký'), 250,
      scrollable: find.byType(Scrollable).last);
    await tester.tap(find.text('Lưu nhật ký'));
    await tester.pumpAndSettle();
    expect(journal.lastPayload?['chestCm'], 90.5);
    expect(journal.lastPayload?['achievements'], [
      {'title': 'Hít đất', 'result': '20 lần'},
    ]);
    expect(find.text('Tập thân trên'), findsOneWidget);
    await tester.tap(find.text('Sửa'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Tập xong');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Lưu nhật ký'), 250,
      scrollable: find.byType(Scrollable).last);
    await tester.tap(find.text('Lưu nhật ký'));
    await tester.pumpAndSettle();
    expect(journal.updated, isTrue);
    expect(find.text('Tập xong'), findsOneWidget);
    await tester.tap(find.text('Xóa').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xóa').last);
    await tester.pumpAndSettle();
    expect(journal.entry, isNull);
    expect(find.text('Chưa có nhật ký tập.'), findsOneWidget);
  });
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
      ? [] : [JournalChartPoint(journalDate: entry!.journalDate,
          chestCm: entry!.chestCm)];
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
    id: 'entry-1', journalDate: '2026-11-13',
    notes: payload['notes'] as String?,
    chestCm: payload['chestCm'] as double?,
    waistCm: payload['waistCm'] as double?,
    hipsCm: payload['hipsCm'] as double?,
    achievements: (payload['achievements'] as List)
        .map(JournalAchievement.fromJson).toList(),
    photoMediaIds: (payload['photoMediaIds'] as List).cast<String>(),
  );
  @override
  Future<void> delete(String id) async { entry = null; }
}

class _MembershipFixture implements MembershipService {
  const _MembershipFixture(this.active);
  final bool active;
  @override
  Future<List<Membership>> getCurrentMemberships() async => active
      ? const [Membership(id: 'm1', startDate: '2026-11-01',
          endDate: '2026-12-01', status: 'ACTIVE')]
      : const [];
  @override
  Future<List<Membership>> getMembershipHistory() async => const [];
  @override
  Future<List<MembershipPlan>> getPlans() async => const [];
  @override
  Future<Payment> createPayment({required String planId,
      required String idempotencyKey}) => throw UnimplementedError();
  @override
  Future<PurchaseResult> confirmMockPayment(String paymentId) =>
      throw UnimplementedError();
}

class _PhotoFixture implements MemberPhotoService {
  @override
  Future<List<ProgressPhoto>> getPage(int page) async => const [];
  @override
  Future<String> upload(SelectedProgressImage image) => throw UnimplementedError();
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
