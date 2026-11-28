import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
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
  Widget build(BuildContext context) {
    final palette = MetaGymTheme.paletteOf(context);
    final isLight = MetaGymTheme.isLightPalette(context);
    return Scaffold(
      backgroundColor: palette.canvas,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leadingWidth: 72,
        leading: Navigator.of(context).canPop()
            ? Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: MetaGymCircleIconButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip: 'Quay lại',
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                ),
              )
            : null,
        titleSpacing: Navigator.of(context).canPop() ? 8 : 16,
        title: Text(
          widget.conversation.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: palette.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const MetaGymBackground(),
          Column(
            children: [
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    MediaQuery.paddingOf(context).top + kToolbarHeight + 12,
                    16,
                    16,
                  ),
                  children: [
                    MetaGymGlassCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: palette.reflection,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Nội dung AI chỉ để tham khảo; không thay thế tư vấn y tế hoặc huấn luyện cá nhân.',
                              style: TextStyle(
                                color: palette.textSecondary,
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
                        child: CircularProgressIndicator(
                          color: MetaGymTheme.primary,
                        ),
                      )
                    else ...[
                      if (_error != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isLight
                                ? palette.error.withValues(alpha: 0.10)
                                : const Color(0xD4331E1E),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: palette.error.withValues(
                                alpha: isLight ? 0.35 : 0.60,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.error_outline_rounded,
                                color: palette.error,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: TextStyle(
                                    color: isLight
                                        ? palette.error
                                        : const Color(0xFFFFB2B6),
                                  ),
                                ),
                              ),
                              TextButton(
                                style: TextButton.styleFrom(
                                  minimumSize: const Size(48, 48),
                                ),
                                onPressed: _messages.isEmpty
                                    ? _load
                                    : _loadMore,
                                child: Text(
                                  'Thử lại',
                                  style: TextStyle(color: palette.primaryText),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (_messages.isEmpty && _error == null)
                        MetaGymGlassCard(
                          padding: const EdgeInsets.all(24),
                          child: Center(
                            child: Text(
                              'Chưa có câu hỏi nào.',
                              style: TextStyle(color: palette.textSecondary),
                            ),
                          ),
                        ),
                      for (final message in _messages)
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: message.role == 'ASSISTANT'
                                ? (isLight
                                      ? palette.surfaceSolid
                                      : const Color(0xC42B2622))
                                : palette.metricPanelBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: message.role == 'ASSISTANT'
                                  ? MetaGymTheme.brandOrange.withValues(
                                      alpha: isLight ? 0.40 : 0.53,
                                    )
                                  : palette.metricPanelBorder,
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
                                        ? palette.primaryText
                                        : palette.reflection,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    message.role == 'ASSISTANT'
                                        ? 'Trợ lý AI'
                                        : 'Bạn',
                                    style: TextStyle(
                                      color: message.role == 'ASSISTANT'
                                          ? palette.primaryText
                                          : palette.textPrimary,
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
                                style: TextStyle(
                                  color: palette.textPrimary,
                                  fontSize: 14,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (_hasMore)
                        TextButton(
                          style: TextButton.styleFrom(
                            minimumSize: const Size(48, 48),
                          ),
                          onPressed: _loadingMore ? null : _loadMore,
                          child: Text(
                            'Tải thêm',
                            style: TextStyle(color: palette.primaryText),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                decoration: BoxDecoration(
                  color: isLight
                      ? palette.surfaceSolid
                      : const Color(0xF0241F1B),
                  border: Border(
                    top: BorderSide(
                      color: isLight
                          ? palette.borderSolid
                          : const Color(0xA3A79D92),
                    ),
                  ),
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
                              color: isLight
                                  ? palette.error
                                  : const Color(0xFFFFB2B6),
                            ),
                          ),
                        ),
                      if (_notice != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            _notice!,
                            style: TextStyle(color: palette.textSecondary),
                          ),
                        ),
                      if ((_sendError != null || _notice != null) &&
                          _question.text.trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: TextButton(
                            style: TextButton.styleFrom(
                              minimumSize: const Size(48, 48),
                            ),
                            onPressed: _sending ? null : _send,
                            child: Text(
                              'Thử lại câu hỏi',
                              style: TextStyle(color: palette.primaryText),
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
                              style: TextStyle(color: palette.textPrimary),
                              decoration: InputDecoration(
                                labelText: 'Câu hỏi',
                                counterText: '',
                                labelStyle: TextStyle(
                                  color: palette.textSecondary,
                                ),
                                floatingLabelStyle: TextStyle(
                                  color: palette.primaryText,
                                  fontWeight: FontWeight.w600,
                                ),
                                filled: true,
                                fillColor: palette.metricPanelBg,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(
                                    color: palette.metricPanelBorder,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(
                                    color: palette.metricPanelBorder,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: MetaGymTheme.brandOrange,
                                    width: 1.5,
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
                                borderRadius: BorderRadius.circular(14),
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
        ],
      ),
    );
  }
}
