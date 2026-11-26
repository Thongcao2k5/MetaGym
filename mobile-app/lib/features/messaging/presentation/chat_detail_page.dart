import 'package:meta_gym_app/core/theme/theme_controller.dart';

import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:meta_gym_app/core/navigation/meta_gym_navigation.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/network/metagym_realtime.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/theme/meta_gym_icons.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_tap.dart';
import 'package:meta_gym_app/features/auth/domain/auth_models.dart';
import 'package:meta_gym_app/features/auth/presentation/session_controller.dart';
import 'package:meta_gym_app/features/calls/data/calls_service.dart';
import 'package:meta_gym_app/features/calls/presentation/live_call_page.dart';
import 'package:meta_gym_app/features/coaching/data/coach_members_service.dart';
import 'package:meta_gym_app/features/coaching/domain/coach_member_models.dart';
import 'package:meta_gym_app/features/coaching/presentation/coach_member_detail_page.dart';
import 'package:meta_gym_app/features/coaching/presentation/coaching_ui.dart';
import 'package:meta_gym_app/features/messaging/data/messaging_service.dart';
import 'package:meta_gym_app/features/messaging/domain/chat_message.dart';
import 'package:meta_gym_app/features/messaging/domain/conversation.dart';
import 'package:meta_gym_app/features/messaging/presentation/chat_message_image.dart';
import 'package:meta_gym_app/features/messaging/presentation/messaging_session_cache.dart';
import 'package:meta_gym_app/features/progress/data/member_photo_service.dart';
import 'package:meta_gym_app/features/training/data/coach_training_service.dart';
import 'package:meta_gym_app/features/training/presentation/coach_training_page.dart';

/// Màn hình **5.2 Chi tiết tin nhắn (Coach ↔ HV)** & chat 1:1 cho Member.
class ConversationDetailPage extends StatefulWidget {
  const ConversationDetailPage({
    required this.conversation,
    this.service,
    required this.currentUserId,
    required this.picker,
    this.coachMode,
    this.mockTitle,
    this.mockInitials,
    this.mockContextTitle,
    this.initialMockMessages,
    this.onMockMessageAdded,
    super.key,
  });

  final Conversation conversation;
  final MessagingService? service;
  final String currentUserId;
  final ProgressPhotoPicker picker;
  final bool? coachMode;
  final String? mockTitle;
  final String? mockInitials;
  final String? mockContextTitle;
  final List<ChatMessage>? initialMockMessages;
  final ValueChanged<ChatMessage>? onMockMessageAdded;

  @override
  State<ConversationDetailPage> createState() => _ConversationDetailPageState();
}

class _ConversationDetailPageState extends State<ConversationDetailPage> {
  static const String _recipientDisabledMessage =
      'Không thể gửi tin nhắn vì tài khoản người nhận đang bị khóa';

  static const _memberQuickReplies = [
    'Lịch tập hôm nay',
    'Đổi giờ tập',
    'Hỏi thực đơn',
    'Cảm ơn Coach!',
  ];

  static const _coachQuickReplies = [
    'Nhận xét form tập',
    'Nhắc uống đủ nước',
    'Xác nhận lịch PT',
    'Đã cập nhật giáo trình',
  ];

