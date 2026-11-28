import 'dart:async';

import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/theme/meta_gym_icons.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_svg_icon.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

typedef ExerciseVideoControllerFactory =
    VideoPlayerController Function(String url);

/// Plays bundled asset preview videos, direct network videos, or YouTube links
/// inside equipment and exercise detail pages.
class ExerciseVideoPlayer extends StatefulWidget {
  const ExerciseVideoPlayer({
    required this.url,
    this.loop = true,
    this.autoPlay = true,
    this.controllerFactory,
    super.key,
  });

  final String url;
  final bool loop;
  final bool autoPlay;
  final ExerciseVideoControllerFactory? controllerFactory;

  @override
  State<ExerciseVideoPlayer> createState() => _ExerciseVideoPlayerState();
}

class _ExerciseVideoPlayerState extends State<ExerciseVideoPlayer>
    with WidgetsBindingObserver {
  VideoPlayerController? _fileController;
  YoutubePlayerController? _youtubeController;
  String? _error;
  bool _loading = false;
  bool _wasPlayingBeforePause = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _openVideo();
  }

  @override
  void didUpdateWidget(covariant ExerciseVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url ||
        oldWidget.loop != widget.loop ||
        oldWidget.autoPlay != widget.autoPlay ||
        oldWidget.controllerFactory != widget.controllerFactory) {
      _openVideo();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _fileController;
    if (controller == null || !controller.value.isInitialized) return;
    if (state == AppLifecycleState.resumed) {
      if (_wasPlayingBeforePause) {
        _wasPlayingBeforePause = false;
        unawaited(controller.play().catchError((Object _) {}));
      }
      return;
    }
    if (controller.value.isPlaying) {
      _wasPlayingBeforePause = true;
      unawaited(controller.pause().catchError((Object _) {}));
    }
  }

  void _disposeControllers() {
    final fileController = _fileController;
    _fileController = null;
    if (fileController != null) {
      unawaited(fileController.dispose().catchError((Object _) {}));
    }
    final youtubeController = _youtubeController;
    _youtubeController = null;
    if (youtubeController != null) {
      unawaited(youtubeController.close().catchError((Object _) {}));
    }
  }

  void _openVideo() {
    _disposeControllers();
    _error = null;
    _loading = false;
    _wasPlayingBeforePause = false;

    final trimmed = widget.url.trim();
    if (trimmed.isEmpty) {
      _error = 'Đường dẫn video không hợp lệ.';
      return;
    }

    if (trimmed.startsWith('assets/')) {
      _startFileController(
        () =>
            widget.controllerFactory?.call(trimmed) ??
            VideoPlayerController.asset(trimmed),
      );
      return;
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null || !{'http', 'https'}.contains(uri.scheme)) {
      _error = 'Đường dẫn video không hợp lệ.';
      return;
    }

    final host = uri.host.toLowerCase();
    final isYouTube =
        host == 'youtu.be' ||
        host == 'youtube.com' ||
        host.endsWith('.youtube.com') ||
        host == 'youtube-nocookie.com' ||
        host.endsWith('.youtube-nocookie.com');
    if (isYouTube) {
      final id = YoutubePlayerController.convertUrlToId(trimmed);
      if (id == null) {
        _error = 'Không nhận diện được video YouTube.';
        return;
      }
      try {
        _youtubeController = YoutubePlayerController.fromVideoId(
          videoId: id,
          autoPlay: widget.autoPlay,
          params: YoutubePlayerParams(
            showControls: true,
            showFullscreenButton: true,
            interfaceLanguage: 'vi',
            loop: widget.loop,
          ),
        );
      } catch (_) {
        _error = 'Không tải được video. Hãy thử lại.';
      }
      return;
    }

    _startFileController(
      () =>
          widget.controllerFactory?.call(trimmed) ??
          VideoPlayerController.networkUrl(uri),
    );
  }

  void _startFileController(VideoPlayerController Function() createController) {
    final VideoPlayerController controller;
    try {
      controller = createController();
    } catch (_) {
      _error = 'Không tải được video. Hãy thử lại.';
      return;
    }

    _fileController = controller;
    _loading = true;
    unawaited(_initializeFileController(controller));
  }

  Future<void> _initializeFileController(
    VideoPlayerController controller,
  ) async {
    try {
      await controller.initialize();
      if (!mounted || !identical(_fileController, controller)) return;

      try {
        await controller.setLooping(widget.loop);
      } catch (_) {}

      if (!mounted || !identical(_fileController, controller)) return;

      if (widget.autoPlay) {
        try {
          await controller.play();
        } catch (_) {}
      }

      if (!mounted || !identical(_fileController, controller)) return;
      setState(() => _loading = false);
    } catch (_) {
      if (!mounted || !identical(_fileController, controller)) return;
      setState(() {
        _loading = false;
        _error = 'Không tải được video. Hãy thử lại.';
      });
    }
  }

  void _togglePlayPause(VideoPlayerController controller) {
    if (!controller.value.isInitialized) return;
    _wasPlayingBeforePause = false;
    if (controller.value.isPlaying) {
      unawaited(controller.pause().catchError((Object _) {}));
    } else {
      unawaited(controller.play().catchError((Object _) {}));
    }
  }

  void _play(VideoPlayerController controller) {
    if (!controller.value.isInitialized) return;
    _wasPlayingBeforePause = false;
    unawaited(controller.play().catchError((Object _) {}));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposeControllers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = MetaGymTheme.paletteOf(context);
    return MetaGymGlassCard(
      solid: false,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_youtubeController != null)
            YoutubePlayer(controller: _youtubeController!, aspectRatio: 16 / 9)
          else
            AspectRatio(
              aspectRatio: 16 / 9,
              child: _error != null
                  ? _videoMessage(
                      _error!,
                      action: TextButton.icon(
                        onPressed: () => setState(_openVideo),
                        style: TextButton.styleFrom(
                          foregroundColor: palette.primaryText,
                          minimumSize: const Size(48, 48),
                        ),
                        icon: const MetaGymSvgIcon(
                          MetaGymIcons.commonRefresh,
                          size: 18,
                          fallbackIcon: Icons.refresh_rounded,
                        ),
                        label: const Text('Thử lại'),
                      ),
                    )
                  : _loading
                  ? _videoMessage(
                      'Đang tải video…',
                      showIcon: false,
                      action: const Padding(
                        padding: EdgeInsets.only(top: 10),
                        child: CircularProgressIndicator(
                          color: MetaGymTheme.primary,
                        ),
                      ),
                    )
                  : _filePlayer(),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: LayoutBuilder(
              builder: (context, constraints) => Row(
                children: [
                  const MetaGymSvgIcon(
                    MetaGymIcons.exerciseVideoPlay,
                    size: 19,
                    fallbackIcon: Icons.ondemand_video_rounded,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Video hướng dẫn',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (widget.loop) ...[
                    const SizedBox(width: 8),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: constraints.maxWidth * 0.48,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: palette.chipActiveBg,
                          borderRadius: BorderRadius.circular(
                            MetaGymTheme.radiusFull,
                          ),
                          border: Border.all(
                            color: MetaGymTheme.primary.withValues(alpha: 0.34),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.repeat_rounded,
                              size: 13,
                              color: palette.chipActiveText,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'Lặp tự động',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: palette.chipActiveText,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filePlayer() {
    final controller = _fileController;
    if (controller == null || !controller.value.isInitialized) {
      return _videoMessage('Video chưa sẵn sàng.');
    }
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final hasDimensions = value.size.width > 0 && value.size.height > 0;
        return Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(
              color: const Color(0xFF0A0C10),
              child: Semantics(
                button: true,
                label: value.isPlaying ? 'Tạm dừng video' : 'Phát video',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _togglePlayPause(controller),
                  child: hasDimensions
                      ? FittedBox(
                          fit: BoxFit.contain,
                          child: SizedBox(
                            width: value.size.width,
                            height: value.size.height,
                            child: VideoPlayer(controller),
                          ),
                        )
                      : VideoPlayer(controller),
                ),
              ),
            ),
            if (!value.isPlaying)
              Center(
                child: IconButton.filled(
                  tooltip: 'Phát video',
                  onPressed: () => _play(controller),
                  icon: const MetaGymSvgIcon(
                    MetaGymIcons.exerciseVideoPlay,
                    size: 28,
                    color: Colors.white,
                    adaptForLightMode: false,
                    fallbackIcon: Icons.play_arrow_rounded,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: MetaGymTheme.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(56, 56),
                  ),
                ),
              ),
            Align(
              alignment: Alignment.bottomCenter,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {},
                child: Container(
                  color: const Color(0xB3000000),
                  padding: const EdgeInsets.fromLTRB(8, 4, 10, 8),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: value.isPlaying ? 'Tạm dừng' : 'Phát video',
                        constraints: const BoxConstraints(
                          minWidth: 48,
                          minHeight: 48,
                        ),
                        onPressed: () => _togglePlayPause(controller),
                        icon: MetaGymResolvedIcon(
                          value.isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: Colors.white,
                          adaptForLightMode: false,
                        ),
                      ),
                      Expanded(
                        child: VideoProgressIndicator(
                          controller,
                          allowScrubbing: true,
                          colors: const VideoProgressColors(
                            playedColor: MetaGymTheme.primary,
                            bufferedColor: Color(0xFF8E95A5),
                            backgroundColor: Color(0xFF4A4D54),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _formatDuration(value.position),
                        maxLines: 1,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          fontFeatures: MetaGymTheme.tabularFigures,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _videoMessage(String text, {Widget? action, bool showIcon = true}) {
    final palette = MetaGymTheme.paletteOf(context);
    return Container(
      color: palette.surfaceRaised,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      alignment: Alignment.center,
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (showIcon) ...[
              const MetaGymSvgIcon(
                MetaGymIcons.commMute,
                size: 28,
                fallbackIcon: Icons.videocam_off_outlined,
              ),
              const SizedBox(height: 8),
            ],
            Text(
              text,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: palette.textPrimary, fontSize: 14),
            ),
            ?action,
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration value) {
    final minutes = value.inMinutes.toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
