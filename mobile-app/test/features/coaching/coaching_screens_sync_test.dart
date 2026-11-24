import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_gym_app/core/config/api_config.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_icon.dart';
import 'package:meta_gym_app/features/coaching/data/coach_selection_service.dart';
import 'package:meta_gym_app/features/coaching/data/member_coaching_service.dart';
import 'package:meta_gym_app/features/coaching/domain/coach_member_models.dart';
import 'package:meta_gym_app/features/coaching/domain/coach_models.dart';
import 'package:meta_gym_app/features/coaching/domain/member_coaching_models.dart';
import 'package:meta_gym_app/features/coaching/presentation/coach_detail_page.dart';
import 'package:meta_gym_app/features/coaching/presentation/coach_selection_page.dart';
import 'package:meta_gym_app/features/coaching/presentation/member_coaching_page.dart';
import 'package:meta_gym_app/features/coaching/presentation/member_health_declaration_page.dart';
import 'package:meta_gym_app/features/progress/data/member_measurement_service.dart';
import 'package:meta_gym_app/features/progress/domain/body_measurement.dart';
import 'package:meta_gym_app/features/progress/presentation/member_measurement_page.dart';
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

  Future<void> verifyResponsiveThemes(
    WidgetTester tester,
    Widget Function() buildScreen, {
    required String label,
  }) async {
    for (final size in const [Size(375, 812), Size(768, 1024)]) {
      for (final (theme, isDark, disableAnim) in [
        (MetaGymTheme.dark, true, false),
        (MetaGymTheme.light, false, true),
      ]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          wrapScreen(
            buildScreen(),
            theme: theme,
            textScale: 1.3,
            disableAnimations: disableAnim,
          ),
        );
        await tester.pumpAndSettle();

        expect(
          tester.takeException(),
          isNull,
          reason: '$label threw at ${size.width}x${size.height} dark=$isDark',
        );
        expect(
          find.byType(MetaGymIcon),
          findsWidgets,
          reason: '$label must render preview SVG icons',
        );

        final glassCards = find.byType(MetaGymGlassCard);
        if (glassCards.evaluate().isNotEmpty) {
          final container = tester.widget<Container>(
            find
                .descendant(
                  of: glassCards.first,
                  matching: find.byType(Container),
                )
                .first,
          );
          final decoration = container.decoration as BoxDecoration;
          if (isDark && !disableAnim) {
            expect(
              decoration.color,
              const Color(0xC42B2622),
              reason: '$label Dark card must use Warm Smoked Liquid Glass fill',
            );
          } else if (!isDark) {
            expect(
              decoration.color,
              const Color(0xFFFFFFFF),
              reason: '$label Light card must use Daylight Studio surface',
            );
          }
        }
      }
    }
  }

  group('Preview Sync & Warm Smoked Liquid Glass (5.4 -> 5.8)', () {
    testWidgets(
      '5.4 MemberHealthDeclarationPage renders Dark/Light 375/768 1.3x + retry + laser picker',
      (tester) async {
        final adapter = _SyncHealthAdapter(failFirst: true);
        final client = ApiClient.withAdapter(
          config: ApiConfig.fromValues(environment: 'local'),
          adapter: adapter,
        );

        await tester.pumpWidget(
          Provider<ApiClient>.value(
            value: client,
            child: wrapScreen(
              const MemberHealthDeclarationPage(),
              theme: MetaGymTheme.dark,
              textScale: 1.0,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Inline load error retry button works cleanly
        expect(find.text('Tải lại hồ sơ'), findsOneWidget);
        await tester.tap(find.text('Tải lại hồ sơ'));
        await tester.pumpAndSettle();

        expect(find.text('Khai báo thể trạng'), findsOneWidget);
        expect(find.textContaining('BMI 23.9'), findsOneWidget);

        // Tapping Chiều cao metric tile opens Laser Stadiometer picker
        await tester.tap(find.text('174 cm'));
        await tester.pumpAndSettle();
        expect(find.text('Thước đo chiều cao'), findsOneWidget);
        await tester.tap(find.byKey(const Key('stadiometer-confirm')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await verifyResponsiveThemes(
          tester,
          () => Provider<ApiClient>.value(
            value: client,
            child: const MemberHealthDeclarationPage(),
          ),
          label: '5.4 MemberHealthDeclarationPage',
        );
      },
    );

    testWidgets(
      '5.5 MemberMeasurementPage prefills date, parses Vietnamese comma decimal, preserves list on refresh error',
      (tester) async {
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final service = _SyncMeasurementFixture();
        await tester.pumpWidget(
          wrapScreen(
            MemberMeasurementPage(service: service),
            theme: MetaGymTheme.dark,
            textScale: 1.0,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Nhật ký & Số đo'), findsOneWidget);
        expect(find.text('Chỉ số mới nhất'), findsOneWidget);

        // Create measurement without manually typing date (prefilled automatically!) & comma decimal
        await tester.tap(find.text('+ Ghi nhận số đo mới'));
        await tester.pumpAndSettle();
        final dateField = tester.widget<TextField>(
          find.byKey(const Key('measurement-date')),
        );
        expect(dateField.controller?.text.trim().isNotEmpty, isTrue);

        await tester.enterText(
          find.byKey(const Key('measurement-weight')),
          '71,6',
        );
        await tester.tap(find.text('Lưu'));
        await tester.pumpAndSettle();
        expect(service.lastCreated?['weightKg'], 71.6);
        expect(find.textContaining('71.6 kg'), findsWidgets);

        // Pull-to-refresh error preserves loaded measurements instead of wiping them
        service.failNext = true;
        await tester.fling(find.byType(ListView), const Offset(0, 300), 1000);
        await tester.pumpAndSettle();
        expect(find.textContaining('71.6 kg'), findsWidgets);
        expect(find.text('Mất kết nối tạm thời.'), findsOneWidget);

        service.failNext = false;
        await verifyResponsiveThemes(
          tester,
          () => MemberMeasurementPage(service: service),
          label: '5.5 MemberMeasurementPage',
        );
      },
    );

    testWidgets(
      '5.6a/5.6b MemberCoachingPage Active & Empty respect Provider, render 3-step onboarding & handle missing chat safely',
      (tester) async {
        final activeService = _SyncCoachingService(empty: false);
        await verifyResponsiveThemes(
          tester,
          () => Provider<MemberCoachingService>.value(
            value: activeService,
            child: const MemberCoachingPage(),
          ),
          label: '5.6a MemberCoachingPage Active',
        );

        // Verify tapping Nhắn Coach without MessagingService surfaces error gracefully
        await tester.pumpWidget(
          Provider<MemberCoachingService>.value(
            value: activeService,
            child: wrapScreen(
              const MemberCoachingPage(),
              theme: MetaGymTheme.dark,
              textScale: 1.0,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Nhắn Coach'));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Chưa thể mở cuộc trò chuyện'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);

        // Verify 5.6b Empty state renders 3-step onboarding card
        final emptyService = _SyncCoachingService(empty: true);
        await verifyResponsiveThemes(
          tester,
          () => MemberCoachingPage(service: emptyService),
          label: '5.6b MemberCoachingPage Empty',
        );
        expect(find.text('Chưa có Coach'), findsOneWidget);
        expect(find.text('Bắt đầu tập 1:1 trong 3 bước'), findsOneWidget);
        expect(find.text('Khai báo thể trạng'), findsOneWidget);
        expect(find.text('Chọn Coach & Gói tập'), findsOneWidget);
        expect(find.text('Đặt lịch buổi tập 90 phút'), findsOneWidget);
      },
    );

    testWidgets(
      '5.7 CoachSelectionPage & 5.8 CoachDetailPage render Warm Smoked Glass & guard missing chat safely',
      (tester) async {
        final coachService = _SyncCoachSelectionService();
        await verifyResponsiveThemes(
          tester,
          () => CoachSelectionPage(service: coachService),
          label: '5.7 CoachSelectionPage',
        );

        await verifyResponsiveThemes(
          tester,
          () => CoachDetailPage(coachId: 'coach-1', service: coachService),
          label: '5.8 CoachDetailPage',
        );

        // Regression check: tapping Nhắn Coach on CoachDetailPage without MessagingService/Session does not crash!
        await tester.pumpWidget(
          wrapScreen(
            CoachDetailPage(coachId: 'coach-2', service: coachService),
            theme: MetaGymTheme.dark,
            textScale: 1.0,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Kinh nghiệm'), findsNothing);
        await tester.tap(find.byTooltip('Nhắn Coach'));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Chưa thể mở cuộc trò chuyện'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  });
}

class _SyncHealthAdapter implements HttpClientAdapter {
  _SyncHealthAdapter({this.failFirst = false});

  final bool failFirst;
  int _loads = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    _loads++;
    if (failFirst && _loads == 1) {
      return ResponseBody.fromString(
        jsonEncode({'message': 'Lỗi tạm thời khi tải hồ sơ.'}),
        503,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    return ResponseBody.fromString(
      jsonEncode({
        'data': {
          'profile': {
            'heightCm': 174,
            'weightKg': 72.4,
            'bodyFatPercent': 15.8,
            'fitnessGoal': 'Tăng cơ giảm mỡ',
            'healthDeclarationCompletedAt': '2026-11-20T08:00:00Z',
          },
        },
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _SyncMeasurementFixture implements MemberMeasurementService {
  bool failNext = false;
  Map<String, Object?>? lastCreated;
  final List<BodyMeasurement> _items = [
    const BodyMeasurement(
      id: 'm-1',
      measuredAt: '2026-11-20T07:30:00Z',
      weightKg: 72.4,
      bodyFatPercent: 15.8,
      chestCm: 99,
      waistCm: 79,
      hipsCm: 96,
    ),
  ];

  @override
  Future<List<BodyMeasurement>> getPage(int page) async {
    if (failNext) {
      throw const ApiException(
        kind: ApiExceptionKind.network,
        message: 'Mất kết nối tạm thời.',
      );
    }
    return page == 1 ? List.of(_items) : const [];
  }

  @override
  Future<BodyMeasurement> create(Map<String, Object?> payload) async {
    lastCreated = payload;
    final created = BodyMeasurement(
      id: 'm-${_items.length + 1}',
      measuredAt: payload['measuredAt'] as String,
      weightKg: payload['weightKg'] as double,
      bodyFatPercent: payload['bodyFatPercent'] as double?,
      chestCm: payload['chestCm'] as double?,
      waistCm: payload['waistCm'] as double?,
      hipsCm: payload['hipsCm'] as double?,
    );
    _items.insert(0, created);
    return created;
  }

  @override
  Future<BodyMeasurement> update(
    String id,
    Map<String, Object?> payload,
  ) async {
    return _items.first;
  }
}

class _SyncCoachingService implements MemberCoachingService {
  _SyncCoachingService({required this.empty});

  final bool empty;

  @override
  Future<MemberCoachRelationship?> getCurrentRelationship() async => empty
      ? null
      : const MemberCoachRelationship(
          id: 'rel-1',
          coachId: 'coach-1',
          coachName: 'Lê Hoàng Nam',
          status: 'ACTIVE',
        );

  @override
  Future<List<MemberCoachRelationship>> getRelationshipHistory() async => empty
      ? const []
      : const [
          MemberCoachRelationship(
            id: 'rel-1',
            coachId: 'coach-1',
            coachName: 'Lê Hoàng Nam',
            status: 'ACTIVE',
          ),
        ];

  @override
  Future<Map<String, String>> getCoachNames() async => const {
    'coach-1': 'Lê Hoàng Nam',
  };

  @override
  Future<List<MemberCoachRequest>> getRequests() async => const [];

  @override
  Future<void> cancelRequest(String id) async {}

  @override
  Future<CoachLockChoiceResult> submitCoachLockChoice({
    required String choice,
    String? note,
  }) async => CoachLockChoiceResult(
    incidentId: 'inc-1',
    relationshipId: 'rel-1',
    status: 'OPEN',
    memberChoice: choice,
  );

  @override
  Future<List<CoachTerminationRequest>> getEarlyTerminationRequests() async =>
      const [];

  @override
  Future<CoachTerminationRequest> requestEarlyTermination(
    String relationshipId,
    String reason,
  ) async => CoachTerminationRequest(
    id: 'term-1',
    relationshipId: relationshipId,
    reason: reason,
    status: 'PENDING_COUNTERPARTY',
  );

  @override
  Future<CoachTerminationRequest> respondEarlyTermination(
    String requestId, {
    required String decision,
    String? reason,
  }) async => CoachTerminationRequest(
    id: requestId,
    relationshipId: 'rel-1',
    reason: 'Đổi lịch',
    status: 'ACCEPTED',
  );
}

class _SyncCoachSelectionService implements CoachSelectionService {
  static const _coaches = [
    CoachProfile(
      id: 'coach-1',
      fullName: 'Lê Hoàng Nam',
      specialties: ['Hypertrophy', 'Sức mạnh'],
      qualifications: 'NASM-CPT',
      experienceYears: 6,
      biography:
          'Chuyên thiết kế giáo án tăng cơ bền vững và theo sát kỹ thuật.',
      availabilityNote: 'Thứ 2 – Thứ 7 · 06:30 – 20:30',
      memberLimit: 14,
      usedSlots: 12,
      availableSlots: 2,
    ),
    CoachProfile(
      id: 'coach-2',
      fullName: 'Trần Minh Đức',
      specialties: ['Giảm mỡ', 'Phục hồi'],
      memberLimit: 10,
      usedSlots: 10,
      availableSlots: 0,
    ),
  ];

  @override
  Future<List<CoachProfile>> getCoaches() async => _coaches;

  @override
  Future<CoachProfile> getCoach(String id) async =>
      _coaches.firstWhere((c) => c.id == id);

  @override
  Future<CoachRequest> sendRequest(String coachId, String? message) async =>
      const CoachRequest(id: 'req-1', status: 'PENDING');
}
