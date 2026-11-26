import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/theme/meta_gym_icons.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_icon.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_tap.dart';
import 'package:meta_gym_app/features/ai/data/ai_service.dart';
import 'package:meta_gym_app/features/ai/domain/ai_conversation.dart';
import 'package:meta_gym_app/features/ai/domain/ai_message.dart';
import 'package:meta_gym_app/features/auth/domain/auth_models.dart';
import 'package:meta_gym_app/features/auth/presentation/session_controller.dart';
import 'package:meta_gym_app/features/coaching/presentation/coaching_ui.dart';
import 'package:meta_gym_app/features/messaging/data/messaging_service.dart';

/// Màn hình **4.1 Trợ lý AI Coach** (`ai_messages_page.dart (Coach)`) & AI Member.
class AiMessagesPage extends StatelessWidget {
  const AiMessagesPage({
    required this.service,
    required this.conversation,
    this.coachMode,
    this.bottomPadding,
    super.key,
  });

  final AiService service;
  final AiConversation conversation;
  final bool? coachMode;
  final double? bottomPadding;

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isLight ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: MetaGymColors.of(context).canvas,
        resizeToAvoidBottomInset: true,
        body: AiMessagesView(
          service: service,
          conversation: conversation,
          coachMode: coachMode,
          bottomPadding: bottomPadding,
        ),
      ),
    );
  }
}

/// Nội dung giao diện **Trợ lý AI Coach / Member** dùng chung giữa tab nhúng
/// (`AiConversationsPage` ở `CoachHomePage` Tab 2) và màn hình độc lập `AiMessagesPage`.
class AiMessagesView extends StatefulWidget {
  const AiMessagesView({
    required this.service,
    required this.conversation,
    this.coachMode,
    this.bottomPadding,
    this.onCreateConversation,
    this.onOpenHistory,
    this.creatingConversation = false,
    super.key,
  });

  final AiService service;
  final AiConversation conversation;
  final bool? coachMode;
  final double? bottomPadding;
  final VoidCallback? onCreateConversation;
  final VoidCallback? onOpenHistory;
  final bool creatingConversation;

  @override
  State<AiMessagesView> createState() => _AiMessagesViewState();
}

class _AiMessagesViewState extends State<AiMessagesView> {
  static const _coachPrompts = <({String label, String prompt})>[
    (
      label: 'Bài thay thế vai yếu',
      prompt:
          'Học viên đau nhẹ khớp vai khi đẩy ngực, gợi ý bài thay thế an toàn?',
    ),
    (
      label: 'Lịch Deload tuần 5',
      prompt:
          'Gợi ý lịch Deload tuần 5 giảm tải hợp lý cho giáo án 4 buổi/tuần.',
    ),
    (
      label: 'Gợi ý thực đơn 2.200 kcal',
      prompt:
          'Gợi ý thực đơn khoảng 2.200 kcal/ngày cho học viên tập 4 buổi/tuần.',
    ),
  ];

  static const _memberPrompts = <({String label, String prompt})>[
    (
      label: 'Ăn gì trước tập?',
      prompt: 'Hôm nay tập Ngực & Tay sau mình nên ăn gì trước tập 1 tiếng?',
    ),
    (
      label: 'Gợi ý lịch tập tuần',
      prompt: 'Gợi ý lịch tập tăng cơ nạc 4 buổi/tuần phù hợp với mình.',
    ),
    (
      label: 'Tính lượng Protein/ngày',
      prompt: 'Với cân nặng 72kg mình cần bao nhiêu gam protein mỗi ngày?',
    ),
  ];

  final _question = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();

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

  bool get _isCoachView {
    if (widget.coachMode != null) return widget.coachMode!;
    return optionalProvider<SessionController>(context)?.user?.role ==
        UserRole.coach;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void didUpdateWidget(covariant AiMessagesView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.conversation.id != widget.conversation.id ||
        !identical(oldWidget.service, widget.service)) {
      _messages = const [];
      _page = 1;
      _hasMore = false;
      _error = null;
      _sendError = null;
      _notice = null;
      _pendingContent = null;
      _pendingRequestId = null;
      _load();
    }
  }

