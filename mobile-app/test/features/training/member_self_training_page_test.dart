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
    'allows picking muscle icons for concise outer self-training card',
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
        find.text('Chọn bài tập (0)'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chọn bài tập (0)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lat Pulldown'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xong'));
      await tester.pumpAndSettle();

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

      // Tapping the concise card expands exercise details.
      await tester.tap(find.text('Buổi đẩy sáng'));
      await tester.pumpAndSettle();
      expect(find.text('Lat Pulldown'), findsOneWidget);
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

  final Map<String, MemberSelfTrainingDay> _items = {};

  @override
  Future<List<MemberSelfTrainingDay>> getRange(String from, String to) async =>
      _items.values.toList();

  @override
  Future<MemberSelfTrainingDay> save({
    required String day,
    required String title,
    required String? startTime,
    required String notes,
    required List<String> exerciseIds,
  }) async {
    final created = MemberSelfTrainingDay(
      id: 'self-$day',
      planDate: day,
      title: title,
      startTime: startTime,
      notes: notes,
      exercises: const [SelfTrainingExercise(id: 'ex-1', name: 'Lat Pulldown')],
    );
    _items[day] = created;
    return created;
  }

  @override
  Future<void> delete(String day) async {
    _items.remove(day);
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
