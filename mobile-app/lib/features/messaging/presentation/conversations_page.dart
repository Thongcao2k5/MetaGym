import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:meta_gym_app/core/navigation/meta_gym_navigation.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/network/metagym_realtime.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/theme/meta_gym_icons.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_bottom_nav.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/features/auth/domain/auth_models.dart';
import 'package:meta_gym_app/features/auth/presentation/session_controller.dart';
import 'package:meta_gym_app/features/calls/presentation/calls_page.dart';
import 'package:meta_gym_app/features/coaching/presentation/coaching_ui.dart';
import 'package:meta_gym_app/features/messaging/data/messaging_service.dart';
import 'package:meta_gym_app/features/messaging/domain/chat_message.dart';
import 'package:meta_gym_app/features/messaging/domain/conversation.dart';
import 'package:meta_gym_app/features/messaging/presentation/chat_detail_page.dart';
import 'package:meta_gym_app/features/messaging/presentation/messaging_session_cache.dart';
import 'package:meta_gym_app/features/progress/data/member_photo_service.dart';
import 'package:provider/provider.dart';

export 'package:meta_gym_app/features/messaging/presentation/chat_detail_page.dart';

enum _MessageFilter { all, coach, unread, support }

class _MockThread {
  _MockThread({
    required this.conversation,
    required this.displayName,
    required this.initials,
    required this.roleLabel,
    required this.category,
    required this.isOnline,
    required this.lastMessage,
    required this.timeLabel,
    required this.contextTitle,
    required this.messages,
  });

  Conversation conversation;
  final String displayName;
  final String initials;
  final String roleLabel;
  final _MessageFilter category;
  final bool isOnline;
  String lastMessage;
  String timeLabel;
  final String contextTitle;
  final List<ChatMessage> messages;
}

/// Màn hình **5.1 Tin nhắn học viên** (Coach) & Tin nhắn 1:1 (Member).
class ConversationsPage extends StatefulWidget {
  const ConversationsPage({
    this.service,
    required this.currentUserId,
    this.picker,
    this.bottomPadding,
    this.isActive = true,
    this.coachMode,
    this.onAvatarTap,
    super.key,
  });

  final MessagingService? service;
  final String currentUserId;
  final ProgressPhotoPicker? picker;
  final double? bottomPadding;
  final bool isActive;
  final bool? coachMode;
  final VoidCallback? onAvatarTap;

  static void clearSessionCache() => MessagingSessionCache.clearAll();

  @override
  State<ConversationsPage> createState() => _ConversationsPageState();
}

class _ConversationsPageState extends State<ConversationsPage> {
  StreamSubscription<String>? _realtimeMessages;
  MessagingService? _service;
  SessionController? _sessionController;
  List<Conversation> _items = const [];
  bool _loading = true;
  bool _refreshing = false;
  bool _loadingMore = false;
  String? _error;
  int _page = 1;
  bool _hasMore = false;
  int _sessionEpoch = 0;
  String _activeUserId = '';

  _MessageFilter _filter = _MessageFilter.all;
  bool _showSearch = false;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _usingMockShowcase = false;
  late List<_MockThread> _mockThreads;
  bool? _lastShowcaseCoachMode;

  String get _effectiveUserId {
    final sessionUser = _sessionController?.user?.id;
    if (sessionUser != null && sessionUser.isNotEmpty) return sessionUser;
    return widget.currentUserId;
  }

  @override
  void initState() {
    super.initState();
    _loading = widget.isActive;
    _activeUserId = widget.currentUserId;
    if (_activeUserId.isNotEmpty) {
      MessagingSessionCache.ensureAccount(_activeUserId);
    }
    _mockThreads = _createInitialMockThreads(
      isCoach: widget.coachMode ?? false,
    );
    _lastShowcaseCoachMode = widget.coachMode ?? false;
    _realtimeMessages = optionalProvider<MetaGymRealtime>(context)?.messages
        .listen((_) {
          if (mounted && widget.isActive) unawaited(_load());
        });
  }

  @override
  void dispose() {
    unawaited(_realtimeMessages?.cancel());
    _sessionController?.removeListener(_handleSessionChanged);
    _searchController.dispose();
    super.dispose();
  }