  @override
  void dispose() {
    _question.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final targetId = widget.conversation.id;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final messages = await widget.service.getMessages(targetId, 1);
      if (!mounted || widget.conversation.id != targetId) return;
      setState(() {
        _messages = messages;
        _page = 1;
        _hasMore = messages.length == 20;
      });
    } on ApiException catch (error) {
      if (mounted && widget.conversation.id == targetId) {
        setState(() => _error = error.message);
      }
    } catch (_) {
      if (mounted && widget.conversation.id == targetId) {
        setState(() => _error = 'Không tải được lịch sử AI.');
      }
    } finally {
      if (mounted && widget.conversation.id == targetId) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadMore() async {
    final targetId = widget.conversation.id;
    setState(() {
      _loadingMore = true;
      _error = null;
    });
    try {
      final messages = await widget.service.getMessages(targetId, _page + 1);
      if (!mounted || widget.conversation.id != targetId) return;
      setState(() {
        _messages = [..._messages, ...messages];
        _page++;
        _hasMore = messages.length == 20;
      });
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
    final targetConvId = widget.conversation.id;
    setState(() {
      _sending = true;
      _sendError = null;
      _notice = null;
    });
    try {
      final answer = await widget.service.sendQuestion(
        targetConvId,
        content,
        _pendingRequestId!,
      );
      if (!mounted || widget.conversation.id != targetConvId) return;
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
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
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

  void _insertSuggestion(String prompt) {
    _question
      ..text = prompt
      ..selection = TextSelection.collapsed(offset: prompt.length);
    _focusNode.requestFocus();
  }

  String _formatTimeLabel(String raw) {
    final parsed = DateTime.tryParse(raw.trim());
    if (parsed == null) return '';
    final local = parsed.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final colors = MetaGymColors.of(context);
    final isLight = Theme.of(context).brightness == Brightness.light;
    final isCoach = _isCoachView;
    final gutter = MediaQuery.sizeOf(context).width >= 600
        ? MetaGymTheme.tabletGutter
        : MetaGymTheme.pageGutter;

    return Stack(
      fit: StackFit.expand,
      children: [
        const MetaGymBackground(),
        SafeArea(
          bottom: false,
          child: Column(
            children: [
              _buildHeader(context, colors, isLight: isLight, isCoach: isCoach),
              Expanded(
                child: RefreshIndicator(
                  color: MetaGymTheme.primary,
                  backgroundColor: colors.overlayGlass,
                  onRefresh: _load,
                  child: ListView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(gutter, 4, gutter, 16),
                    children: [
                      _buildCompanionCard(colors, isCoach: isCoach),
                      const SizedBox(height: 14),
                      if (_loading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: MetaGymTheme.primary,
                            ),
                          ),
                        )
                      else ...[
                        if (_error != null) ...[
                          _buildErrorBanner(colors),
                          const SizedBox(height: 12),
                        ],
                        if (_messages.isEmpty && _error == null)
                          MetaGymGlassCard(
                            solid: !isCoach,
                            padding: const EdgeInsets.all(22),
                            child: Center(
                              child: Text(
                                isCoach
                                    ? 'Chưa có câu hỏi nào. Chọn gợi ý bên dưới để hỏi Meta Kong!'
                                    : 'Chưa có câu hỏi nào.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: colors.textWarmMuted,
                                  fontSize: 13.5,
                                ),
                              ),
                            ),
                          ),
                        for (final message in _messages)
                          _buildMessageItem(
                            context,
                            colors: colors,
                            isLight: isLight,
                            isCoach: isCoach,
                            message: message,
                          ),
                        if (_sending)
                          _buildThinkingIndicator(
                            colors: colors,
                            isLight: isLight,
                          ),
                        if (_hasMore)
                          TextButton(
                            style: TextButton.styleFrom(
                              minimumSize: const Size(48, 48),
                            ),
                            onPressed: _loadingMore ? null : _loadMore,
                            child: Text(
                              _loadingMore ? 'Đang tải…' : 'Tải thêm',
                              style: TextStyle(
                                color: colors.primaryText,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
              _buildComposerDock(
                context,
                colors: colors,
                isLight: isLight,
                isCoach: isCoach,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(
    BuildContext context,
    MetaGymColors colors, {
    required bool isLight,
    required bool isCoach,
  }) {
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    final gutter = MediaQuery.sizeOf(context).width >= 600
        ? MetaGymTheme.tabletGutter
        : MetaGymTheme.pageGutter;

    final titleColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          isCoach ? 'META GYM · COACH' : 'META GYM · AI',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: colors.primaryText,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.3,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                widget.conversation.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 16.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            if (widget.onOpenHistory != null) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: colors.textSecondary,
              ),
            ],
          ],
        ),
      ],
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(gutter, 8, gutter, 10),
      child: Row(
        children: [
          if (canPop) ...[
            MetaGymCircleIconButton(
              svgAsset: MetaGymIcons.commonBack,
              icon: Icons.arrow_back_ios_new_rounded,
              tooltip: 'Quay lại',
              onTap: () => Navigator.of(context).maybePop(),
            ),
            const SizedBox(width: 8),
          ] else ...[
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: isLight ? colors.surface : const Color(0xFF141821),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isLight
                      ? colors.border
                      : MetaGymTheme.primary.withValues(alpha: 0.35),
                ),
                boxShadow: [
                  BoxShadow(
                    color: MetaGymTheme.primary.withValues(alpha: 0.16),
                    blurRadius: 12,
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              alignment: Alignment.center,
              child: const MetaGymIcon(MetaGymIcons.appIconMark, size: 40),
            ),
            const SizedBox(width: 11),
          ],
          Expanded(
            child: widget.onOpenHistory != null
                ? Semantics(
                    button: true,
                    label: 'Danh sách hội thoại AI',
                    child: MetaGymTap(
                      onTap: widget.onOpenHistory,
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 2,
                          vertical: 4,
                        ),
                        child: titleColumn,
                      ),
                    ),
                  )
                : titleColumn,
          ),
          if (widget.onCreateConversation != null) ...[
            const SizedBox(width: 8),
            MetaGymCircleIconButton(
              svgAsset: MetaGymIcons.commonAdd,
              icon: Icons.add_rounded,
              tooltip: 'Hội thoại AI mới',
              onTap: widget.creatingConversation
                  ? null
                  : widget.onCreateConversation,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompanionCard(MetaGymColors colors, {required bool isCoach}) {
    return MetaGymGlassCard(
      solid: false,
      borderRadius: BorderRadius.circular(18),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Image.asset(
            'assets/images/mascot/meta_kong_hero.webp',
            width: 52,
            height: 52,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: colors.chipActiveBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.auto_awesome_rounded,
                color: colors.primaryText,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCoach
                      ? 'Meta Kong · Trợ lý Huấn luyện AI'
                      : 'Meta Kong · Trợ lý AI Meta Gym',
                  style: TextStyle(
                    color: colors.primaryText,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  isCoach
                      ? 'Hỗ trợ gợi ý bài tập thay thế an toàn chấn thương và gợi ý định lượng món ăn theo kcal cho học viên.'
                      : 'Nội dung AI chỉ để tham khảo; không thay thế tư vấn y tế hoặc huấn luyện cá nhân.',
                  style: TextStyle(
                    color: colors.textWarmMuted,
                    fontSize: 12,
                    height: 1.38,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(MetaGymColors colors) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.error.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.error.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: colors.error, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _error!,
              style: TextStyle(color: colors.error, fontSize: 13),
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: _messages.isEmpty ? _load : _loadMore,
            child: Text(
              'Thử lại',
              style: TextStyle(
                color: colors.primaryText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageItem(
    BuildContext context, {
    required MetaGymColors colors,
    required bool isLight,
    required bool isCoach,
    required AiMessage message,
  }) {
    final isAssistant = message.role == 'ASSISTANT';
    final timeLabel = _formatTimeLabel(message.createdAt);

    if (!isAssistant) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.80,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 10,
                ),
                decoration: const BoxDecoration(
                  color: MetaGymTheme.primary,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                    bottomLeft: Radius.circular(18),
                    bottomRight: Radius.circular(4),
                  ),
                ),
                child: Text(
                  message.content,
                  style: const TextStyle(
                    color: MetaGymTheme.onPrimary,
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
              ),
            ),
            if (timeLabel.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                timeLabel,
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 11,
                  fontFeatures: MetaGymTheme.tabularFigures,
                ),
              ),
            ],
          ],
        ),
      );
    }

    final displayBody = message.status != 'COMPLETED'
        ? 'Phản hồi chưa hoàn tất.'
        : message.content;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _buildAiAvatar(isLight),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.sizeOf(context).width * 0.82,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(18),
                        topRight: Radius.circular(18),
                        bottomRight: Radius.circular(18),
                        bottomLeft: Radius.circular(4),
                      ),
                      border: Border.all(
                        color: MetaGymTheme.primary.withValues(alpha: 0.34),
                      ),
                      boxShadow: isLight
                          ? const [
                              BoxShadow(
                                color: Color(0x0D0F172A),
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isCoach ? 'Trợ lý AI Coach' : 'Trợ lý AI',
                          style: TextStyle(
                            color: colors.primaryText,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 5),
                        _FormattedAiContent(
                          text: displayBody,
                          textColor: colors.textPrimary,
                        ),
                      ],
                    ),
                  ),
                ),
                if (timeLabel.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    timeLabel,
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 11,
                      fontFeatures: MetaGymTheme.tabularFigures,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiAvatar(bool isLight) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        gradient: isLight
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFEBE3), Color(0xFFFFDED2)],
              )
            : null,
        color: isLight ? null : const Color(0xFF222834),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: MetaGymTheme.primary.withValues(alpha: isLight ? 0.42 : 0.45),
        ),
      ),
      alignment: Alignment.center,
      child: const MetaGymIcon(MetaGymIcons.navAiEmblem, size: 18),
    );
  }

  Widget _buildThinkingIndicator({
    required MetaGymColors colors,
    required bool isLight,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildAiAvatar(isLight),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.border),
            ),
            child: Text(
              'Meta Kong đang phân tích…',
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComposerDock(
    BuildContext context, {
    required MetaGymColors colors,
    required bool isLight,
    required bool isCoach,
  }) {
    final media = MediaQuery.of(context);
    final navPadding = widget.bottomPadding;
    final viewInsetBottom = media.viewInsets.bottom;
    final resolvedBottomPadding = navPadding != null
        ? math.max(0.0, navPadding - viewInsetBottom - 8.0)
        : media.padding.bottom + 12.0;
    final suggestions = isCoach ? _coachPrompts : _memberPrompts;
    final gutter = media.size.width >= 600
        ? MetaGymTheme.tabletGutter
        : MetaGymTheme.pageGutter;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            colors.canvas.withValues(alpha: 0.0),
            colors.canvas.withValues(alpha: 0.90),
            colors.canvas.withValues(alpha: 0.98),
          ],
          stops: const [0.0, 0.25, 1.0],
        ),
      ),
      padding: EdgeInsets.fromLTRB(gutter, 8, gutter, resolvedBottomPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_sendError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                _sendError!,
                style: TextStyle(color: colors.error, fontSize: 12.5),
              ),
            ),
          if (_notice != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                _notice!,
                style: TextStyle(color: colors.textWarmMuted, fontSize: 12.5),
              ),
            ),
          if ((_sendError != null || _notice != null) &&
              _question.text.trim().isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                style: TextButton.styleFrom(minimumSize: const Size(48, 44)),
                onPressed: _sending ? null : _send,
                child: Text(
                  'Thử lại câu hỏi',
                  style: TextStyle(
                    color: colors.primaryText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < suggestions.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  _SuggestionPill(
                    label: suggestions[i].label,
                    colors: colors,
                    isLight: isLight,
                    onTap: () => _insertSuggestion(suggestions[i].prompt),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(minHeight: 46),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: colors.border),
                  ),
                  child: TextField(
                    controller: _question,
                    focusNode: _focusNode,
                    maxLength: 10000,
                    minLines: 1,
                    maxLines: 3,
                    style: TextStyle(color: colors.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: isCoach
                          ? 'Hỏi AI về giáo trình, kỹ thuật...'
                          : 'Nhập câu hỏi cho Trợ lý AI...',
                      hintStyle: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 13.5,
                      ),
                      counterText: '',
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 11,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (isCoach)
                Tooltip(
                  message: 'Hỏi AI',
                  child: Semantics(
                    button: true,
                    label: 'Hỏi AI',
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: Material(
                        color: _sending
                            ? MetaGymTheme.primary.withValues(alpha: 0.5)
                            : MetaGymTheme.primary,
                        borderRadius: BorderRadius.circular(14),
                        clipBehavior: Clip.antiAlias,
                        child: MetaGymTap(
                          onTap: _sending ? null : _send,
                          borderRadius: BorderRadius.circular(14),
                          child: const Center(
                            child: Icon(
                              Icons.arrow_upward_rounded,
                              color: MetaGymTheme.onPrimary,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              else
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: MetaGymTheme.primary,
                    foregroundColor: MetaGymTheme.onPrimary,
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
    );
  }
}

class _SuggestionPill extends StatelessWidget {
  const _SuggestionPill({
    required this.label,
    required this.colors,
    required this.isLight,
    required this.onTap,
  });

  final String label;
  final MetaGymColors colors;
  final bool isLight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isLight ? colors.surface : colors.liquidGlass,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isLight ? colors.border : colors.liquidGlassBorder,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: MetaGymTap(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          constraints: const BoxConstraints(minHeight: 36),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          alignment: Alignment.center,
          child: Text(
            label,
            maxLines: 1,
            style: TextStyle(
              color: colors.textWarmMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _FormattedAiContent extends StatelessWidget {
  const _FormattedAiContent({required this.text, required this.textColor});

  final String text;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final spans = <InlineSpan>[];
    final pattern = RegExp(r'\*\*(.+?)\*\*');
    var start = 0;
    for (final match in pattern.allMatches(text)) {
      if (match.start > start) {
        spans.add(TextSpan(text: text.substring(start, match.start)));
      }
      spans.add(
        TextSpan(
          text: match.group(1),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      );
      start = match.end;
    }
    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start)));
    }
    if (spans.isEmpty) {
      spans.add(TextSpan(text: text));
    }
    return Text.rich(
      TextSpan(
        style: TextStyle(color: textColor, fontSize: 14, height: 1.48),
        children: spans,
      ),
    );
  }
}
