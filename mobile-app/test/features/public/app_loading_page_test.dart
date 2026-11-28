import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/features/public/presentation/app_loading_page.dart';

void main() {
  testWidgets(
    'AppLoadingPage keeps percentage label on a single line at 1.2x text scale',
    (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: MetaGymTheme.dark,
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.2)),
            child: const AppLoadingPage(debugProgressOverride: 1.0),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final pctFinder = find.text('100%');
      expect(pctFinder, findsOneWidget);
      expect(tester.getSize(pctFinder).height, lessThan(28));
    },
  );
}
