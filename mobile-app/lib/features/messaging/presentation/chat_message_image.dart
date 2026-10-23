import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/features/messaging/data/messaging_service.dart';

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

  @override
  Widget build(BuildContext context) {
    if (_loading) return const CircularProgressIndicator();
    if (_error != null) {
      return Column(
        children: [
          Text(_error!),
          TextButton(onPressed: _load, child: const Text('Tải lại ảnh')),
        ],
      );
    }
    if (_url case final url?) {
      return Image.network(
        url.toString(),
        height: 180,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => Column(
          children: [
            const Text('Ảnh lỗi hoặc URL đã hết hạn.'),
            TextButton(onPressed: _load, child: const Text('Tải lại ảnh')),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
