import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/theme/meta_gym_icons.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_svg_icon.dart';

void main() {
  group('MetaGymTheme & Design System Tokens', () {
    test('aligns core dark tokens with DESIGN.md and tokens.css', () {
      expect(MetaGymTheme.scaffoldBackground, const Color(0xFF0F1115));
      expect(MetaGymTheme.cardSurface, const Color(0xFF181B22));
      expect(MetaGymTheme.elevatedSurface, const Color(0xFF1F232C));
      expect(MetaGymTheme.cardBorder, const Color(0xFF262A34));
      expect(MetaGymTheme.primary, const Color(0xFFFF5E36));
      expect(MetaGymTheme.brandOrangeHover, const Color(0xFFE84E27));
      expect(MetaGymTheme.textPrimary, const Color(0xFFF7F9FC));
      expect(MetaGymTheme.textSecondary, const Color(0xFF8E95A5));
      expect(MetaGymTheme.performanceGlassBlur, 12);
      expect(MetaGymTheme.overlayGlassBlur, 18);
    });

    testWidgets('exposes Dark and Light MetaGymPalette via ThemeExtension', (
      tester,
    ) async {
      late MetaGymPalette darkPalette;
      late MetaGymPalette lightPalette;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Builder(
            builder: (context) {
              darkPalette = MetaGymTheme.paletteOf(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(darkPalette.canvas, const Color(0xFF0F1115));
      expect(darkPalette.surfaceSolid, const Color(0xFF181B22));
      expect(darkPalette.textPrimary, const Color(0xFFF7F9FC));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) {
              lightPalette = MetaGymTheme.paletteOf(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(lightPalette.canvas, const Color(0xFFE8EEF5));
      expect(lightPalette.surfaceSolid, const Color(0xFFFFFFFF));
      expect(lightPalette.textPrimary, const Color(0xFF11151A));
    });

    testWidgets(
      'MetaGymSvgIcon and glass surfaces render cleanly in dark and light modes',
      (tester) async {
        for (final theme in [AppTheme.dark, AppTheme.light]) {
          await tester.pumpWidget(
            MaterialApp(
              theme: theme,
              home: Scaffold(
                body: Column(
                  children: [
                    const MetaGymHeroGlassCard(
                      child: Row(
                        children: [
                          MetaGymSvgIcon(
                            MetaGymIcons.navHomeFilled,
                            size: 24,
                            semanticsLabel: 'Trang chủ',
                          ),
                          SizedBox(width: 8),
                          Text('Hero Card'),
                        ],
                      ),
                    ),
                    const MetaGymGlassCard(
                      padding: EdgeInsets.all(16),
                      child: Text('Solid Level 1 Card'),
                    ),
                    MetaGymCircleIconButton(
                      icon: Icons.notifications_none_rounded,
                      svgAsset: MetaGymIcons.settingThemeAppearance,
                      tooltip: 'Giao diện',
                      onTap: () {},
                    ),
                  ],
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(MetaGymSvgIcon), findsNWidgets(2));
          expect(find.text('Hero Card'), findsOneWidget);
          expect(find.text('Solid Level 1 Card'), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
      },
    );
  });
}
