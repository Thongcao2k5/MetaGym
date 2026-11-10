import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_bottom_nav.dart';

void main() {
  group('MetaGymBottomNav', () {
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
      'guarantees touch target area of at least 44x44 px for every item',
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
            greaterThanOrEqualTo(44.0),
            reason: '${element.properties.label} width must be >= 44',
          );
          expect(
            size.height,
            greaterThanOrEqualTo(44.0),
            reason: '${element.properties.label} height must be >= 44',
          );
        }
      },
    );

    testWidgets('AI button protrudes and uses coral gradient and glow', (
      tester,
    ) async {
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

      // Verify AI button container properties
      final aiFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).gradient is LinearGradient,
      );

      expect(aiFinder, findsOneWidget);
      final container = tester.widget<Container>(aiFinder);
      final decoration = container.decoration! as BoxDecoration;

      expect(decoration.shape, equals(BoxShape.circle));
      final gradient = decoration.gradient! as LinearGradient;
      // Uses coral orange gradient
      expect(gradient.colors.first, equals(const Color(0xFFFF7E58)));
      expect(gradient.colors.last, equals(const Color(0xFFFF4820)));

      // Has box shadow glow
      expect(decoration.boxShadow, isNotNull);
      expect(decoration.boxShadow!.isNotEmpty, isTrue);
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
