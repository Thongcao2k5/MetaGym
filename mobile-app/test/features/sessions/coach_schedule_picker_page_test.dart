import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_gym_app/core/config/api_config.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/features/coaching/data/coach_v2_api.dart';
import 'package:meta_gym_app/features/sessions/presentation/coach_schedule_picker_page.dart';

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
    'renders all 4 shift states without overflow at 360x640 and 130% text scale',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final adapter = _SchedulePickerAdapter();
      final api = CoachV2Api(
        ApiClient.withAdapter(
          config: ApiConfig.fromValues(environment: 'local'),
          adapter: adapter,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(1.3),
            ),
            child: child!,
          ),
          home: CoachSchedulePickerPage(
            api: api,
            pack: {
              'id': 'pack-1',
              'coachId': 'coach-1',
              'startsOn': adapter.todayStr,
              'endsOn': adapter.endsOnStr,
            },
            existingBookings: [
              {
                'id': 'b-mine-today',
                'entitlementId': 'pack-1',
                'startsAt': adapter.todayMineStartsAt,
                'status': 'BOOKED',
              },
              {
                'id': 'b-mine-tomorrow',
                'entitlementId': 'pack-1',
                'startsAt': adapter.tomorrowMineStartsAt,
                'status': 'BOOKED',
              },
            ],
            availableToBook: 4,
            bookingId: 'b-mine-today',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Today shows past ('Đã qua giờ'), mine ('Bạn đã đặt'), open ('Còn trống'),
      // and booked ('Đã có lịch', unless clock is >= 23:45 VN time).
      expect(find.text('00:00 – 01:30'), findsOneWidget);
      expect(find.text('Đã qua giờ'), findsOneWidget);
      expect(find.text('02:00 – 03:30'), findsOneWidget);
      expect(find.text('Bạn đã đặt'), findsOneWidget);
      expect(find.text('22:00 – 23:30'), findsOneWidget);
      expect(find.text('Còn trống'), findsOneWidget);
      if (adapter.todayLateIsFuture) {
        expect(find.text('23:45 – 01:15'), findsOneWidget);
        expect(find.text('Đã có lịch'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);

      // Also verify Tomorrow in the same 360x640 @ 130% viewport where
      // open ('Còn trống'), booked ('Đã có lịch'), and mine ('Bạn đã đặt')
      // are unconditionally non-past regardless of wall-clock time.
      if (adapter.tomorrowCrossesWeek) {
        await tester.tap(find.byTooltip('Tuần sau'));
        await tester.pumpAndSettle();
      }
      await tester.tap(
        find
            .descendant(
              of: find.byType(GridView),
              matching: find.text('${adapter.tomorrowDay}'),
            )
            .first,
      );
      await tester.pumpAndSettle();

      expect(find.text('09:00 – 10:30'), findsOneWidget);
      expect(find.text('Còn trống'), findsOneWidget);
      expect(find.text('14:00 – 15:30'), findsOneWidget);
      expect(find.text('Đã có lịch'), findsOneWidget);
      expect(find.text('16:00 – 17:30'), findsOneWidget);
      expect(find.text('Bạn đã đặt'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

class _SchedulePickerAdapter implements HttpClientAdapter {
  _SchedulePickerAdapter() {
    final gymNow = DateTime.now().toUtc().add(const Duration(hours: 7));
    final todayDay = DateTime.utc(gymNow.year, gymNow.month, gymNow.day);
    final tomorrow = todayDay.add(const Duration(days: 1));
    final endsOn = todayDay.add(const Duration(days: 30));

    todayStr = todayDay.toIso8601String().substring(0, 10);
    tomorrowStr = tomorrow.toIso8601String().substring(0, 10);
    endsOnStr = endsOn.toIso8601String().substring(0, 10);
    tomorrowDay = tomorrow.day;
    tomorrowCrossesWeek = tomorrow.weekday < todayDay.weekday;
    todayLateIsFuture =
        DateTime.utc(todayDay.year, todayDay.month, todayDay.day, 23, 45)
            .isAfter(gymNow);

    todayMineStartsAt = _toUtcIso(todayDay, 2, 0);
    tomorrowMineStartsAt = _toUtcIso(tomorrow, 16, 0);
  }

  late final String todayStr;
  late final String tomorrowStr;
  late final String endsOnStr;
  late final int tomorrowDay;
  late final bool tomorrowCrossesWeek;
  late final bool todayLateIsFuture;
  late final String todayMineStartsAt;
  late final String tomorrowMineStartsAt;

  static String _toUtcIso(DateTime gymDate, int hour, int minute) => gymDate
      .add(Duration(hours: hour, minutes: minute))
      .subtract(const Duration(hours: 7))
      .toIso8601String();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path == '/coach-bookings/available-slots') {
      final date = options.queryParameters['date'] as String;
      final base = DateTime.parse('${date}T00:00:00Z');
      if (date == todayStr) {
        return _jsonResponse([
          {
            'startsAt': _toUtcIso(base, 22, 0),
            'endsAt': _toUtcIso(base, 23, 30),
          },
        ]);
      }
      if (date == tomorrowStr) {
        return _jsonResponse([
          {
            'startsAt': _toUtcIso(base, 9, 0),
            'endsAt': _toUtcIso(base, 10, 30),
          },
        ]);
      }
      return _jsonResponse([]);
    }

    if (options.path == '/coaches/coach-1/work-slots') {
      final todayWd = DateTime.parse('${todayStr}T00:00:00Z').weekday;
      final tomorrowWd = DateTime.parse('${tomorrowStr}T00:00:00Z').weekday;
      return _jsonResponse({
        'configured': true,
        'days': [
          for (var wd = 1; wd <= 7; wd++)
            {
              'weekday': wd,
              'starts': wd == todayWd
                  ? ['00:00', '02:00', '22:00', '23:45']
                  : wd == tomorrowWd
                  ? ['09:00', '14:00', '16:00']
                  : ['09:00'],
            },
        ],
      });
    }

    throw StateError('Unhandled path: ${options.method} ${options.path}');
  }

  @override
  void close({bool force = false}) {}
}
