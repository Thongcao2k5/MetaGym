import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/theme/theme_mode_controller.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';

void main() {
  group('ThemeModeController', () {
    test('defaults to light mode and notifies on toggle', () async {
      final controller = ThemeModeController(persist: false);
      var notifications = 0;
      controller.addListener(() => notifications++);

      expect(controller.themeMode, ThemeMode.light);
      expect(controller.isLight, isTrue);

      await controller.setThemeMode(ThemeMode.dark);
      expect(controller.themeMode, ThemeMode.dark);
      expect(controller.isLight, isFalse);
      expect(notifications, 1);

      await controller.toggle();
      expect(controller.themeMode, ThemeMode.light);
      expect(controller.isLight, isTrue);
      expect(notifications, 2);

      controller.dispose();
    });
  });

  group('MetaGymBackground', () {
    testWidgets('uses bg_app_dark.webp in dark theme', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: MetaGymTheme.light,
          darkTheme: MetaGymTheme.dark,
          themeMode: ThemeMode.dark,
          home: const Scaffold(body: MetaGymBackground()),
        ),
      );

      final image = tester.widget<Image>(find.byType(Image));
      expect(image.image, MetaGymBackground.darkBackgroundAsset);
      expect(
        (image.image as AssetImage).assetName,
        'assets/images/backgrounds/bg_app_dark.webp',
      );
    });

    testWidgets('uses bg_app_light.webp in light theme', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: MetaGymTheme.light,
          darkTheme: MetaGymTheme.dark,
          themeMode: ThemeMode.light,
          home: const Scaffold(body: MetaGymBackground()),
        ),
      );

      final image = tester.widget<Image>(find.byType(Image));
      expect(image.image, MetaGymBackground.lightBackgroundAsset);
      expect(
        (image.image as AssetImage).assetName,
        'assets/images/backgrounds/bg_app_light.webp',
      );
    });
  });
}
