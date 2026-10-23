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
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ConversationDetailPage(
                            conversation: item,
                            service: _service!,
                          ),
                        ),
                      ),
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
    super.key,
  });
  final Conversation conversation;
  final MessagingService service;

  @override
  State<ConversationDetailPage> createState() => _ConversationDetailPageState();
}

class _ConversationDetailPageState extends State<ConversationDetailPage> {
  List<ChatMessage> _messages = const [];
  bool _loading = true;
  String? _error;

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
    });
    try {
      final messages = await widget.service.getMessages(
        widget.conversation.relationshipId,
        1,
      );
      if (mounted) setState(() => _messages = messages);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không tải được tin nhắn.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Cuộc trò chuyện')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Quan hệ ${widget.conversation.relationshipId}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Text(
          widget.conversation.canSend
              ? 'Tin nhắn văn bản sẽ được bổ sung ở UI22.'
              : 'Quan hệ đã kết thúc; lịch sử chỉ đọc.',
        ),
        if (_loading)
          const Center(child: CircularProgressIndicator())
        else if (_error != null) ...[
          Text(_error!),
          TextButton(onPressed: _load, child: const Text('Thử lại')),
        ] else if (_messages.isEmpty)
          const ListTile(title: Text('Chưa có tin nhắn.'))
        else
          for (final message in _messages)
            ListTile(
              title: Text(message.content ?? 'Ảnh'),
              subtitle: Text(message.sentAt),
            ),
      ],
    ),
  );
}
