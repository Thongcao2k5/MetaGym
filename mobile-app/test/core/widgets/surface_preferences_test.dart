import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/theme/theme_controller.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/core/widgets/muscle_anatomy_tile.dart';

void main() {
  testWidgets('reduce blur makes featured cards solid', (tester) async {
    Widget screen(bool reduced) => MetaGymSurfacePreferences(
      reduceBlur: reduced,
      child: MaterialApp(
        theme: MetaGymTheme.dark,
        home: const Scaffold(
          body: MetaGymGlassCard(
            key: Key('featured-card'),
            solid: false,
            featured: true,
            child: Text('Card'),
          ),
        ),
      ),
    );
    Color? background() => tester
        .widgetList<Container>(
          find.descendant(
            of: find.byKey(const Key('featured-card')),
            matching: find.byType(Container),
          ),
        )
        .map((widget) => widget.decoration)
        .whereType<BoxDecoration>()
        .first
        .color;
    await tester.pumpWidget(screen(false));
    expect(background(), MetaGymWarmGlassTokens.cardFeaturedFill);
    await tester.pumpWidget(screen(true));
    expect(background(), MetaGymPalette.dark.surfaceSolid);
  });

  testWidgets('anatomy tile uses light surfaces in light mode', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: MetaGymTheme.light,
        home: const Scaffold(body: MuscleAnatomyTile(width: 40, height: 48)),
      ),
    );
    final tile = find.byType(MuscleAnatomyTile);
    final decoration = tester
        .widgetList<Container>(
          find.descendant(of: tile, matching: find.byType(Container)),
        )
        .map((widget) => widget.decoration)
        .whereType<BoxDecoration>()
        .first;
    final gradient = decoration.gradient! as LinearGradient;
    expect(gradient.colors.first, MetaGymColors.light.surfaceRaised);
    expect(gradient.colors.last, MetaGymColors.light.surface);
  });
}
