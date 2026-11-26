import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import 'package:meta_gym_app/core/theme/meta_gym_icons.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_svg_icon.dart';

/// Plays the catalog's YouTube links or direct video files inside the detail page.
class ExerciseVideoPlayer extends StatefulWidget {
  const ExerciseVideoPlayer({required this.url, super.key});

  final String url;

  @override
  State<ExerciseVideoPlayer> createState() => _ExerciseVideoPlayerState();
}

class _ExerciseVideoPlayerState extends State<ExerciseVideoPlayer>
    with WidgetsBindingObserver {
  VideoPlayerController? _fileController;
  YoutubePlayerController? _youtubeController;
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _openVideo();
  }

  @override
  void didUpdateWidget(covariant ExerciseVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) _openVideo();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _fileController?.pause();
  }

  void _openVideo() {
    _fileController?.dispose();
    _youtubeController?.close();
    _fileController = null;
    _youtubeController = null;
    _error = null;
    _loading = false;

    final uri = Uri.tryParse(widget.url);
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
      final id = YoutubePlayerController.convertUrlToId(widget.url);
      if (id == null) {
        _error = 'Không nhận diện được video YouTube.';
        return;
      }
      _youtubeController = YoutubePlayerController.fromVideoId(
        videoId: id,
        autoPlay: false,
        params: const YoutubePlayerParams(
          showControls: true,
          showFullscreenButton: true,
          interfaceLanguage: 'vi',
        ),
      );
      return;
    }

    final controller = VideoPlayerController.networkUrl(uri);
    _fileController = controller;
    _loading = true;
    controller
        .initialize()
        .then((_) {
          if (mounted && identical(_fileController, controller)) {
            setState(() => _loading = false);
          }
        })
        .catchError((Object _) {
          if (mounted && identical(_fileController, controller)) {
            setState(() {
              _loading = false;
              _error = 'Không tải được video. Hãy thử lại.';
            });
          }
        });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _fileController?.dispose();
    _youtubeController?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = MetaGymTheme.paletteOf(context);
    return MetaGymGlassCard(
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
                        icon: const MetaGymSvgIcon(MetaGymIcons.commonRefresh, fallbackIcon: Icons.refresh_rounded),
                        label: const Text('Thử lại'),
                      ),
                    )
                  : _loading
                  ? _videoMessage(
                      'Đang tải video…',
                      action: const CircularProgressIndicator(
                        color: MetaGymTheme.primary,
                      ),
                    )
                  : _filePlayer(),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                MetaGymSvgIcon(MetaGymIcons.exerciseVideoPlay, size: 19, fallbackIcon: Icons.ondemand_video_rounded),
                const SizedBox(width: 8),
                Text(
                  'Video hướng dẫn',
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
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
      builder: (context, value, _) => Stack(
        fit: StackFit.expand,
        children: [
          FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: value.size.width,
              height: value.size.height,
              child: VideoPlayer(controller),
            ),
          ),
          if (!value.isPlaying)
            Center(
              child: IconButton.filled(
                tooltip: 'Phát video',
                onPressed: controller.play,
                icon: const MetaGymSvgIcon(MetaGymIcons.exerciseVideoPlay, size: 32, color: Colors.white, adaptForLightMode: false, fallbackIcon: Icons.play_arrow_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: MetaGymTheme.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(56, 56),
                ),
              ),
            ),
          Align(
            alignment: Alignment.bottomCenter,
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
                    onPressed: value.isPlaying
                        ? controller.pause
                        : controller.play,
                    icon: MetaGymResolvedIcon(value.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded, color: Colors.white, adaptForLightMode: false),
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
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _videoMessage(String text, {Widget? action}) {
    final palette = MetaGymTheme.paletteOf(context);
    return Container(
      color: palette.surfaceRaised,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          MetaGymSvgIcon(MetaGymIcons.commMute, size: 30, fallbackIcon: Icons.videocam_off_outlined),
          const SizedBox(height: 8),
          Text(text, style: TextStyle(color: palette.textPrimary)),
          ?action,
        ],
      ),
    );
  }

  String _formatDuration(Duration value) {
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
