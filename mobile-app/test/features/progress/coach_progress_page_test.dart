import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_gym_app/features/coaching/data/coach_members_service.dart';
import 'package:meta_gym_app/features/coaching/domain/coach_member_models.dart';
import 'package:meta_gym_app/features/coaching/presentation/coach_member_detail_page.dart';
import 'package:meta_gym_app/features/progress/data/coach_progress_service.dart';
import 'package:meta_gym_app/features/progress/domain/body_measurement.dart';
import 'package:meta_gym_app/features/progress/domain/meal_log.dart';
import 'package:meta_gym_app/features/progress/domain/progress_comment.dart';
import 'package:meta_gym_app/features/progress/domain/progress_models.dart';
import 'package:meta_gym_app/features/progress/domain/progress_photo.dart';
import 'package:meta_gym_app/features/progress/domain/workout_log.dart';
import 'package:meta_gym_app/features/progress/presentation/coach_progress_page.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('opens progress from a Coach Member detail', (tester) async {
    await tester.pumpWidget(
      Provider<CoachProgressService>.value(
        value: _CoachProgressFixture(),
        child: MaterialApp(
          home: CoachMemberDetailPage(
            memberId: 'member-1',
            service: _DetailFixture(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xem tiến độ'));
    await tester.pumpAndSettle();
    expect(find.byType(CoachProgressPage), findsOneWidget);
    expect(find.text('Buổi tập: 1'), findsOneWidget);
  });

  testWidgets('shows Member progress and sends a general comment', (
    tester,
  ) async {
    final service = _CoachProgressFixture();
    await tester.pumpWidget(
      MaterialApp(
        home: CoachProgressPage(
          memberId: 'member-1',
          memberName: 'Nguyễn An',
          service: service,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Buổi tập: 1'), findsOneWidget);
    expect(find.text('Nhật ký tập'), findsOneWidget);
    expect(find.text('Nhật ký ăn'), findsOneWidget);
    expect(find.text('Số đo'), findsOneWidget);
    expect(find.text('Ảnh tiến trình'), findsOneWidget);
    await tester.tap(find.text('Nhận xét chung'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('progress-comment')),
      'Tiến bộ tốt',
    );
    await tester.tap(find.text('Gửi nhận xét').last);
    await tester.pumpAndSettle();
    expect(service.sent?['memberId'], 'member-1');
    expect(service.sent?['content'], 'Tiến bộ tốt');
    await tester.scrollUntilVisible(find.text('Nhận xét đã gửi'), 300);
    await tester.tap(find.text('Nhận xét đã gửi'));
    await tester.pumpAndSettle();
    expect(find.text('Tiến bộ tốt'), findsOneWidget);
  });

  testWidgets('clears private progress when relationship access ends', (
    tester,
  ) async {
    final service = _CoachProgressFixture();
    await tester.pumpWidget(
      MaterialApp(
        home: CoachProgressPage(
          memberId: 'member-1',
          memberName: 'Nguyễn An',
          service: service,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Buổi tập: 1'), findsOneWidget);
    service.revoked = true;
    await tester.drag(find.byType(ListView).first, const Offset(0, 350));
    await tester.pumpAndSettle();
    expect(find.text('Buổi tập: 1'), findsNothing);
    expect(find.text('Không còn quyền xem tiến độ.'), findsOneWidget);
  });

  testWidgets('requires text and targets a workout when commenting', (tester) async {
    final service = _CoachProgressFixture();
    await tester.pumpWidget(MaterialApp(home: CoachProgressPage(
      memberId: 'member-1', memberName: 'Nguyễn An', service: service,
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nhật ký tập'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nhận xét').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gửi nhận xét').last);
    await tester.pumpAndSettle();
    expect(find.text('Vui lòng nhập nhận xét.'), findsOneWidget);
    expect(service.sent, isNull);
    await tester.enterText(find.byKey(const Key('progress-comment')), 'Tăng mức tạ dần');
    await tester.tap(find.text('Gửi nhận xét').last);
    await tester.pumpAndSettle();
    expect(service.sent?['workoutLogId'], 'w-1');
  });
}

class _DetailFixture implements CoachMembersService {
  @override
  Future<CoachMemberDetail> getMember(String memberId) async =>
      const CoachMemberDetail(
        relationshipId: 'r-1',
        memberId: 'member-1',
        memberFullName: 'Nguyễn An',
        status: 'ACTIVE',
        email: 'member@test.local',
      );
  @override
  Future<List<CoachTerminationRequest>> getTerminationRequests() async =>
      const [];
  @override
  Future<List<CoachMemberSummary>> getMembers() async => const [];
  @override
  Future<void> requestTermination(String id, String reason) =>
      throw UnimplementedError();
}

class _CoachProgressFixture implements CoachProgressService {
  bool revoked = false;
  Map<String, Object?>? sent;
  @override
  Future<ProgressSummary> getSummary(String memberId) async {
    if (revoked) throw StateError('revoked');
    return const ProgressSummary(
      workoutCount: 1,
      mealCount: 1,
      progressPhotoCount: 1,
    );
  }

  @override
  Future<List<WorkoutLog>> getWorkouts(String memberId) async => const [
    WorkoutLog(
      id: 'w-1',
      performedAt: '2026-10-23T08:00:00Z',
      durationMinutes: 45,
    ),
  ];
  @override
  Future<List<MealLog>> getMeals(String memberId) async => const [
    MealLog(id: 'm-1', eatenAt: '2026-10-23T12:00:00Z', mealName: 'Cơm gà'),
  ];
  @override
  Future<List<BodyMeasurement>> getMeasurements(String memberId) async =>
      const [
        BodyMeasurement(
          id: 'b-1',
          measuredAt: '2026-10-23T08:00:00Z',
          weightKg: 72.5,
        ),
      ];
  @override
  Future<List<ProgressPhoto>> getPhotos(String memberId) async => const [
    ProgressPhoto(
      id: 'p-1',
      mediaId: 'media-1',
      takenAt: '2026-10-23T08:00:00Z',
    ),
  ];
  @override
  Future<List<ProgressComment>> getComments(String memberId) async => [
    if (sent != null)
      ProgressComment(
        id: 'c-1',
        content: sent!['content'] as String,
        createdAt: '2026-10-23T08:00:00Z',
      ),
  ];
  @override
  Future<ProgressComment> comment(Map<String, Object?> payload) async {
    sent = payload;
    return ProgressComment(
      id: 'c-1',
      content: payload['content'] as String,
      createdAt: '2026-10-23T08:00:00Z',
    );
  }

  @override
  Future<Uri> getPhotoAccessUrl(String mediaId) async =>
      Uri.parse('https://example.test/image.png');
}
