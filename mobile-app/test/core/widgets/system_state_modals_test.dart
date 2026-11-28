import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_gym_app/core/widgets/system_state_modals.dart';
import 'package:meta_gym_app/features/public/presentation/system_states_page.dart';

void main() {
  testWidgets('State catalogue opens and dismisses each preview modal', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: SystemStatesPage()));
    await tester.pumpAndSettle();
    for (final label in [
      'Màn hình Trống (Empty State)',
      'Mất kết nối mạng (Offline)',
      'Lỗi hệ thống (Error / Retry)',
      'Đang tải dữ liệu (Loading)',
      'Chúc mừng Thành tựu (Streak)',
      'Hệ thống đang bảo trì',
      'Mời gọi mua gói tập VIP',
    ]) {
      final entry = find.text(label);
      await tester.scrollUntilVisible(
        entry,
        240,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(entry);
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      await tester.ensureVisible(find.text('Đóng'));
      await tester.tap(find.text('Đóng'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    'System modal scrolls long text on a small phone with large type',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.6)),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showMetaGymSystemModal(
                  context,
                  kind: MetaGymSystemModalKind.offline,
                  customMessage: List.filled(
                    12,
                    'Vui lòng kiểm tra kết nối mạng trước khi thử lại.',
                  ).join(' '),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(Dialog), const Offset(0, -1800));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('System modal dismisses before invoking its action once', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showMetaGymSystemModal(
                context,
                kind: MetaGymSystemModalKind.serverError,
                onPrimaryAction: () => calls++,
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.byType(Dialog), findsNothing);
  });
}