  StreamSubscription<String>? _realtimeMessages;
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  List<ChatMessage> _messages = const [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _sending = false;
  bool _imageSending = false;
  bool _creatingCall = false;
  bool _recipientDisabled = false;
  String? _error;
  String? _sendError;
  String? _draftMessageId;
  String? _draftContent;
  String? _imageError;
  SelectedProgressImage? _pendingImage;
  String? _pendingMediaId;
  String? _pendingImageMessageId;
  String? _lastReadId;
  String? _markingReadId;
  SessionController? _sessionController;
  int _sessionEpoch = 0;
  Timer? _pollTimer;
  bool _polling = false;
  int _page = 1;
  bool _hasMore = false;

  bool get _isMockMode => widget.initialMockMessages != null;

  bool get _isCoachView {
    if (widget.coachMode != null) return widget.coachMode!;
    final role = _sessionController?.user?.role;
    if (role != null) return role == UserRole.coach;
    return widget.currentUserId.isNotEmpty &&
        widget.conversation.coachId == widget.currentUserId &&
        widget.conversation.memberId != widget.currentUserId;
  }

  List<String> get _quickReplies =>
      _isCoachView ? _coachQuickReplies : _memberQuickReplies;

  void _storeCache(
    List<ChatMessage> messages, {
    bool? hasMore,
    String? lastReadId,
  }) {
    MessagingSessionCache.writeThread(
      widget.currentUserId,
      widget.service,
      widget.conversation.messageKey,
      messages: messages,
      hasMore: hasMore,
      lastReadId: lastReadId ?? _lastReadId,
    );
  }

  List<ChatMessage> _mergeMessages({
    List<ChatMessage> newer = const [],
    List<ChatMessage> current = const [],
    List<ChatMessage> older = const [],
  }) {
    final combined = <ChatMessage>[...newer, ...current, ...older];
    final byId = <String, ChatMessage>{};
    final orderIndex = <String, int>{};
    for (var i = 0; i < combined.length; i++) {
      final item = combined[i];
      orderIndex.putIfAbsent(item.id, () => i);
      byId.putIfAbsent(item.id, () => item);
    }
    final unique = byId.values.toList();
    unique.sort((a, b) {
      final aTime = DateTime.tryParse(a.sentAt);
      final bTime = DateTime.tryParse(b.sentAt);
      if (aTime != null && bTime != null) {
        final cmp = bTime.compareTo(aTime);
        if (cmp != 0) return cmp;
      }
      return orderIndex[a.id]!.compareTo(orderIndex[b.id]!);
    });
    return unique;
  }

  bool _isActiveRequest(int epoch, String userId, String messageKey) {
    if (!mounted) return false;
    if (epoch != _sessionEpoch ||
        userId != widget.currentUserId ||
        messageKey != widget.conversation.messageKey) {
      return false;
    }
    final session = _sessionController;
    if (session != null) {
      if (session.status == SessionStatus.unauthenticated) return false;
      if (session.user != null && session.user!.id != userId) return false;
    }
    return true;
  }

  void _handleSessionChanged() {
    if (!mounted) return;
    final session = _sessionController;
    if (session == null) return;
    if (session.status == SessionStatus.unauthenticated ||
        session.user == null ||
        session.user!.id != widget.currentUserId) {
      _sessionEpoch++;
      _pollTimer?.cancel();
      MessagingSessionCache.clearAll();
      setState(() {
        _messages = const [];
        _loading = false;
        _loadingMore = false;
        _sending = false;
        _imageSending = false;
        _polling = false;
        _recipientDisabled = false;
        _error = null;
        _sendError = null;
        _imageError = null;
        _draftMessageId = null;
        _draftContent = null;
        _pendingImage = null;
        _pendingMediaId = null;
        _pendingImageMessageId = null;
        _lastReadId = null;
        _markingReadId = null;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final session = optionalProvider<SessionController>(context);
    if (!identical(_sessionController, session)) {
      _sessionController?.removeListener(_handleSessionChanged);
      _sessionController = session;
      _sessionController?.addListener(_handleSessionChanged);
    }
  }

  @override
  void didUpdateWidget(covariant ConversationDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentUserId != widget.currentUserId ||
        oldWidget.conversation.messageKey != widget.conversation.messageKey ||
        !identical(oldWidget.service, widget.service)) {
      _sessionEpoch++;
      if (oldWidget.currentUserId != widget.currentUserId) {
        MessagingSessionCache.clearAll();
      }
      final cached = MessagingSessionCache.readThread(
        widget.currentUserId,
        widget.service,
        widget.conversation.messageKey,
      );
      setState(() {
        _messages = cached != null
            ? List<ChatMessage>.from(cached.messages)
            : const [];
        _hasMore = cached?.hasMore ?? false;
        _lastReadId = cached?.lastReadId;
        _markingReadId = null;
        _loading = cached == null;
        _loadingMore = false;
        _sending = false;
        _imageSending = false;
        _polling = false;
        _recipientDisabled = false;
        _page = 1;
        _error = null;
        _sendError = null;
        _imageError = null;
        _draftMessageId = null;
        _draftContent = null;
        _pendingImage = null;
        _pendingMediaId = null;
        _pendingImageMessageId = null;
      });
      if (!_isMockMode) {
        _load();
      }
    }
  }

  @override
  void dispose() {
    _sessionController?.removeListener(_handleSessionChanged);
    _pollTimer?.cancel();
    unawaited(_realtimeMessages?.cancel());
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    if (_isMockMode) {
      _messages = widget.initialMockMessages!.reversed.toList();
      _loading = false;
    } else {
      _realtimeMessages = optionalProvider<MetaGymRealtime>(context)?.messages
          .listen((id) {
            if (mounted && id == widget.conversation.id) {
              unawaited(_refreshLatest());
            }
          });
      final cached = MessagingSessionCache.readThread(
        widget.currentUserId,
        widget.service,
        widget.conversation.messageKey,
      );
      if (cached != null) {
        _messages = List<ChatMessage>.from(cached.messages);
        _hasMore = cached.hasMore;
        _lastReadId = cached.lastReadId;
        _loading = false;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load();
      });
      _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
        if (mounted) _refreshLatest();
      });
    }
  }

