import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_gym_app/core/config/api_config.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/core/theme/meta_gym_icons.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_svg_icon.dart';
import 'package:meta_gym_app/features/sessions/presentation/coach_booking_history_page.dart';
import 'package:meta_gym_app/features/sessions/presentation/coach_booking_page.dart';
import 'package:meta_gym_app/features/sessions/presentation/coach_muscle_anatomy_tile.dart';
import 'package:meta_gym_app/features/sessions/presentation/coach_schedule_picker_page.dart';
import 'package:meta_gym_app/features/training/presentation/member_day_plan_page.dart';
import 'package:provider/provider.dart';

const _wdLabels = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

ResponseBody _jsonResponse(Object? data, {int statusCode = 200}) =>
    ResponseBody.fromString(
      jsonEncode({'data': data}),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

void main() {
  testWidgets(
    'shows a paused package, keeps booking disabled, and opens history page',
    (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final api = ApiClient.withAdapter(
        config: ApiConfig.fromValues(environment: 'local'),
        adapter: _BookingAdapter(),
      );
      await tester.pumpWidget(
        Provider.value(
          value: api,
          child: const MaterialApp(home: CoachBookingPage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Gói 10 buổi'), findsOneWidget);
      expect(find.textContaining('Tạm dừng'), findsOneWidget);
      expect(find.text('Đặt lịch'), findsNothing);
      expect(find.byTooltip('Thông báo Coach'), findsNothing);
      expect(find.byTooltip('Tải lại'), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byTooltip('Lịch sử buổi tập'));
      await tester.pumpAndSettle();
      expect(find.byType(CoachBookingHistoryPage), findsOneWidget);
      expect(find.text('Chưa có lịch sử buổi tập với Coach.'), findsOneWidget);
    },
  );

  testWidgets('disables booking button when remaining sessions count is 0', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final api = ApiClient.withAdapter(
      config: ApiConfig.fromValues(environment: 'local'),
      adapter: _ZeroSessionsAdapter(),
    );
    await tester.pumpWidget(
      Provider.value(
        value: api,
        child: const MaterialApp(home: CoachBookingPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Gói VIP 0 buổi'), findsOneWidget);
    expect(find.textContaining('Đã hết số buổi tập'), findsOneWidget);
    expect(find.text('Đặt lịch'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hides reschedule button when relationship is PAUSED', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final api = ApiClient.withAdapter(
      config: ApiConfig.fromValues(environment: 'local'),
      adapter: _PausedBookingAdapter(),
    );
    await tester.pumpWidget(
      Provider.value(
        value: api,
        child: const MaterialApp(home: CoachBookingPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Đổi giờ'), findsNothing);
    expect(find.text('Hủy buổi'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders 3-column stats and hides book CTA when quota is full', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final api = ApiClient.withAdapter(
      config: ApiConfig.fromValues(environment: 'local'),
      adapter: _FullBookedAdapter(),
    );
    await tester.pumpWidget(
      Provider.value(
        value: api,
        child: const MaterialApp(home: CoachBookingPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Hạn dùng đến 14/03/2030'), findsOneWidget);
    expect(find.text('Còn lại'), findsOneWidget);
    expect(find.text('Đã đặt'), findsWidgets);
    expect(find.text('Chưa đặt'), findsOneWidget);
    expect(find.text('Đặt lịch'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'links cards with curriculum muscle tile, relative times, and opens day plan',
    (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final adapter = _LinkedCurriculumAdapter();
      final api = ApiClient.withAdapter(
        config: ApiConfig.fromValues(environment: 'local'),
        adapter: adapter,
      );
      await tester.pumpWidget(
        Provider.value(
          value: api,
          child: const MaterialApp(home: CoachBookingPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CoachMuscleAnatomyTile), findsWidgets);
      expect(find.text('Ngực & Vai'), findsOneWidget);
      expect(find.text('Lưng & Tay trước'), findsOneWidget);
      expect(find.text('Giáo án · 2 bài tập'), findsOneWidget);
      expect(find.text('Hôm nay · ${adapter.todayRange}'), findsOneWidget);
      expect(find.text('Ngày mai · ${adapter.tomorrowRange}'), findsOneWidget);

      final thirdTimeFinder = find.text(
        '${adapter.threeDaysLabel} · ${adapter.threeDaysRange}',
      );
      await tester.scrollUntilVisible(
        thirdTimeFinder,
        240,
        scrollable: find.byType(Scrollable).first,
      );
      expect(thirdTimeFinder, findsOneWidget);

      final noticeFinder = find.textContaining(
        'Hủy hoặc đổi giờ trong vòng 12 giờ',
      );
      await tester.scrollUntilVisible(
        noticeFinder,
        240,
        scrollable: find.byType(Scrollable).first,
      );
      expect(noticeFinder, findsOneWidget);
      expect(find.textContaining('< 12h'), findsNothing);
      // Linked cards (Ngực & Vai, Lưng & Tay trước) hide Coach name;
      // unlinked card 3 (b-later) falls back to default card showing Coach name.
      expect(find.textContaining('Lê Hoàng Nam'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is MetaGymSvgIcon && w.assetPath == MetaGymIcons.equipDumbbell,
        ),
        findsOneWidget,
      );

      await tester.ensureVisible(find.text('Ngực & Vai'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ngực & Vai'));
      await tester.pumpAndSettle();
      expect(find.byType(MemberDayPlanPage), findsOneWidget);
      expect(find.text('Bench Press'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'decouples booking-count prerequisite and links full-week curriculum by weekday',
    (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final api = ApiClient.withAdapter(
        config: ApiConfig.fromValues(environment: 'local'),
        adapter: _UnderHalfSessionsAdapter(),
      );
      await tester.pumpWidget(
        Provider.value(
          value: api,
          child: const MaterialApp(home: CoachBookingPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Đặt tối thiểu'), findsNothing);
      expect(find.textContaining('Chờ Coach lên giáo án'), findsNothing);
      expect(find.byType(CoachMuscleAnatomyTile), findsNothing);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -180));
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is MetaGymSvgIcon && w.assetPath == MetaGymIcons.equipDumbbell,
        ),
        findsNWidgets(2),
      );
      expect(find.text('Lê Hoàng Nam'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'matches full-week Coach curriculum onto PT booking card by weekday',
    (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final api = ApiClient.withAdapter(
        config: ApiConfig.fromValues(environment: 'local'),
        adapter: _WeeklyCurriculumAdapter(),
      );
      await tester.pumpWidget(
        Provider.value(
          value: api,
          child: const MaterialApp(home: CoachBookingPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CoachMuscleAnatomyTile), findsWidgets);
      expect(find.text('Giáo án tuần · Ngực'), findsOneWidget);
      expect(find.text('Giáo án · 1 bài tập'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'blocks booking Coach appointment on rest/recovery curriculum days and allows training days',
    (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final adapter = _RestDayRulePickerAdapter();
      final api = ApiClient.withAdapter(
        config: ApiConfig.fromValues(environment: 'local'),
        adapter: adapter,
      );
      await tester.pumpWidget(
        Provider.value(
          value: api,
          child: const MaterialApp(home: CoachBookingPage()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Đặt lịch'));
      await tester.pumpAndSettle();
      expect(find.byType(CoachSchedulePickerPage), findsOneWidget);

      // Tomorrow is configured as a recovery/rest day -> banner shown, shifts disabled
      if (adapter.tomorrowCrossesWeek) {
        await tester.tap(find.byTooltip('Tuần sau'));
        await tester.pumpAndSettle();
      }
      await tester.tap(
        find.descendant(
          of: find.byType(GridView),
          matching: find.text(_wdLabels[adapter.tomorrowWeekday - 1]),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('coach-picker-rest-day-banner')),
        findsOneWidget,
      );
      expect(find.text('Ngày nghỉ hồi phục'), findsWidgets);
      await tester.tap(find.text('08:00 – 09:30'));
      await tester.pumpAndSettle();
      expect(find.text('Đặt lịch'), findsNothing);

      // Day after tomorrow is a training day -> green curriculum banner shown, shift selectable
      if (adapter.dayAfterCrossesWeek) {
        await tester.tap(find.byTooltip('Tuần sau'));
        await tester.pumpAndSettle();
      }
      await tester.tap(
        find.descendant(
          of: find.byType(GridView),
          matching: find.text(_wdLabels[adapter.dayAfterWeekday - 1]),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('coach-picker-rest-day-banner')),
        findsNothing,
      );
      expect(find.textContaining('Giáo án hôm đó: Ngực & Vai'), findsOneWidget);
      await tester.tap(find.text('08:00 – 09:30'));
      await tester.pumpAndSettle();
      expect(find.text('Đặt lịch'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'schedule picker supports multi-day booking, enforces 1/day, and hides CTA until picked',
    (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final adapter = _MultiBookingAdapter();
      final api = ApiClient.withAdapter(
        config: ApiConfig.fromValues(environment: 'local'),
        adapter: adapter,
      );
      await tester.pumpWidget(
        Provider.value(
          value: api,
          child: const MaterialApp(home: CoachBookingPage()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Đặt lịch'));
      await tester.pumpAndSettle();
      expect(find.byType(CoachSchedulePickerPage), findsOneWidget);
      // CTA hidden until at least 1 shift is selected
      expect(find.text('Đặt lịch'), findsNothing);
      // Today already has 1 booking -> enforces 1/day limit banner
      expect(
        find.textContaining('Mỗi ngày chỉ được đặt tối đa 1 buổi'),
        findsOneWidget,
      );

      // Select tomorrow on calendar and pick 08:00 shift
      if (adapter.tomorrowCrossesWeek) {
        await tester.tap(find.byTooltip('Tuần sau'));
        await tester.pumpAndSettle();
      }
      await tester.tap(
        find.descendant(
          of: find.byType(GridView),
          matching: find.text(_wdLabels[adapter.tomorrowWeekday - 1]),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('08:00 – 09:30'));
      await tester.pumpAndSettle();
      expect(find.text('Đã chọn 1/5 buổi tập'), findsOneWidget);
      expect(find.text('Đặt lịch'), findsOneWidget);

      // Select day after tomorrow on calendar and pick 18:00 shift
      if (adapter.dayAfterCrossesWeek) {
        await tester.tap(find.byTooltip('Tuần sau'));
        await tester.pumpAndSettle();
      }
      await tester.tap(
        find.descendant(
          of: find.byType(GridView),
          matching: find.text(_wdLabels[adapter.dayAfterWeekday - 1]),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('18:00 – 19:30'));
      await tester.pumpAndSettle();
      expect(find.text('Đã chọn 2/5 buổi tập'), findsOneWidget);

      await tester.ensureVisible(find.text('Đặt lịch'));
      await tester.tap(find.text('Đặt lịch'));
      await tester.pumpAndSettle();
      expect(adapter.createdStartsAt.length, 2);
      expect(find.byType(CoachBookingPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

class _BookingAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final data = switch (options.path) {
      '/coach-entitlements' => [
        {
          'id': 'pack',
          'planName': 'Gói 10 buổi',
          'status': 'ACTIVE',
          'relationshipStatus': 'PAUSED',
          'remainingSessions': 8,
          'totalSessions': 10,
          'endsOn': '2030-03-14',
        },
      ],
      '/coach-bookings' => [],
      '/training-plans/me/active' => null,
      _ => throw StateError('Path: ${options.path}'),
    };
    return _jsonResponse(data);
  }

  @override
  void close({bool force = false}) {}
}

class _ZeroSessionsAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final data = switch (options.path) {
      '/coach-entitlements' => [
        {
          'id': 'pack-0',
          'planName': 'Gói VIP 0 buổi',
          'status': 'ACTIVE',
          'relationshipStatus': 'ACTIVE',
          'remainingSessions': 0,
          'totalSessions': 10,
          'endsOn': '2030-03-14',
        },
      ],
      '/coach-bookings' => [],
      '/training-plans/me/active' => null,
      _ => throw StateError('Path: ${options.path}'),
    };
    return _jsonResponse(data);
  }

  @override
  void close({bool force = false}) {}
}

class _PausedBookingAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final data = switch (options.path) {
      '/coach-entitlements' => [
        {
          'id': 'pack-paused',
          'planName': 'Gói 10 buổi',
          'status': 'ACTIVE',
          'relationshipStatus': 'PAUSED',
          'remainingSessions': 5,
          'totalSessions': 10,
          'endsOn': '2030-03-14',
        },
      ],
      '/coach-bookings' => [
        {
          'id': 'booking-1',
          'entitlementId': 'pack-paused',
          'coachName': 'Alex Nguyen',
          'startsAt': '2030-01-01T10:00:00.000Z',
          'endsAt': '2030-01-01T11:30:00.000Z',
          'status': 'BOOKED',
        },
      ],
      '/training-plans/me/active' => null,
      _ => throw StateError('Path: ${options.path}'),
    };
    return _jsonResponse(data);
  }

  @override
  void close({bool force = false}) {}
}

class _FullBookedAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final data = switch (options.path) {
      '/coach-entitlements' => [
        {
          'id': 'pack-full',
          'planName': 'Gói 10 buổi',
          'status': 'ACTIVE',
          'relationshipStatus': 'ACTIVE',
          'remainingSessions': 1,
          'totalSessions': 10,
          'endsOn': '2030-03-14',
        },
      ],
      '/coach-bookings' => [
        {
          'id': 'booking-full',
          'entitlementId': 'pack-full',
          'coachName': 'Alex Nguyen',
          'startsAt': '2030-01-01T10:00:00.000Z',
          'endsAt': '2030-01-01T11:30:00.000Z',
          'status': 'BOOKED',
        },
      ],
      '/training-plans/me/active' => null,
      _ => throw StateError('Path: ${options.path}'),
    };
    return _jsonResponse(data);
  }

  @override
  void close({bool force = false}) {}
}

class _LinkedCurriculumAdapter implements HttpClientAdapter {
  _LinkedCurriculumAdapter() {
    final nowUtc = DateTime.now().toUtc();
    final todayUtc = nowUtc.add(const Duration(minutes: 2));
    final todayEndUtc = todayUtc.add(const Duration(minutes: 90));
    final gymToday = todayUtc.add(const Duration(hours: 7));
    final gymTodayEnd = todayEndUtc.add(const Duration(hours: 7));
    todayIso = todayUtc.toIso8601String();
    todayEndIso = todayEndUtc.toIso8601String();
    todayDate = gymToday.toIso8601String().substring(0, 10);
    todayRange =
        '${gymToday.toIso8601String().substring(11, 16)} – ${gymTodayEnd.toIso8601String().substring(11, 16)}';

    final gymTomorrow = DateTime.utc(
      gymToday.year,
      gymToday.month,
      gymToday.day,
      18,
      30,
    ).add(const Duration(days: 1));
    final gymTomorrowEnd = gymTomorrow.add(const Duration(minutes: 90));
    tomorrowDate = gymTomorrow.toIso8601String().substring(0, 10);
    tomorrowIso = gymTomorrow
        .subtract(const Duration(hours: 7))
        .toIso8601String();
    tomorrowEndIso = gymTomorrowEnd
        .subtract(const Duration(hours: 7))
        .toIso8601String();
    tomorrowRange =
        '${gymTomorrow.toIso8601String().substring(11, 16)} – ${gymTomorrowEnd.toIso8601String().substring(11, 16)}';

    final gymThreeDays = DateTime.utc(
      gymToday.year,
      gymToday.month,
      gymToday.day,
      18,
      30,
    ).add(const Duration(days: 3));
    final gymThreeDaysEnd = gymThreeDays.add(const Duration(minutes: 90));
    threeDaysIso = gymThreeDays
        .subtract(const Duration(hours: 7))
        .toIso8601String();
    threeDaysEndIso = gymThreeDaysEnd
        .subtract(const Duration(hours: 7))
        .toIso8601String();
    threeDaysLabel =
        '${gymThreeDays.day.toString().padLeft(2, '0')}/${gymThreeDays.month.toString().padLeft(2, '0')}/${gymThreeDays.year}';
    threeDaysRange =
        '${gymThreeDays.toIso8601String().substring(11, 16)} – ${gymThreeDaysEnd.toIso8601String().substring(11, 16)}';
  }

  late final String todayIso;
  late final String todayEndIso;
  late final String todayDate;
  late final String todayRange;
  late final String tomorrowIso;
  late final String tomorrowEndIso;
  late final String tomorrowDate;
  late final String tomorrowRange;
  late final String threeDaysIso;
  late final String threeDaysEndIso;
  late final String threeDaysLabel;
  late final String threeDaysRange;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final data = switch (options.path) {
      '/coach-entitlements' => [
        {
          'id': 'pack-linked',
          'planName': 'Gói Cơ bản · 10 buổi',
          'status': 'ACTIVE',
          'relationshipStatus': 'ACTIVE',
          'remainingSessions': 6,
          'totalSessions': 10,
          'endsOn': '2030-12-31',
        },
      ],
      '/coach-bookings' => [
        {
          'id': 'b-today',
          'entitlementId': 'pack-linked',
          'coachName': 'Lê Hoàng Nam',
          'startsAt': todayIso,
          'endsAt': todayEndIso,
          'status': 'BOOKED',
        },
        {
          'id': 'b-tomorrow',
          'entitlementId': 'pack-linked',
          'coachName': 'Lê Hoàng Nam',
          'startsAt': tomorrowIso,
          'endsAt': tomorrowEndIso,
          'status': 'BOOKED',
        },
        {
          'id': 'b-later',
          'entitlementId': 'pack-linked',
          'coachName': 'Lê Hoàng Nam',
          'startsAt': threeDaysIso,
          'endsAt': threeDaysEndIso,
          'status': 'BOOKED',
        },
      ],
      '/training-plans/me/active' => {
        'id': 'plan-1',
        'title': 'Tăng cơ & Sức mạnh',
        'status': 'ACTIVE',
        'version': 1,
        'days': [
          {
            'dayNumber': 1,
            'scheduledDate': todayDate,
            'title': 'Ngực & Vai',
            'exercises': [
              {
                'exerciseId': 'ex-1',
                'exerciseName': 'Bench Press',
                'displayOrder': 1,
                'sets': 4,
                'reps': '8',
              },
              {
                'exerciseId': 'ex-2',
                'exerciseName': 'Overhead Press',
                'displayOrder': 2,
                'sets': 3,
                'reps': '10',
              },
            ],
          },
          {
            'dayNumber': 2,
            'scheduledDate': tomorrowDate,
            'title': 'Lưng & Tay trước',
            'exercises': [
              {
                'exerciseId': 'ex-3',
                'exerciseName': 'Pull Up',
                'displayOrder': 1,
                'sets': 4,
                'reps': '8',
              },
            ],
          },
        ],
      },
      _ => throw StateError('Path: ${options.path}'),
    };
    return _jsonResponse(data);
  }

  @override
  void close({bool force = false}) {}
}

class _UnderHalfSessionsAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final data = switch (options.path) {
      '/coach-entitlements' => [
        {
          'id': 'pack-half',
          'planName': 'Gói 10 buổi',
          'status': 'ACTIVE',
          'relationshipStatus': 'ACTIVE',
          'remainingSessions': 10,
          'totalSessions': 10,
          'endsOn': '2030-12-31',
        },
      ],
      '/coach-bookings' => [
        {
          'id': 'b1',
          'entitlementId': 'pack-half',
          'coachName': 'Lê Hoàng Nam',
          'startsAt': '2030-02-01T10:00:00Z',
          'endsAt': '2030-02-01T11:30:00Z',
          'status': 'BOOKED',
        },
        {
          'id': 'b2',
          'entitlementId': 'pack-half',
          'coachName': 'Lê Hoàng Nam',
          'startsAt': '2030-02-03T10:00:00Z',
          'endsAt': '2030-02-03T11:30:00Z',
          'status': 'BOOKED',
        },
      ],
      '/training-plans/me/active' => null,
      _ => throw StateError('Path: ${options.path}'),
    };
    return _jsonResponse(data);
  }

  @override
  void close({bool force = false}) {}
}

class _MultiBookingAdapter implements HttpClientAdapter {
  _MultiBookingAdapter() {
    final gymNow = DateTime.now().toUtc().add(const Duration(hours: 7));
    final todayDay = DateTime.utc(gymNow.year, gymNow.month, gymNow.day);
    final tmrw = todayDay.add(const Duration(days: 1));
    final dayAfter = todayDay.add(const Duration(days: 2));
    // Anchor inside the same Monday..Sunday week if needed? Calendar grid shows week of selectedDate,
    // and we make sure both tomorrow and dayAfter are in the current week OR we test dates inside the same week:
    todayStr = todayDay.toIso8601String().substring(0, 10);
    todayBookingStart = todayDay
        .add(const Duration(hours: 20))
        .subtract(const Duration(hours: 7))
        .toIso8601String();
    todayBookingEnd = todayDay
        .add(const Duration(hours: 21, minutes: 30))
        .subtract(const Duration(hours: 7))
        .toIso8601String();
    // Calendar defaults to Mon..Sun week view; track week boundaries for Sat/Sun runs.
    DateTime weekMonday(DateTime d) => d.subtract(Duration(days: d.weekday - 1));
    tomorrowCrossesWeek = weekMonday(tmrw) != weekMonday(todayDay);
    dayAfterCrossesWeek = weekMonday(dayAfter) != weekMonday(tmrw);
    tomorrowStr = tmrw.toIso8601String().substring(0, 10);
    dayAfterStr = dayAfter.toIso8601String().substring(0, 10);
    tomorrowWeekday = tmrw.weekday;
    dayAfterWeekday = dayAfter.weekday;
  }

  late final String todayStr;
  late final String todayBookingStart;
  late final String todayBookingEnd;
  late final String tomorrowStr;
  late final String dayAfterStr;
  late final int tomorrowWeekday;
  late final int dayAfterWeekday;
  late final bool tomorrowCrossesWeek;
  late final bool dayAfterCrossesWeek;
  final List<String> createdStartsAt = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.method == 'POST' && options.path == '/coach-bookings') {
      final body = options.data is String
          ? jsonDecode(options.data as String) as Map<String, dynamic>
          : Map<String, dynamic>.from(options.data as Map);
      final startsAt = body['startsAt'] as String;
      createdStartsAt.add(startsAt);
      return _jsonResponse({
        'id': 'created-${createdStartsAt.length}',
        'entitlementId': body['entitlementId'],
        'coachName': 'Lê Hoàng Nam',
        'startsAt': startsAt,
        'endsAt': startsAt,
        'status': 'BOOKED',
      }, statusCode: 201);
    }

    if (options.path == '/coach-bookings/available-slots') {
      final date = options.queryParameters['date'] as String;
      if (date == todayStr) return _jsonResponse([]);
      final base = DateTime.parse('${date}T00:00:00Z');
      String toUtcIso(int h, int m) => base
          .add(Duration(hours: h, minutes: m))
          .subtract(const Duration(hours: 7))
          .toIso8601String();
      return _jsonResponse([
        {'startsAt': toUtcIso(8, 0), 'endsAt': toUtcIso(9, 30)},
        {'startsAt': toUtcIso(18, 0), 'endsAt': toUtcIso(19, 30)},
      ]);
    }

    final data = switch (options.path) {
      '/coach-entitlements' => [
        {
          'id': 'pack-multi',
          'coachId': 'coach-1',
          'planName': 'Gói 10 buổi',
          'status': 'ACTIVE',
          'relationshipStatus': 'ACTIVE',
          'remainingSessions': 6,
          'totalSessions': 10,
          'endsOn': '2030-12-31',
        },
      ],
      '/coach-bookings' => [
        {
          'id': 'b-existing-today',
          'entitlementId': 'pack-multi',
          'coachName': 'Lê Hoàng Nam',
          'startsAt': todayBookingStart,
          'endsAt': todayBookingEnd,
          'status': 'BOOKED',
        },
      ],
      '/coaches/coach-1/work-slots' => {
        'configured': true,
        'days': [
          for (var wd = 1; wd <= 7; wd++)
            {
              'weekday': wd,
              'starts': ['08:00', '18:00'],
            },
        ],
      },
      '/training-plans/me/active' => null,
      _ => throw StateError('Path: ${options.path}'),
    };
    return _jsonResponse(data);
  }

  @override
  void close({bool force = false}) {}
}

class _WeeklyCurriculumAdapter implements HttpClientAdapter {
  _WeeklyCurriculumAdapter() {
    final gymToday = DateTime.now().toUtc().add(const Duration(hours: 7));
    final bookingGym = DateTime.utc(
      gymToday.year,
      gymToday.month,
      gymToday.day,
      10,
    ).add(const Duration(days: 1));
    targetWeekday = bookingGym.weekday;
    bookingIso = bookingGym.subtract(const Duration(hours: 7)).toIso8601String();
    bookingEndIso = bookingGym
        .subtract(const Duration(hours: 7))
        .add(const Duration(minutes: 90))
        .toIso8601String();
  }

  late final int targetWeekday;
  late final String bookingIso;
  late final String bookingEndIso;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final data = switch (options.path) {
      '/coach-entitlements' => [
        {
          'id': 'pack-wk',
          'planName': 'Gói 12 buổi',
          'status': 'ACTIVE',
          'relationshipStatus': 'ACTIVE',
          'remainingSessions': 10,
          'totalSessions': 12,
          'endsOn': '2030-12-31',
        },
      ],
      '/coach-bookings' => [
        {
          'id': 'b-wk-1',
          'entitlementId': 'pack-wk',
          'coachName': 'Lê Hoàng Nam',
          'startsAt': bookingIso,
          'endsAt': bookingEndIso,
          'status': 'BOOKED',
        },
      ],
      '/training-plans/me/active' => {
        'id': 'plan-wk',
        'title': 'Giáo trình Full Tuần',
        'status': 'ACTIVE',
        'version': 1,
        'days': [
          {
            'dayNumber': targetWeekday,
            'title': 'Giáo án tuần · Ngực',
            'exercises': [
              {
                'exerciseId': 'ex-1',
                'exerciseName': 'Barbell Bench Press',
                'displayOrder': 1,
                'sets': 4,
                'reps': '8',
              },
            ],
          },
        ],
      },
      _ => throw StateError('Path: ${options.path}'),
    };
    return _jsonResponse(data);
  }

  @override
  void close({bool force = false}) {}
}

class _RestDayRulePickerAdapter implements HttpClientAdapter {
  _RestDayRulePickerAdapter() {
    final nowGym = DateTime.now().toUtc().add(const Duration(hours: 7));
    final today = DateTime.utc(nowGym.year, nowGym.month, nowGym.day);
    final tomorrow = today.add(const Duration(days: 1));
    final dayAfter = today.add(const Duration(days: 2));
    tomorrowDate = tomorrow.toIso8601String().substring(0, 10);
    tomorrowDay = tomorrow.day;
    tomorrowWeekday = tomorrow.weekday;
    dayAfterDate = dayAfter.toIso8601String().substring(0, 10);
    dayAfterDay = dayAfter.day;
    dayAfterWeekday = dayAfter.weekday;
    final todayMonday = today.subtract(Duration(days: today.weekday - 1));
    final tomorrowMonday =
        tomorrow.subtract(Duration(days: tomorrow.weekday - 1));
    final dayAfterMonday =
        dayAfter.subtract(Duration(days: dayAfter.weekday - 1));
    tomorrowCrossesWeek = tomorrowMonday != todayMonday;
    dayAfterCrossesWeek = dayAfterMonday != tomorrowMonday;
  }

  late final String tomorrowDate;
  late final int tomorrowDay;
  late final int tomorrowWeekday;
  late final String dayAfterDate;
  late final int dayAfterDay;
  late final int dayAfterWeekday;
  late final bool tomorrowCrossesWeek;
  late final bool dayAfterCrossesWeek;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path == '/coach-bookings/available-slots') {
      final date = (options.queryParameters['date'] as String?) ?? dayAfterDate;
      return _jsonResponse([
        {'startsAt': '${date}T08:00:00+07:00', 'endsAt': '${date}T09:30:00+07:00'},
      ]);
    }
    final data = switch (options.path) {
      '/coach-entitlements' => [
        {
          'id': 'pack-rest-rule',
          'coachId': 'coach-1',
          'planName': 'Gói 10 buổi',
          'status': 'ACTIVE',
          'relationshipStatus': 'ACTIVE',
          'remainingSessions': 8,
          'totalSessions': 10,
          'endsOn': '2030-12-31',
        },
      ],
      '/coach-bookings' => const <Object>[],
      '/coaches/coach-1/work-slots' => {
        'configured': true,
        'days': [
          for (var wd = 1; wd <= 7; wd++)
            {
              'weekday': wd,
              'starts': ['08:00'],
            },
        ],
      },
      '/training-plans/me/active' => {
        'id': 'plan-rest-rule',
        'title': 'Giáo trình Chuẩn Tuần',
        'status': 'ACTIVE',
        'version': 1,
        'days': [
          {
            'dayNumber': tomorrowWeekday,
            'title': 'Phục Hồi Chủ Động & Giãn Cơ',
            'exercises': [
              {
                'exerciseId': 'ex-rec',
                'exerciseName': 'Foam Rolling',
                'displayOrder': 1,
                'sets': 1,
                'durationSeconds': 900,
              },
            ],
          },
          {
            'dayNumber': dayAfterWeekday,
            'title': 'Ngực & Vai',
            'exercises': [
              {
                'exerciseId': 'ex-1',
                'exerciseName': 'Bench Press',
                'displayOrder': 1,
                'sets': 4,
                'reps': '8',
              },
            ],
          },
        ],
      },
      _ => throw StateError('Path: ${options.path}'),
    };
    return _jsonResponse(data);
  }

  @override
  void close({bool force = false}) {}
}
