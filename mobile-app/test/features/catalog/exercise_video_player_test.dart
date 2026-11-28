import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/features/catalog/presentation/exercise_video_player.dart';
import 'package:video_player/video_player.dart';

class _FakeVideoPlayerController extends VideoPlayerController {
  _FakeVideoPlayerController(
    super.dataSource, {
    this.failInitialize = false,
  }) : super.asset();

  final bool failInitialize;
  int initializeCalls = 0;
  final List<bool> loopCalls = <bool>[];
  int playCalls = 0;
  int pauseCalls = 0;
  int disposeCalls = 0;

  @override
  Future<void> initialize() async {
    initializeCalls++;
    if (failInitialize) {
      throw MissingPluginException('video_player unavailable in test');
    }
    value = value.copyWith(
      duration: const Duration(seconds: 6),
      size: const Size(854, 480),
      isInitialized: true,
    );
  }

  @override
  Future<void> setLooping(bool looping) async {
    loopCalls.add(looping);
    value = value.copyWith(isLooping: looping);
  }

  @override
  Future<void> play() async {
    playCalls++;
    value = value.copyWith(isPlaying: true);
  }

  @override
  Future<void> pause() async {
    pauseCalls++;
    value = value.copyWith(isPlaying: false);
  }

  @override
  Future<void> dispose() async {
    disposeCalls++;
    await super.dispose();
  }
}

void main() {
  testWidgets(
    'accepts bundled asset video, shows loop badge, calls setLooping(true) and play()',
    (tester) async {
      final createdUrls = <String>[];
      late _FakeVideoPlayerController controller;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: ExerciseVideoPlayer(
              url: '  assets/videos/catalog/pec_deck_fly_480p.mp4  ',
              controllerFactory: (url) {
                createdUrls.add(url);
                controller = _FakeVideoPlayerController(url);
                return controller;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(createdUrls, ['assets/videos/catalog/pec_deck_fly_480p.mp4']);
      expect(controller.initializeCalls, 1);
      expect(controller.loopCalls, [true]);
      expect(controller.playCalls, 1);
      expect(find.text('Đường dẫn video không hợp lệ.'), findsNothing);
      expect(find.text('Video hướng dẫn'), findsOneWidget);
      expect(find.text('Lặp tự động'), findsOneWidget);
      expect(find.byTooltip('Tạm dừng'), findsOneWidget);

      await tester.tap(find.byTooltip('Tạm dừng'));
      await tester.pumpAndSettle();
      expect(controller.pauseCalls, 1);
      expect(find.byTooltip('Phát video'), findsNWidgets(2));

      await tester.tap(find.byTooltip('Phát video').first);
      await tester.pumpAndSettle();
      expect(controller.playCalls, 2);
    },
  );

  testWidgets(
    'respects loop: false and autoPlay: false and hides loop badge',
    (tester) async {
      late _FakeVideoPlayerController controller;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: ExerciseVideoPlayer(
              url: 'assets/videos/catalog/seated_leg_curl_480p.mp4',
              loop: false,
              autoPlay: false,
              controllerFactory: (url) {
                controller = _FakeVideoPlayerController(url);
                return controller;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(controller.initializeCalls, 1);
      expect(controller.loopCalls, [false]);
      expect(controller.playCalls, 0);
      expect(find.text('Video hướng dẫn'), findsOneWidget);
      expect(find.text('Lặp tự động'), findsNothing);
      expect(find.byTooltip('Phát video'), findsNWidgets(2));
    },
  );

  testWidgets('rejects invalid URLs cleanly', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(
          body: ExerciseVideoPlayer(url: 'ftp://invalid.example/video.mp4'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Đường dẫn video không hợp lệ.'), findsOneWidget);
    expect(find.text('Thử lại'), findsOneWidget);
  });

  testWidgets(
    'handles plugin initialization failure gracefully without uncaught errors',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: ExerciseVideoPlayer(
              url: 'assets/videos/catalog/assisted_pull_up_480p.mp4',
              controllerFactory: (url) =>
                  _FakeVideoPlayerController(url, failInitialize: true),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Đường dẫn video không hợp lệ.'), findsNothing);
      expect(find.text('Không tải được video. Hãy thử lại.'), findsOneWidget);
      expect(find.text('Thử lại'), findsOneWidget);
    },
  );

  for (final entry in [('dark', AppTheme.dark), ('light', AppTheme.light)]) {
    testWidgets(
      'renders cleanly without overflow at 375x812 @ 1.3x (${entry.$1})',
      (tester) async {
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            theme: entry.$2,
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(375, 812),
                textScaler: TextScaler.linear(1.3),
              ),
              child: Scaffold(
                body: Padding(
                  padding: const EdgeInsets.all(16),
                  child: ExerciseVideoPlayer(
                    url: 'assets/videos/catalog/reverse_machine_fly_480p.mp4',
                    controllerFactory: (url) => _FakeVideoPlayerController(url),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Video hướng dẫn'), findsOneWidget);
        expect(find.text('Lặp tự động'), findsOneWidget);
      },
    );
  }
}