  Future<void> _load() async {
    if (widget.service == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final requestEpoch = _sessionEpoch;
    final requestUserId = widget.currentUserId;
    final requestKey = widget.conversation.messageKey;
    final showLoader = _messages.isEmpty;
    setState(() {
      if (showLoader) _loading = true;
      _error = null;
    });
    try {
      final messages = await widget.service!.getMessages(requestKey, 1);
      if (!_isActiveRequest(requestEpoch, requestUserId, requestKey)) return;
      final hasMore = messages.length == 20;
      final merged = _mergeMessages(newer: messages, current: _messages);
      setState(() {
        _messages = merged;
        if (_page <= 1) {
          _page = 1;
          _hasMore = hasMore;
        }
        _loading = false;
      });
      _storeCache(merged, hasMore: _hasMore);
      unawaited(_markLatestReceived(merged).catchError((_) {}));
    } on ApiException catch (error) {
      if (!_isActiveRequest(requestEpoch, requestUserId, requestKey)) return;
      if (_messages.isEmpty) {
        setState(() => _error = error.message);
      }
    } catch (_) {
      if (!_isActiveRequest(requestEpoch, requestUserId, requestKey)) return;
      if (_messages.isEmpty) {
        setState(() => _error = 'Không tải được tin nhắn.');
      }
    } finally {
      if (_isActiveRequest(requestEpoch, requestUserId, requestKey) &&
          _loading) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _refreshLatest() async {
    if (_polling || _loading || widget.service == null) return;
    final requestEpoch = _sessionEpoch;
    final requestUserId = widget.currentUserId;
    final requestKey = widget.conversation.messageKey;
    _polling = true;
    try {
      final latest = await widget.service!.getMessages(requestKey, 1);
      if (!_isActiveRequest(requestEpoch, requestUserId, requestKey)) return;
      final merged = _mergeMessages(newer: latest, current: _messages);
      setState(() => _messages = merged);
      _storeCache(merged);
      unawaited(_markLatestReceived(merged).catchError((_) {}));
    } catch (_) {
      // Giữ danh sách tin nhắn đang hiển thị khi đồng bộ nền lỗi.
    } finally {
      if (_isActiveRequest(requestEpoch, requestUserId, requestKey)) {
        _polling = false;
      }
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || widget.service == null) return;
    final requestEpoch = _sessionEpoch;
    final requestUserId = widget.currentUserId;
    final requestKey = widget.conversation.messageKey;
    final targetPage = _page + 1;
    setState(() {
      _loadingMore = true;
      _error = null;
    });
    try {
      final messages = await widget.service!.getMessages(
        requestKey,
        targetPage,
      );
      if (!_isActiveRequest(requestEpoch, requestUserId, requestKey)) return;
      final merged = _mergeMessages(current: _messages, older: messages);
      setState(() {
        _messages = merged;
        _page = targetPage;
        _hasMore = messages.length == 20;
      });
      _storeCache(merged, hasMore: _hasMore);
      unawaited(_markLatestReceived(merged).catchError((_) {}));
    } on ApiException catch (error) {
      if (!_isActiveRequest(requestEpoch, requestUserId, requestKey)) return;
      setState(() => _error = error.message);
    } catch (_) {
      if (!_isActiveRequest(requestEpoch, requestUserId, requestKey)) return;
      setState(() => _error = 'Không tải thêm được tin nhắn.');
    } finally {
      if (_isActiveRequest(requestEpoch, requestUserId, requestKey)) {
        setState(() => _loadingMore = false);
      }
    }
  }

  Future<void> _markLatestReceived(List<ChatMessage> messages) async {
    final service = widget.service;
    if (service == null) return;
    final latest = messages
        .where((message) => message.senderId != widget.currentUserId)
        .firstOrNull;
    if (latest == null ||
        latest.id == _lastReadId ||
        latest.id == _markingReadId) {
      return;
    }

    final requestEpoch = _sessionEpoch;
    final requestUserId = widget.currentUserId;
    final requestKey = widget.conversation.messageKey;
    _markingReadId = latest.id;
    try {
      await service.markRead(requestKey, latest.id);
      if (!_isActiveRequest(requestEpoch, requestUserId, requestKey)) return;
      _lastReadId = latest.id;
      _storeCache(_messages, lastReadId: latest.id);
    } catch (_) {
      // Giữ nguyên _lastReadId để lần đồng bộ tiếp theo thử lại.
    } finally {
      if (_markingReadId == latest.id) {
        _markingReadId = null;
      }
    }
  }

  String _nowHHmm() {
    final now = DateTime.now();
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  String _formatBubbleTime(String raw) {
    final parsed = DateTime.tryParse(raw.trim());
    if (parsed == null) return raw;
    final local = parsed.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  void _sendMockMessage(String rawText) {
    final text = rawText.trim();
    if (text.isEmpty) return;
    final msg = ChatMessage(
      id: 'local-${DateTime.now().microsecondsSinceEpoch}',
      senderId: widget.currentUserId,
      messageType: 'TEXT',
      content: text,
      mediaId: null,
      sentAt: _nowHHmm(),
    );
    _textController.clear();
    setState(() {
      _messages = [msg, ..._messages];
      _sendError = null;
    });
    widget.onMockMessageAdded?.call(msg);
  }

  void _saveMessage(ChatMessage message) {
    final updated = _mergeMessages(newer: [message], current: _messages);
    _messages = updated;
    _storeCache(updated);
    if (_scrollController.hasClients && _scrollController.offset > 0) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _send([String? presetText]) async {
    if (_sending || _recipientDisabled) return;
    final candidate = presetText ?? _textController.text;
    final text = candidate.trim().isNotEmpty
        ? candidate.trim()
        : (_draftContent ?? '').trim();
    if (text.isEmpty) return;

    if (_isMockMode) {
      _sendMockMessage(text);
      return;
    }

    final service = widget.service;
    if (service == null) return;
    final requestEpoch = _sessionEpoch;
    final requestUserId = widget.currentUserId;
    final requestKey = widget.conversation.messageKey;
    if (_draftContent != text || _draftMessageId == null) {
      _draftContent = text;
      _draftMessageId = newClientMessageId();
    }
    final clientMessageId = _draftMessageId!;
    setState(() {
      _sending = true;
      _sendError = null;
    });
    try {
      final created = await service.sendText(requestKey, text, clientMessageId);
      if (!_isActiveRequest(requestEpoch, requestUserId, requestKey)) return;
      _textController.clear();
      _draftContent = null;
      _draftMessageId = null;
      setState(() {
        _saveMessage(created);
      });
    } on ApiException catch (error) {
      if (!_isActiveRequest(requestEpoch, requestUserId, requestKey)) return;
      if (error.code == 'RECIPIENT_ACCOUNT_DISABLED') {
        _draftContent = null;
        _draftMessageId = null;
        setState(() {
          _recipientDisabled = true;
          _sendError = null;
          _imageError = null;
        });
        return;
      }
      setState(() => _sendError = error.message);
    } catch (_) {
      if (!_isActiveRequest(requestEpoch, requestUserId, requestKey)) return;
      setState(() => _sendError = 'Không gửi được tin nhắn.');
    } finally {
      if (_isActiveRequest(requestEpoch, requestUserId, requestKey)) {
        setState(() => _sending = false);
      }
    }
  }

  Future<void> _pickImage() async {
    if (_isMockMode || widget.service == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Chế độ xem trước giao diện — chưa kết nối upload ảnh.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (_imageSending || _recipientDisabled) return;
    final requestEpoch = _sessionEpoch;
    final requestUserId = widget.currentUserId;
    final requestKey = widget.conversation.messageKey;
    final image = await widget.picker.pick();
    if (image == null ||
        !_isActiveRequest(requestEpoch, requestUserId, requestKey)) {
      return;
    }
    setState(() {
      _pendingImage = image;
      _pendingMediaId = null;
      _pendingImageMessageId = newClientMessageId();
      _imageError = null;
    });
    await _sendImage();
  }

  Future<void> _sendImage() async {
    final image = _pendingImage;
    if (image == null ||
        _imageSending ||
        _recipientDisabled ||
        widget.service == null) {
      return;
    }
    final requestEpoch = _sessionEpoch;
    final requestUserId = widget.currentUserId;
    final requestKey = widget.conversation.messageKey;
    final clientMessageId = _pendingImageMessageId ??= newClientMessageId();
    setState(() {
      _imageSending = true;
      _imageError = null;
    });
    try {
      final mediaId = _pendingMediaId ??= await widget.service!.uploadImage(
        image,
      );
      if (!_isActiveRequest(requestEpoch, requestUserId, requestKey)) return;
      final created = await widget.service!.sendImage(
        requestKey,
        mediaId,
        clientMessageId,
      );
      if (!_isActiveRequest(requestEpoch, requestUserId, requestKey)) return;
      _pendingImage = null;
      _pendingMediaId = null;
      _pendingImageMessageId = null;
      setState(() {
        _saveMessage(created);
      });
    } on ApiException catch (error) {
      if (!_isActiveRequest(requestEpoch, requestUserId, requestKey)) return;
      if (error.code == 'RECIPIENT_ACCOUNT_DISABLED') {
        _pendingImage = null;
        _pendingMediaId = null;
        _pendingImageMessageId = null;
        setState(() {
          _recipientDisabled = true;
          _sendError = null;
          _imageError = null;
        });
        return;
      }
      setState(() => _imageError = error.message);
    } catch (_) {
      if (!_isActiveRequest(requestEpoch, requestUserId, requestKey)) return;
      setState(() => _imageError = 'Không gửi được hình ảnh.');
    } finally {
      if (_isActiveRequest(requestEpoch, requestUserId, requestKey)) {
        setState(() => _imageSending = false);
      }
    }
  }

  Future<void> _startCall(String callType) async {
    if (_creatingCall) return;
    final service = optionalProvider<CallsService>(context);
    if (service is! CallsApi) {
      _showCallNotice('Dịch vụ cuộc gọi chưa khả dụng.');
      return;
    }
    final conversation = widget.conversation;
    final relationshipId = conversation.relationshipId;
    if (_isMockMode && relationshipId == null) {
      _showCallNotice('Cuộc gọi trực tiếp khả dụng trên phiên học viên 1:1.');
      return;
    }
    if (relationshipId == null || conversation.status != 'ACTIVE') {
      _showCallNotice('Chỉ có thể gọi khi quan hệ huấn luyện đang hoạt động.');
      return;
    }
    final navigator = Navigator.of(context, rootNavigator: true);
    if (LiveCallPage.isOpen(navigator)) return;
    setState(() => _creatingCall = true);
    try {
      final call = await service.createLiveCall(relationshipId, callType);
      if (!mounted) return;
      final peerName =
          widget.mockTitle ?? conversation.displayNameFor(widget.currentUserId);
      await LiveCallPage.show(
        navigator,
        api: service,
        call: call,
        currentUserId: widget.currentUserId,
        peerName: peerName,
      );
    } on ApiException catch (error) {
      if (mounted) _showCallNotice(error.message);
    } catch (_) {
      if (mounted) _showCallNotice('Không thể bắt đầu cuộc gọi.');
    } finally {
      if (mounted) setState(() => _creatingCall = false);
    }
  }

  void _showCallNotice(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _openMemberProfile() {
    if (!_isCoachView) return;
    final memberId = widget.conversation.memberId;
    if (memberId.isEmpty) return;
    final membersService = optionalProvider<CoachMembersService>(context);
    final apiClient = optionalProvider<ApiClient>(context);
    final resolvedService =
        membersService ??
        (apiClient != null ? CoachMembersApi(apiClient) : null);
    if (resolvedService == null) {
      _showCallNotice('Không mở được hồ sơ học viên lúc này.');
      return;
    }
    MetaGymNavigation.pushOnce<void>(
      context,
      MetaGymPageRoute(
        builder: (_) =>
            CoachMemberDetailPage(memberId: memberId, service: resolvedService),
      ),
    );
  }

  void _openMemberPlans(String peerName) {
    if (!_isCoachView) return;
    final memberId = widget.conversation.memberId;
    if (memberId.isEmpty) return;
    final trainingService = optionalProvider<CoachTrainingService>(context);
    final apiClient = optionalProvider<ApiClient>(context);
    final resolvedTraining =
        trainingService ??
        (apiClient != null ? CoachTrainingApi(apiClient) : null);
    if (resolvedTraining == null) {
      _showCallNotice('Không mở được giáo trình học viên lúc này.');
      return;
    }
    final summary = CoachMemberSummary(
      relationshipId:
          widget.conversation.relationshipId ?? widget.conversation.id,
      memberId: memberId,
      memberFullName: peerName,
      status: widget.conversation.status,
    );
    MetaGymNavigation.pushOnce<void>(
      context,
      MetaGymPageRoute(
        builder: (_) =>
            CoachMemberPlansPage(member: summary, service: resolvedTraining),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = MetaGymColors.of(context);
    final isLight = Theme.of(context).brightness == Brightness.light;
    final title =
        widget.mockTitle ??
        widget.conversation.displayNameFor(widget.currentUserId);
    final initials =
        widget.mockInitials ??
        widget.conversation.initialsFor(widget.currentUserId);
    final isCoachView = _isCoachView;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isLight ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: colors.canvas,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const MetaGymBackground(),
            Column(
              children: [
                _buildGlassAppBar(
                  context,
                  colors: colors,
                  isLight: isLight,
                  title: title,
                  initials: initials,
                  isCoachView: isCoachView,
                ),
                Expanded(
                  child: ListView(
                    controller: _scrollController,
                    reverse: true,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    children: [
                      if (_loading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 32),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: MetaGymTheme.primary,
                              strokeWidth: 2.5,
                            ),
                          ),
                        )
                      else ...[
                        if (_error != null)
                          MetaGymGlassCard(
                            solid: !_isCoachView,
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _error!,
                                  style: TextStyle(
                                    color: colors.error,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextButton(
                                  onPressed: _messages.isEmpty
                                      ? _load
                                      : _loadMore,
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
                          ),
                        if (_messages.isEmpty && _error == null)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                              child: Text(
                                'Chưa có tin nhắn.',
                                style: TextStyle(
                                  color: colors.textWarmMuted,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          )
                        else ...[
                          for (final message in _messages)
                            KeyedSubtree(
                              key: ValueKey('chat-msg-${message.id}'),
                              child: Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: _buildChatMessageBubble(
                                  context,
                                  colors: colors,
                                  isLight: isLight,
                                  message: message,
                                ),
                              ),
                            ),
                          if (_hasMore)
                            Center(
                              child: TextButton(
                                onPressed: _loadingMore ? null : _loadMore,
                                child: Text(
                                  _loadingMore ? 'Đang tải…' : 'Tải tin cũ',
                                  style: TextStyle(
                                    color: colors.primaryText,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          Center(
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: colors.metricPanelBg,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: colors.metricPanelBorder,
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                'Hôm nay',
                                style: TextStyle(
                                  color: colors.textWarmMuted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                      _buildContextHeaderCard(
                        context,
                        colors: colors,
                        title: title,
                        isCoachView: isCoachView,
                      ),
                    ],
                  ),
                ),
                if (widget.conversation.canSend)
                  _buildComposerArea(
                    context,
                    colors: colors,
                    isLight: isLight,
                    isCoachView: isCoachView,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContextHeaderCard(
    BuildContext context, {
    required MetaGymColors colors,
    required String title,
    required bool isCoachView,
  }) {
    final canOpenCoachShortcuts =
        isCoachView &&
        (optionalProvider<CoachMembersService>(context) != null ||
            optionalProvider<ApiClient>(context) != null);

    return MetaGymGlassCard(
      solid: !_isCoachView,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
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
                      ? colors.success
                      : colors.textSecondary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.mockContextTitle ?? 'Trò chuyện riêng tư',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            widget.conversation.canSend
                ? (_isMockMode
                      ? (isCoachView
                            ? 'Kênh 1:1 trực tiếp với học viên'
                            : 'Kết nối trực tiếp với huấn luyện viên')
                      : (widget.conversation.status == 'ENDED'
                            ? 'Bạn vẫn có thể tiếp tục nhắn tin.'
                            : 'Có thể nhắn tin.'))
                : 'Không thể gửi tin nhắn.',
            style: TextStyle(color: colors.textWarmMuted, fontSize: 12),
          ),
          if (canOpenCoachShortcuts) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ChatContextShortcutChip(
                  icon: Icons.person_outline_rounded,
                  label: 'Hồ sơ HV',
                  onTap: _openMemberProfile,
                ),
                _ChatContextShortcutChip(
                  icon: Icons.fitness_center_rounded,
                  label: 'Giáo trình',
                  onTap: () => _openMemberPlans(title),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGlassAppBar(
    BuildContext context, {
    required MetaGymColors colors,
    required bool isLight,
    required String title,
    required String initials,
    required bool isCoachView,
  }) {
    final enableBlur =
        !MetaGymTheme.isFlutterTestEnvironment &&
        !isLight &&
        !MetaGymSurfacePreferences.reduceBlurOf(context);
    final hasMemberLink =
        isCoachView &&
        (optionalProvider<CoachMembersService>(context) != null ||
            optionalProvider<ApiClient>(context) != null);

    final identityBlock = Row(
      children: [
        CoachingAvatar(
          fullName: title,
          size: 38,
          round: true,
          paletteIndex: isCoachView ? 1 : 0,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 1),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _recipientDisabled
                          ? colors.error
                          : widget.conversation.canSend
                          ? colors.success
                          : colors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      _recipientDisabled
                          ? 'Tài khoản bị khóa'
                          : widget.conversation.canSend
                          ? 'Đang hoạt động'
                          : 'Chỉ đọc',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _recipientDisabled
                            ? colors.error
                            : widget.conversation.canSend
                            ? colors.success
                            : colors.textSecondary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );

    final bar = Container(
      decoration: BoxDecoration(
        color: isLight ? colors.surface : colors.navBarWarmGlass,
        border: Border(
          bottom: BorderSide(
            color: isLight ? colors.border : colors.warmGlassBorder,
            width: 0.9,
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 10, 10),
          child: Row(
            children: [
              MetaGymCircleIconButton(
                svgAsset: MetaGymIcons.commonBack,
                icon: Icons.arrow_back_ios_new_rounded,
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onTap: () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: hasMemberLink
                    ? Semantics(
                        button: true,
                        label: 'Xem hồ sơ $title',
                        child: MetaGymTap(
                          onTap: _openMemberProfile,
                          borderRadius: BorderRadius.circular(14),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 4,
                            ),
                            child: identityBlock,
                          ),
                        ),
                      )
                    : identityBlock,
              ),
              const SizedBox(width: 4),
              MetaGymCircleIconButton(
                svgAsset: MetaGymIcons.callAudioBadge,
                icon: Icons.call_outlined,
                tooltip: 'Gọi thoại',
                onTap: _creatingCall ? null : () => _startCall('VOICE'),
              ),
              const SizedBox(width: 6),
              MetaGymCircleIconButton(
                svgAsset: MetaGymIcons.callVideoBadge,
                icon: Icons.videocam_outlined,
                tooltip: 'Gọi video',
                onTap: _creatingCall ? null : () => _startCall('VIDEO'),
              ),
            ],
          ),
        ),
      ),
    );

    if (!enableBlur) return bar;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: bar,
      ),
    );
  }

  Widget _buildComposerArea(
    BuildContext context, {
    required MetaGymColors colors,
    required bool isLight,
    required bool isCoachView,
  }) {
    final enableBlur =
        !MetaGymTheme.isFlutterTestEnvironment &&
        !isLight &&
        !MetaGymSurfacePreferences.reduceBlurOf(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_recipientDisabled)
              Container(
                key: const Key('chat-recipient-disabled-banner'),
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isLight
                      ? colors.error.withValues(alpha: 0.1)
                      : const Color(0xFF24161A),
                  borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
                  border: Border.all(
                    color: colors.error.withValues(alpha: 0.55),
                    width: 1,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.block_rounded, color: colors.error, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _recipientDisabledMessage,
                            style: TextStyle(
                              color: isLight
                                  ? colors.error
                                  : const Color(0xFFFFB2B6),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Bạn vẫn có thể xem lại toàn bộ lịch sử tin nhắn.',
                            style: TextStyle(
                              color: colors.textWarmMuted,
                              fontSize: 11.5,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            if (_sendError != null && !_recipientDisabled)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _sendError!,
                        style: TextStyle(color: colors.error, fontSize: 12),
                      ),
                    ),
                    if (_draftMessageId != null)
                      TextButton(
                        onPressed: _sending ? null : _send,
                        child: Text(
                          'Thử gửi lại',
                          style: TextStyle(
                            color: colors.primaryText,
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
                        style: TextStyle(color: colors.error, fontSize: 12),
                      ),
                    ),
                    if (_pendingImage != null)
                      TextButton(
                        onPressed: _imageSending ? null : _sendImage,
                        child: Text(
                          'Thử lại gửi ảnh',
                          style: TextStyle(
                            color: colors.primaryText,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            if (!_recipientDisabled)
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: _imageSending ? null : _pickImage,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              minWidth: 48,
                              minHeight: 48,
                            ),
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 11,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.reflection.withValues(
                                    alpha: 0.14,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: colors.reflection.withValues(
                                      alpha: 0.34,
                                    ),
                                    width: 0.9,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.image_outlined,
                                      size: 14,
                                      color: colors.reflection,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      _imageSending
                                          ? 'Đang gửi ảnh…'
                                          : 'Gửi ảnh',
                                      style: TextStyle(
                                        color: colors.reflection,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      for (final reply in _quickReplies) ...[
                        const SizedBox(width: 8),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () => _send(reply),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                minWidth: 48,
                                minHeight: 48,
                              ),
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isLight
                                        ? colors.surface
                                        : colors.metricPanelBg,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: isLight
                                          ? colors.border
                                          : colors.liquidGlassBorder,
                                      width: 0.9,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    reply,
                                    style: TextStyle(
                                      color: colors.textPrimary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: enableBlur
                  ? BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                      child: _buildCapsuleComposerBody(
                        colors: colors,
                        isLight: isLight,
                        isCoachView: isCoachView,
                      ),
                    )
                  : _buildCapsuleComposerBody(
                      colors: colors,
                      isLight: isLight,
                      isCoachView: isCoachView,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCapsuleComposerBody({
    required MetaGymColors colors,
    required bool isLight,
    required bool isCoachView,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 5, 6, 5),
      decoration: BoxDecoration(
        color: isLight ? colors.surface : const Color(0xCC1E1A17),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isLight ? colors.border : colors.liquidGlassBorder,
          width: 1.0,
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: (_imageSending || _recipientDisabled)
                ? null
                : _pickImage,
            tooltip: 'Gửi ảnh',
            icon: _imageSending
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.textPrimary,
                    ),
                  )
                : Icon(
                    Icons.image_outlined,
                    color: _recipientDisabled
                        ? colors.textSecondary
                        : colors.textPrimary,
                    size: 21,
                  ),
          ),
          Expanded(
            child: TextField(
              controller: _textController,
              enabled: !_recipientDisabled,
              maxLength: 5000,
              minLines: 1,
              maxLines: 4,
              style: TextStyle(color: colors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: _recipientDisabled
                    ? 'Không thể gửi tin nhắn lúc này'
                    : (isCoachView
                          ? 'Nhắn tin cho học viên...'
                          : 'Nhắn tin cho Coach...'),
                hintStyle: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 13.5,
                ),
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                counterText: '',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 8,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: (_sending || _recipientDisabled) ? null : _send,
              borderRadius: BorderRadius.circular(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 48, minHeight: 44),
                child: Ink(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: _recipientDisabled
                        ? colors.borderStrong
                        : MetaGymTheme.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Center(
                    child: Text(
                      'Gửi',
                      style: TextStyle(
                        color: _recipientDisabled
                            ? colors.textSecondary
                            : MetaGymTheme.onPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatMessageBubble(
    BuildContext context, {
    required MetaGymColors colors,
    required bool isLight,
    required ChatMessage message,
  }) {
    final isMe = message.senderId == widget.currentUserId;

    final bubbleRadius = BorderRadius.only(
      topLeft: const Radius.circular(18),
      topRight: const Radius.circular(18),
      bottomLeft: isMe ? const Radius.circular(18) : const Radius.circular(4),
      bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(18),
    );

    final isImageMessage =
        message.messageType == 'IMAGE' &&
        message.mediaId != null &&
        widget.service != null;

    final bubbleBody = Container(
      padding: isImageMessage
          ? const EdgeInsets.all(6)
          : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isMe
            ? MetaGymTheme.primary
            : (isLight ? colors.surface : colors.liquidGlass),
        borderRadius: bubbleRadius,
        border: isMe
            ? null
            : Border.all(
                color: isLight ? colors.border : colors.liquidGlassBorder,
                width: 1.0,
              ),
      ),
      child: Column(
        crossAxisAlignment: isMe
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          if (isImageMessage)
            ChatMessageImage(
              service: widget.service!,
              mediaId: message.mediaId!,
            )
          else
            Text(
              message.content ?? '',
              style: TextStyle(
                color: isMe ? MetaGymTheme.onPrimary : colors.textPrimary,
                fontSize: 14,
                height: 1.38,
              ),
            ),
          const SizedBox(height: 4),
          Padding(
            padding: isImageMessage
                ? const EdgeInsets.symmetric(horizontal: 6, vertical: 2)
                : EdgeInsets.zero,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatBubbleTime(message.sentAt),
                  style: TextStyle(
                    color: isMe
                        ? MetaGymTheme.onPrimary.withValues(alpha: 0.82)
                        : colors.textSecondary,
                    fontSize: 11,
                    fontFeatures: MetaGymTheme.tabularFigures,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.done_all_rounded,
                    size: 13,
                    color: MetaGymTheme.onPrimary.withValues(alpha: 0.88),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        child: bubbleBody,
      ),
    );
  }
}

class _ChatContextShortcutChip extends StatelessWidget {
  const _ChatContextShortcutChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = MetaGymColors.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 38),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            decoration: BoxDecoration(
              color: colors.metricPanelBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.metricPanelBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 15, color: colors.primaryText),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
