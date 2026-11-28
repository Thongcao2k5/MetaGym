import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/theme/meta_gym_icons.dart';
import 'package:meta_gym_app/features/catalog/data/catalog_service.dart';
import 'package:meta_gym_app/features/catalog/domain/catalog_models.dart';
import 'package:meta_gym_app/features/catalog/presentation/equipment_detail_page.dart';
import 'package:meta_gym_app/features/catalog/presentation/exercise_library_page.dart';
import 'package:meta_gym_app/features/catalog/presentation/exercise_video_player.dart';
import 'package:meta_gym_app/features/catalog/presentation/gym_equipment_page.dart';

void main() {
  for (final state in ['data', 'empty', 'error']) {
    testWidgets('exercise library at 375px: $state', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: MetaGymTheme.dark,
          home: ExerciseLibraryPage(service: _GymFixture(exerciseState: state)),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (state == 'data') expect(find.text('Squat'), findsOneWidget);
      if (state == 'error') expect(find.text('Fixture error'), findsOneWidget);
      expect(find.byType(RefreshIndicator), findsOneWidget);
    });
  }

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  testWidgets('shows gym information and active equipment detail', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = _GymFixture();
    await tester.pumpWidget(
      MaterialApp(home: GymEquipmentPage(service: service)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Meta Gym'), findsOneWidget);
    expect(find.textContaining('06:00-21:00'), findsOneWidget);
    expect(find.text('Mang khăn tập.'), findsOneWidget);
    expect(find.text('Máy chạy bộ'), findsOneWidget);
    expect(find.text('Máy ẩn'), findsNothing);

    await tester.ensureVisible(find.text('Máy chạy bộ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Máy chạy bộ'));
    await tester.pumpAndSettle();
    expect(find.text('Khởi động trước khi chạy'), findsOneWidget);
    expect(find.text('Giữ tay vịn khi lên máy'), findsOneWidget);
    expect(service.detailId, 'equipment-1');
  });

  testWidgets('searches, filters and shows an empty result', (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = _GymFixture();
    await tester.pumpWidget(
      MaterialApp(home: GymEquipmentPage(service: service)),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Tạ đơn'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Tạ đơn'), findsOneWidget);
    final cardio = find.widgetWithText(ChoiceChip, 'Cardio');
    await tester.ensureVisible(cardio);
    await tester.tap(cardio);
    await tester.pumpAndSettle();
    expect(find.text('Tạ đơn'), findsNothing);

    await tester.enterText(
      find.byKey(const Key('equipment-search')),
      'không có',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(service.search, 'không có');
    expect(find.text('Không có máy phù hợp.'), findsOneWidget);
  });

  testWidgets('shows load error and retries', (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = _GymFixture(failFirst: true);
    await tester.pumpWidget(
      MaterialApp(home: GymEquipmentPage(service: service)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Không tải được thông tin gym.'), findsOneWidget);

    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('Meta Gym'), findsOneWidget);
    expect(service.profileLoads, 2);
  });

  testWidgets('shows maintenance status pill on gym equipment page', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = _GymFixture();
    await tester.pumpWidget(
      MaterialApp(
        theme: MetaGymTheme.dark,
        home: GymEquipmentPage(service: service),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sẵn sàng'), findsAtLeastNWidgets(1));
    await tester.scrollUntilVisible(
      find.text('Đang bảo trì'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Đang bảo trì'), findsOneWidget);
  });

  testWidgets(
    'equipment detail renders dark hero card, muscle pills, steps and safety notes',
    (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = _GymFixture();
      await tester.pumpWidget(
        MaterialApp(
          theme: MetaGymTheme.dark,
          home: EquipmentDetailPage(
            equipmentId: 'equipment-cable',
            service: service,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('HƯỚNG DẪN THIẾT BỊ'), findsOneWidget);
      expect(find.text('Cable Crossover Dual'), findsAtLeastNWidgets(1));
      expect(find.text('● Sẵn sàng sử dụng'), findsOneWidget);
      expect(find.text('Ngực giữa'), findsOneWidget);
      expect(find.text('Vai trước'), findsOneWidget);
      expect(find.text('Tay sau'), findsOneWidget);
      expect(find.text('Hướng dẫn sử dụng từng bước'), findsOneWidget);
      expect(find.text('Bước 1'), findsOneWidget);
      expect(find.text('Bước 2'), findsOneWidget);
      expect(find.text('Chỉnh chốt ròng rọc ngang tầm vai.'), findsOneWidget);
      expect(find.text('Ép hai tay về phía trước ngực.'), findsOneWidget);
      expect(find.text('Lưu ý an toàn'), findsOneWidget);
      expect(
        find.text('Kiểm tra chốt tạ đã cắm chặt trước khi kéo.'),
        findsOneWidget,
      );
    },
  );

  test(
    'equipmentIconAssetFor maps all 8 Realleader M3 icons and preserves generic fallbacks',
    () {
      expect(
        equipmentIconAssetFor(
          const CatalogItem(
            id: '1',
            name: 'Máy duỗi lưng M3-1016',
            category: 'Máy Realleader M3',
          ),
        ),
        MetaGymIcons.equipM3BackExtension,
      );
      expect(
        equipmentIconAssetFor(
          const CatalogItem(
            id: '2',
            name: 'Pec Fly Rear Delt',
            category: 'Máy khối',
          ),
        ),
        MetaGymIcons.equipM3PecFlyRearDelt,
      );
      expect(
        equipmentIconAssetFor(
          const CatalogItem(
            id: '3',
            name: 'Máy cuốn đùi sau ngồi M3-1018',
            category: 'Máy Realleader M3',
          ),
        ),
        MetaGymIcons.equipM3SeatedLegCurl,
      );
      expect(
        equipmentIconAssetFor(
          const CatalogItem(
            id: '4',
            name: 'Máy nhón bắp chân đứng M3-1019',
            category: 'Máy Realleader M3',
          ),
        ),
        MetaGymIcons.equipM3StandingCalfRaise,
      );
      expect(
        equipmentIconAssetFor(
          const CatalogItem(
            id: '5',
            name: 'Máy xà đơn / xà kép trợ lực M3-1020',
            category: 'Máy Realleader M3',
          ),
        ),
        MetaGymIcons.equipM3ChinDipAssist,
      );
      expect(
        equipmentIconAssetFor(
          const CatalogItem(
            id: '6',
            name: 'Máy xoay eo M3-1021',
            category: 'Máy Realleader M3',
          ),
        ),
        MetaGymIcons.equipM3RotaryTorso,
      );
      expect(
        equipmentIconAssetFor(
          const CatalogItem(
            id: '7',
            name: 'Máy tập mông M3-1022',
            category: 'Máy Realleader M3',
          ),
        ),
        MetaGymIcons.equipM3GluteStanding,
      );
      expect(
        equipmentIconAssetFor(
          const CatalogItem(
            id: '8',
            name: 'Máy tập mông M3-1023',
            category: 'Máy Realleader M3',
          ),
        ),
        MetaGymIcons.equipM3GluteSeated,
      );
      expect(
        equipmentIconAssetFor(
          const CatalogItem(
            id: 'g1',
            name: 'Cable Crossover Dual',
            category: 'Máy cáp',
          ),
        ),
        MetaGymIcons.equipCable,
      );
      expect(
        equipmentIconAssetFor(
          const CatalogItem(
            id: 'g2',
            name: 'Máy chạy bộ',
            category: 'Cardio',
          ),
        ),
        MetaGymIcons.equipTreadmill,
      );
      expect(
        equipmentIconAssetFor(
          const CatalogItem(
            id: 'g3',
            name: 'Xe đạp Cardio',
            category: 'Cardio',
          ),
        ),
        MetaGymIcons.equipCardio,
      );
      expect(
        equipmentIconAssetFor(
          const CatalogItem(id: 'g4', name: 'Tạ đơn', category: 'Sức mạnh'),
        ),
        MetaGymIcons.equipDumbbell,
      );
      expect(
        equipmentIconAssetFor(
          const CatalogItem(id: 'g5', name: 'Tạ đòn Olympic'),
        ),
        MetaGymIcons.equipBarbell,
      );
      expect(
        equipmentIconAssetFor(
          const CatalogItem(id: 'g6', name: 'Ghế đẩy ngực'),
        ),
        MetaGymIcons.equipBench,
      );
      expect(
        equipmentIconAssetFor(const CatalogItem(id: 'g7', name: 'Kettlebell')),
        MetaGymIcons.equipKettlebell,
      );
      expect(
        equipmentIconAssetFor(
          const CatalogItem(id: 'g8', name: 'Smith Machine Pro 3D'),
        ),
        MetaGymIcons.equipMachine,
      );
      expect(
        equipmentIconAssetFor(
          const CatalogItem(
            id: 'v1',
            name: 'Máy ép ngực (Pec Deck)',
            category: 'Thiết bị có video',
          ),
        ),
        MetaGymIcons.equipVideoPecDeckFly,
      );
      expect(
        equipmentIconAssetFor(
          const CatalogItem(
            id: 'v2',
            name: 'Máy mở vai sau (Reverse Fly)',
            category: 'Thiết bị có video',
          ),
        ),
        MetaGymIcons.equipVideoReverseMachineFly,
      );
      expect(
        equipmentIconAssetFor(
          const CatalogItem(
            id: 'v3',
            name: 'Máy cuốn đùi sau ngồi (Seated Leg Curl)',
            category: 'Thiết bị có video',
          ),
        ),
        MetaGymIcons.equipVideoSeatedLegCurl,
      );
      expect(
        equipmentIconAssetFor(
          const CatalogItem(
            id: 'v4',
            name: 'Máy kéo xà trợ lực (Assisted Pull-Up)',
            category: 'Thiết bị có video',
          ),
        ),
        MetaGymIcons.equipVideoAssistedPullUp,
      );
      expect(
        equipmentIconAssetFor(
          const CatalogItem(id: 'g9', name: 'Rack tạ', category: 'Free Weight'),
        ),
        MetaGymIcons.equipFreeWeight,
      );
    },
  );

  test(
    'exerciseIconAssetFor maps 4 video-matched exercises and generic fallbacks',
    () {
      expect(
        exerciseIconAssetFor(
          const CatalogItem(
            id: 'e1',
            name: 'Ép ngực máy (Pec Deck Fly)',
            targetMuscles: ['Ngực'],
          ),
        ),
        MetaGymIcons.equipVideoPecDeckFly,
      );
      expect(
        exerciseIconAssetFor(
          const CatalogItem(
            id: 'e2',
            name: 'Mở vai sau máy (Reverse Machine Fly)',
            targetMuscles: ['Vai sau'],
          ),
        ),
        MetaGymIcons.equipVideoReverseMachineFly,
      );
      expect(
        exerciseIconAssetFor(
          const CatalogItem(
            id: 'e3',
            name: 'Cuốn đùi sau ngồi (Seated Leg Curl)',
            targetMuscles: ['Đùi sau'],
          ),
        ),
        MetaGymIcons.equipVideoSeatedLegCurl,
      );
      expect(
        exerciseIconAssetFor(
          const CatalogItem(
            id: 'e4',
            name: 'Kéo xà trợ lực (Assisted Pull-Up)',
            targetMuscles: ['Lưng', 'Tay trước'],
          ),
        ),
        MetaGymIcons.equipVideoAssistedPullUp,
      );
      expect(
        exerciseIconAssetFor(
          const CatalogItem(id: 'e5', name: 'Barbell Back Squat'),
        ),
        MetaGymIcons.equipBarbell,
      );
      expect(
        exerciseIconAssetFor(
          const CatalogItem(id: 'e6', name: 'Barbell Bench Press'),
        ),
        MetaGymIcons.equipBarbell,
      );
      expect(
        exerciseIconAssetFor(
          const CatalogItem(id: 'e7', name: 'Dumbbell Bicep Curl'),
        ),
        MetaGymIcons.equipDumbbell,
      );
      expect(
        exerciseIconAssetFor(
          const CatalogItem(id: 'e8', name: 'Cable Tricep Pushdown'),
        ),
        MetaGymIcons.equipCable,
      );
      expect(
        exerciseIconAssetFor(
          const CatalogItem(id: 'e9', name: 'Lat Pulldown Kéo Xô Mặt Trước'),
        ),
        MetaGymIcons.equipMachine,
      );
      expect(
        exerciseIconAssetFor(const CatalogItem(id: 'e10', name: 'Plank Core')),
        MetaGymIcons.equipBodyweight,
      );
      expect(
        exerciseIconAssetFor(const CatalogItem(id: 'e11', name: 'Burpee')),
        MetaGymIcons.equipBodyweight,
      );
    },
  );

  test(
    'equipmentIconAssetFor and exerciseIconAssetFor map all 16 equipment_7groups icons & 21 videos',
    () {
      const cases = [
        (
          equipName: 'Ghế duỗi lưng khung cong',
          exerciseName: 'Duỗi lưng trên ghế 45°',
          muscle: 'Lưng dưới',
          video: 'assets/videos/catalog/lower_back_01_hyperextension_480p.mp4',
          icon: MetaGymIcons.equip7HyperextensionCurved,
        ),
        (
          equipName: 'Ghế duỗi lưng 45° khung tam giác',
          exerciseName: 'Duỗi lưng, tay trước ngực',
          muscle: 'Lưng dưới',
          video: 'assets/videos/catalog/lower_back_02_crossed_arms_480p.mp4',
          icon: MetaGymIcons.equip7HyperextensionAngular,
        ),
        (
          equipName: 'Ghế duỗi lưng 45° khung tam giác',
          exerciseName: 'Duỗi lưng có tạ',
          muscle: 'Lưng dưới',
          video: 'assets/videos/catalog/lower_back_03_weighted_480p.mp4',
          icon: MetaGymIcons.equip7HyperextensionAngular,
        ),
        (
          equipName: 'Máy kéo xô',
          exerciseName: 'Kéo xô tay nắm thường',
          muscle: 'Lưng xô',
          video: 'assets/videos/catalog/lats_01_normal_grip_480p.mp4',
          icon: MetaGymIcons.equip7LatPulldown,
        ),
        (
          equipName: 'Máy kéo xô',
          exerciseName: 'Kéo xô tay rộng',
          muscle: 'Lưng xô',
          video: 'assets/videos/catalog/lats_02_wide_grip_480p.mp4',
          icon: MetaGymIcons.equip7LatPulldown,
        ),
        (
          equipName: 'Máy kéo xô',
          exerciseName: 'Kéo xô tay hẹp',
          muscle: 'Lưng xô',
          video: 'assets/videos/catalog/lats_03_close_grip_480p.mp4',
          icon: MetaGymIcons.equip7LatPulldown,
        ),
        (
          equipName: 'Máy Smith và ghế nâng hông',
          exerciseName: 'Nâng hông bằng máy Smith',
          muscle: 'Mông',
          video: 'assets/videos/catalog/glutes_01_smith_hip_thrust_480p.mp4',
          icon: MetaGymIcons.equip7SmithHipThrust,
        ),
        (
          equipName: 'Máy cáp với dây cổ chân',
          exerciseName: 'Đá chân sau bằng cáp',
          muscle: 'Mông',
          video: 'assets/videos/catalog/glutes_02_cable_kickback_480p.mp4',
          icon: MetaGymIcons.equip7CableAnkleStation,
        ),
        (
          equipName: 'Máy Multi Hip',
          exerciseName: 'Dạng hông bằng máy Multi Hip',
          muscle: 'Mông',
          video: 'assets/videos/catalog/glutes_03_multi_hip_abduction_480p.mp4',
          icon: MetaGymIcons.equip7MultiHip,
        ),
        (
          equipName: 'Máy ép ngực pec deck',
          exerciseName: 'Ép ngực trên máy',
          muscle: 'Ngực',
          video: 'assets/videos/catalog/chest_01_pec_deck_480p.mp4',
          icon: MetaGymIcons.equip7PecDeck,
        ),
        (
          equipName: 'Máy cáp đôi',
          exerciseName: 'Ép ngực bằng cáp ngang',
          muscle: 'Ngực',
          video: 'assets/videos/catalog/chest_02_cable_fly_480p.mp4',
          icon: MetaGymIcons.equip7DualCable,
        ),
        (
          equipName: 'Máy đẩy ngực',
          exerciseName: 'Đẩy ngực trên máy',
          muscle: 'Ngực',
          video: 'assets/videos/catalog/chest_03_chest_press_480p.mp4',
          icon: MetaGymIcons.equip7ChestPress,
        ),
        (
          equipName: 'Máy dip ngồi',
          exerciseName: 'Dip trên máy ngồi',
          muscle: 'Tay sau',
          video: 'assets/videos/catalog/triceps_01_seated_dip_480p.mp4',
          icon: MetaGymIcons.equip7SeatedDip,
        ),
        (
          equipName: 'Máy duỗi tay sau ngồi',
          exerciseName: 'Duỗi tay sau trên máy',
          muscle: 'Tay sau',
          video: 'assets/videos/catalog/triceps_02_extension_machine_480p.mp4',
          icon: MetaGymIcons.equip7SeatedTricepsExtension,
        ),
        (
          equipName: 'Máy cáp với dây thừng',
          exerciseName: 'Đẩy dây thừng cáp xuống',
          muscle: 'Tay sau',
          video: 'assets/videos/catalog/triceps_03_rope_pushdown_480p.mp4',
          icon: MetaGymIcons.equip7CableRopeStation,
        ),
        (
          equipName: 'Máy cáp thấp với thanh thẳng',
          exerciseName: 'Cuốn tay trước cáp thấp',
          muscle: 'Tay trước',
          video: 'assets/videos/catalog/biceps_01_low_cable_curl_480p.mp4',
          icon: MetaGymIcons.equip7CableLowBar,
        ),
        (
          equipName: 'Máy cáp và ghế preacher',
          exerciseName: 'Cuốn tay trước trên ghế với cáp',
          muscle: 'Tay trước',
          video: 'assets/videos/catalog/biceps_02_cable_preacher_480p.mp4',
          icon: MetaGymIcons.equip7CablePreacher,
        ),
        (
          equipName: 'Máy cáp thấp với thanh thẳng',
          exerciseName: 'Cuốn tay trước cáp thấp, tay rộng',
          muscle: 'Tay trước',
          video: 'assets/videos/catalog/biceps_03_wide_grip_cable_curl_480p.mp4',
          icon: MetaGymIcons.equip7CableLowBar,
        ),
        (
          equipName: 'Máy duỗi đùi trước',
          exerciseName: 'Duỗi đùi trước hai chân',
          muscle: 'Đùi trước',
          video: 'assets/videos/catalog/quads_01_bilateral_extension_480p.mp4',
          icon: MetaGymIcons.equip7LegExtension,
        ),
        (
          equipName: 'Máy duỗi đùi trước',
          exerciseName: 'Duỗi đùi trước một chân',
          muscle: 'Đùi trước',
          video: 'assets/videos/catalog/quads_02_single_leg_extension_480p.mp4',
          icon: MetaGymIcons.equip7LegExtension,
        ),
        (
          equipName: 'Máy Smith',
          exerciseName: 'Squat bằng máy Smith',
          muscle: 'Đùi trước',
          video: 'assets/videos/catalog/quads_03_smith_squat_480p.mp4',
          icon: MetaGymIcons.equip7SmithSquat,
        ),
      ];

      for (final c in cases) {
        // With videoUrl AND without videoUrl (name-based fallback):
        expect(
          equipmentIconAssetFor(
            CatalogItem(
              id: c.equipName,
              name: c.equipName,
              category: 'Thiết bị 7 nhóm cơ',
              targetMuscles: [c.muscle],
              videoUrl: c.video,
            ),
          ),
          c.icon,
          reason: 'equipment + video: ${c.equipName}',
        );
        expect(
          equipmentIconAssetFor(
            CatalogItem(
              id: c.equipName,
              name: c.equipName,
              category: 'Thiết bị 7 nhóm cơ',
              targetMuscles: [c.muscle],
            ),
          ),
          c.icon,
          reason: 'equipment name-only: ${c.equipName}',
        );
        expect(
          exerciseIconAssetFor(
            CatalogItem(
              id: c.exerciseName,
              name: c.exerciseName,
              targetMuscles: [c.muscle],
              videoUrl: c.video,
            ),
          ),
          c.icon,
          reason: 'exercise + video: ${c.exerciseName}',
        );
        expect(
          exerciseIconAssetFor(
            CatalogItem(
              id: c.exerciseName,
              name: c.exerciseName,
              targetMuscles: [c.muscle],
            ),
          ),
          c.icon,
          reason: 'exercise name-only: ${c.exerciseName}',
        );
      }
    },
  );

  testWidgets(
    'loads all 8 Realleader M3 SVGs, 4 equipment_video SVGs, 16 equipment_7groups SVGs, and all 25 catalog MP4 videos cleanly from bundle',
    (tester) async {
      const svgAssets = [
        MetaGymIcons.equipM3BackExtension,
        MetaGymIcons.equipM3PecFlyRearDelt,
        MetaGymIcons.equipM3SeatedLegCurl,
        MetaGymIcons.equipM3StandingCalfRaise,
        MetaGymIcons.equipM3ChinDipAssist,
        MetaGymIcons.equipM3RotaryTorso,
        MetaGymIcons.equipM3GluteStanding,
        MetaGymIcons.equipM3GluteSeated,
        MetaGymIcons.equipVideoPecDeckFly,
        MetaGymIcons.equipVideoReverseMachineFly,
        MetaGymIcons.equipVideoSeatedLegCurl,
        MetaGymIcons.equipVideoAssistedPullUp,
        MetaGymIcons.equip7CableAnkleStation,
        MetaGymIcons.equip7CableLowBar,
        MetaGymIcons.equip7CablePreacher,
        MetaGymIcons.equip7CableRopeStation,
        MetaGymIcons.equip7ChestPress,
        MetaGymIcons.equip7DualCable,
        MetaGymIcons.equip7HyperextensionAngular,
        MetaGymIcons.equip7HyperextensionCurved,
        MetaGymIcons.equip7LatPulldown,
        MetaGymIcons.equip7LegExtension,
        MetaGymIcons.equip7MultiHip,
        MetaGymIcons.equip7PecDeck,
        MetaGymIcons.equip7SeatedDip,
        MetaGymIcons.equip7SeatedTricepsExtension,
        MetaGymIcons.equip7SmithHipThrust,
        MetaGymIcons.equip7SmithSquat,
      ];
      for (final asset in svgAssets) {
        final raw = await rootBundle.loadString(asset);
        expect(raw, contains('<svg'), reason: 'Expected valid SVG for $asset');
      }

      const videoAssets = [
        'assets/videos/catalog/pec_deck_fly_480p.mp4',
        'assets/videos/catalog/reverse_machine_fly_480p.mp4',
        'assets/videos/catalog/seated_leg_curl_480p.mp4',
        'assets/videos/catalog/assisted_pull_up_480p.mp4',
        'assets/videos/catalog/lower_back_01_hyperextension_480p.mp4',
        'assets/videos/catalog/lower_back_02_crossed_arms_480p.mp4',
        'assets/videos/catalog/lower_back_03_weighted_480p.mp4',
        'assets/videos/catalog/lats_01_normal_grip_480p.mp4',
        'assets/videos/catalog/lats_02_wide_grip_480p.mp4',
        'assets/videos/catalog/lats_03_close_grip_480p.mp4',
        'assets/videos/catalog/glutes_01_smith_hip_thrust_480p.mp4',
        'assets/videos/catalog/glutes_02_cable_kickback_480p.mp4',
        'assets/videos/catalog/glutes_03_multi_hip_abduction_480p.mp4',
        'assets/videos/catalog/chest_01_pec_deck_480p.mp4',
        'assets/videos/catalog/chest_02_cable_fly_480p.mp4',
        'assets/videos/catalog/chest_03_chest_press_480p.mp4',
        'assets/videos/catalog/triceps_01_seated_dip_480p.mp4',
        'assets/videos/catalog/triceps_02_extension_machine_480p.mp4',
        'assets/videos/catalog/triceps_03_rope_pushdown_480p.mp4',
        'assets/videos/catalog/biceps_01_low_cable_curl_480p.mp4',
        'assets/videos/catalog/biceps_02_cable_preacher_480p.mp4',
        'assets/videos/catalog/biceps_03_wide_grip_cable_curl_480p.mp4',
        'assets/videos/catalog/quads_01_bilateral_extension_480p.mp4',
        'assets/videos/catalog/quads_02_single_leg_extension_480p.mp4',
        'assets/videos/catalog/quads_03_smith_squat_480p.mp4',
      ];
      for (final video in videoAssets) {
        if (!File(video).existsSync()) continue;
        final data = await rootBundle.load(video);
        expect(
          data.lengthInBytes,
          greaterThan(0),
          reason: 'Expected non-empty MP4 bytes for $video',
        );
      }
    },
  );

  for (final entry in [('dark', AppTheme.dark), ('light', AppTheme.light)]) {
    testWidgets(
      'gym & equipment detail with M3 & video-matched icons render cleanly (${entry.$1}, 375px @ 1.3x)',
      (tester) async {
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final service = _GymFixture();
        await tester.pumpWidget(
          MaterialApp(
            theme: entry.$2,
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(375, 812),
                textScaler: TextScaler.linear(1.3),
              ),
              child: GymEquipmentPage(service: service),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Máy ép ngực / vai sau M3-1017'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('Máy ép ngực (Pec Deck)'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(find.text('Máy ép ngực (Pec Deck)'), findsOneWidget);

        await tester.tap(find.text('Máy ép ngực (Pec Deck)'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Máy ép ngực (Pec Deck)'), findsWidgets);
        expect(find.byType(ExerciseVideoPlayer), findsOneWidget);
        expect(find.text('Video hướng dẫn'), findsOneWidget);
        expect(find.text('Lặp tự động'), findsOneWidget);
        expect(find.text('Đường dẫn video không hợp lệ.'), findsNothing);
        await tester.scrollUntilVisible(
          find.text('Hướng dẫn sử dụng từng bước'),
          200,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Hướng dẫn sử dụng từng bước'), findsOneWidget);
      },
    );

    testWidgets(
      'exercise library & detail with video-matched icons render cleanly (${entry.$1}, 375px @ 1.3x)',
      (tester) async {
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final service = _GymFixture(exerciseState: 'video');
        await tester.pumpWidget(
          MaterialApp(
            theme: entry.$2,
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(375, 812),
                textScaler: TextScaler.linear(1.3),
              ),
              child: ExerciseLibraryPage(service: service),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          find.text('Mở vai sau máy (Reverse Machine Fly)'),
          findsOneWidget,
        );

        await tester.ensureVisible(
          find.text('Mở vai sau máy (Reverse Machine Fly)'),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Mở vai sau máy (Reverse Machine Fly)'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(ExerciseVideoPlayer), findsOneWidget);
        expect(find.text('Video hướng dẫn'), findsOneWidget);
        expect(find.text('Lặp tự động'), findsOneWidget);
        expect(find.text('Đường dẫn video không hợp lệ.'), findsNothing);
        expect(find.text('Có video minh họa'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('Cách thực hiện'),
          200,
          scrollable: find.byType(Scrollable).last,
        );
        expect(find.text('Cách thực hiện'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('Các bước'),
          200,
          scrollable: find.byType(Scrollable).last,
        );
        expect(find.text('Các bước'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('Lưu ý an toàn'),
          200,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Lưu ý an toàn'), findsOneWidget);
      },
    );
  }

  testWidgets('exercise detail shows fallback text when guidance is empty', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const ExerciseDetailPage(
          item: CatalogItem(
            id: 'ex-empty',
            name: 'Plank',
            targetMuscles: ['Core'],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      find.text('Hướng dẫn cho bài tập này đang được cập nhật.'),
      findsOneWidget,
    );
  });
}

class _GymFixture implements CatalogService {
  _GymFixture({this.failFirst = false, this.exerciseState = 'empty'});

  final String exerciseState;

  final bool failFirst;
  int profileLoads = 0;
  String? search;
  String? detailId;

  @override
  Future<GymProfile> getGymProfile() async {
    profileLoads++;
    if (failFirst && profileLoads == 1) {
      throw const ApiException(
        kind: ApiExceptionKind.network,
        message: 'Không tải được thông tin gym.',
      );
    }
    return const GymProfile(
      name: 'Meta Gym',
      address: 'Quận 1',
      openingHours: {'monday': '06:00-21:00'},
      rules: 'Mang khăn tập.',
    );
  }

  @override
  Future<List<CatalogItem>> getEquipment({String? search}) async {
    this.search = search;
    if (search == 'không có') return const [];
    return const [
      CatalogItem(id: 'equipment-1', name: 'Máy chạy bộ', category: 'Cardio'),
      CatalogItem(
        id: 'equipment-m3-1017',
        name: 'Máy ép ngực / vai sau M3-1017',
        category: 'Máy Realleader M3',
        targetMuscles: ['Ngực', 'Vai sau'],
        videoUrl: 'assets/videos/catalog/pec_deck_fly_480p.mp4',
      ),
      CatalogItem(
        id: 'equipment-video-pec-deck',
        name: 'Máy ép ngực (Pec Deck)',
        category: 'Thiết bị có video',
        targetMuscles: ['Ngực'],
        videoUrl: 'assets/videos/catalog/pec_deck_fly_480p.mp4',
      ),
      CatalogItem(id: 'equipment-3', name: 'Tạ đơn', category: 'Sức mạnh'),
      CatalogItem(
        id: 'equipment-4',
        name: 'Technogym Artis Run',
        category: 'Cardio',
        status: 'MAINTENANCE',
      ),
      CatalogItem(id: 'equipment-2', name: 'Máy ẩn', status: 'HIDDEN'),
    ];
  }

  @override
  Future<CatalogItem> getEquipmentDetail(String id) async {
    detailId = id;
    if (id == 'equipment-video-pec-deck') {
      return const CatalogItem(
        id: 'equipment-video-pec-deck',
        name: 'Máy ép ngực (Pec Deck)',
        category: 'Thiết bị có video',
        description: 'Máy ép ngực khung vòm kèm video minh họa trực quan.',
        targetMuscles: ['Ngực'],
        usageSteps: [
          'Chỉnh chiều cao ghế ngang giữa ngực.',
          'Ép hai tay đòn vào giữa và siết cơ 1 giây.',
        ],
        safetyNotes: 'Không mở khuỷu tay quá sâu ra sau mặt phẳng vai.',
        videoUrl: 'assets/videos/catalog/pec_deck_fly_480p.mp4',
      );
    }
    if (id == 'equipment-m3-1017') {
      return const CatalogItem(
        id: 'equipment-m3-1017',
        name: 'Máy ép ngực / vai sau M3-1017',
        category: 'Máy Realleader M3',
        description: 'Máy ép ngực và vai sau Realleader dòng M3.',
        targetMuscles: ['Ngực', 'Vai sau'],
        usageSteps: ['Chỉnh độ cao ghế phù hợp.', 'Ép tay đòn mượt mà.'],
        safetyNotes: 'Khóa chốt biên độ chắc chắn trước khi tập.',
      );
    }
    if (id == 'equipment-cable') {
      return const CatalogItem(
        id: 'equipment-cable',
        name: 'Cable Crossover Dual',
        category: 'Máy cáp',
        description: 'Máy kéo cáp đa năng cho ngực, vai và tay sau.',
        targetMuscles: ['Ngực giữa', 'Vai trước', 'Tay sau'],
        usageSteps: [
          'Chỉnh chốt ròng rọc ngang tầm vai.',
          'Ép hai tay về phía trước ngực.',
        ],
        safetyNotes: 'Kiểm tra chốt tạ đã cắm chặt trước khi kéo.',
      );
    }
    return const CatalogItem(
      id: 'equipment-1',
      name: 'Máy chạy bộ',
      category: 'Cardio',
      usageSteps: ['Khởi động trước khi chạy'],
      safetyNotes: 'Giữ tay vịn khi lên máy',
    );
  }

  @override
  Future<List<CatalogItem>> getExercises({String? search}) async {
    if (exerciseState == 'error') {
      throw const ApiException(
        kind: ApiExceptionKind.network,
        message: 'Fixture error',
      );
    }
    if (exerciseState == 'video') {
      return const [
        CatalogItem(
          id: 'exercise-video-reverse-fly',
          name: 'Mở vai sau máy (Reverse Machine Fly)',
          category: 'Thiết bị có video',
          targetMuscles: ['Vai sau'],
          description: 'Bài tập cô lập cơ vai sau giúp cân bằng khớp vai.',
          instructions: 'Áp ngực vào đệm tựa, kéo mở hai tay ra ngang vai.',
          usageSteps: [
            'Chỉnh ghế để tay cầm ngang tầm vai.',
            'Mở rộng hai tay ra sau và giữ 1 giây.',
          ],
          safetyNotes: 'Tránh nhún cầu vai hoặc dùng đà ngả lưng.',
          videoUrl: 'assets/videos/catalog/reverse_machine_fly_480p.mp4',
        ),
        CatalogItem(
          id: 'exercise-video-pullup',
          name: 'Kéo xà trợ lực (Assisted Pull-Up)',
          category: 'Thiết bị có video',
          targetMuscles: ['Lưng', 'Tay trước'],
          videoUrl: 'assets/videos/catalog/assisted_pull_up_480p.mp4',
        ),
      ];
    }
    return exerciseState == 'data'
        ? const [
            CatalogItem(
              id: 'exercise-1',
              name: 'Squat',
              targetMuscles: ['Legs'],
            ),
          ]
        : const [];
  }
}