  List<_MockThread> _createInitialMockThreads({required bool isCoach}) {
    final me = widget.currentUserId.isNotEmpty
        ? widget.currentUserId
        : (isCoach ? 'coach-demo' : 'member-demo');

    if (isCoach) {
      return [
        _MockThread(
          conversation: Conversation(
            id: 'mock-coach-conv-1',
            relationshipId: 'rel-demo-001',
            memberId: 'member-mq',
            coachId: me,
            memberName: 'Nguyễn Minh Quân',
            status: 'ACTIVE',
            unreadCount: 1,
            lastMessageAt: '14:20',
          ),
          displayName: 'Nguyễn Minh Quân',
          initials: 'NQ',
          roleLabel: 'PT 1:1 · Hypertrophy',
          category: _MessageFilter.coach,
          isOnline: true,
          lastMessage:
              'Chiều nay 18:00 mình tập Ngực & Tay sau đúng không anh?',
          timeLabel: '14:20',
          contextTitle: 'Gói PT 24 buổi · Còn 14 buổi · 18:00 hôm nay',
          messages: [
            ChatMessage(
              id: 'mc-1',
              senderId: me,
              messageType: 'TEXT',
              content: 'Chào Quân! Anh đã cập nhật giáo trình 8 tuần mới nhất cho em nhé.',
              mediaId: null,
              sentAt: '14:12',
            ),
            const ChatMessage(
              id: 'mc-2',
              senderId: 'member-mq',
              messageType: 'TEXT',
              content: 'Dạ em cảm ơn Coach Nam! Chiều nay 18:00 mình tập Ngực & Tay sau đúng không anh?',
              mediaId: null,
              sentAt: '14:20',
            ),
          ],
        ),
        _MockThread(
          conversation: Conversation(
            id: 'mock-coach-conv-2',
            relationshipId: 'rel-demo-002',
            memberId: 'member-bn',
            coachId: me,
            memberName: 'Trần Bảo Ngọc',
            status: 'ACTIVE',
            unreadCount: 2,
            lastMessageAt: '11:35',
          ),
          displayName: 'Trần Bảo Ngọc',
          initials: 'BN',
          roleLabel: 'PT 1:1 · Giảm mỡ',
          category: _MessageFilter.coach,
          isOnline: true,
          lastMessage: 'Em đã hoàn thành 3 hiệp Glute Bridge, mai mình tăng thêm 5kg được không anh?',
          timeLabel: '11:35',
          contextTitle: 'Giáo trình Săn chắc Thân dưới · Thực đơn 1.650 kcal',
          messages: [
            const ChatMessage(
              id: 'mc-2-1',
              senderId: 'member-bn',
              messageType: 'TEXT',
              content: 'Em đã hoàn thành 3 hiệp Glute Bridge, mai mình tăng thêm 5kg được không anh?',
              mediaId: null,
              sentAt: '11:35',
            ),
          ],
        ),
        _MockThread(
          conversation: Conversation(
            id: 'mock-coach-conv-3',
            relationshipId: 'rel-admin-mg',
            memberId: 'admin-mg',
            coachId: me,
            memberName: 'Quản trị Meta Gym',
            status: 'ACTIVE',
            unreadCount: 0,
            lastMessageAt: 'Hôm qua',
          ),
          displayName: 'Quản trị Meta Gym',
          initials: 'MG',
          roleLabel: 'Quản trị',
          category: _MessageFilter.support,
          isOnline: false,
          lastMessage:
              'Lịch ca PT tháng 11 và bảng tổng hợp giờ dạy đã được cập nhật.',
          timeLabel: 'Hôm qua',
          contextTitle: 'Kênh hỗ trợ & điều phối HLV Meta Gym',
          messages: [
            const ChatMessage(
              id: 'mc-3-1',
              senderId: 'admin-mg',
              messageType: 'TEXT',
              content: 'Lịch ca PT tháng 11 và bảng tổng hợp giờ dạy đã được cập nhật.',
              mediaId: null,
              sentAt: 'Hôm qua',
            ),
          ],
        ),
      ];
    }

    return [
      _MockThread(
        conversation: const Conversation(
          id: 'mock-conv-1',
          relationshipId: 'rel-coach-nam',
          memberId: 'member-demo',
          coachId: 'coach-nam',
          status: 'ACTIVE',
          unreadCount: 2,
          lastMessageAt: '14:20',
        ),
        displayName: 'Lê Hoàng Nam',
        initials: 'LN',
        roleLabel: 'Coach cá nhân',
        category: _MessageFilter.coach,
        isOnline: true,
        lastMessage:
            'Nhớ khởi động kỹ khớp vai trước buổi Upper Body 17:30 nhé!',
        timeLabel: '14:20',
        contextTitle: 'Buổi tập hôm nay · 17:30 Upper Body & Core',
        messages: [
          const ChatMessage(
            id: 'm-1',
            senderId: 'coach-nam',
            messageType: 'TEXT',
            content:
                'Chào Quân! Hôm nay mình tập Upper Body & Core lúc 17:30 nhé.',
            mediaId: null,
            sentAt: '14:15',
          ),
          ChatMessage(
            id: 'm-2',
            senderId: me,
            messageType: 'TEXT',
            content: 'Dạ ok anh, em sẽ tới sớm 10 phút để khởi động ạ!',
            mediaId: null,
            sentAt: '14:18',
          ),
          const ChatMessage(
            id: 'm-3',
            senderId: 'coach-nam',
            messageType: 'TEXT',
            content: 'Tuyệt vời! Nhớ khởi động kỹ khớp vai trước buổi Upper Body 17:30 nhé!',
            mediaId: null,
            sentAt: '14:20',
          ),
        ],
      ),
      _MockThread(
        conversation: const Conversation(
          id: 'mock-conv-2',
          relationshipId: 'rel-nutrition-ma',
          memberId: 'member-demo',
          coachId: 'coach-minh-anh',
          status: 'ACTIVE',
          unreadCount: 1,
          lastMessageAt: '11:05',
        ),
        displayName: 'Minh Anh · Dinh dưỡng',
        initials: 'MA',
        roleLabel: 'Chuyên gia',
        category: _MessageFilter.coach,
        isOnline: true,
        lastMessage:
            'Mình đã cập nhật thực đơn 160g đạm tuần này cho bạn rồi đó.',
        timeLabel: '11:05',
        contextTitle: 'Thực đơn tăng cơ · Mục tiêu 160g đạm/ngày',
        messages: [
          const ChatMessage(
            id: 'm-n1',
            senderId: 'coach-minh-anh',
            messageType: 'TEXT',
            content: 'Mình đã cập nhật thực đơn 160g đạm tuần này cho bạn rồi đó. Bạn xem ở mục Dinh dưỡng nhé!',
            mediaId: null,
            sentAt: '11:05',
          ),
        ],
      ),
      _MockThread(
        conversation: const Conversation(
          id: 'mock-conv-3',
          relationshipId: 'rel-support',
          memberId: 'member-demo',
          coachId: 'support-mg',
          status: 'ACTIVE',
          unreadCount: 0,
          lastMessageAt: 'Hôm qua',
        ),
        displayName: 'Meta Gym Support',
        initials: 'MG',
        roleLabel: 'Hỗ trợ',
        category: _MessageFilter.support,
        isOnline: false,
        lastMessage: 'Gói Meta Pro của bạn hiện còn 112 ngày hiệu lực.',
        timeLabel: 'Hôm qua',
        contextTitle: 'Hỗ trợ hội viên & Gói tập Meta Gym',
        messages: [
          const ChatMessage(
            id: 'm-s1',
            senderId: 'support-mg',
            messageType: 'TEXT',
            content: 'Xin chào! Gói Meta Pro của bạn hiện còn 112 ngày hiệu lực. Nếu cần gia hạn hoặc đổi khung giờ check-in hãy nhắn tại đây nhé.',
            mediaId: null,
            sentAt: 'Hôm qua',
          ),
        ],
      ),
    ];
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
    final isCoach = _resolveCoachHeader(context);
    if (_lastShowcaseCoachMode != isCoach) {
      _lastShowcaseCoachMode = isCoach;
      _mockThreads = _createInitialMockThreads(isCoach: isCoach);
    }
    final nextService =
        widget.service ?? optionalProvider<MessagingService>(context);
    final initialBind = _service == null;
    if (!identical(_service, nextService)) {
      _service = nextService;
      _sessionEpoch++;
    }
    final currentUser = _effectiveUserId;
    if (currentUser != _activeUserId) {
      _resetForUserChange(currentUser);
      return;
    }
    if (initialBind && widget.isActive) _scheduleLoad();
  }

