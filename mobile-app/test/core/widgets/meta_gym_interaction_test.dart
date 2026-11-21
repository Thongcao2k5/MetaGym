import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:meta_gym_app/core/navigation/meta_gym_navigation.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_action_button.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_tap.dart';
import 'package:meta_gym_app/features/coaching/presentation/termination_reason_dialog.dart';

void main() {
  testWidgets(
    'confirmation opens once, validates empty reason and can be cancelled',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => MetaGymNavigation.showDialogOnce<String>(
                  context: context,
                  builder: (_) => const TerminationReasonDialog(),
                ),
                child: const Text('Kết thúc'),
              ),
            ),
          ),
        ),
      );
      final open = tester
          .widget<TextButton>(find.byType(TextButton))
          .onPressed!;
      open();
      open();
      await tester.pumpAndSettle();
      expect(find.byType(TerminationReasonDialog), findsOneWidget);
      await tester.tap(find.text('Xác nhận kết thúc'));
      await tester.pumpAndSettle();
      expect(find.text('Vui lòng nhập lý do.'), findsOneWidget);
      await tester.tap(find.text('Quay lại'));
      await tester.pumpAndSettle();
      expect(find.byType(TerminationReasonDialog), findsNothing);
      open();
      await tester.pumpAndSettle();
      expect(find.byType(TerminationReasonDialog), findsOneWidget);
      await tester.tap(find.text('Quay lại'));
      await tester.pumpAndSettle();
    },
  );

  Widget host(Widget child, {bool reduced = false}) => MaterialApp(
    theme: MetaGymTheme.dark,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        disableAnimations: reduced,
        textScaler: TextScaler.linear(reduced ? 1.3 : 1),
      ),
      child: child!,
    ),
    home: Scaffold(body: Center(child: child)),
  );

  testWidgets(
    'async CTA locks immediately and reports success after completion',
    (tester) async {
      final pending = Completer<void>();
      var calls = 0;
      await tester.pumpWidget(
        host(
          MetaGymActionButton(
            label: 'Lưu',
            showSuccessOnCompletion: true,
            onPressed: () {
              calls++;
              return pending.future;
            },
          ),
        ),
      );
      final button = find.byType(FilledButton);
      await tester.tap(button);
      await tester.tap(button);
      await tester.pump();
      expect(calls, 1);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Đã xong'), findsNothing);
      pending.complete();
      await tester.pumpAndSettle();
      expect(find.text('Đã xong'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'failed CTA exposes error and allows retry, disabled CTA stays inert',
    (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        host(
          MetaGymActionButton(
            label: 'Đặt lịch',
            onPressed: () async {
              calls++;
              throw StateError('API failed');
            },
          ),
        ),
      );
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(find.text('Có lỗi · Thử lại'), findsOneWidget);
      expect(find.text('Đã xong'), findsNothing);
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(calls, 2);
      await tester.pumpWidget(
        host(
          MetaGymActionButton(
            label: 'Đặt lịch',
            enabled: false,
            onPressed: () {
              calls++;
            },
          ),
        ),
      );
      await tester.tap(find.byType(FilledButton));
      expect(calls, 2);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('card action consumes its own tap without opening the parent', (
    tester,
  ) async {
    var cardCalls = 0;
    var actionCalls = 0;
    await tester.pumpWidget(
      host(
        MetaGymGlassCard(
          onTap: () {
            cardCalls++;
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Chi tiết'),
              TextButton(
                onPressed: () {
                  actionCalls++;
                },
                child: const Text('Hủy'),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
    expect(actionCalls, 1);
    expect(cardCalls, 0);
    await tester.tap(find.text('Chi tiết'));
    await tester.pumpAndSettle();
    expect(cardCalls, 1);
  });

  testWidgets('detail route opens once and returns to the same origin', (
    tester,
  ) async {
    var opened = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () {
                MetaGymNavigation.pushOnce<void>(
                  context,
                  MetaGymPageRoute(
                    builder: (_) {
                      opened++;
                      return Scaffold(
                        appBar: AppBar(title: const Text('Chi tiết')),
                        body: const Text('Trang chi tiết'),
                      );
                    },
                  ),
                );
              },
              child: const Text('Mở'),
            ),
          ),
        ),
      ),
    );
    final callback = tester
        .widget<TextButton>(find.byType(TextButton))
        .onPressed!;
    callback();
    callback();
    await tester.pumpAndSettle();
    expect(opened, 1);
    expect(find.text('Trang chi tiết'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Mở'), findsOneWidget);
    await tester.tap(find.text('Mở'));
    await tester.pumpAndSettle();
    expect(opened, 2);
  });

  testWidgets('declarative route rejects double push and releases after back', (
    tester,
  ) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: TextButton(
              onPressed: () =>
                  MetaGymNavigation.pushPathOnce(context, '/detail'),
              child: const Text('Mở'),
            ),
          ),
        ),
        GoRoute(
          path: '/detail',
          builder: (_, _) => const Scaffold(body: Text('Chi tiết')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    final callback = tester
        .widget<TextButton>(find.byType(TextButton))
        .onPressed!;
    callback();
    callback();
    await tester.pumpAndSettle();
    router.pop();
    await tester.pumpAndSettle();
    expect(router.canPop(), isFalse);
    expect(find.text('Mở'), findsOneWidget);
    await tester.tap(find.text('Mở'));
    await tester.pumpAndSettle();
    expect(find.text('Chi tiết'), findsOneWidget);
  });

  for (final width in [375.0, 768.0]) {
    testWidgets(
      'controls at width $width remain visible with reduced motion and larger text',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          host(
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                MetaGymCircleIconButton(
                  icon: Icons.arrow_back_rounded,
                  tooltip: 'Quay lại',
                  onTap: () {},
                ),
                MetaGymActionButton(
                  label: 'Xác nhận thanh toán mô phỏng',
                  onPressed: () {},
                ),
              ],
            ),
            reduced: true,
          ),
        );
        expect(tester.takeException(), isNull);
        expect(
          tester.getSize(find.byType(MetaGymCircleIconButton)),
          const Size(48, 48),
        );
        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(MetaGymCircleIconButton)),
        );
        await tester.pump();
        for (final scale in tester.widgetList<AnimatedScale>(
          find.byType(AnimatedScale),
        )) {
          expect(scale.duration, Duration.zero);
          expect(scale.scale, 1);
        }
        await gesture.up();
        await tester.pumpAndSettle();
      },
    );
  }

  testWidgets('custom tap responds to focus and keyboard activation', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      host(
        MetaGymTap(
          semanticLabel: 'Mở lịch',
          onTap: () {
            calls++;
          },
          child: const Text('Lịch'),
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(calls, 1);
  });
}
