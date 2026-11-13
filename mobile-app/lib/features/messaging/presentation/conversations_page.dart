import 'dart:async';

import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_bottom_nav.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/features/messaging/data/messaging_service.dart';
import 'package:meta_gym_app/features/messaging/domain/chat_message.dart';
import 'package:meta_gym_app/features/messaging/domain/conversation.dart';
import 'package:meta_gym_app/features/messaging/presentation/chat_message_image.dart';
import 'package:meta_gym_app/features/progress/data/member_photo_service.dart';
import 'package:provider/provider.dart';

class ConversationsPage extends StatefulWidget {
  const ConversationsPage({
    this.service,
    required this.currentUserId,
    this.picker,
    this.bottomPadding,
    super.key,
  });

  final MessagingService? service;
  final String currentUserId;
  final ProgressPhotoPicker? picker;
  final double? bottomPadding;

  @override
  State<ConversationsPage> createState() => _ConversationsPageState();
}

class _ConversationsPageState extends State<ConversationsPage> {
  MessagingService? _service;
  List<Conversation> _items = const [];
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  int _page = 1;
  bool _hasMore = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_service != null) return;
    _service = widget.service ?? context.read<MessagingService>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _service!.getConversations(1);
      if (mounted) {
        setState(() {
          _items = items;
          _page = 1;
          _hasMore = items.length == 20;
        });
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không tải được cuộc trò chuyện.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    setState(() {
      _loadingMore = true;
      _error = null;
    });
    try {
      final items = await _service!.getConversations(_page + 1);
      if (mounted) {
        setState(() {
          _items = [..._items, ...items];
          _page++;
          _hasMore = items.length == 20;
        });
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Không tải thêm được cuộc trò chuyện.');
      }
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveBottomPadding =
        widget.bottomPadding ?? MetaGymBottomNav.contentBottomPadding(context);

    return Scaffold(
      backgroundColor: MetaGymTheme.scaffoldBackground,
      extendBody: true,
      appBar: AppBar(
        title: const Text(
          'Tin nhắn',
          style: TextStyle(
            color: MetaGymTheme.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 20,
            fontFamily: MetaGymTheme.fontFamily,
          ),
        ),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.refresh_rounded,
              color: MetaGymTheme.textSecondary,
              size: 22,
            ),
            tooltip: 'Làm mới',
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                color: MetaGymTheme.primary,
                strokeWidth: 2.5,
              ),
            )
          : RefreshIndicator(
              color: MetaGymTheme.brandOrange,
              backgroundColor: MetaGymTheme.darkSurfaceRaised,
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  16,
                  12,
                  16,
                  effectiveBottomPadding + 16,
                ),
                children: [
                  if (_error != null) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0x1FF15B64),
                        borderRadius: BorderRadius.circular(
                          MetaGymTheme.radiusCard,
                        ),
                        border: Border.all(color: const Color(0x4DF15B64)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                color: MetaGymTheme.dangerCoral,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: _items.isEmpty ? _load : _loadMore,
                            icon: const Icon(
                              Icons.replay_rounded,
                              size: 16,
                              color: MetaGymTheme.brandOrange,
                            ),
                            label: const Text(
                              'Thử lại',
                              style: TextStyle(
                                color: MetaGymTheme.brandOrange,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (_items.isEmpty && _error == null)
                    MetaGymGlassCard(
                      padding: const EdgeInsets.all(28),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 54,
                              height: 54,
                              decoration: BoxDecoration(
                                color: const Color(0x14A9C7E8),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0x2EA9C7E8),
                                ),
                              ),
                              child: const Icon(
                                Icons.chat_bubble_outline_rounded,
                                color: MetaGymTheme.reflectionBlue,
                                size: 26,
                              ),
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              'Bạn chưa có cuộc trò chuyện nào.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: MetaGymTheme.darkTextPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Khi bạn kết nối với Huấn luyện viên, tin nhắn sẽ hiển thị tại đây.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: MetaGymTheme.darkTextTertiary,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  for (final item in _items) ...[
                    MetaGymGlassCard(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(
                          MetaGymTheme.radiusCard,
                        ),
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => ConversationDetailPage(
                                conversation: item,
                                service: _service!,
                                currentUserId: widget.currentUserId,
                                picker:
                                    widget.picker ??
                                    DeviceProgressPhotoPicker(),
                              ),
                            ),
                          );
                          if (mounted) _load();
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Color(0xFF223145),
                                      Color(0xFF141F2E),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: const Color(0x38D4E4FF),
                                    width: 1.0,
                                  ),
                                ),
                                child: Center(
                                  child: Icon(
                                    item.memberId == widget.currentUserId
                                        ? Icons.sports_gymnastics_rounded
                                        : Icons.person_rounded,
                                    color: MetaGymTheme.reflectionBlue,
                                    size: 24,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.memberId == widget.currentUserId
                                          ? 'Coach ${item.coachId}'
                                          : 'Hội viên ${item.memberId}',
                                      style: const TextStyle(
                                        color: MetaGymTheme.darkTextPrimary,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Container(
                                          width: 6,
                                          height: 6,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: item.canSend
                                                ? MetaGymTheme.progressGreen
                                                : MetaGymTheme.darkTextTertiary,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            item.canSend ? 'Có thể nhắn tin' : 'Quan hệ đã kết thúc · chỉ đọc',
                                            style: const TextStyle(
                                              color: MetaGymTheme
                                                  .darkTextSecondary,
                                              fontSize: 12,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (item.unreadCount > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: MetaGymTheme.brandOrange,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x4DFF5A36),
                                        blurRadius: 8,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    '${item.unreadCount} tin chưa đọc',
                                    style: const TextStyle(
                                      color: MetaGymTheme.onBrandOrange,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                )
                              else
                                const Icon(
                                  Icons.chevron_right,
                                  color: MetaGymTheme.darkTextTertiary,
                                  size: 20,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (_hasMore)
                    Center(
                      child: TextButton(
                        onPressed: _loadingMore ? null : _loadMore,
                        child: Text(
                          _loadingMore ? 'Đang tải…' : 'Tải thêm',
                          style: const TextStyle(
                            color: MetaGymTheme.brandOrange,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class ConversationDetailPage extends StatefulWidget {
  const ConversationDetailPage({
    required this.conversation,
    required this.service,
    required this.currentUserId,
    required this.picker,
    super.key,
  });
  final Conversation conversation;
  final MessagingService service;
  final String currentUserId;
  final ProgressPhotoPicker picker;

  @override
  State<ConversationDetailPage> createState() => _ConversationDetailPageState();
}

class _ConversationDetailPageState extends State<ConversationDetailPage> {
  final _textController = TextEditingController();
  List<ChatMessage> _messages = const [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _sending = false;
  bool _imageSending = false;
  String? _error;
  String? _sendError;
  String? _draftMessageId;
  String? _draftContent;
  String? _imageError;
  SelectedProgressImage? _pendingImage;
  String? _pendingMediaId;
  String? _pendingImageMessageId;
  String? _lastReadId;
  Timer? _pollTimer;
  bool _polling = false;
  int _page = 1;
  bool _hasMore = false;

  @override
  void dispose() {
    _pollTimer?.cancel();
    _textController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) _refreshLatest();
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final messages = await widget.service.getMessages(
        widget.conversation.messageKey,
        1,
      );
      if (mounted) {
        setState(() {
          _messages = messages;
          _page = 1;
          _hasMore = messages.length == 20;
        });
        await _markLatestReceived(messages);
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không tải được tin nhắn.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markLatestReceived(List<ChatMessage> messages) async {
    for (final message in messages) {
      if (message.senderId == widget.currentUserId) continue;
      if (message.id == _lastReadId) return;
      try {
        await widget.service.markRead(
          widget.conversation.messageKey,
          message.id,
        );
        _lastReadId = message.id;
      } catch (_) {
        // The next poll can retry this cursor without hiding the messages.
      }
      return;
    }
  }

  Future<void> _refreshLatest() async {
    if (_polling || _loading) return;
    _polling = true;
    try {
      final latest = await widget.service.getMessages(
        widget.conversation.messageKey,
        1,
      );
      if (!mounted) return;
      final existingIds = _messages.map((item) => item.id).toSet();
      final added = latest.where((item) => !existingIds.contains(item.id));
      if (added.isNotEmpty) {
        setState(() => _messages = [...added, ..._messages]);
        await _markLatestReceived(latest);
      }
    } catch (_) {
      // Background poll failure is silent.
    } finally {
      _polling = false;
    }
  }

  Future<void> _loadMore() async {
    setState(() {
      _loadingMore = true;
      _error = null;
    });
    try {
      final messages = await widget.service.getMessages(
        widget.conversation.messageKey,
        _page + 1,
      );
      if (mounted) {
        setState(() {
          _messages = [..._messages, ...messages];
          _page++;
          _hasMore = messages.length == 20;
        });
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không tải thêm được tin nhắn.');
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _send() async {
    final raw = _textController.text;
    final text = raw.trim();
    if (text.isEmpty || _sending) return;

    if (_draftContent != text) {
      _draftMessageId = newClientMessageId();
      _draftContent = text;
    }

    setState(() {
      _sending = true;
      _sendError = null;
    });

    try {
      final message = await widget.service.sendText(
        widget.conversation.messageKey,
        text,
        _draftMessageId!,
      );
      if (mounted) {
        setState(() {
          _messages = [
            message,
            ..._messages.where((item) => item.id != message.id),
          ];
          _draftMessageId = null;
          _draftContent = null;
          _textController.clear();
        });
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _sendError = error.message);
    } catch (_) {
      if (mounted) setState(() => _sendError = 'Không gửi được tin nhắn.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pickImage() async {
    if (_imageSending) return;
    try {
      final image = await widget.picker.pick();
      if (image == null || !mounted) return;
      final validation = validateProgressImage(image);
      if (validation != null) throw FormatException(validation);
      _pendingImage = image;
      _pendingMediaId = null;
      _pendingImageMessageId = newClientMessageId();
      await _sendImage();
    } on FormatException catch (error) {
      if (mounted) setState(() => _imageError = error.message);
    } catch (_) {
      if (mounted) setState(() => _imageError = 'Không chọn được ảnh.');
    }
  }

  Future<void> _sendImage() async {
    if (_imageSending || _pendingImage == null) return;
    setState(() {
      _imageSending = true;
      _imageError = null;
    });
    try {
      _pendingMediaId ??= await widget.service.uploadImage(_pendingImage!);
      final message = await widget.service.sendImage(
        widget.conversation.messageKey,
        _pendingMediaId!,
        _pendingImageMessageId!,
      );
      if (mounted) {
        setState(() {
          _messages = [
            message,
            ..._messages.where((item) => item.id != message.id),
          ];
          _pendingImage = null;
          _pendingMediaId = null;
          _pendingImageMessageId = null;
        });
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _imageError = error.message);
    } catch (_) {
      if (mounted) setState(() => _imageError = 'Không gửi được ảnh.');
    } finally {
      if (mounted) setState(() => _imageSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MetaGymTheme.darkCanvas,
      appBar: AppBar(
        title: const Text(
          'Cuộc trò chuyện',
          style: TextStyle(
            color: MetaGymTheme.darkTextPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 18,
            fontFamily: MetaGymTheme.fontFamily,
          ),
        ),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                MetaGymGlassCard(
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: widget.conversation.canSend
                                  ? MetaGymTheme.progressGreen
                                  : MetaGymTheme.darkTextTertiary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Trò chuyện riêng tư',
                              style: const TextStyle(
                                color: MetaGymTheme.darkTextPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.conversation.canSend
                            ? (widget.conversation.status == 'ENDED'
                                ? 'Bạn vẫn có thể tiếp tục nhắn tin.'
                                : 'Có thể nhắn tin.')
                            : 'Không thể gửi tin nhắn.',
                        style: const TextStyle(
                          color: MetaGymTheme.darkTextSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_loading)
                  const Center(
                    child: CircularProgressIndicator(
                      color: MetaGymTheme.brandOrange,
                      strokeWidth: 2.5,
                    ),
                  )
                else ...[
                  if (_error != null) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0x1FF15B64),
                        borderRadius: BorderRadius.circular(
                          MetaGymTheme.radiusCard,
                        ),
                        border: Border.all(color: const Color(0x4DF15B64)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _error!,
                            style: const TextStyle(
                              color: MetaGymTheme.dangerCoral,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextButton(
                            onPressed: _messages.isEmpty ? _load : _loadMore,
                            child: const Text(
                              'Thử lại',
                              style: TextStyle(
                                color: MetaGymTheme.brandOrange,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (_messages.isEmpty && _error == null)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'Chưa có tin nhắn.',
                          style: TextStyle(
                            color: MetaGymTheme.darkTextTertiary,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    )
                  else
                    for (final message in _messages) ...[
                      _buildChatMessageBubble(message),
                      const SizedBox(height: 8),
                    ],
                ],
                if (_hasMore)
                  Center(
                    child: TextButton(
                      onPressed: _loadingMore ? null : _loadMore,
                      child: Text(
                        _loadingMore ? 'Đang tải…' : 'Tải tin cũ',
                        style: const TextStyle(
                          color: MetaGymTheme.brandOrange,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (widget.conversation.canSend)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              decoration: BoxDecoration(
                color: const Color(0xE6080A0D),
                border: Border(
                  top: BorderSide(
                    color: MetaGymTheme.darkCardBorderSubtle,
                    width: 0.8,
                  ),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_sendError != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _sendError!,
                                style: const TextStyle(
                                  color: MetaGymTheme.dangerCoral,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            if (_draftMessageId != null)
                              TextButton(
                                onPressed: _sending ? null : _send,
                                child: const Text(
                                  'Thử gửi lại',
                                  style: TextStyle(
                                    color: MetaGymTheme.brandOrange,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    if (_imageError != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _imageError!,
                                style: const TextStyle(
                                  color: MetaGymTheme.dangerCoral,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            if (_pendingImage != null)
                              TextButton(
                                onPressed: _imageSending ? null : _sendImage,
                                child: const Text(
                                  'Thử lại gửi ảnh',
                                  style: TextStyle(
                                    color: MetaGymTheme.brandOrange,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _textController,
                            maxLength: 5000,
                            style: const TextStyle(
                              color: MetaGymTheme.darkTextPrimary,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Tin nhắn',
                              labelStyle: TextStyle(
                                color: MetaGymTheme.darkTextSecondary,
                              ),
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: MetaGymTheme.brandOrange,
                            foregroundColor: MetaGymTheme.onBrandOrange,
                          ),
                          onPressed: _sending ? null : _send,
                          child: const Text('Gửi'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: MetaGymTheme.reflectionBlue,
                        side: const BorderSide(color: Color(0x38D4E4FF)),
                      ),
                      onPressed: _imageSending ? null : _pickImage,
                      icon: const Icon(Icons.image_outlined),
                      label: Text(_imageSending ? 'Đang gửi ảnh…' : 'Gửi ảnh'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildChatMessageBubble(ChatMessage message) {
    final isMe = message.senderId == widget.currentUserId;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: isMe
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFF6A42), Color(0xFFFF4520)],
                  )
                : const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0x59162232), Color(0x420E1520)],
                  ),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: isMe
                  ? const Radius.circular(16)
                  : const Radius.circular(4),
              bottomRight: isMe
                  ? const Radius.circular(4)
                  : const Radius.circular(16),
            ),
            border: isMe
                ? null
                : Border.all(color: const Color(0x38D4E4FF), width: 1.0),
            boxShadow: const [
              BoxShadow(
                color: Color(0x26000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: isMe
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              if (message.messageType == 'IMAGE' && message.mediaId != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: ChatMessageImage(
                    service: widget.service,
                    mediaId: message.mediaId!,
                  ),
                )
              else
                Text(
                  message.content ?? '',
                  style: TextStyle(
                    color: isMe
                        ? MetaGymTheme.onBrandOrange
                        : MetaGymTheme.darkTextPrimary,
                    fontSize: 14,
                    height: 1.3,
                  ),
                ),
              const SizedBox(height: 4),
              Text(
                message.sentAt,
                style: TextStyle(
                  color: isMe
                      ? MetaGymTheme.onBrandOrange.withValues(alpha: 0.75)
                      : MetaGymTheme.darkTextTertiary,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
