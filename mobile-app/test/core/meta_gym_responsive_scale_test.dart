import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_responsive_scale.dart';

void main() {
  group('MetaGymResponsiveScale.scaleForSize', () {
    test('returns 1.0 on phone viewports (portrait & landscape)', () {
      expect(MetaGymResponsiveScale.scaleForSize(const Size(375, 812)), 1.0);
      expect(MetaGymResponsiveScale.scaleForSize(const Size(393, 852)), 1.0);
      expect(MetaGymResponsiveScale.scaleForSize(const Size(844, 390)), 1.0);
      expect(MetaGymResponsiveScale.scaleForSize(const Size(599, 960)), 1.0);
    });

    test('ramps proportionally on tablet viewports and caps at 1.42', () {
      final smallTablet = MetaGymResponsiveScale.scaleForSize(
        const Size(600, 960),
      );
      final smX520Portrait = MetaGymResponsiveScale.scaleForSize(
        const Size(822.9, 1316.6),
      );
      final smX520Landscape = MetaGymResponsiveScale.scaleForSize(
        const Size(1316.6, 822.9),
      );
      final largeTablet = MetaGymResponsiveScale.scaleForSize(
        const Size(1024, 1366),
      );

      expect(smallTablet, closeTo(1.12, 0.01));
      expect(smX520Portrait, closeTo(1.352, 0.01));
      expect(smX520Landscape, closeTo(smX520Portrait, 0.001));
      expect(largeTablet, 1.42);
      // Preserves >= 600dp virtual width on 10–11" tablets for tablet breakpoints.
      expect(822.9 / smX520Portrait, greaterThanOrEqualTo(600.0));
    });
  });

  group('MetaGymResponsiveScale widget', () {
    testWidgets('scales MediaQuery size, DPR, and insets proportionally', (
      tester,
    ) async {
      late MediaQueryData innerMq;

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(823, 1317),
            devicePixelRatio: 1.75,
            padding: EdgeInsets.only(top: 28, bottom: 56),
            viewPadding: EdgeInsets.only(top: 28, bottom: 56),
            viewInsets: EdgeInsets.only(bottom: 320),
          ),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: MetaGymResponsiveScale(
              enabled: true,
              child: Builder(
                builder: (context) {
                  innerMq = MediaQuery.of(context);
                  return const SizedBox.expand();
                },
              ),
            ),
          ),
        ),
      );

      final expectedScale = MetaGymResponsiveScale.scaleForSize(
        const Size(823, 1317),
      );
      expect(innerMq.size.width, closeTo(823 / expectedScale, 0.1));
      expect(innerMq.size.height, closeTo(1317 / expectedScale, 0.1));
      expect(innerMq.devicePixelRatio, closeTo(1.75 * expectedScale, 0.01));
      expect(innerMq.padding.top, closeTo(28 / expectedScale, 0.1));
      expect(innerMq.padding.bottom, closeTo(56 / expectedScale, 0.1));
      expect(innerMq.viewInsets.bottom, closeTo(320 / expectedScale, 0.1));
    });

    testWidgets('is a no-op on phone sizes even when enabled', (tester) async {
      late MediaQueryData innerMq;

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(390, 844),
            devicePixelRatio: 3.0,
          ),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: MetaGymResponsiveScale(
              enabled: true,
              child: Builder(
                builder: (context) {
                  innerMq = MediaQuery.of(context);
                  return const SizedBox.expand();
                },
              ),
            ),
          ),
        ),
      );

      expect(innerMq.size, const Size(390, 844));
      expect(innerMq.devicePixelRatio, 3.0);
    });
  });
}
