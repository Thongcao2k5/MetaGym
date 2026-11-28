import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_gym_app/core/network/api_cache_interceptor.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/offline_cache_banner.dart';

void main() {
  group('OfflineCacheBannerOverlay', () {
    testWidgets(
      'is hidden online, appears on cached fallback with timestamp, dismisses on tap, and hides when back online',
      (tester) async {
        final controller = ApiCacheStatusController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          MaterialApp(
            theme: MetaGymTheme.dark,
            home: OfflineCacheBannerOverlay(
              controller: controller,
              child: const Scaffold(body: Center(child: Text('Nội dung'))),
            ),
          ),
        );

        expect(find.byKey(const Key('offline-cache-banner')), findsNothing);

        final syncedAt = DateTime.now().subtract(const Duration(minutes: 5));
        controller.recordCacheFallback(syncedAt);
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('offline-cache-banner')), findsOneWidget);
        expect(find.textContaining('Đang xem dữ liệu đã lưu'), findsOneWidget);
        expect(find.textContaining('Cập nhật'), findsOneWidget);

        // Đạt kích thước tối thiểu vùng chạm 44x44
        final dismissSize = tester.getSize(
          find.byKey(const Key('offline-cache-banner-dismiss')),
        );
        expect(dismissSize.width, greaterThanOrEqualTo(44));
        expect(dismissSize.height, greaterThanOrEqualTo(44));

        // Bấm đóng banner
        await tester.tap(find.byKey(const Key('offline-cache-banner-dismiss')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('offline-cache-banner')), findsNothing);

        // Chuyển về online rồi fallback lại -> banner hiện lại
        controller.recordLiveSuccess(DateTime.now());
        await tester.pump();
        controller.recordCacheFallback(DateTime.now());
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('offline-cache-banner')), findsOneWidget);

        // Khi kết nối lại thành công -> tự ẩn banner
        controller.recordLiveSuccess(DateTime.now());
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('offline-cache-banner')), findsNothing);
      },
    );

    for (final themeEntry in <String, ThemeData>{
      'dark': MetaGymTheme.dark,
      'light': MetaGymTheme.light,
    }.entries) {
      for (final viewport in const [Size(375, 812), Size(667, 375)]) {
        testWidgets(
          'renders cleanly without overflow (${themeEntry.key}, ${viewport.width.toInt()}x${viewport.height.toInt()})',
          (tester) async {
            tester.view.physicalSize = viewport;
            tester.view.devicePixelRatio = 1.0;
            addTearDown(tester.view.reset);

            final controller = ApiCacheStatusController();
            addTearDown(controller.dispose);
            controller.recordCacheFallback(DateTime.now());

            await tester.pumpWidget(
              MaterialApp(
                theme: themeEntry.value,
                home: OfflineCacheBannerOverlay(
                  controller: controller,
                  child: const Scaffold(body: SizedBox.expand()),
                ),
              ),
            );
            await tester.pumpAndSettle();

            expect(
              find.byKey(const Key('offline-cache-banner')),
              findsOneWidget,
            );
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  });
}
