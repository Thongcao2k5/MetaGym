import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/features/catalog/domain/catalog_models.dart';
import 'package:meta_gym_app/features/coaching/domain/coach_member_models.dart';
import 'package:meta_gym_app/features/training/data/coach_training_service.dart';
import 'package:meta_gym_app/features/training/data/member_training_service.dart';
import 'package:meta_gym_app/features/training/domain/training_models.dart';
import 'package:meta_gym_app/features/training/presentation/coach_plan_detail_page.dart';
import 'package:meta_gym_app/features/training/presentation/member_training_page.dart';

void main() {
  testWidgets(
    'confirms publication, archives old version and exposes new one to Member',
    (tester) async {
      final service = _PublicationFixture();
      await tester.pumpWidget(
        MaterialApp(
          home: CoachPlanDetailPage(id: 'new', service: service),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Công bố'));
      await tester.pumpAndSettle();
      expect(find.text('Xác nhận công bố'), findsOneWidget);
      expect(service.published, false);
      await tester.tap(find.text('Xác nhận công bố'));
      await tester.pumpAndSettle();
      expect(service.published, true);
      expect(find.text('Đã công bố · Phiên bản 2'), findsOneWidget);
      expect(find.text('Sửa bản nháp'), findsNothing);

      await tester.pumpWidget(
        MaterialApp(home: MemberTrainingPage(service: service)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Giáo trình mới'), findsOneWidget);
      expect(find.text('Giáo trình cũ'), findsOneWidget);
    },
  );

  testWidgets('reports relationship-expired publication error', (tester) async {
    final service = _PublicationFixture(expired: true);
    await tester.pumpWidget(
      MaterialApp(
        home: CoachPlanDetailPage(id: 'new', service: service),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Công bố'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xác nhận công bố'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('quan hệ Coach–Member không còn hoạt động'),
      findsOneWidget,
    );
    expect(find.text('Bản nháp · Phiên bản 2'), findsOneWidget);
  });
}

class _PublicationFixture
    implements CoachTrainingService, MemberTrainingService {
  _PublicationFixture({this.expired = false});

  final bool expired;
  bool published = false;

  TrainingPlan get newest => TrainingPlan(
    id: 'new',
    title: 'Giáo trình mới',
    status: published ? 'ACTIVE' : 'DRAFT',
    version: 2,
  );

  @override
  Future<TrainingPlan> publish(String id) async {
    if (expired) {
      throw const ApiException(
        kind: ApiExceptionKind.request,
        statusCode: 409,
        code: 'PUBLICATION_NOT_ALLOWED',
        message: 'Không thể công bố giáo trình',
      );
    }
    published = true;
    return newest;
  }

  @override
  Future<TrainingPlan?> getActive() async => published
      ? newest
      : const TrainingPlan(
          id: 'old',
          title: 'Giáo trình cũ',
          status: 'ACTIVE',
          version: 1,
        );

  @override
  Future<List<TrainingPlan>> getHistory() async => published
      ? [
          newest,
          const TrainingPlan(
            id: 'old',
            title: 'Giáo trình cũ',
            status: 'ARCHIVED',
            version: 1,
          ),
        ]
      : const [];

  @override
  Future<TrainingPlan> getPlan(String id) async => newest;

  @override
  Future<List<CoachMemberSummary>> getMembers() async => const [];

  @override
  Future<List<CatalogItem>> getExercises() async => const [];

  @override
  Future<List<TrainingPlan>> getPlans(String memberId) async => [newest];

  @override
  Future<TrainingPlan> create(String memberId, Map<String, Object?> payload) =>
      throw UnimplementedError();

  @override
  Future<TrainingPlan> update(String id, Map<String, Object?> payload) =>
      throw UnimplementedError();
}