  @override
  void didUpdateWidget(covariant ConversationsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.service != null && !identical(widget.service, _service)) {
      _service = widget.service;
      _sessionEpoch++;
    }
    final nextUser = _effectiveUserId;
    if (nextUser != _activeUserId ||
        widget.currentUserId != oldWidget.currentUserId) {
      _resetForUserChange(nextUser);
      return;
    }
    if (widget.isActive && !oldWidget.isActive) _scheduleLoad();
  }

  void _handleSessionChanged() {
    if (!mounted) return;
    final session = _sessionController;
    if (session == null) return;
    if (session.status == SessionStatus.unauthenticated ||
        session.user == null) {
      _sessionEpoch++;
      _activeUserId = '';
      MessagingSessionCache.clearAll();
      setState(() {
        _items = const [];
        _page = 1;
        _hasMore = false;
        _error = null;
        _loading = false;
        _refreshing = false;
        _loadingMore = false;
      });
      return;
    }
    final nextUser = session.user!.id;
    if (nextUser != _activeUserId) {
      _resetForUserChange(nextUser);
    }
  }

  void _resetForUserChange(String nextUser) {
    _sessionEpoch++;
    _activeUserId = nextUser;
    MessagingSessionCache.clearAll();
    if (nextUser.isNotEmpty) {
      MessagingSessionCache.ensureAccount(nextUser);
    }
    setState(() {
      _items = const [];
      _page = 1;
      _hasMore = false;
      _error = null;
      _loading = widget.isActive && nextUser.isNotEmpty;
      _refreshing = false;
      _loadingMore = false;
    });
    if (widget.isActive && nextUser.isNotEmpty) {
      _scheduleLoad();
    }
  }

  bool _isActiveSession(int epoch, String userId) {
    if (!mounted) return false;
    if (epoch != _sessionEpoch || userId != _effectiveUserId) return false;
    final session = _sessionController;
    if (session != null) {
      if (session.status == SessionStatus.unauthenticated) return false;
      if (session.user != null && session.user!.id != userId) return false;
    }
    return true;
  }

  Conversation _enrichFromCache(Conversation item, String userId) {
    final service = _service;
    if (service == null) return item;
    final cached = MessagingSessionCache.readThread(
      userId,
      service,
      item.messageKey,
    );
    if (cached == null || cached.messages.isEmpty) return item;
    final newest = cached.messages.first;
    final itemTime = DateTime.tryParse(item.lastMessageAt ?? '');
    final cachedTime = DateTime.tryParse(newest.sentAt);
    final useCachedPreview =
        (item.lastMessageType == null &&
            (item.lastMessageContent == null ||
                item.lastMessageContent!.trim().isEmpty)) ||
        (cachedTime != null &&
            (itemTime == null || cachedTime.isAfter(itemTime)));
    if (!useCachedPreview) return item;
    return item.copyWith(
      lastMessageAt: newest.sentAt,
      lastMessageType: newest.messageType,
      lastMessageContent: newest.content,
      lastMessageSenderId: newest.senderId,
    );
  }

  List<Conversation> _sortAndDedupeConversations(
    List<Conversation> items,
    String userId,
  ) {
    final byId = <String, Conversation>{};
    final orderIndex = <String, int>{};
    for (var i = 0; i < items.length; i++) {
      final enriched = _enrichFromCache(items[i], userId);
      orderIndex.putIfAbsent(enriched.id, () => i);
      byId[enriched.id] = enriched;
    }
    final unique = byId.values.toList();
    unique.sort((a, b) {
      final aTime = DateTime.tryParse(a.lastMessageAt ?? '');
      final bTime = DateTime.tryParse(b.lastMessageAt ?? '');
      if (aTime != null && bTime != null) {
        final cmp = bTime.compareTo(aTime);
        if (cmp != 0) return cmp;
      } else if (aTime != null) {
        return -1;
      } else if (bTime != null) {
        return 1;
      }
      return orderIndex[a.id]!.compareTo(orderIndex[b.id]!);
    });
    return unique;
  }

  void _scheduleLoad() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.isActive) _load();
    });
  }

  Future<void> _load() async {
    if (_refreshing || _loadingMore) return;
    final service = _service;
    if (service == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _usingMockShowcase = !MetaGymTheme.isFlutterTestEnvironment;
        });
      }
      return;
    }

    final requestEpoch = _sessionEpoch;
    final requestUserId = _effectiveUserId;
    if (requestUserId.isNotEmpty) {
      MessagingSessionCache.ensureAccount(requestUserId);
    }

    _refreshing = true;
    final showInitialLoader = _items.isEmpty;
    setState(() {
      if (showInitialLoader) _loading = true;
      _error = null;
      _usingMockShowcase = false;
    });
    try {
      final items = await service.getConversations(1);
      if (!_isActiveSession(requestEpoch, requestUserId)) return;
      setState(() {
        _items = _sortAndDedupeConversations(items, requestUserId);
        _page = 1;
        _hasMore = items.length == 20;
      });
    } on ApiException catch (error) {
      if (!_isActiveSession(requestEpoch, requestUserId)) return;
      setState(() => _error = error.message);
    } catch (_) {
      if (!_isActiveSession(requestEpoch, requestUserId)) return;
      setState(() => _error = 'Không tải được cuộc trò chuyện.');
    } finally {
      if (_isActiveSession(requestEpoch, requestUserId)) {
        _refreshing = false;
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadMore() async {
    if (_service == null || _loading || _loadingMore) return;
    final requestEpoch = _sessionEpoch;
    final requestUserId = _effectiveUserId;
    final targetPage = _page + 1;
    setState(() {
      _loadingMore = true;
      _error = null;
    });
    try {
      final items = await _service!.getConversations(targetPage);
      if (!_isActiveSession(requestEpoch, requestUserId)) return;
      setState(() {
        _items = _sortAndDedupeConversations([
          ..._items,
          ...items,
        ], requestUserId);
        _page = targetPage;
        _hasMore = items.length == 20;
      });
    } on ApiException catch (error) {
      if (!_isActiveSession(requestEpoch, requestUserId)) return;
      setState(() => _error = error.message);
    } catch (_) {
      if (!_isActiveSession(requestEpoch, requestUserId)) return;
      setState(() => _error = 'Không tải thêm được cuộc trò chuyện.');
    } finally {
      if (_isActiveSession(requestEpoch, requestUserId)) {
        setState(() => _loadingMore = false);
      }
    }
  }

  String _userInitials(BuildContext context, {required bool isCoach}) {
    final cleanName =
        (optionalProvider<SessionController>(context)?.user?.fullName ?? '')
            .trim();
    if (cleanName.isNotEmpty) {
      return coachInitials(cleanName);
    }
    return isCoach ? 'LN' : 'MQ';
  }

  List<_MockThread> get _filteredMockThreads {
    final query = _searchQuery.trim().toLowerCase();
    return _mockThreads.where((thread) {
      if (_filter == _MessageFilter.coach &&
          thread.category != _MessageFilter.coach) {
        return false;
      }
      if (_filter == _MessageFilter.unread &&
          thread.conversation.unreadCount == 0) {
        return false;
      }
      if (_filter == _MessageFilter.support &&
          thread.category != _MessageFilter.support) {
        return false;
      }
      if (query.isNotEmpty) {
        final haystack =
            '${thread.displayName} ${thread.roleLabel} ${thread.lastMessage}'
                .toLowerCase();
        if (!haystack.contains(query)) return false;
      }
      return true;
    }).toList();
  }

  List<Conversation> get _filteredRealItems {
    final query = _searchQuery.trim().toLowerCase();
    final userId = _effectiveUserId;
    return _items.where((item) {
      if (_filter == _MessageFilter.coach &&
          item.memberId != userId &&
          item.coachId != userId) {
        return false;
      }
      if (_filter == _MessageFilter.unread && item.unreadCount == 0) {
        return false;
      }
      if (_filter == _MessageFilter.support) {
        return false;
      }
      if (query.isNotEmpty) {
        final label = item.displayNameFor(userId).toLowerCase();
        final preview = item.lastMessagePreview.toLowerCase();
        if (!label.contains(query) && !preview.contains(query)) return false;
      }
      return true;
    }).toList();
  }

  Future<void> _openMockThread(
    _MockThread thread, {
    required bool isCoach,
  }) async {
    setState(() {
      thread.conversation = thread.conversation.copyWith(unreadCount: 0);
    });

    await MetaGymNavigation.pushOnce<void>(
      context,
      MetaGymPageRoute(
        builder: (_) => ConversationDetailPage(
          conversation: thread.conversation,
          service: _service,
          currentUserId: widget.currentUserId.isNotEmpty
              ? widget.currentUserId
              : (isCoach ? 'coach-demo' : 'member-demo'),
          picker: widget.picker ?? DeviceProgressPhotoPicker(),
          coachMode: isCoach,
          mockTitle: thread.displayName,
          mockInitials: thread.initials,
          mockContextTitle: thread.contextTitle,
          initialMockMessages: List<ChatMessage>.from(thread.messages),
          onMockMessageAdded: (msg) {
            if (!mounted) return;
            setState(() {
              thread.messages.add(msg);
              thread.lastMessage = msg.content ?? 'Đã gửi hình ảnh';
              thread.timeLabel = msg.sentAt;
            });
          },
        ),
      ),
    );
  }

  Future<void> _openRealConversation(
    Conversation item, {
    required bool isCoach,
  }) async {
    final userId = _effectiveUserId;
    await MetaGymNavigation.pushOnce<void>(
      context,
      MetaGymPageRoute(
        builder: (_) => ConversationDetailPage(
          conversation: item,
          service: _service,
          currentUserId: userId,
          picker: widget.picker ?? DeviceProgressPhotoPicker(),
          coachMode: isCoach,
        ),
      ),
    );
    if (!mounted || userId != _effectiveUserId) return;
    setState(() {
      _items = _sortAndDedupeConversations(_items, userId);
    });
    await _load();
  }

  void _openCallsHub({required bool isCoach}) {
    MetaGymNavigation.pushOnce<void>(
      context,
      MetaGymPageRoute(
        builder: (_) => CallsPage(
          currentUserId: _effectiveUserId.isNotEmpty
              ? _effectiveUserId
              : (isCoach ? 'coach-demo' : 'member-demo'),
          coachMode: isCoach,
        ),
      ),
    );
  }

  bool _resolveCoachHeader(BuildContext context) {
    if (widget.coachMode != null) return widget.coachMode!;
    try {
      return context.watch<SessionController?>()?.user?.role == UserRole.coach;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = MetaGymColors.of(context);
    final isLight = Theme.of(context).brightness == Brightness.light;
    final effectiveBottomPadding =
        widget.bottomPadding ?? MetaGymBottomNav.contentBottomPadding(context);
    final useCoachHeader = _resolveCoachHeader(context);
    final initials = _userInitials(context, isCoach: useCoachHeader);
    final gutter = MediaQuery.sizeOf(context).width >= 600
        ? MetaGymTheme.tabletGutter
        : MetaGymTheme.pageGutter;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isLight ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light,
      child: Material(
        color: colors.canvas,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const MetaGymBackground(),
            SafeArea(
              bottom: false,
              child: RefreshIndicator(
                color: MetaGymTheme.primary,
                backgroundColor: colors.overlayGlass,
                onRefresh: _load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    gutter,
                    0,
                    gutter,
                    effectiveBottomPadding,
                  ),
                  children: [
                    const SizedBox(height: 6),
                    useCoachHeader
                        ? _buildCoachHeader(context, colors, initials)
                        : _buildHeader(context, colors, initials),
                    if (_showSearch) ...[
                      const SizedBox(height: 10),
                      _buildSearchBar(
                        colors,
                        isLight: isLight,
                        useCoachHeader: useCoachHeader,
                      ),
                    ],
                    const SizedBox(height: 12),
                    _buildQuickFilterDock(
                      colors,
                      isLight: isLight,
                      useCoachHeader: useCoachHeader,
                    ),
                    const SizedBox(height: 10),
                    if (_loading && widget.isActive)
                      MetaGymGlassCard(
                        solid: !_resolveCoachHeader(context),
                        child: SizedBox(
                          height: 140,
                          child: Center(
                            child: CircularProgressIndicator(
                              color: MetaGymTheme.primary,
                              strokeWidth: 2.4,
                            ),
                          ),
                        ),
                      )
                    else if (_error != null && !_usingMockShowcase)
                      _buildErrorCard(colors)
                    else if (_usingMockShowcase) ...[
                      if (_filter == _MessageFilter.all ||
                          _filter == _MessageFilter.coach) ...[
                        _buildFeaturedCard(
                          colors,
                          useCoachHeader: useCoachHeader,
                        ),
                        const SizedBox(height: 12),
                      ],
                      _buildSectionTitle(
                        colors,
                        useCoachHeader
                            ? 'Cuộc trò chuyện học viên'
                            : 'Cuộc trò chuyện gần đây',
                      ),
                      const SizedBox(height: 8),
                      if (_filteredMockThreads.isEmpty)
                        _buildEmptyCard(
                          colors,
                          title: 'Không tìm thấy cuộc trò chuyện phù hợp.',
                          subtitle:
                              'Thử đổi bộ lọc hoặc từ khóa tìm kiếm của bạn.',
                        )
                      else
                        for (var i = 0; i < _filteredMockThreads.length; i++)
                          _buildMockConversationCard(
                            colors,
                            _filteredMockThreads[i],
                            paletteIndex: i + 1,
                            useCoachHeader: useCoachHeader,
                          ),
                    ] else ...[
                      if (_items.isEmpty)
                        _buildEmptyCard(
                          colors,
                          title: 'Bạn chưa có cuộc trò chuyện nào.',
                          subtitle: useCoachHeader
                              ? 'Khi có học viên kết nối PT 1:1, tin nhắn sẽ hiển thị tại đây.'
                              : 'Khi bạn kết nối với Huấn luyện viên, tin nhắn sẽ hiển thị tại đây.',
                        )
                      else ...[
                        if (_filteredRealItems.isEmpty)
                          _buildEmptyCard(
                            colors,
                            title: 'Không tìm thấy cuộc trò chuyện phù hợp.',
                            subtitle: 'Thử đổi bộ lọc hoặc từ khóa tìm kiếm.',
                          )
                        else
                          for (var i = 0; i < _filteredRealItems.length; i++)
                            _buildRealConversationCard(
                              colors,
                              _filteredRealItems[i],
                              paletteIndex: i + 1,
                              useCoachHeader: useCoachHeader,
                            ),
                        if (_hasMore)
                          Center(
                            child: TextButton(
                              onPressed: _loadingMore ? null : _loadMore,
                              child: Text(
                                _loadingMore ? 'Đang tải…' : 'Tải thêm',
                                style: TextStyle(
                                  color: colors.primaryText,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ],
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    MetaGymColors colors,
    String initials,
  ) {
    return MetaGymBrandHeader(
      eyebrow: 'META GYM',
      title: 'Tin nhắn',
      subtitle: 'Trao đổi cùng Coach & hỗ trợ',
      inlineSubtitle: true,
      actions: [
        MetaGymCircleIconButton(
          svgAsset: _showSearch
              ? MetaGymIcons.commonClose
              : MetaGymIcons.commonSearch,
          icon: _showSearch ? Icons.close_rounded : Icons.search_rounded,
          tooltip: 'Tìm kiếm cuộc trò chuyện',
          isActive: _showSearch,
          onTap: () {
            setState(() {
              _showSearch = !_showSearch;
              if (!_showSearch) {
                _searchController.clear();
                _searchQuery = '';
              }
            });
          },
        ),
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: colors.circleButtonBg,
            shape: BoxShape.circle,
            border: Border.all(color: colors.circleButtonBorder, width: 1.0),
          ),
          alignment: Alignment.center,
          child: Text(
            initials,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCoachHeader(
    BuildContext context,
    MetaGymColors colors,
    String initials,
  ) {
    final canPop =
        widget.onAvatarTap == null &&
        (ModalRoute.of(context)?.canPop ?? Navigator.of(context).canPop());
    final avatarCircle = Container(
      width: 42,
      height: 42,
      decoration: const BoxDecoration(
        color: MetaGymTheme.coachAvatarBackground,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(
          color: MetaGymTheme.coachAvatarForeground,
          fontSize: 13.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );

    return MetaGymBrandHeader(
      eyebrow: 'META GYM · COACH',
      title: 'Tin nhắn',
      subtitle: 'Trao đổi cùng học viên & hỗ trợ',
      leading: canPop
          ? MetaGymCircleIconButton(
              svgAsset: MetaGymIcons.commonBack,
              icon: Icons.arrow_back_ios_new_rounded,
              tooltip: 'Quay lại',
              onTap: () => Navigator.of(context).maybePop(),
            )
          : null,
      actions: [
        MetaGymCircleIconButton(
          svgAsset: MetaGymIcons.callAudioBadge,
          icon: Icons.call_outlined,
          tooltip: 'Cuộc gọi 1:1',
          onTap: () => _openCallsHub(isCoach: true),
        ),
        MetaGymCircleIconButton(
          svgAsset: _showSearch
              ? MetaGymIcons.commonClose
              : MetaGymIcons.commonSearch,
          icon: _showSearch ? Icons.close_rounded : Icons.search_rounded,
          tooltip: 'Tìm kiếm cuộc trò chuyện',
          isActive: _showSearch,
          onTap: () {
            setState(() {
              _showSearch = !_showSearch;
              if (!_showSearch) {
                _searchController.clear();
                _searchQuery = '';
              }
            });
          },
        ),
        widget.onAvatarTap != null
            ? Semantics(
                button: true,
                label: 'Hồ sơ Coach',
                child: InkWell(
                  onTap: widget.onAvatarTap,
                  customBorder: const CircleBorder(),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    child: Center(child: avatarCircle),
                  ),
                ),
              )
            : avatarCircle,
      ],
    );
  }

  Widget _buildSearchBar(
    MetaGymColors colors, {
    required bool isLight,
    required bool useCoachHeader,
  }) {
    return MetaGymGlassCard(
      solid: !_resolveCoachHeader(context),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Row(
        children: [
          Icon(Icons.search_rounded, color: colors.reflection, size: 19),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value),
              style: TextStyle(color: colors.textPrimary, fontSize: 13.5),
              decoration: InputDecoration(
                hintText: useCoachHeader
                    ? 'Tìm học viên hoặc nội dung tin nhắn...'
                    : 'Tìm Coach hoặc nội dung tin nhắn...',
                hintStyle: TextStyle(color: colors.textSecondary, fontSize: 13),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          if (_searchQuery.isNotEmpty)
            IconButton(
              onPressed: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
              },
              icon: Icon(
                Icons.clear_rounded,
                color: colors.textSecondary,
                size: 18,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            ),
        ],
      ),
    );
  }

  Widget _buildQuickFilterDock(
    MetaGymColors colors, {
    required bool isLight,
    required bool useCoachHeader,
  }) {
    final studentCount = _usingMockShowcase
        ? _mockThreads.where((t) => t.category == _MessageFilter.coach).length
        : _items.length;
    final unreadCount = _usingMockShowcase
        ? _mockThreads.where((t) => t.conversation.unreadCount > 0).length
        : _items.where((i) => i.unreadCount > 0).length;

    final coachStudentsLabel = studentCount > 0
        ? 'Học viên ($studentCount)'
        : 'Học viên';
    final unreadLabel = useCoachHeader && unreadCount > 0
        ? 'Chưa đọc ($unreadCount)'
        : 'Chưa đọc';

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterButton(
              colors,
              isLight: isLight,
              label: 'Tất cả',
              filter: _MessageFilter.all,
            ),
            const SizedBox(width: 8),
            _buildFilterButton(
              colors,
              isLight: isLight,
              label: useCoachHeader ? coachStudentsLabel : 'Coach',
              filter: _MessageFilter.coach,
            ),
            const SizedBox(width: 8),
            _buildFilterButton(
              colors,
              isLight: isLight,
              label: unreadLabel,
              filter: _MessageFilter.unread,
            ),
            const SizedBox(width: 8),
            _buildFilterButton(
              colors,
              isLight: isLight,
              label: useCoachHeader ? 'Quản trị' : 'Hỗ trợ',
              filter: _MessageFilter.support,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterButton(
    MetaGymColors colors, {
    required bool isLight,
    required String label,
    required _MessageFilter filter,
  }) {
    final isActive = _filter == filter;
    final body = Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: isActive
            ? colors.chipActiveBg
            : (isLight ? colors.surface : colors.liquidGlass),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive
              ? MetaGymTheme.primary
              : (isLight ? colors.border : colors.liquidGlassBorder),
          width: isActive ? 1.2 : 1.0,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          color: isActive
              ? (isLight ? colors.chipActiveText : Colors.white)
              : colors.textSecondary,
          fontSize: 12.5,
          fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
        ),
        maxLines: 1,
      ),
    );

    return Semantics(
      button: true,
      selected: isActive,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _filter = filter),
          borderRadius: BorderRadius.circular(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            child: Center(child: body),
          ),
        ),
      ),
    );
  }

  Widget _buildFeaturedCard(
    MetaGymColors colors, {
    required bool useCoachHeader,
  }) {
    final topThread = _mockThreads.first;
    return MetaGymHeroGlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.chat_bubble_outline_rounded,
                color: colors.primaryText,
                size: 13,
              ),
              const SizedBox(width: 5),
              Text(
                useCoachHeader ? 'HỌC VIÊN NỔI BẬT' : 'COACH CÁ NHÂN',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(width: 8),
              const CoachingPill(
                label: 'Đang hoạt động',
                tone: CoachingPillTone.green,
                icon: Icons.circle,
              ),
            ],
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              CoachingAvatar(
                fullName: topThread.displayName,
                size: 40,
                round: true,
                paletteIndex: useCoachHeader ? 1 : 0,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      topThread.displayName,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      topThread.contextTitle,
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 38,
                child: FilledButton(
                  onPressed: () =>
                      _openMockThread(topThread, isCoach: useCoachHeader),
                  style: FilledButton.styleFrom(
                    backgroundColor: MetaGymTheme.primary,
                    foregroundColor: MetaGymTheme.onPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Nhắn ngay',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(MetaGymColors colors, String title) {
    return Row(
      children: [
        Icon(Icons.history_rounded, color: colors.reflection, size: 16),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildMockConversationCard(
    MetaGymColors colors,
    _MockThread thread, {
    required int paletteIndex,
    required bool useCoachHeader,
  }) {
    final unread = thread.conversation.unreadCount;
    return MetaGymGlassCard(
      solid: !_resolveCoachHeader(context),
      margin: const EdgeInsets.only(bottom: 8),
      onTap: () => _openMockThread(thread, isCoach: useCoachHeader),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              CoachingAvatar(
                fullName: thread.displayName,
                size: 42,
                round: true,
                paletteIndex: thread.category == _MessageFilter.support
                    ? 2
                    : paletteIndex,
              ),
              if (thread.isOnline)
                Positioned(
                  right: -1,
                  bottom: -1,
                  child: Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      color: colors.success,
                      shape: BoxShape.circle,
                      border: Border.all(color: colors.surface, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        thread.displayName,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: colors.metricPanelBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        thread.roleLabel,
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  thread.lastMessage,
                  style: TextStyle(
                    color: unread > 0
                        ? colors.textPrimary
                        : colors.textSecondary,
                    fontSize: 12.5,
                    fontWeight: unread > 0 ? FontWeight.w500 : FontWeight.w400,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                thread.timeLabel,
                style: TextStyle(
                  color: unread > 0 ? colors.primaryText : colors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  fontFeatures: MetaGymTheme.tabularFigures,
                ),
              ),
              if (unread > 0) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: MetaGymTheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$unread',
                    style: const TextStyle(
                      color: MetaGymTheme.onPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRealConversationCard(
    MetaGymColors colors,
    Conversation item, {
    required int paletteIndex,
    required bool useCoachHeader,
  }) {
    final userId = _effectiveUserId;
    final peerName = item.displayNameFor(userId);
    final timeLabel = item.formatLastMessageTime();

    return MetaGymGlassCard(
      solid: !_resolveCoachHeader(context),
      margin: const EdgeInsets.only(bottom: 8),
      onTap: () => _openRealConversation(item, isCoach: useCoachHeader),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          CoachingAvatar(
            fullName: peerName,
            size: 42,
            round: true,
            paletteIndex: useCoachHeader ? paletteIndex : 0,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  peerName,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: item.canSend
                            ? colors.success
                            : colors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        item.lastMessagePreview,
                        style: TextStyle(
                          color: item.unreadCount > 0
                              ? colors.textPrimary
                              : colors.textSecondary,
                          fontSize: 12.5,
                          fontWeight: item.unreadCount > 0
                              ? FontWeight.w600
                              : FontWeight.w400,
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (timeLabel.isNotEmpty)
                Text(
                  timeLabel,
                  style: TextStyle(
                    color: item.unreadCount > 0
                        ? colors.primaryText
                        : colors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    fontFeatures: MetaGymTheme.tabularFigures,
                  ),
                ),
              if (timeLabel.isNotEmpty && item.unreadCount > 0)
                const SizedBox(height: 4),
              if (item.unreadCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: MetaGymTheme.primary,
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
                      color: MetaGymTheme.onPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              else if (timeLabel.isEmpty)
                Icon(
                  Icons.chevron_right,
                  color: colors.textSecondary,
                  size: 20,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(MetaGymColors colors) {
    return MetaGymGlassCard(
      solid: !_resolveCoachHeader(context),
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline_rounded, color: colors.error, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _error!,
                  style: TextStyle(
                    color: colors.error,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _load,
            icon: Icon(
              Icons.replay_rounded,
              size: 16,
              color: colors.primaryText,
            ),
            label: Text(
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

  Widget _buildEmptyCard(
    MetaGymColors colors, {
    required String title,
    required String subtitle,
  }) {
    return MetaGymGlassCard(
      solid: !_resolveCoachHeader(context),
      padding: const EdgeInsets.all(28),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: colors.metricPanelBg,
                shape: BoxShape.circle,
                border: Border.all(color: colors.metricPanelBorder),
              ),
              child: Icon(
                Icons.chat_bubble_outline_rounded,
                color: colors.reflection,
                size: 26,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.textSecondary, fontSize: 12.5),
            ),
          ],
        ),
      ),
    );
  }
}
