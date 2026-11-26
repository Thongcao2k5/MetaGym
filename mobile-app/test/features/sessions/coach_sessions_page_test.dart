import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_bottom_nav.dart';
import 'package:meta_gym_app/features/coaching/data/coach_members_service.dart';
import 'package:meta_gym_app/features/coaching/domain/coach_member_models.dart';
import 'package:meta_gym_app/features/sessions/data/coach_sessions_service.dart';
import 'package:meta_gym_app/features/sessions/domain/training_session.dart';
import 'package:meta_gym_app/features/sessions/presentation/coach_sessions_page.dart';

void main() {
  test('rejects impossible local dates', () {
    expect(parseSessionLocalTime('31/02/2026 08:00'), isNull);
    expect(parseSessionLocalTime('23/10/2026 25:00'), isNull);
  });

  testWidgets('creates a session for an active member', (tester) async {
    final sessions = _SessionsFixture();
    await tester.pumpWidget(
      MaterialApp(
        theme: MetaGymTheme.dark,
        home: CoachSessionsPage(
          service: sessions,
          membersService: _MembersFixture(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tạo buổi tập'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('session-title')), 'Tập chân');
    await tester.enterText(
      find.byKey(const Key('session-start')),
      '24/10/2026 08:00',
    );
    await tester.enterText(
      find.byKey(const Key('session-end')),
      '24/10/2026 09:00',
    );
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();
    expect(sessions.created?['memberId'], 'member-1');
    expect(sessions.created?['title'], 'Tập chân');
    expect(find.text('Tập chân'), findsOneWidget);
  });

  testWidgets(
    'rejects end time before start and requires cancellation reason',
    (tester) async {
      final sessions = _SessionsFixture(seed: true);
      await tester.pumpWidget(
        MaterialApp(
          theme: MetaGymTheme.dark,
          home: CoachSessionsPage(
            service: sessions,
            membersService: _MembersFixture(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Buổi cũ'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chỉnh sửa buổi tập'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('session-end')),
        '23/10/2026 07:00',
      );
      await tester.tap(find.text('Lưu'));
      await tester.pumpAndSettle();
      expect(find.text('Giờ kết thúc phải sau giờ bắt đầu.'), findsOneWidget);
      expect(sessions.updated, isNull);
      await tester.tap(find.byTooltip('Quay lại'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('session-action-cancel')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xác nhận hủy ca'));
      await tester.pumpAndSettle();
      expect(find.text('Vui lòng nhập lý do hủy.'), findsOneWidget);
      expect(sessions.updated, isNull);
    },
  );

  testWidgets('marks a scheduled session completed', (tester) async {
    final sessions = _SessionsFixture(seed: true);
    await tester.pumpWidget(
      MaterialApp(
        theme: MetaGymTheme.dark,
        home: CoachSessionsPage(
          service: sessions,
          membersService: _MembersFixture(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('session-action-complete')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xác nhận'));
    await tester.pumpAndSettle();
    expect(sessions.updated, {'status': 'COMPLETED'});
  });

  testWidgets(
    'cancels a session with a reason without disposing an active field',
    (tester) async {
      final sessions = _SessionsFixture(seed: true);
      await tester.pumpWidget(
        MaterialApp(
          theme: MetaGymTheme.dark,
          home: CoachSessionsPage(
            service: sessions,
            membersService: _MembersFixture(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('session-action-cancel')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('session-cancellation-reason')),
        'Bận đột xuất',
      );
      await tester.tap(find.text('Xác nhận hủy ca'));
      await tester.pumpAndSettle();
      expect(sessions.updated?['cancellationReason'], 'Bận đột xuất');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'renders 4 preview status tabs, schedule banner & coachBooking fallback without overflow at 375x812',
    (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final sessions = _SessionsFixture(seed: true);
      await tester.pumpWidget(
        MaterialApp(
          theme: MetaGymTheme.dark,
          home: CoachSessionsPage(
            service: sessions,
            membersService: _MembersFixture(),
            coachBooking: const Scaffold(body: Center(child: Text('Booking'))),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Lịch dạy'), findsOneWidget);
      expect(find.text('Lịch làm việc hằng tuần'), findsOneWidget);
      expect(find.text('Hôm nay'), findsOneWidget);
      expect(find.text('Sắp tới'), findsOneWidget);
      expect(find.text('Đã xong'), findsOneWidget);
      expect(find.text('Đã hủy'), findsOneWidget);
      expect(find.text('Buổi cũ'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const Key('sessions-tab-done')));
      await tester.pumpAndSettle();
      expect(find.text('Chưa có ca dạy đã hoàn thành.'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const Key('sessions-tab-today')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quản lý lịch làm việc Coach'));
      await tester.pumpAndSettle();
      expect(find.text('Booking'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'renders header subtitle without truncation or overflow at 375x812',
    (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final sessions = _SessionsFixture(seed: true);
      await tester.pumpWidget(
        MaterialApp(
          theme: MetaGymTheme.dark,
          home: CoachSessionsPage(
            service: sessions,
            membersService: _MembersFixture(),
            coachBooking: const Scaffold(body: Center(child: Text('Booking'))),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final subtitleFinder = find.text('Quản lý ca 1:1 & điểm danh');
      expect(find.text('Lịch dạy'), findsOneWidget);
      expect(subtitleFinder, findsOneWidget);
      final renderParagraph = tester.renderObject<RenderParagraph>(subtitleFinder);
      expect(renderParagraph.didExceedMaxLines, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'places Tạo buổi tập FAB strictly above MetaGymBottomNav when embedded in extendBody Scaffold',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: MetaGymTheme.dark,
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(390, 844),
              padding: EdgeInsets.only(top: 44, bottom: 24),
              viewPadding: EdgeInsets.only(top: 44, bottom: 24),
            ),
            child: Builder(
              builder: (context) => Scaffold(
                extendBody: true,
                body: CoachSessionsPage(
                  service: _SessionsFixture(seed: true),
                  membersService: _MembersFixture(),
                  bottomPadding: MetaGymBottomNav.contentBottomPadding(context),
                ),
                bottomNavigationBar: MetaGymBottomNav(
                  currentIndex: 1,
                  warmGlass: true,
                  secondTabLabel: 'Lịch dạy',
                  onTap: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final fabRect = tester.getRect(find.byType(FloatingActionButton));
      final navRect = tester.getRect(find.byType(MetaGymBottomNav));
      expect(fabRect.bottom, lessThanOrEqualTo(navRect.top));

      await tester.tap(find.text('Tạo buổi tập'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('session-title')), findsOneWidget);
    },
  );
}

class _MembersFixture implements CoachMembersService {
  @override
  Future<List<CoachMemberSummary>> getMembers() async => const [
    CoachMemberSummary(
      relationshipId: 'r-1',
      memberId: 'member-1',
      memberFullName: 'Hội viên A',
      status: 'ACTIVE',
    ),
  ];
  @override
  Future<CoachMemberDetail> getMember(String id) => throw UnimplementedError();
  @override
  Future<List<CoachTerminationRequest>> getTerminationRequests() =>
      throw UnimplementedError();
  @override
  Future<void> requestTermination(String id, String reason) =>
      throw UnimplementedError();
  @override
  Future<CoachTerminationRequest> respondTermination(
    String requestId, {
    required String decision,
    String? reason,
  }) => throw UnimplementedError();
}

class _SessionsFixture implements CoachSessionsService {
  _SessionsFixture({this.seed = false});
  final bool seed;
  Map<String, Object?>? created;
  Map<String, Object?>? updated;
  @override
  Future<List<TrainingSession>> getAll() async => [
    if (seed)
      const TrainingSession(
        id: 's-1',
        title: 'Buổi cũ',
        scheduledStartAt: '2026-10-23T08:00:00Z',
        status: 'SCHEDULED',
      ),
    if (created != null)
      TrainingSession(
        id: 's-2',
        title: created!['title'] as String,
        scheduledStartAt: created!['scheduledStartAt'] as String,
        status: 'SCHEDULED',
      ),
  ];
  @override
  Future<TrainingSession> create(Map<String, Object?> payload) async {
    created = payload;
    return TrainingSession(
      id: 's-2',
      title: payload['title'] as String,
      scheduledStartAt: payload['scheduledStartAt'] as String,
      status: 'SCHEDULED',
    );
  }

  @override
  Future<TrainingSession> update(
    String id,
    Map<String, Object?> payload,
  ) async {
    updated = payload;
    return const TrainingSession(
      id: 's-1',
      title: 'Buổi cũ',
      scheduledStartAt: '2026-10-23T08:00:00Z',
      status: 'CANCELLED',
    );
  }
}
