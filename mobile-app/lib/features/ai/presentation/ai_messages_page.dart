import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_tap.dart';
import 'package:meta_gym_app/features/ai/data/ai_service.dart';
import 'package:meta_gym_app/features/ai/domain/ai_conversation.dart';
import 'package:meta_gym_app/features/ai/domain/ai_message.dart';
import 'package:meta_gym_app/features/messaging/data/messaging_service.dart';
import 'package:meta_gym_app/core/theme/meta_gym_icons.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_svg_icon.dart';

const _aiQuickSuggestions = <String>[
  'Gợi ý bữa phụ 25g đạm',
  'Chỉnh form Bench Press',
  'Lịch phục hồi vai',
];

String _formatAiMessageTime(String raw) {
  final parsed = DateTime.tryParse(raw.trim());
  if (parsed == null) return raw;
  final local = parsed.toLocal();
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  return '$hh:$mm';
}

class AiMessagesPage extends StatefulWidget {
  const AiMessagesPage({
    required this.service,
    required this.conversation,
    this.initialPrompt,
    super.key,
  });
  final AiService service;
  final AiConversation conversation;
  final String? initialPrompt;
  @override
  State<AiMessagesPage> createState() => _AiMessagesPageState();
}

class _AiMessagesPageState extends State<AiMessagesPage> {
  final _question = TextEditingController();
  final _scrollController = ScrollController();
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
    if (widget.initialPrompt != null && widget.initialPrompt!.trim().isNotEmpty) {
      _question.text = widget.initialPrompt!.trim();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _question.dispose();
    _scrollController.dispose();
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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) return;
        final reduced = MediaQuery.disableAnimationsOf(context);
        final target = _scrollController.position.maxScrollExtent;
        if (reduced) {
          _scrollController.jumpTo(target);
        } else {
          _scrollController.animateTo(
            target,
            duration: MetaGymTheme.localStateDuration,
            curve: Curves.easeOutCubic,
          );
        }
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
    final canPop = Navigator.of(context).canPop();
    return Scaffold(
      backgroundColor: palette.canvas,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leadingWidth: canPop ? 72 : null,
        leading: canPop
            ? Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: MetaGymCircleIconButton(
                    svgAsset: MetaGymIcons.commonBack,
                    icon: Icons.arrow_back_rounded,
                    tooltip: 'Quay lại',
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                ),
              )
            : null,
        titleSpacing: canPop ? 8 : 16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.conversation.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'Trợ lý AI Meta Gym',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: palette.primaryText,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
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
                  controller: _scrollController,
                  padding: EdgeInsets.fromLTRB(
                    16,
                    MediaQuery.paddingOf(context).top + kToolbarHeight + 12,
                    16,
                    16,
                  ),
                  children: [
                    MetaGymGlassCard(
                      solid: false,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Image.asset(
                            'assets/images/mascot/meta_kong_hero.webp',
                            width: 52,
                            height: 52,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: isLight
                                    ? const Color(0xFFFFEBE3)
                                    : const Color(0xFF222834),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: MetaGymTheme.primary.withValues(
                                    alpha: 0.45,
                                  ),
                                ),
                              ),
                              alignment: Alignment.center,
                              child: const MetaGymSvgIcon(
                                MetaGymIcons.navAiEmblem,
                                size: 22,
                                fallbackIcon: Icons.auto_awesome_rounded,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Meta Kong · Trợ lý AI Meta Gym',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: palette.primaryText,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Nội dung AI chỉ để tham khảo; không thay thế tư vấn y tế hoặc huấn luyện cá nhân.',
                                  style: TextStyle(
                                    color: palette.textWarmMuted,
                                    fontSize: 12,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (_loading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 28),
                          child: CircularProgressIndicator(
                            color: MetaGymTheme.primary,
                          ),
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
                                alpha: isLight ? 0.45 : 0.60,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              const MetaGymSvgIcon(
                                MetaGymIcons.stateError,
                                size: 18,
                                fallbackIcon: Icons.error_outline_rounded,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: TextStyle(
                                    color: isLight
                                        ? palette.error
                                        : const Color(0xFFFFB2B6),
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              TextButton(
                                style: TextButton.styleFrom(
                                  minimumSize: const Size(48, 48),
                                ),
                                onPressed:
                                    _messages.isEmpty ? _load : _loadMore,
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
                          solid: false,
                          padding: const EdgeInsets.all(24),
                          child: Center(
                            child: Text(
                              'Chưa có câu hỏi nào.',
                              style: TextStyle(
                                color: palette.textWarmMuted,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      for (final message in _messages)
                        _buildAiChatBubble(context, message, palette, isLight),
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
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                decoration: BoxDecoration(
                  color: isLight
                      ? const Color(0xF5F5F7FA)
                      : const Color(0xF2171412),
                  border: Border(
                    top: BorderSide(
                      color: isLight
                          ? palette.borderSolid
                          : const Color(0x52A79D92),
                      width: 0.9,
                    ),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
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
                              fontSize: 13,
                            ),
                          ),
                        ),
                      if (_notice != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            _notice!,
                            style: TextStyle(
                              color: palette.textWarmMuted,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      if ((_sendError != null || _notice != null) &&
                          _question.text.trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Align(
                            alignment: Alignment.centerLeft,
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
                        ),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final (idx, tip)
                                in _aiQuickSuggestions.indexed) ...[
                              if (idx > 0) const SizedBox(width: 8),
                              MetaGymTap(
                                onTap: _sending
                                    ? null
                                    : () {
                                        _question.text = tip;
                                        _question.selection =
                                            TextSelection.collapsed(
                                              offset: tip.length,
                                            );
                                      },
                                borderRadius: BorderRadius.circular(999),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 11,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isLight
                                        ? palette.surfaceSolid
                                        : const Color(0xA6231F1C),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: isLight
                                          ? palette.borderSolid
                                          : const Color(0x52A79D92),
                                    ),
                                  ),
                                  child: Text(
                                    tip,
                                    style: TextStyle(
                                      color: palette.textPrimary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _question,
                              maxLength: 10000,
                              minLines: 1,
                              maxLines: 3,
                              style: TextStyle(
                                color: palette.textPrimary,
                                fontSize: 14,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Nhập câu hỏi cho Trợ lý AI...',
                                counterText: '',
                                hintStyle: TextStyle(
                                  color: palette.textSecondary,
                                  fontSize: 13.5,
                                ),
                                filled: true,
                                fillColor: palette.metricPanelBg,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: _sending ? null : _send,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                _sending ? 'Đang hỏi…' : 'Hỏi AI',
                                maxLines: 1,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
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

  Widget _buildAiChatBubble(
    BuildContext context,
    AiMessage message,
    MetaGymPalette palette,
    bool isLight,
  ) {
    final isAi = message.role == 'ASSISTANT';
    final maxBubbleWidth = MediaQuery.sizeOf(context).width * 0.80;
    final formattedTime = _formatAiMessageTime(message.createdAt);
    final bodyText = isAi && message.status != 'COMPLETED'
        ? 'Phản hồi chưa hoàn tất.'
        : message.content;

    if (!isAi) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Align(
          alignment: Alignment.centerRight,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxBubbleWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: MetaGymTheme.primary,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(18),
                      topRight: Radius.circular(18),
                      bottomLeft: Radius.circular(18),
                      bottomRight: Radius.circular(4),
                    ),
                    boxShadow: isLight
                        ? null
                        : const [
                            BoxShadow(
                              color: Color(0x3DFF5E36),
                              blurRadius: 12,
                              offset: Offset(0, 4),
                            ),
                          ],
                  ),
                  child: Text(
                    bodyText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.45,
                    ),
                  ),
                ),
                if (formattedTime.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    formattedTime,
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 12,
                      fontFeatures: MetaGymTheme.tabularFigures,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: isLight ? const Color(0xFFFFEBE3) : const Color(0xFF222834),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: MetaGymTheme.primary.withValues(
                  alpha: isLight ? 0.42 : 0.45,
                ),
              ),
            ),
            alignment: Alignment.center,
            child: const MetaGymSvgIcon(
              MetaGymIcons.navAiEmblem,
              size: 18,
              fallbackIcon: Icons.auto_awesome_rounded,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxBubbleWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: isLight
                          ? palette.surfaceSolid
                          : const Color(0xD426211D),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(18),
                        topRight: Radius.circular(18),
                        bottomLeft: Radius.circular(4),
                        bottomRight: Radius.circular(18),
                      ),
                      border: Border.all(
                        color: MetaGymTheme.primary.withValues(
                          alpha: isLight ? 0.28 : 0.34,
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Trợ lý AI Meta Gym',
                          style: TextStyle(
                            color: palette.primaryText,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          bodyText,
                          style: TextStyle(
                            color: palette.textPrimary,
                            fontSize: 14,
                            height: 1.48,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (formattedTime.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      formattedTime,
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 12,
                        fontFeatures: MetaGymTheme.tabularFigures,
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
}
