import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_bottom_nav.dart';

void main() {
  group('MetaGymBottomNav', () {
    for (final width in [375.0, 768.0]) {
      for (final warm in [false, true]) {
        for (final reduced in [false, true]) {
          testWidgets(
            'AI pressed feedback: width=$width warm=$warm reduced=$reduced',
            (tester) async {
              tester.view.physicalSize = Size(width, 900);
              tester.view.devicePixelRatio = 1;
              addTearDown(tester.view.reset);
              var taps = 0;
              await tester.pumpWidget(
                MaterialApp(
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(disableAnimations: reduced),
                    child: child!,
                  ),
                  home: Scaffold(
                    bottomNavigationBar: MetaGymBottomNav(
                      currentIndex: 0,
                      warmGlass: warm,
                      onTap: (_) => taps++,
                    ),
                  ),
                ),
              );
              final ai = find.byWidgetPredicate(
                (widget) =>
                    widget is Semantics && widget.properties.label == 'AI',
              );
              final gesture = await tester.startGesture(
                tester.getCenter(find.byIcon(Icons.auto_awesome_rounded)),
              );
              await tester.pump(const Duration(milliseconds: 110));
              expect(taps, 0);
              final scales = tester.widgetList<AnimatedScale>(
                find.descendant(of: ai, matching: find.byType(AnimatedScale)),
              );
              expect(scales.any((scale) => scale.scale < 1), !reduced);
              await gesture.up();
              await tester.pumpAndSettle();
              expect(taps, 1);
              expect(tester.takeException(), isNull);
            },
          );
        }
      }
    }

    testWidgets('renders all 5 items in the exact required order', (
      tester,
    ) async {
      int selectedIndex = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: MetaGymBottomNav(
              currentIndex: selectedIndex,
              onTap: (index) => selectedIndex = index,
            ),
          ),
        ),
      );

      // Verify 5 tab labels in order: Trang chủ · Tập luyện · AI · Tin nhắn · Hồ sơ
      expect(find.text('Trang chủ'), findsOneWidget);
      expect(find.text('Tập luyện'), findsOneWidget);
      expect(find.text('AI'), findsOneWidget);
      expect(find.text('Tin nhắn'), findsOneWidget);
      expect(find.text('Hồ sơ'), findsOneWidget);

      // Verify AI button is in the center
      final aiFinder = find.text('AI');
      final homeFinder = find.text('Trang chủ');
      final profileFinder = find.text('Hồ sơ');

      final aiCenter = tester.getCenter(aiFinder);
      final homeCenter = tester.getCenter(homeFinder);
      final profileCenter = tester.getCenter(profileFinder);

      expect(homeCenter.dx < aiCenter.dx, isTrue);
      expect(aiCenter.dx < profileCenter.dx, isTrue);
    });

    testWidgets('triggers onTap callback when tabs are pressed', (
      tester,
    ) async {
      int? tappedIndex;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: MetaGymBottomNav(
              currentIndex: 0,
              onTap: (index) => tappedIndex = index,
            ),
          ),
        ),
      );

      // Tap Tập luyện (index 1)
      await tester.tap(find.text('Tập luyện'));
      await tester.pumpAndSettle();
      expect(tappedIndex, equals(1));

      // Tap AI (index 2)
      await tester.tap(find.text('AI'));
      await tester.pumpAndSettle();
      expect(tappedIndex, equals(2));

      // Tap Tin nhắn (index 3)
      await tester.tap(find.text('Tin nhắn'));
      await tester.pumpAndSettle();
      expect(tappedIndex, equals(3));

      // Tap Hồ sơ (index 4)
      await tester.tap(find.text('Hồ sơ'));
      await tester.pumpAndSettle();
      expect(tappedIndex, equals(4));

      // Tap Trang chủ (index 0)
      await tester.tap(find.text('Trang chủ'));
      await tester.pumpAndSettle();
      expect(tappedIndex, equals(0));
    });

    testWidgets(
      'guarantees touch target area of at least 48x48 dp for every item',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              bottomNavigationBar: MetaGymBottomNav(
                currentIndex: 0,
                onTap: (_) {},
              ),
            ),
          ),
        );

        final navItemSemantics = find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.button == true &&
              widget.properties.label != null &&
              [
                'Trang chủ',
                'Tập luyện',
                'AI',
                'Tin nhắn',
                'Hồ sơ',
              ].contains(widget.properties.label),
        );

        expect(navItemSemantics, findsNWidgets(5));

        for (final element in tester.widgetList<Semantics>(navItemSemantics)) {
          final itemFinder = find.byWidget(element);
          final size = tester.getSize(itemFinder);
          expect(
            size.width,
            greaterThanOrEqualTo(48.0),
            reason: '${element.properties.label} width must be >= 48',
          );
          expect(
            size.height,
            greaterThanOrEqualTo(48.0),
            reason: '${element.properties.label} height must be >= 48',
          );
        }
      },
    );

    testWidgets('AI button uses coral only while selected', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: MetaGymBottomNav(
              currentIndex: 2,
              onTap: (_) {},
            ),
          ),
        ),
      );

      final aiFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).shape == BoxShape.circle &&
            (widget.decoration as BoxDecoration).color ==
                MetaGymTheme.brandOrange,
      );

      expect(aiFinder, findsOneWidget);
      final container = tester.widget<Container>(aiFinder);
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.shape, equals(BoxShape.circle));
      expect(decoration.boxShadow, isNotNull);
      expect(decoration.boxShadow!.isNotEmpty, isTrue);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: MetaGymBottomNav(
              currentIndex: 0,
              onTap: (_) {},
            ),
          ),
        ),
      );
      final inactiveAi = find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).shape == BoxShape.circle &&
            (widget.decoration as BoxDecoration).color ==
                MetaGymTheme.darkSurfaceRaised,
      );
      expect(inactiveAi, findsOneWidget);
    });

    testWidgets(
      'respects reduce motion (disableAnimations) by setting duration to zero',
      (tester) async {
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: MaterialApp(
              home: Scaffold(
                bottomNavigationBar: MetaGymBottomNav(
                  currentIndex: 0,
                  onTap: (_) {},
                ),
              ),
            ),
          ),
        );

        // With disableAnimations: true, animated align should be rendered with Duration.zero
        final animatedAlignFinder = find.byType(AnimatedAlign);
        expect(animatedAlignFinder, findsOneWidget);
        final animatedAlign = tester.widget<AnimatedAlign>(animatedAlignFinder);
        expect(animatedAlign.duration, equals(Duration.zero));
      },
    );

    testWidgets(
      'provides contentBottomPadding helper to prevent obscuring content',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                final padding = MetaGymBottomNav.contentBottomPadding(context);
                expect(padding, greaterThan(80.0));
                return const SizedBox();
              },
            ),
          ),
        );
      },
    );
  });
}
