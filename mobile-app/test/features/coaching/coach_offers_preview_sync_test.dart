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
import 'package:meta_gym_app/features/coaching/presentation/coach_offers_page.dart';
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
          reason: '$label must render MetaGymIcons SVGs',
        );

        final glassCards = find.byType(MetaGymGlassCard);
        expect(glassCards, findsWidgets);
        final firstContainer = tester.widget<Container>(
          find
              .descendant(
                of: glassCards.first,
                matching: find.byType(Container),
              )
              .first,
        );
        final decoration = firstContainer.decoration as BoxDecoration;
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

  group('5.9 CoachOffersPage Preview Sync & Warm Smoked Liquid Glass', () {
    testWidgets(
      'renders Dark & Light at 375px/768px 1.3x with Gold tier perk, health metrics, and package hierarchy',
      (tester) async {
        final adapter = _PreviewOffersAdapter();
        final client = ApiClient.withAdapter(
          config: ApiConfig.fromValues(environment: 'local'),
          adapter: adapter,
        );

        await verifyResponsiveThemes(
          tester,
          () => Provider<ApiClient>.value(
            value: client,
            child: const CoachOffersPage(coachId: 'coach-1'),
          ),
          label: '5.9 CoachOffersPage',
        );

        // Preview header, health declaration metrics, Gold tier perk, and packages
        expect(find.text('GÓI COACHING 1:1'), findsOneWidget);
        expect(find.text('Gói của Lê Hoàng Nam'), findsOneWidget);
        expect(find.text('Đã khai báo thể trạng'), findsOneWidget);
        expect(
          find.text('174 cm · 72.4 kg · Sẵn sàng thuê Coach'),
          findsOneWidget,
        );
        expect(find.text('Xem / sửa'), findsOneWidget);
        expect(find.text('Đặc quyền Thẻ Vàng đang áp dụng'), findsOneWidget);
        expect(find.text('-5%'), findsOneWidget);
        expect(find.text('Gói Chuyên Sâu 24 buổi'), findsWidgets);
        expect(find.text('Phổ biến'), findsOneWidget);
        expect(find.text('8.455.000 ₫'), findsWidgets);
        expect(find.text('8.900.000 ₫'), findsWidgets);
        expect(find.text('Gói Tiêu Chuẩn 12 buổi'), findsOneWidget);
        expect(find.text('4.560.000 ₫'), findsOneWidget);
        expect(find.text('Chọn gói & Thanh toán'), findsOneWidget);
        expect(find.widgetWithText(FilledButton, 'Thanh toán'), findsOneWidget);
      },
    );

    testWidgets(
      'switches package selection, creates demo hold without 0 ₫ bug, and edits health declaration',
      (tester) async {
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final adapter = _PreviewOffersAdapter(demoShapeHold: true);
        final client = ApiClient.withAdapter(
          config: ApiConfig.fromValues(environment: 'local'),
          adapter: adapter,
        );

        await tester.pumpWidget(
          Provider<ApiClient>.value(
            value: client,
            child: wrapScreen(
              const CoachOffersPage(coachId: 'coach-1'),
              theme: MetaGymTheme.dark,
              textScale: 1.0,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap standard 12-session offer card to switch selection
        final stdCard = find.byKey(const ValueKey('offer-card-PT12'));
        await tester.ensureVisible(stdCard);
        await tester.pumpAndSettle();
        await tester.tap(stdCard);
        await tester.pumpAndSettle();

        // Tap Thanh toán to reserve PT12 with demo-shape hold (amountVnd: null)
        final payBtn = find.widgetWithText(FilledButton, 'Thanh toán');
        await tester.ensureVisible(payBtn);
        await tester.pumpAndSettle();
        await tester.tap(payBtn);
        await tester.pumpAndSettle();

        expect(adapter.lastReservedCode, 'PT12');
        expect(find.byKey(const Key('offers-hold-card')), findsOneWidget);
        expect(find.text('Đang giữ suất · Chờ thanh toán'), findsOneWidget);
        expect(
          find.text('Gói Tiêu Chuẩn 12 buổi · 4.800.000 ₫'),
          findsOneWidget,
        );
        expect(find.textContaining('· 0 ₫'), findsNothing);

        // Cancel hold and verify returning to normal selection state
        final cancelBtn = find.text('Hủy giữ suất');
        await tester.ensureVisible(cancelBtn);
        await tester.pumpAndSettle();
        await tester.tap(cancelBtn);
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: find.byKey(const Key('offers-hold-card')),
            matching: find.text('Đã hủy giữ suất'),
          ),
          findsOneWidget,
        );

        // Open health declaration from Xem / sửa and verify metrics refresh on return
        final editHealth = find.text('Xem / sửa');
        await tester.ensureVisible(editHealth);
        await tester.pumpAndSettle();
        await tester.tap(editHealth);
        await tester.pumpAndSettle();
        expect(find.text('Khai báo thể trạng'), findsOneWidget);
        await tester.enterText(find.byKey(const Key('health-weight')), '71.5');
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        final saveBtn = find.widgetWithText(FilledButton, 'Lưu khai báo');
        await tester.ensureVisible(saveBtn);
        await tester.pumpAndSettle();
        await tester.tap(saveBtn);
        await tester.pumpAndSettle();

        expect(
          find.text('174 cm · 71.5 kg · Sẵn sàng thuê Coach'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'handles empty offers, load error retry, no-Gym guard, full coach, and missing ApiClient cleanly',
      (tester) async {
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        // 1. Load error -> retry -> empty offers + no Gym + undeclared health + full coach
        final adapter = _PreviewOffersAdapter(
          failFirstLoad: true,
          emptyOffers: true,
          activeGym: false,
          healthDeclared: false,
          availableSlots: 0,
        );
        final client = ApiClient.withAdapter(
          config: ApiConfig.fromValues(environment: 'local'),
          adapter: adapter,
        );

        await tester.pumpWidget(
          Provider<ApiClient>.value(
            value: client,
            child: wrapScreen(
              const CoachOffersPage(coachId: 'coach-1'),
              theme: MetaGymTheme.light,
              textScale: 1.3,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('Máy chủ đang gặp sự cố. Vui lòng thử lại sau.'),
          findsOneWidget,
        );
        expect(find.text('Thử lại'), findsOneWidget);

        await tester.tap(find.text('Thử lại'));
        await tester.pumpAndSettle();

        expect(find.text('Chưa khai báo thể trạng'), findsOneWidget);
        expect(find.text('Khai báo'), findsOneWidget);
        expect(find.text('Gói Gym chưa hiệu lực'), findsOneWidget);
        expect(find.text('Coach đã hết suất'), findsOneWidget);
        expect(find.byKey(const Key('offers-empty-card')), findsOneWidget);
        expect(find.text('Chưa có gói Coach đang mở bán.'), findsOneWidget);
        expect(tester.takeException(), isNull);

        // 2. Assigned to another coach blocks checkout clearly
        final elsewhereAdapter = _PreviewOffersAdapter(
          assignedCoachId: 'coach-other',
        );
        final elsewhereClient = ApiClient.withAdapter(
          config: ApiConfig.fromValues(environment: 'local'),
          adapter: elsewhereAdapter,
        );
        await tester.pumpWidget(
          Provider<ApiClient>.value(
            value: elsewhereClient,
            child: wrapScreen(
              const CoachOffersPage(coachId: 'coach-1'),
              theme: MetaGymTheme.dark,
              textScale: 1.3,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Bạn đã có Coach khác'), findsOneWidget);
        expect(find.text('Đang có Coach khác'), findsOneWidget);
        expect(tester.takeException(), isNull);

        // 3. Missing ApiClient provider does not crash
        await tester.pumpWidget(
          wrapScreen(
            const CoachOffersPage(coachId: 'coach-1'),
            theme: MetaGymTheme.dark,
            textScale: 1.3,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('Chưa kết nối máy chủ'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}

class _PreviewOffersAdapter implements HttpClientAdapter {
  _PreviewOffersAdapter({
    this.failFirstLoad = false,
    this.emptyOffers = false,
    this.activeGym = true,
    this.healthDeclared = true,
    this.availableSlots = 2,
    this.demoShapeHold = false,
    this.assignedCoachId,
  });

  final bool failFirstLoad;
  final bool emptyOffers;
  final bool activeGym;
  bool healthDeclared;
  final int availableSlots;
  final bool demoShapeHold;
  final String? assignedCoachId;

  int _packageLoads = 0;
  double _heightCm = 174;
  double _weightKg = 72.4;
  String? lastReservedCode;

  static const _previewOffers = [
    {
      'code': 'PT24',
      'name': 'Gói Chuyên Sâu 24 buổi',
      'description': '24 buổi tập 1:1 (90 phút) · Giáo trình riêng + Thực đơn tuần + Hỗ trợ chat 24/7',
      'sessionCount': 24,
      'durationDays': 90,
      'price': 8900000,
      'status': 'ACTIVE',
    },
    {
      'code': 'PT12',
      'name': 'Gói Tiêu Chuẩn 12 buổi',
      'description': '12 buổi 1:1 · Giáo trình cá nhân',
      'sessionCount': 12,
      'durationDays': 45,
      'price': 4800000,
      'status': 'ACTIVE',
    },
  ];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path == '/coach-packages') {
      _packageLoads++;
      if (failFirstLoad && _packageLoads == 1) {
        return ResponseBody.fromString(
          jsonEncode({'message': 'Không thể kết nối bảng giá Coach.'}),
          503,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      }
      return _json(emptyOffers ? const <Object>[] : _previewOffers);
    }

    if (options.path == '/users/me/health-declaration' &&
        options.method == 'PATCH') {
      if (requestStream != null) {
        final raw = utf8.decode(
          (await requestStream.toList()).expand((c) => c).toList(),
        );
        if (raw.isNotEmpty) {
          final map = jsonDecode(raw) as Map<String, dynamic>;
          _heightCm = (map['heightCm'] as num?)?.toDouble() ?? _heightCm;
          _weightKg = (map['weightKg'] as num?)?.toDouble() ?? _weightKg;
        }
      }
      healthDeclared = true;
      return _json({
        'profile': {
          'heightCm': _heightCm,
          'weightKg': _weightKg,
          'healthDeclarationCompletedAt': '2026-11-23T08:00:00Z',
        },
      });
    }

    if (options.path == '/coach-payment-holds' && options.method == 'POST') {
      var code = 'PT24';
      if (requestStream != null) {
        final raw = utf8.decode(
          (await requestStream.toList()).expand((c) => c).toList(),
        );
        if (raw.isNotEmpty) {
          final parsed = jsonDecode(raw) as Map<String, dynamic>;
          code = (parsed['planCode'] as String?) ?? code;
        }
      }
      lastReservedCode = code;
      final matched = _previewOffers.firstWhere(
        (o) => o['code'] == code,
        orElse: () => _previewOffers.first,
      );
      return _json({
        'id': 'hold-1',
        'coachId': 'coach-1',
        'planCode': matched['code'],
        'planName': matched['name'],
        if (demoShapeHold) 'amountVnd': null else 'amount': matched['price'],
        'status': 'HELD',
        'expiresAt': '2099-01-01T00:15:00Z',
      });
    }

    if (options.path == '/coach-payment-holds/hold-1/cancel') {
      return _json({
        'id': 'hold-1',
        'coachId': 'coach-1',
        'planCode': lastReservedCode ?? 'PT12',
        'planName': 'Gói Tiêu Chuẩn 12 buổi',
        'amount': 4800000,
        'status': 'CANCELLED',
        'expiresAt': '2099-01-01T00:15:00Z',
      });
    }

    final Object? data = switch (options.path) {
      '/coach-payment-holds' => const <Object>[],
      '/coaches/coach-1' => {
        'id': 'coach-1',
        'fullName': 'Lê Hoàng Nam',
        'specialties': ['Hypertrophy', 'Sức mạnh'],
        'memberLimit': 14,
        'usedSlots': 14 - availableSlots,
        'availableSlots': availableSlots,
      },
      '/users/me' => {
        'id': 'member-1',
        'profile': healthDeclared
            ? {
                'heightCm': _heightCm,
                'weightKg': _weightKg,
                'bodyFatPercent': 15.8,
                'healthNotes': '',
                'injuryNotes': '',
                'healthDeclarationCompletedAt': '2026-11-20T08:00:00Z',
              }
            : <String, Object?>{},
      },
      '/memberships/me' =>
        activeGym
            ? const [
                {
                  'id': 'mem-gold-1',
                  'status': 'ACTIVE',
                  'planName': 'Gói 6 Tháng Elite (Thẻ Vàng)',
                  'startDate': '2026-10-01',
                  'endDate': '2027-03-30',
                },
              ]
            : const <Object>[],
      '/relationships/me' =>
        assignedCoachId == null
            ? null
            : {
                'id': 'rel-1',
                'memberId': 'member-1',
                'coachId': assignedCoachId,
                'status': 'ACTIVE',
              },
      '/coach-entitlements' => const <Object>[],
      _ => throw StateError('Unexpected path: ${options.path}'),
    };
    return _json(data);
  }

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
