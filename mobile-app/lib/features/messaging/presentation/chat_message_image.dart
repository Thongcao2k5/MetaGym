import 'dart:ui' show ImageFilter;

import 'package:meta_gym_app/core/navigation/meta_gym_navigation.dart';
import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/features/messaging/data/messaging_service.dart';
import 'package:meta_gym_app/core/theme/meta_gym_icons.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_svg_icon.dart';

class ChatMessageImage extends StatefulWidget {
  const ChatMessageImage({
    required this.service,
    required this.mediaId,
    super.key,
  });
  final MessagingService service;
  final String mediaId;

  @override
  State<ChatMessageImage> createState() => _ChatMessageImageState();
}

class _ChatMessageImageState extends State<ChatMessageImage> {
  Uri? _url;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _url = null;
    });
    try {
      final url = await widget.service.getImageAccessUrl(widget.mediaId);
      if (mounted) setState(() => _url = url);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không mở được ảnh.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openFullscreen(BuildContext context, Uri url) {
    MetaGymNavigation.pushOnce(
      context,
      PageRouteBuilder<void>(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.black87,
        transitionDuration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : MetaGymTheme.pageTransitionDuration,
        reverseTransitionDuration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 240),
        pageBuilder: (context, animation, secondaryAnimation) =>
            _FullscreenChatImagePage(
              imageUrl: url.toString(),
              onRetryUrl: _load,
            ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          if (MediaQuery.disableAnimationsOf(context)) return child;
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.94, end: 1.0).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  Widget _buildErrorBox(BuildContext context, String message) {
    final palette = MetaGymTheme.paletteOf(context);
    final isLight = MetaGymTheme.isLightPalette(context);
    return Container(
      width: 210,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: isLight ? palette.metricPanelBg : const Color(0x44000000),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isLight
              ? palette.borderSolid
              : Colors.white.withValues(alpha: 0.14),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          MetaGymSvgIcon(MetaGymIcons.stateBrokenImage, size: 26, color: Colors.white, adaptForLightMode: false, fallbackIcon: Icons.broken_image_outlined),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: palette.textPrimary, fontSize: 12),
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: _load,
            style: TextButton.styleFrom(
              foregroundColor: palette.primaryText,
              minimumSize: const Size(0, 48),
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            child: const Text('Tải lại ảnh'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = MetaGymTheme.paletteOf(context);
    final isLight = MetaGymTheme.isLightPalette(context);
    if (_loading) {
      return Container(
        width: 210,
        height: 180,
        decoration: BoxDecoration(
          color: isLight ? palette.metricPanelBg : const Color(0x33000000),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2.2,
            color: MetaGymTheme.primary,
          ),
        ),
      );
    }
    if (_error != null) {
      return _buildErrorBox(context, _error!);
    }
    if (_url case final url?) {
      return GestureDetector(
        key: Key('chat-image-tap-${widget.mediaId}'),
        onTap: () => _openFullscreen(context, url),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              Image.network(
                url.toString(),
                width: 220,
                height: 190,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    width: 220,
                    height: 190,
                    color: isLight
                        ? palette.metricPanelBg
                        : const Color(0x33000000),
                    alignment: Alignment.center,
                    child: const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: MetaGymTheme.primary,
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) =>
                    _buildErrorBox(context, 'Ảnh lỗi hoặc URL đã hết hạn.'),
              ),
              Positioned(
                right: 8,
                bottom: 8,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0x88060608),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                      child: const MetaGymSvgIcon(MetaGymIcons.commonExpandCollapse, size: 15, color: Colors.white, adaptForLightMode: false, fallbackIcon: Icons.zoom_out_map_rounded),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

class _FullscreenChatImagePage extends StatefulWidget {
  const _FullscreenChatImagePage({
    required this.imageUrl,
    required this.onRetryUrl,
  });

  final String imageUrl;
  final Future<void> Function() onRetryUrl;

  @override
  State<_FullscreenChatImagePage> createState() =>
      _FullscreenChatImagePageState();
}

class _FullscreenChatImagePageState extends State<_FullscreenChatImagePage> {
  final TransformationController _transformController =
      TransformationController();
  TapDownDetails? _doubleTapDetails;

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  void _handleDoubleTap() {
    final current = _transformController.value;
    if (!current.isIdentity()) {
      _transformController.value = current.clone()..setIdentity();
      return;
    }
    final position = _doubleTapDetails?.localPosition;
    if (position == null) return;
    const scale = 2.2;
    _transformController.value = current.clone()
      ..setIdentity()
      ..translateByDouble(
        -position.dx * (scale - 1),
        -position.dy * (scale - 1),
        0,
        1,
      )
      ..scaleByDouble(scale, scale, 1, 1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xF5060608),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const MetaGymBackground(),
          SafeArea(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  top: 68,
                  bottom: 12,
                  left: 12,
                  right: 12,
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).maybePop(),
                    onDoubleTapDown: (details) => _doubleTapDetails = details,
                    onDoubleTap: _handleDoubleTap,
                    child: InteractiveViewer(
                      transformationController: _transformController,
                      minScale: 1,
                      maxScale: 4.5,
                      child: Center(
                        child: Image.network(
                          widget.imageUrl,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.contain,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return const Center(
                              child: SizedBox(
                                width: 32,
                                height: 32,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: MetaGymTheme.primary,
                                ),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) => Padding(
                            padding: const EdgeInsets.all(24),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const MetaGymSvgIcon(MetaGymIcons.stateBrokenImage, size: 40, color: Colors.white, adaptForLightMode: false, fallbackIcon: Icons.broken_image_outlined),
                                  const SizedBox(height: 10),
                                  const Text(
                                    'Không thể tải ảnh phóng to.',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.of(context).maybePop();
                                      widget.onRetryUrl();
                                    },
                                    child: const Text('Tải lại ảnh'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Row(
                      children: [
                        Flexible(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xAA0E1117),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.14),
                                  ),
                                ),
                                child: Text(
                                  'Chụm 2 ngón hoặc chạm đúp để phóng to',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.86),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const Spacer(),
                        ClipOval(
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xAA0E1117),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.16),
                                ),
                              ),
                              child: IconButton(
                                key: const Key('fullscreen-image-close-button'),
                                tooltip: 'Đóng',
                                onPressed: () =>
                                    Navigator.of(context).maybePop(),
                                icon: const MetaGymSvgIcon(MetaGymIcons.commonClose, color: Colors.white, adaptForLightMode: false, fallbackIcon: Icons.close_rounded),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
