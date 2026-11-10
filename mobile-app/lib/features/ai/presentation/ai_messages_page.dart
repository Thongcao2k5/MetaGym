import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/features/ai/data/ai_service.dart';
import 'package:meta_gym_app/features/ai/domain/ai_conversation.dart';
import 'package:meta_gym_app/features/ai/domain/ai_message.dart';
import 'package:meta_gym_app/features/messaging/data/messaging_service.dart';

class AiMessagesPage extends StatefulWidget {
  const AiMessagesPage({
    required this.service,
    required this.conversation,
    super.key,
  });
  final AiService service;
  final AiConversation conversation;
  @override
  State<AiMessagesPage> createState() => _AiMessagesPageState();
}

class _AiMessagesPageState extends State<AiMessagesPage> {
  final _question = TextEditingController();
  List<AiMessage> _messages = const [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _sending = false;
  bool _hasMore = false;
  int _page = 1;
  String? _error;
  String? _sendError;
  String? _notice;
  String? _pendingContent;
  String? _pendingRequestId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _question.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final messages = await widget.service.getMessages(
        widget.conversation.id,
        1,
      );
      if (mounted) {
        setState(() {
          _messages = messages;
          _page = 1;
          _hasMore = messages.length == 20;
        });
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không tải được lịch sử AI.');
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
      final messages = await widget.service.getMessages(
        widget.conversation.id,
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
      if (mounted) setState(() => _error = 'Không tải thêm được lịch sử AI.');
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _send() async {
    if (_sending) return;
    final content = _question.text.trim();
    if (content.isEmpty || content.length > 10000) {
      setState(() => _sendError = 'Câu hỏi phải dài từ 1 đến 10000 ký tự.');
      return;
    }
    if (_pendingContent != content) {
      _pendingContent = content;
      _pendingRequestId = newClientMessageId();
    }
    setState(() {
      _sending = true;
      _sendError = null;
      _notice = null;
    });
    try {
      final answer = await widget.service.sendQuestion(
        widget.conversation.id,
        content,
        _pendingRequestId!,
      );
      if (!mounted) return;
      if (answer.status == 'PROCESSING') {
        setState(() => _notice = 'Yêu cầu đang xử lý. Hãy thử lại sau.');
        return;
      }
      if (!answer.isComplete) {
        setState(() {
          _pendingContent = null;
          _pendingRequestId = null;
          _sendError = 'Yêu cầu AI đã thất bại. Thử lại sẽ gửi yêu cầu mới.';
        });
        return;
      }
      final reply = answer.reply!;
      setState(() {
        final known = _messages.map((message) => message.id).toSet();
        _messages = [
          ..._messages,
          if (!known.contains(answer.requestId))
            AiMessage(
              id: answer.requestId,
              role: 'USER',
              content: content,
              status: 'COMPLETED',
              createdAt: DateTime.now().toUtc().toIso8601String(),
            ),
          if (!known.contains(reply.id))
            AiMessage(
              id: reply.id,
              role: 'ASSISTANT',
              content: reply.content,
              status: 'COMPLETED',
              createdAt: reply.createdAt,
            ),
        ];
        _question.clear();
        _pendingContent = null;
        _pendingRequestId = null;
      });
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          if (error.code == 'AI_PROVIDER_ERROR') {
            _pendingContent = null;
            _pendingRequestId = null;
          }
          _sendError = error.statusCode == 503
              ? 'Dịch vụ AI chưa sẵn sàng. Vui lòng thử lại sau.'
              : error.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _sendError = 'Không nhận được câu trả lời AI.');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: MetaGymTheme.scaffoldBackground,
    appBar: AppBar(
      title: Text(
        widget.conversation.title,
        style: const TextStyle(
          color: MetaGymTheme.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
    ),
    body: Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: MetaGymTheme.cardSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: MetaGymTheme.cardBorder),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: MetaGymTheme.reflectionBlue,
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Nội dung AI chỉ để tham khảo; không thay thế tư vấn y tế hoặc huấn luyện cá nhân.',
                        style: TextStyle(
                          color: MetaGymTheme.textSecondary,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (_loading)
                const Center(
                  child: CircularProgressIndicator(color: MetaGymTheme.primary),
                )
              else ...[
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0x1FF15B64),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0x4DF15B64)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: MetaGymTheme.dangerCoral,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _messages.isEmpty ? _load : _loadMore,
                          child: const Text(
                            'Thử lại',
                            style: TextStyle(color: MetaGymTheme.primary),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (_messages.isEmpty && _error == null)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: MetaGymTheme.cardSurface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: MetaGymTheme.cardBorder),
                    ),
                    child: const Center(
                      child: Text(
                        'Chưa có câu hỏi nào.',
                        style: TextStyle(color: MetaGymTheme.textSecondary),
                      ),
                    ),
                  ),
                for (final message in _messages)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: message.role == 'ASSISTANT'
                          ? MetaGymTheme.cardSurface
                          : MetaGymTheme.elevatedSurface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: message.role == 'ASSISTANT'
                            ? const Color(0x33FF5E36)
                            : MetaGymTheme.cardBorder,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              message.role == 'ASSISTANT'
                                  ? Icons.auto_awesome_rounded
                                  : Icons.person_rounded,
                              size: 16,
                              color: message.role == 'ASSISTANT'
                                  ? MetaGymTheme.primary
                                  : MetaGymTheme.reflectionBlue,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              message.role == 'ASSISTANT' ? 'Trợ lý AI' : 'Bạn',
                              style: TextStyle(
                                color: message.role == 'ASSISTANT'
                                    ? MetaGymTheme.primary
                                    : MetaGymTheme.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          message.role == 'ASSISTANT' &&
                                  message.status != 'COMPLETED'
                              ? 'Phản hồi chưa hoàn tất.'
                              : message.content,
                          style: const TextStyle(
                            color: MetaGymTheme.textPrimary,
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_hasMore)
                  TextButton(
                    onPressed: _loadingMore ? null : _loadMore,
                    child: const Text(
                      'Tải thêm',
                      style: TextStyle(color: MetaGymTheme.primary),
                    ),
                  ),
              ],
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: const BoxDecoration(
            color: MetaGymTheme.cardSurface,
            border: Border(top: BorderSide(color: MetaGymTheme.cardBorder)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                if (_sendError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      _sendError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                if (_notice != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      _notice!,
                      style: const TextStyle(color: MetaGymTheme.textSecondary),
                    ),
                  ),
                if ((_sendError != null || _notice != null) &&
                    _question.text.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: TextButton(
                      onPressed: _sending ? null : _send,
                      child: const Text(
                        'Thử lại câu hỏi',
                        style: TextStyle(color: MetaGymTheme.primary),
                      ),
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _question,
                        maxLength: 10000,
                        maxLines: 2,
                        style: const TextStyle(color: MetaGymTheme.textPrimary),
                        decoration: InputDecoration(
                          labelText: 'Câu hỏi',
                          counterText: '',
                          labelStyle: const TextStyle(
                            color: MetaGymTheme.textSecondary,
                          ),
                          filled: true,
                          fillColor: MetaGymTheme.elevatedSurface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: MetaGymTheme.cardBorder,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: MetaGymTheme.cardBorder,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: MetaGymTheme.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(80, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _sending ? null : _send,
                      child: Text(_sending ? 'Đang hỏi…' : 'Hỏi AI'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
