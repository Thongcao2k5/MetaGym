import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_gym_app/core/config/api_config.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/core/widgets/muscle_anatomy_tile.dart';
import 'package:meta_gym_app/features/catalog/data/catalog_service.dart';
import 'package:meta_gym_app/features/catalog/domain/catalog_models.dart';
import 'package:meta_gym_app/features/training/data/member_self_training_api.dart';
import 'package:meta_gym_app/features/training/data/self_training_icon_store.dart';
import 'package:meta_gym_app/features/training/domain/member_self_training_day.dart';
import 'package:meta_gym_app/features/training/presentation/member_self_training_page.dart';

void main() {
  test('muscle view orientation and multi-focus resolution', () {
    expect(isPosteriorMuscleView(const {}), isFalse);
    expect(isPosteriorMuscleView({MuscleFocus.chest}), isFalse);
    expect(
      isPosteriorMuscleView({MuscleFocus.chest, MuscleFocus.shoulders}),
      isFalse,
    );
    expect(isPosteriorMuscleView({MuscleFocus.back}), isTrue);
    expect(isPosteriorMuscleView({MuscleFocus.glutes}), isTrue);

    expect(
      resolveMuscleFocusSet('Ngực & Vai'),
      equals({MuscleFocus.chest, MuscleFocus.shoulders}),
    );
    expect(resolveMuscleFocusSet('Lưng & Xô'), equals({MuscleFocus.back}));
    expect(
      resolveMuscleFocusSet('Tự tập hôm nay', explicitKey: 'chest,core'),
      equals({MuscleFocus.chest, MuscleFocus.core}),
    );
  });

  testWidgets(
    'allows picking muscle icons and entering manual exercises with sets and reps',
    (tester) async {
      SelfTrainingIconStore.clearMemoryCache();
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        SelfTrainingIconStore.clearMemoryCache();
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final api = _FakeSelfTrainingApi();
      final catalog = _FakeCatalogService();
      await tester.pumpWidget(
        MaterialApp(
          home: MemberSelfTrainingPage(api: api, catalog: catalog),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Lên lịch tập'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Buổi đẩy sáng');
      await tester.pump();

      // Multi-select muscles (Ngực + Vai) inside the schedule editor.
      await tester.tap(find.text('Ngực'));
      await tester.pump();
      await tester.tap(find.text('Vai'));
      await tester.pump();
      expect(find.text('Ngực · Vai · Mặt trước'), findsOneWidget);

      // Add Lưng · Xô while Ngực is active (remains Mặt trước), then isolate Lưng · Xô -> Mặt sau.
      await tester.tap(find.text('Lưng · Xô'));
      await tester.pump();
      expect(find.text('Ngực · Vai · Lưng · Xô · Mặt trước'), findsOneWidget);

      await tester.tap(find.text('Ngực'));
      await tester.pump();
      await tester.tap(find.text('Vai'));
      await tester.pump();
      expect(find.text('Lưng · Xô · Mặt sau'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Chọn giờ tập'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chọn giờ tập'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // Enter manual exercise 1 (name, sets, reps)
      await tester.scrollUntilVisible(
        find.byKey(const Key('self-training-exercise-name-0')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(
        find.byKey(const Key('self-training-exercise-name-0')),
        'Lat Pulldown',
      );
      await tester.enterText(
        find.byKey(const Key('self-training-exercise-sets-0')),
        '4',
      );
      await tester.enterText(
        find.byKey(const Key('self-training-exercise-reps-0')),
        '10-12',
      );

      // Add and enter manual exercise 2
      await tester.scrollUntilVisible(
        find.byKey(const Key('self-training-add-exercise')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('self-training-add-exercise')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('self-training-exercise-reps-1')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(
        find.byKey(const Key('self-training-exercise-name-1')),
        'Dumbbell Curl',
      );
      await tester.enterText(
        find.byKey(const Key('self-training-exercise-sets-1')),
        '3',
      );
      await tester.enterText(
        find.byKey(const Key('self-training-exercise-reps-1')),
        '12',
      );

      await tester.scrollUntilVisible(
        find.text('Lưu kế hoạch'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lưu kế hoạch'));
      await tester.pumpAndSettle();

      // Concise outer summary card displays chosen MuscleAnatomyTile and short summary.
      expect(find.byType(MuscleAnatomyTile), findsOneWidget);
      expect(find.text('Buổi đẩy sáng'), findsOneWidget);
      expect(find.text('Lưng · Xô'), findsOneWidget);
      expect(find.text('Lat Pulldown'), findsNothing);

      // Tapping the concise card expands exercise details with sets and reps.
      await tester.tap(find.text('Buổi đẩy sáng'));
      await tester.pumpAndSettle();
      expect(find.text('Lat Pulldown'), findsOneWidget);
      expect(find.text('4 set × 10-12 rep'), findsOneWidget);
      expect(find.text('Dumbbell Curl'), findsOneWidget);
      expect(find.text('3 set × 12 rep'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('validates manual exercise name, sets, and reps before saving', (
    tester,
  ) async {
    SelfTrainingIconStore.clearMemoryCache();
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      SelfTrainingIconStore.clearMemoryCache();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final api = _FakeSelfTrainingApi();
    await tester.pumpWidget(MaterialApp(home: MemberSelfTrainingPage(api: api)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Lên lịch tập'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Buổi ngực');
    await tester.scrollUntilVisible(
      find.text('Chọn giờ tập'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Chọn giờ tập'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chọn giờ tập'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('self-training-exercise-name-0')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(
      find.byKey(const Key('self-training-exercise-name-0')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('self-training-exercise-name-0')),
      'Bench Press',
    );
    await tester.scrollUntilVisible(
      find.text('Lưu kế hoạch'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Lưu kế hoạch'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lưu kế hoạch'));
    await tester.pumpAndSettle();

    expect(
      find.text('Nhập đầy đủ tên bài tập, số set (1–99) và số rep.'),
      findsOneWidget,
    );
    expect(api.saveCalls, 0);
  });

  testWidgets(
    'allows scheduling multiple sessions on the same day via the bottom CTA',
    (tester) async {
      SelfTrainingIconStore.clearMemoryCache();
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        SelfTrainingIconStore.clearMemoryCache();
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final api = _FakeSelfTrainingApi();
      await tester.pumpWidget(
        MaterialApp(home: MemberSelfTrainingPage(api: api)),
      );
      await tester.pumpAndSettle();

      // Empty day shows bottom CTA 'Lên lịch tập'.
      final bottomCta = find.byKey(
        const Key('self-training-bottom-add-session'),
      );
      expect(bottomCta, findsOneWidget);
      expect(find.text('Lên lịch tập'), findsOneWidget);

      await tester.tap(bottomCta);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Buổi sáng · Ngực');
      await tester.tap(find.text('Ngực'));
      await tester.pump();

      await tester.scrollUntilVisible(
        find.text('Chọn giờ tập'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('Chọn giờ tập'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chọn giờ tập'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byKey(const Key('self-training-exercise-name-0')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(
        find.byKey(const Key('self-training-exercise-name-0')),
        'Bench Press',
      );
      await tester.enterText(
        find.byKey(const Key('self-training-exercise-sets-0')),
        '4',
      );
      await tester.enterText(
        find.byKey(const Key('self-training-exercise-reps-0')),
        '8-10',
      );

      await tester.scrollUntilVisible(
        find.text('Lưu kế hoạch'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('Lưu kế hoạch'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lưu kế hoạch'));
      await tester.pumpAndSettle();

      expect(find.text('1 buổi tập'), findsOneWidget);
      expect(find.text('Buổi sáng · Ngực'), findsOneWidget);
      // Bottom CTA switches to 'Thêm buổi tập mới'.
      expect(find.text('Thêm buổi tập mới'), findsOneWidget);

      // Add a second session on the exact same date.
      await tester.tap(bottomCta);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField).first,
        'Buổi chiều · Chân',
      );
      await tester.tap(find.text('Chân · Đùi'));
      await tester.pump();

      await tester.scrollUntilVisible(
        find.text('Chọn giờ tập'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('Chọn giờ tập'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chọn giờ tập'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byKey(const Key('self-training-exercise-name-0')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(
        find.byKey(const Key('self-training-exercise-name-0')),
        'Squat',
      );
      await tester.enterText(
        find.byKey(const Key('self-training-exercise-sets-0')),
        '5',
      );
      await tester.enterText(
        find.byKey(const Key('self-training-exercise-reps-0')),
        '5',
      );

      await tester.scrollUntilVisible(
        find.text('Lưu kế hoạch'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('Lưu kế hoạch'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lưu kế hoạch'));
      await tester.pumpAndSettle();

      // Both sessions coexist cleanly on the same day.
      expect(find.text('2 buổi tập'), findsOneWidget);
      expect(find.text('Buổi sáng · Ngực'), findsOneWidget);
      expect(find.text('Buổi chiều · Chân'), findsOneWidget);
      expect(find.byType(MuscleAnatomyTile), findsNWidgets(2));

      // Edit session 2 without overwriting session 1.
      final editSession2 = find.byKey(const Key('self-training-edit-self-2'));
      await tester.scrollUntilVisible(
        editSession2,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(editSession2);
      await tester.pumpAndSettle();
      await tester.tap(editSession2);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField).first,
        'Buổi chiều · Đùi & Mông',
      );
      await tester.drag(find.byType(ListView).first, const Offset(0, -600));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Lưu kế hoạch'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lưu kế hoạch'));
      await tester.pumpAndSettle();

      expect(find.text('2 buổi tập'), findsOneWidget);
      expect(find.text('Buổi sáng · Ngực'), findsOneWidget);
      expect(find.text('Buổi chiều · Đùi & Mông'), findsOneWidget);

      // Delete session 1 while keeping session 2.
      final deleteSession1 = find.byKey(
        const Key('self-training-delete-self-1'),
      );
      await tester.scrollUntilVisible(
        deleteSession1,
        -200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(deleteSession1);
      await tester.pumpAndSettle();
      await tester.tap(deleteSession1);
      await tester.pumpAndSettle();

      expect(find.text('1 buổi tập'), findsOneWidget);
      expect(find.text('Buổi sáng · Ngực'), findsNothing);
      expect(find.text('Buổi chiều · Đùi & Mông'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

class _NoopAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => throw StateError('Unexpected HTTP request: ${options.path}');

  @override
  void close({bool force = false}) {}
}

class _FakeSelfTrainingApi extends MemberSelfTrainingApi {
  _FakeSelfTrainingApi()
    : super(
        ApiClient.withAdapter(
          config: ApiConfig.fromValues(environment: 'local'),
          adapter: _NoopAdapter(),
        ),
      );

  final List<MemberSelfTrainingDay> _items = [];
  int saveCalls = 0;
  int _nextId = 1;

  @override
  Future<List<MemberSelfTrainingDay>> getRange(String from, String to) async =>
      List<MemberSelfTrainingDay>.unmodifiable(_items);

  @override
  Future<MemberSelfTrainingDay> createSession({
    required String day,
    required String title,
    required String? startTime,
    required String notes,
    required List<SelfTrainingExercise> exercises,
  }) async {
    saveCalls++;
    final created = MemberSelfTrainingDay(
      id: 'self-${_nextId++}',
      planDate: day,
      title: title,
      startTime: startTime,
      notes: notes,
      exercises: exercises,
    );
    _items.add(created);
    return created;
  }

  @override
  Future<MemberSelfTrainingDay> updateSession({
    required String id,
    required String title,
    required String? startTime,
    required String notes,
    required List<SelfTrainingExercise> exercises,
  }) async {
    saveCalls++;
    final idx = _items.indexWhere((item) => item.id == id);
    final planDate = idx >= 0 ? _items[idx].planDate : '2026-11-26';
    final updated = MemberSelfTrainingDay(
      id: id,
      planDate: planDate,
      title: title,
      startTime: startTime,
      notes: notes,
      exercises: exercises,
    );
    if (idx >= 0) {
      _items[idx] = updated;
    } else {
      _items.add(updated);
    }
    return updated;
  }

  @override
  Future<void> deleteSession(String id) async {
    _items.removeWhere((item) => item.id == id);
  }

  @override
  Future<MemberSelfTrainingDay> save({
    required String day,
    required String title,
    required String? startTime,
    required String notes,
    required List<SelfTrainingExercise> exercises,
  }) async => createSession(
    day: day,
    title: title,
    startTime: startTime,
    notes: notes,
    exercises: exercises,
  );

  @override
  Future<void> delete(String day) async {
    _items.removeWhere((item) => item.planDate == day);
  }
}

class _FakeCatalogService implements CatalogService {
  @override
  Future<GymProfile> getGymProfile() async =>
      const GymProfile(name: 'Meta Gym', address: 'TP.HCM');

  @override
  Future<List<CatalogItem>> getEquipment({String? search}) async => const [];

  @override
  Future<CatalogItem> getEquipmentDetail(String id) async =>
      throw StateError('unused');

  @override
  Future<List<CatalogItem>> getExercises({String? search}) async => const [
    CatalogItem(id: 'ex-1', name: 'Lat Pulldown', targetMuscles: ['Lưng']),
  ];
}
