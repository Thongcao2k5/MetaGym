import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_gym_app/features/sessions/data/member_sessions_service.dart';
import 'package:meta_gym_app/features/sessions/domain/training_session.dart';
import 'package:meta_gym_app/features/sessions/presentation/member_sessions_page.dart';

void main() {
  test('parses API fields and formats a device-local time', () {
    final session = TrainingSession.fromJson({
      'id': 'session-1',
      'title': 'Tập chân',
      'scheduledStartAt': '2026-10-23T08:30:00Z',
      'scheduledEndAt': null,
      'status': 'MEMBER_ABSENT',
      'notes': 'Khởi động kỹ',
    });
    expect(session.statusLabel, 'Hội viên vắng');
    final local = DateTime.parse(session.scheduledStartAt).toLocal();
    expect(
      formatSessionLocalTime(session.scheduledStartAt),
      '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year} '
      '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}',
    );
  });

  test('shows a scheduled session as locked during membership expiry', () {
    final session = TrainingSession.fromJson({
      'id': 'session-locked',
      'title': 'Tập chân',
      'scheduledStartAt': '2026-11-15T08:30:00Z',
      'status': 'SCHEDULED',
      'accessLocked': true,
    });
    expect(session.statusLabel, 'Tạm khóa · Chờ gia hạn gói');
  });

  testWidgets('shows schedule, loads detail, and refreshes the list', (
    tester,
  ) async {
    final service = _SessionsFixture();
    await tester.pumpWidget(
      MaterialApp(home: MemberSessionsPage(service: service)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Tập chân'), findsOneWidget);
    expect(find.textContaining('Đã lên lịch'), findsOneWidget);
    await tester.tap(find.text('Tập chân'));
    await tester.pumpAndSettle();
    expect(service.detailLoads, 1);
    expect(find.text('Khởi động kỹ'), findsOneWidget);
    expect(find.textContaining('Giờ địa phương'), findsWidgets);
    expect(find.text('Hoàn thành'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, 350));
    await tester.pumpAndSettle();
    expect(service.listLoads, 2);
  });

  testWidgets('shows error, retry, then empty schedule', (tester) async {
    final service = _SessionsFixture(failFirst: true, empty: true);
    await tester.pumpWidget(
      MaterialApp(home: MemberSessionsPage(service: service)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Không tải được lịch buổi tập.'), findsOneWidget);
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('Bạn chưa có buổi tập nào.'), findsOneWidget);
  });
}

class _SessionsFixture implements MemberSessionsService {
  _SessionsFixture({this.failFirst = false, this.empty = false});

  final bool failFirst;
  final bool empty;
  int listLoads = 0;
  int detailLoads = 0;

  @override
  Future<List<TrainingSession>> getMine() async {
    listLoads++;
    if (failFirst && listLoads == 1) throw StateError('failed');
    return empty
        ? []
        : [
            const TrainingSession(
              id: 'session-1',
              title: 'Tập chân',
              scheduledStartAt: '2026-10-23T08:30:00Z',
              status: 'SCHEDULED',
            ),
          ];
  }

  @override
  Future<TrainingSession> getDetail(String id) async {
    detailLoads++;
    return const TrainingSession(
      id: 'session-1',
      title: 'Tập chân',
      scheduledStartAt: '2026-10-23T08:30:00Z',
      scheduledEndAt: '2026-10-23T09:30:00Z',
      status: 'COMPLETED',
      notes: 'Khởi động kỹ',
    );
  }
}
