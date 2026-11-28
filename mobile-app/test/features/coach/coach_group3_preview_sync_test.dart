import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_gym_app/core/config/api_config.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_icon.dart';
import 'package:meta_gym_app/features/coaching/domain/coach_member_models.dart';
import 'package:meta_gym_app/features/training/data/coach_training_service.dart';
import 'package:meta_gym_app/features/training/presentation/coach_nutrition_page.dart';
import 'package:meta_gym_app/features/training/presentation/coach_plan_detail_page.dart';
import 'package:meta_gym_app/features/training/presentation/coach_plan_form_page.dart';
import 'package:meta_gym_app/features/training/presentation/coach_training_page.dart';
import 'package:meta_gym_app/features/training/presentation/meal_plans_page.dart';
import 'package:provider/provider.dart';

void main() {
  Widget wrapScreen(
    Widget child, {
    required ThemeData theme,
    double textScale = 1.3,
    bool disableAnimations = false,
  }) {
    return MaterialApp(
      theme: theme,
      builder: (context, inner) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          disableAnimations: disableAnimations,
        ),
        child: inner!,
      ),
      home: child,
    );
  }

  Future<void> pumpViewportMatrix(
    WidgetTester tester,
    Widget Function() build, {
    required String label,
    FutureOr<void> Function(bool isDark)? verifyPerViewport,
  }) async {
    const viewports = <Size>[
      Size(375, 812),
      Size(768, 1024),
      Size(812, 375),
    ];
    for (final size in viewports) {
      for (final (theme, isDark, disableAnim) in [
        (MetaGymTheme.dark, true, false),
        (MetaGymTheme.light, false, true),
      ]) {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();

        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final errorDetails = <FlutterErrorDetails>[];
        final prevOnError = FlutterError.onError;
        FlutterError.onError = (details) {
          errorDetails.add(details);
          prevOnError?.call(details);
        };
        try {
          await tester.pumpWidget(
            KeyedSubtree(
              key: ValueKey('$label-${size.width}x${size.height}-$isDark'),
              child: wrapScreen(
                build(),
                theme: theme,
                textScale: 1.3,
                disableAnimations: disableAnim,
              ),
            ),
          );
          await tester.pumpAndSettle();

          final firstError = tester.takeException();
          if (firstError != null) {
            for (final d in errorDetails) {
              debugPrint('DETAILS ($label): $d');
            }
          }
          expect(
            firstError,
            isNull,
            reason: '$label threw at ${size.width}x${size.height} dark=$isDark',
          );
          expect(find.byType(MetaGymBackground), findsWidgets);
          expect(find.byType(MetaGymIcon), findsWidgets);
          await verifyPerViewport?.call(isDark);
          final postError = tester.takeException();
          if (postError != null) {
            for (final d in errorDetails) {
              debugPrint('POST DETAILS ($label): $d');
            }
          }
          expect(
            postError,
            isNull,
            reason:
                '$label threw after scroll/tap at ${size.width}x${size.height} dark=$isDark',
          );
        } finally {
          FlutterError.onError = prevOnError;
        }
      }
    }
  }

  Finder verticalScrollable() => find.byWidgetPredicate(
    (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
  );

  group('Coach Group 3 & 4 (3.1 - 3.4 & 4.1 - 4.2) Preview Sync & Dark/Light Matrix', () {
    testWidgets(
      '3.1 CoachTrainingPage is Training-only (no Nutrition overlap) across Dark/Light & search/filter',
      (tester) async {
        final adapter = _Group3CoachApiAdapter();
        final api = ApiClient.withAdapter(
          config: ApiConfig.fromValues(environment: 'local'),
          adapter: adapter,
        );

        await pumpViewportMatrix(
          tester,
          () => Provider<ApiClient>.value(
            value: api,
            child: CoachTrainingPage(service: CoachTrainingApi(api)),
          ),
          label: '3.1 CoachTrainingPage',
          verifyPerViewport: (isDark) async {
            expect(find.text('GIÁO ÁN TẬP LUYỆN'), findsOneWidget);
            expect(find.text('Chọn hội viên tập luyện'), findsOneWidget);
            expect(find.text('Tổng quan giáo án tập'), findsOneWidget);
            expect(find.text('Chưa có lịch'), findsOneWidget);
            expect(find.text('Bài tập giao'), findsOneWidget);
            expect(find.text('GIÁO ÁN & THỰC ĐƠN'), findsNothing);
            await tester.scrollUntilVisible(
              find.text('Nguyễn Minh Quân'),
              180,
              scrollable: verticalScrollable().first,
            );
            expect(find.text('Nguyễn Minh Quân'), findsOneWidget);
            expect(find.byKey(const Key('hub-open-meal-m-1')), findsNothing);
          },
        );

        // Search, Filter & Navigation to 3.2 at 390x844
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await tester.pumpWidget(
          Provider<ApiClient>.value(
            value: api,
            child: wrapScreen(
              CoachTrainingPage(service: CoachTrainingApi(api)),
              theme: MetaGymTheme.dark,
              textScale: 1.0,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Filter: Chưa có giáo án (Đỗ Khánh Linh)
        await tester.tap(find.byKey(const Key('hub-filter-pending')));
        await tester.pumpAndSettle();
        expect(find.text('Đỗ Khánh Linh'), findsOneWidget);
        expect(find.text('Nguyễn Minh Quân'), findsNothing);

        // Filter back to All + search Quân
        await tester.tap(find.byKey(const Key('hub-filter-all')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('hub-member-search')),
          'Quân',
        );
        await tester.pumpAndSettle();
        expect(find.text('Nguyễn Minh Quân'), findsOneWidget);
        expect(find.text('Đỗ Khánh Linh'), findsNothing);

        // Open 3.2 Giáo trình tập
        await tester.tap(find.byKey(const Key('hub-open-training-m-1')));
        await tester.pumpAndSettle();
        expect(find.byType(CoachMemberPlansPage), findsOneWidget);
      },
    );

    testWidgets(
      '4.1 CoachNutritionPage(structured: true) is Nutrition-only across Dark/Light & opens 4.2 MealPlansPage',
      (tester) async {
        final adapter = _Group3CoachApiAdapter();
        final api = ApiClient.withAdapter(
          config: ApiConfig.fromValues(environment: 'local'),
          adapter: adapter,
        );

        await pumpViewportMatrix(
          tester,
          () => Provider<ApiClient>.value(
            value: api,
            child: const CoachNutritionPage(structured: true),
          ),
          label: '4.1 CoachNutritionPage',
          verifyPerViewport: (isDark) async {
            expect(find.text('DINH DƯỠNG HUẤN LUYỆN'), findsOneWidget);
            expect(find.text('Dinh dưỡng học viên'), findsOneWidget);
            expect(find.text('Tổng quan dinh dưỡng'), findsOneWidget);
            expect(find.text('Có thực đơn'), findsOneWidget);
            expect(find.text('TB kcal/ngày'), findsOneWidget);
            expect(find.text('GIÁO ÁN TẬP LUYỆN'), findsNothing);
            await tester.scrollUntilVisible(
              find.text('Nguyễn Minh Quân'),
              180,
              scrollable: verticalScrollable().first,
            );
            expect(find.text('Nguyễn Minh Quân'), findsOneWidget);
          },
        );

        // Search, Filter & Navigation to 4.2 at 390x844
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await tester.pumpWidget(
          Provider<ApiClient>.value(
            value: api,
            child: wrapScreen(
              const CoachNutritionPage(structured: true),
              theme: MetaGymTheme.light,
              textScale: 1.0,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('nutrition-filter-no-meal')));
        await tester.pumpAndSettle();
        expect(find.text('Đỗ Khánh Linh'), findsOneWidget);
        expect(find.text('Nguyễn Minh Quân'), findsNothing);

        await tester.tap(find.byKey(const Key('nutrition-filter-all')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('nutrition-member-search')),
          'Quân',
        );
        await tester.pumpAndSettle();
        expect(find.text('Nguyễn Minh Quân'), findsOneWidget);

        await tester.tap(find.byKey(const Key('nutrition-open-meal-m-1')));
        await tester.pumpAndSettle();
        expect(find.byType(MealPlansPage), findsOneWidget);
        expect(find.text('Thiết kế thực đơn'), findsOneWidget);
        expect(find.text('Nguyên tắc & Ghi chú ăn uống'), findsOneWidget);
      },
    );

    testWidgets(
      '3.2 CoachMemberPlansPage renders Hero, filters, plan cards & opens 3.3 across Dark/Light',
      (tester) async {
        final adapter = _Group3CoachApiAdapter();
        final api = ApiClient.withAdapter(
          config: ApiConfig.fromValues(environment: 'local'),
          adapter: adapter,
        );
        final trainingApi = CoachTrainingApi(api);
        const member = CoachMemberSummary(
          relationshipId: 'rel-1',
          memberId: 'm-1',
          memberFullName: 'Nguyễn Minh Quân',
          status: 'ACTIVE',
        );

        await pumpViewportMatrix(
          tester,
          () => CoachMemberPlansPage(member: member, service: trainingApi),
          label: '3.2 CoachMemberPlansPage',
          verifyPerViewport: (isDark) async {
            expect(find.text('GIÁO ÁN TẬP LUYỆN'), findsOneWidget);
            expect(find.text('Nguyễn Minh Quân'), findsOneWidget);
            expect(
              find.text('Cập nhật giáo trình hiện tại'),
              findsOneWidget,
            );
            await tester.scrollUntilVisible(
              find.text('Giáo trình bài tập'),
              160,
              scrollable: verticalScrollable().first,
            );
            expect(find.text('Giáo trình bài tập'), findsOneWidget);
            expect(
              find.text('Upper / Lower Split — Hypertrophy 4 tuần'),
              findsWidgets,
            );
            await tester.scrollUntilVisible(
              find.text('Làm quen kỹ thuật cơ bản (Nền tảng)'),
              160,
              scrollable: verticalScrollable().first,
            );
            expect(
              find.text('Làm quen kỹ thuật cơ bản (Nền tảng)'),
              findsOneWidget,
            );
          },
        );
      },
    );

    testWidgets(
      '3.3 CoachPlanDetailPage renders KPI hero, switches day tabs & opens edit form across Dark/Light',
      (tester) async {
        final adapter = _Group3CoachApiAdapter();
        final api = ApiClient.withAdapter(
          config: ApiConfig.fromValues(environment: 'local'),
          adapter: adapter,
        );
        final trainingApi = CoachTrainingApi(api);

        await pumpViewportMatrix(
          tester,
          () => CoachPlanDetailPage(
            id: 'plan-active-1',
            service: trainingApi,
            memberId: 'm-1',
            memberName: 'Nguyễn Minh Quân',
          ),
          label: '3.3 CoachPlanDetailPage',
          verifyPerViewport: (isDark) async {
            expect(find.text('Chi tiết giáo trình'), findsOneWidget);
            expect(find.text('Đã công bố · Phiên bản 3'), findsOneWidget);
            expect(find.text('1. Incline Dumbbell Press'), findsOneWidget);

            // Switch to Day 2
            final day2Tab = find.byKey(const Key('plan-detail-day-tab-1'));
            await tester.ensureVisible(day2Tab);
            await tester.pumpAndSettle();
            await tester.tap(day2Tab);
            await tester.pumpAndSettle();
            expect(find.text('1. Wide-Grip Lat Pulldown'), findsOneWidget);
          },
        );
      },
    );

    testWidgets(
      '3.4 CoachPlanFormPage supports catalog library picker modal, add day & Dark/Light rendering',
      (tester) async {
        final adapter = _Group3CoachApiAdapter();
        final api = ApiClient.withAdapter(
          config: ApiConfig.fromValues(environment: 'local'),
          adapter: adapter,
        );
        final trainingApi = CoachTrainingApi(api);
        final plan = (await tester.runAsync(
          () => trainingApi.getPlan('plan-active-1'),
        ))!;

        await pumpViewportMatrix(
          tester,
          () => CoachPlanFormPage(
            memberId: 'm-1',
            memberName: 'Nguyễn Minh Quân',
            service: trainingApi,
            plan: plan,
          ),
          label: '3.4 CoachPlanFormPage',
          verifyPerViewport: (isDark) async {
            expect(find.text('Cập nhật giáo trình tập'), findsOneWidget);
            expect(find.text('Thông tin giáo trình'), findsOneWidget);
            final formScroll = find
                .descendant(
                  of: find.byKey(const Key('coach-plan-form-list')),
                  matching: find.byType(Scrollable),
                )
                .first;
            await tester.scrollUntilVisible(
              find.text('Cấu trúc ngày & bài tập'),
              180,
              scrollable: formScroll,
            );
            expect(find.text('Cấu trúc ngày & bài tập'), findsOneWidget);
            await tester.scrollUntilVisible(
              find.text('Lưu giáo trình'),
              220,
              scrollable: formScroll,
            );
            expect(find.text('Lưu giáo trình'), findsOneWidget);
          },
        );

        // Test Catalog Picker Bottom Sheet at 390x844
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await tester.pumpWidget(
          wrapScreen(
            CoachPlanFormPage(
              memberId: 'm-1',
              memberName: 'Nguyễn Minh Quân',
              service: trainingApi,
              plan: plan,
            ),
            theme: MetaGymTheme.dark,
            textScale: 1.0,
          ),
        );
        await tester.pumpAndSettle();

        final formScroll = find
            .descendant(
              of: find.byKey(const Key('coach-plan-form-list')),
              matching: find.byType(Scrollable),
            )
            .first;
        final pickerBtn = find.byKey(const Key('plan-open-catalog-picker-0'));
        await tester.scrollUntilVisible(
          pickerBtn,
          200,
          scrollable: formScroll,
        );
        await tester.ensureVisible(pickerBtn);
        await tester.pumpAndSettle();
        await tester.tap(pickerBtn);
        await tester.pumpAndSettle();

        expect(find.text('Thêm bài tập · Ngày 1'), findsOneWidget);
        await tester.tap(find.text('Cable Chest Fly').last);
        await tester.pumpAndSettle();

        expect(find.text('Cable Chest Fly'), findsWidgets);

        final restField = find.byKey(const Key('exercise-rest-0-0'));
        await tester.scrollUntilVisible(
          restField,
          160,
          scrollable: formScroll,
        );
        await tester.enterText(restField, '75');
        await tester.enterText(
          find.byKey(const Key('exercise-weight-0-0')),
          '24 kg/tay',
        );

        await tester.scrollUntilVisible(
          find.text('Lưu giáo trình'),
          200,
          scrollable: formScroll,
        );
        await tester.ensureVisible(find.text('Lưu giáo trình'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Lưu giáo trình'));
        await tester.pumpAndSettle();
        expect(adapter.savedTrainingCurrentCount, 1);
        expect(adapter.lastTrainingPayload?['startDate'], '2026-11-10');
        expect(adapter.lastTrainingPayload?['endDate'], '2026-12-08');
        final savedDays = adapter.lastTrainingPayload?['days'] as List;
        final savedFirstEx =
            (savedDays.first as Map)['exercises'].first as Map;
        expect(savedFirstEx['restSeconds'], 75);
        expect(savedFirstEx['weightGuidance'], '24 kg/tay');
      },
    );

    testWidgets(
      '4.2 MealPlansPage renders Coach & Member views with Nguyên tắc ăn uống across Dark/Light 375/768/landscape',
      (tester) async {
        await pumpViewportMatrix(
          tester,
          () => const MealPlansPage(
            memberId: 'm-1',
            memberName: 'Nguyễn Minh Quân',
            editable: true,
            previewMode: true,
          ),
          label: '4.2 MealPlansPage Coach',
          verifyPerViewport: (isDark) async {
            expect(find.text('Thiết kế thực đơn'), findsOneWidget);
            expect(find.text('Chế độ Coach'), findsOneWidget);
            expect(find.text('TB kcal/ngày'), findsOneWidget);
            expect(find.text('Sáng · Trưa · Tối'), findsOneWidget);
            expect(find.text('Ngày T2 – CN'), findsOneWidget);
            await tester.scrollUntilVisible(
              find.text('Nguyên tắc & Ghi chú ăn uống'),
              160,
              scrollable: verticalScrollable().first,
            );
            expect(find.text('Nguyên tắc & Ghi chú ăn uống'), findsOneWidget);
          },
        );

        await pumpViewportMatrix(
          tester,
          () => const MealPlansPage(
            editable: false,
            previewMode: true,
          ),
          label: '4.2 MealPlansPage Member',
          verifyPerViewport: (isDark) async {
            expect(find.text('Thực đơn 7 ngày'), findsOneWidget);
            expect(find.text('Đang áp dụng'), findsOneWidget);
            await tester.scrollUntilVisible(
              find.text('Nguyên tắc & Ghi chú ăn uống'),
              160,
              scrollable: verticalScrollable().first,
            );
            expect(find.text('Nguyên tắc & Ghi chú ăn uống'), findsOneWidget);
          },
        );

        // Verify live backend save of 'notes' & reload via adapter
        final adapter = _Group3CoachApiAdapter();
        final api = ApiClient.withAdapter(
          config: ApiConfig.fromValues(environment: 'local'),
          adapter: adapter,
        );
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await tester.pumpWidget(
          wrapScreen(
            MealPlansPage(
              memberId: 'm-1',
              memberName: 'Nguyễn Minh Quân',
              editable: true,
              apiClient: api,
            ),
            theme: MetaGymTheme.dark,
            textScale: 1.0,
          ),
        );
        await tester.pumpAndSettle();

        final notesBtn = find.byKey(const Key('meal-edit-notes-btn'));
        await tester.scrollUntilVisible(
          notesBtn,
          160,
          scrollable: verticalScrollable().first,
        );
        await tester.tap(notesBtn);
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('meal-notes-input')),
          'Uống tối thiểu 3L nước mỗi ngày.',
        );
        await tester.tap(find.byKey(const Key('meal-save-notes-btn')));
        await tester.pumpAndSettle();
        expect(
          adapter.lastMealPlanPayload?['notes'],
          'Uống tối thiểu 3L nước mỗi ngày.',
        );
      },
    );
  });
}

class _Group3CoachApiAdapter implements HttpClientAdapter {
  int savedTrainingCurrentCount = 0;
  Map<String, dynamic>? lastTrainingPayload;
  Map<String, dynamic>? lastMealPlanPayload;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.method == 'PUT' &&
        options.path == '/coach/members/m-1/training-plans/current') {
      savedTrainingCurrentCount++;
      final raw = options.data;
      if (raw is Map) {
        lastTrainingPayload = Map<String, dynamic>.from(raw);
      }
      return _json(_activePlanJson());
    }
    if (options.method == 'PUT' &&
        options.path.startsWith('/coach/meal-plans/')) {
      final raw = options.data;
      if (raw is Map) {
        lastMealPlanPayload = Map<String, dynamic>.from(raw);
      }
      return _json({
        'id': 'mp-1',
        'title': lastMealPlanPayload?['title'] ?? 'Thực đơn Tuần 4',
        'notes': lastMealPlanPayload?['notes'],
        'items': lastMealPlanPayload?['items'] ?? [],
      });
    }

    final Object data = switch (options.path) {
      '/coach/members' => [
        {
          'id': 'rel-1',
          'memberId': 'm-1',
          'memberFullName': 'Nguyễn Minh Quân',
          'status': 'ACTIVE',
        },
        {
          'id': 'rel-2',
          'memberId': 'm-4',
          'memberFullName': 'Đỗ Khánh Linh',
          'status': 'ACTIVE',
        },
      ],
      '/coach/members/m-1/training-plans' => [
        _activePlanJson(),
        _archivedPlanJson(),
      ],
      '/coach/members/m-4/training-plans' => <Object>[],
      '/training-plans/plan-active-1' => _activePlanJson(),
      '/training-plans/plan-arch-1' => _archivedPlanJson(),
      '/exercises' => [
        {
          'id': 'ex-1',
          'name': 'Incline Dumbbell Press',
          'category': 'Ngực trên',
          'targetMuscles': ['chest', 'shoulders'],
        },
        {
          'id': 'ex-2',
          'name': 'Wide-Grip Lat Pulldown',
          'category': 'Lưng xô',
          'targetMuscles': ['lats', 'back'],
        },
        {
          'id': 'ex-3',
          'name': 'Cable Chest Fly',
          'category': 'Ngực giữa',
          'targetMuscles': ['chest'],
        },
      ],
      '/coach/meal-plans/m-1' => {
        'id': 'mp-1',
        'title': 'Thực đơn Tăng cơ · Tuần 4',
        'notes': lastMealPlanPayload?['notes'] ?? 'Uống tối thiểu 2,5 lít nước/ngày.',
        'status': 'ACTIVE',
        'items': [
          {
            'day': 1,
            'meal': 'LUNCH',
            'foodId': 'f-1',
            'foodName': 'Ức gà áp chảo',
            'kcalPer100g': 165,
            'grams': 200,
          },
        ],
      },
      '/coach/meal-plans/m-4' => <String, dynamic>{},
      '/nutrition-foods' => [
        {'id': 'f-1', 'name': 'Ức gà áp chảo', 'kcalPer100g': 165},
      ],
      _ => <Object>[],
    };
    return _json(data);
  }

  Map<String, dynamic> _activePlanJson() => {
    'id': 'plan-active-1',
    'title': 'Upper / Lower Split — Hypertrophy 4 tuần',
    'goal': 'Tránh góc đẩy vai > 90° (Impingement nhẹ vai phải)',
    'status': 'ACTIVE',
    'version': 3,
    'startDate': '2026-11-10',
    'endDate': '2026-12-08',
    'days': [
      {
        'dayNumber': 1,
        'scheduledDate': '2026-11-10',
        'title': 'Push · Ngực & Vai',
        'notes': 'Khởi động khớp vai 5 phút với dây kháng lực nhẹ.',
        'exercises': [
          {
            'exerciseId': 'ex-1',
            'exerciseName': 'Incline Dumbbell Press',
            'displayOrder': 1,
            'sets': 4,
            'reps': '8–10',
            'restSeconds': 90,
            'weightGuidance': '22 kg/tay',
            'instructions': 'Kiểm soát pha hạ tạ 3 giây.',
            'safetyNotes': 'Không hạ khuỷu tay sâu hơn mặt ghế.',
          },
        ],
        'meals': [
          {
            'displayOrder': 1,
            'mealType': 'BREAKFAST',
            'scheduledTime': '07:00',
            'title': 'Yến mạch + Trứng gà',
          },
        ],
      },
      {
        'dayNumber': 2,
        'scheduledDate': '2026-11-12',
        'title': 'Pull · Lưng xô',
        'exercises': [
          {
            'exerciseId': 'ex-2',
            'exerciseName': 'Wide-Grip Lat Pulldown',
            'displayOrder': 1,
            'sets': 4,
            'reps': '10–12',
            'restSeconds': 90,
          },
        ],
        'meals': [
          {
            'displayOrder': 1,
            'mealType': 'LUNCH',
            'scheduledTime': '12:00',
            'title': 'Ức gà + Cơm gạo lứt',
          },
        ],
      },
    ],
  };

  Map<String, dynamic> _archivedPlanJson() => {
    'id': 'plan-arch-1',
    'title': 'Làm quen kỹ thuật cơ bản (Nền tảng)',
    'goal': 'Toàn thân · Hoàn thành 12/12 buổi',
    'status': 'ARCHIVED',
    'version': 2,
    'days': const [],
  };

  ResponseBody _json(Object? data) => ResponseBody.fromString(
    jsonEncode({'data': data}),
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}
