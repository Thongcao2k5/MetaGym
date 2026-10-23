import 'dart:async';

import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/features/messaging/data/messaging_service.dart';
import 'package:meta_gym_app/features/messaging/domain/conversation.dart';
import 'package:meta_gym_app/features/messaging/domain/chat_message.dart';
import 'package:provider/provider.dart';

class ConversationsPage extends StatefulWidget {
  const ConversationsPage({
    this.service,
    required this.currentUserId,
    super.key,
  });

  final MessagingService? service;
  final String currentUserId;

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
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Tin nhắn')),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                if (_error != null) ...[
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  TextButton(
                    onPressed: _items.isEmpty ? _load : _loadMore,
                    child: const Text('Thử lại'),
                  ),
                ],
                if (_items.isEmpty && _error == null)
                  const ListTile(
                    title: Text('Bạn chưa có cuộc trò chuyện nào.'),
                  ),
                for (final item in _items)
                  Card(
                    child: ListTile(
                      title: Text(
                        item.memberId == widget.currentUserId
                            ? 'Coach ${item.coachId}'
                            : 'Hội viên ${item.memberId}',
                      ),
                      subtitle: Text(
                        item.canSend
                            ? 'Đang hoạt động'
                            : 'Quan hệ đã kết thúc · chỉ đọc',
                      ),
                      trailing: item.unreadCount > 0
                          ? Text('${item.unreadCount} tin chưa đọc')
                          : const Icon(Icons.chevron_right),
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ConversationDetailPage(
                              conversation: item,
                              service: _service!,
                              currentUserId: widget.currentUserId,
                            ),
                          ),
                        );
                        if (mounted) _load();
                      },
                    ),
                  ),
                if (_hasMore)
                  TextButton(
                    onPressed: _loadingMore ? null : _loadMore,
                    child: Text(_loadingMore ? 'Đang tải…' : 'Tải thêm'),
                  ),
              ],
            ),
          ),
  );
}

class ConversationDetailPage extends StatefulWidget {
  const ConversationDetailPage({
    required this.conversation,
    required this.service,
    required this.currentUserId,
    super.key,
  });
  final Conversation conversation;
  final MessagingService service;
  final String currentUserId;

  @override
  State<ConversationDetailPage> createState() => _ConversationDetailPageState();
}

class _ConversationDetailPageState extends State<ConversationDetailPage> {
  final _textController = TextEditingController();
  List<ChatMessage> _messages = const [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _sending = false;
  String? _error;
  String? _sendError;
  String? _draftMessageId;
  String? _draftContent;
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
        widget.conversation.relationshipId,
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
          widget.conversation.relationshipId,
          message.id,
        );
        _lastReadId = message.id;
      } catch (_) {
        // The next poll can retry this cursor without hiding the messages.
      }
      break;
    }
  }

  Future<void> _refreshLatest() async {
    if (_polling || _loading) return;
    _polling = true;
    try {
      final latest = await widget.service.getMessages(
        widget.conversation.relationshipId,
        1,
      );
      if (!mounted) return;
      final oldIds = _messages.map((item) => item.id).toSet();
      setState(
        () => _messages = [
          ...latest.where((item) => !oldIds.contains(item.id)),
          ..._messages,
        ],
      );
      await _markLatestReceived(latest);
    } catch (_) {
      // Polling is best-effort; manual retry remains available.
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
        widget.conversation.relationshipId,
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
    if (_sending || !widget.conversation.canSend) return;
    final content = _textController.text.trim();
    if (content.isEmpty || content.length > 5000) {
      setState(() => _sendError = 'Tin nhắn phải dài từ 1 đến 5000 ký tự.');
      return;
    }
    if (_draftContent != content) {
      _draftContent = content;
      _draftMessageId = newClientMessageId();
    }
    setState(() {
      _sending = true;
      _sendError = null;
    });
    try {
      final message = await widget.service.sendText(
        widget.conversation.relationshipId,
        content,
        _draftMessageId!,
      );
      if (mounted) {
        setState(() {
          _messages = [
            message,
            ..._messages.where((item) => item.id != message.id),
          ];
          _textController.clear();
          _draftContent = null;
          _draftMessageId = null;
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

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Cuộc trò chuyện')),
    body: Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Quan hệ ${widget.conversation.relationshipId}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Text(
                widget.conversation.canSend
                    ? 'Quan hệ đang hoạt động.'
                    : 'Quan hệ đã kết thúc; lịch sử chỉ đọc.',
              ),
              if (_loading)
                const Center(child: CircularProgressIndicator())
              else ...[
                if (_error != null) ...[
                  Text(_error!),
                  TextButton(
                    onPressed: _messages.isEmpty ? _load : _loadMore,
                    child: const Text('Thử lại'),
                  ),
                ],
                if (_messages.isEmpty && _error == null)
                  const ListTile(title: Text('Chưa có tin nhắn.'))
                else
                  for (final message in _messages)
                    ListTile(
                      title: Text(message.content ?? 'Ảnh'),
                      subtitle: Text(message.sentAt),
                    ),
              ],
              if (_hasMore)
                TextButton(
                  onPressed: _loadingMore ? null : _loadMore,
                  child: Text(_loadingMore ? 'Đang tải…' : 'Tải tin cũ'),
                ),
            ],
          ),
        ),
        if (widget.conversation.canSend)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (_sendError != null)
                  Text(
                    _sendError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                if (_sendError != null && _draftMessageId != null)
                  TextButton(
                    onPressed: _sending ? null : _send,
                    child: const Text('Thử gửi lại'),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _textController,
                        maxLength: 5000,
                        decoration: const InputDecoration(
                          labelText: 'Tin nhắn',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _sending ? null : _send,
                      child: const Text('Gửi'),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    ),
  );
}
