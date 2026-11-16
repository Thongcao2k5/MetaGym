import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/network/metagym_realtime.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_bottom_nav.dart';
import 'package:meta_gym_app/features/auth/presentation/session_controller.dart';
import 'package:meta_gym_app/features/calls/data/calls_service.dart';
import 'package:meta_gym_app/features/calls/presentation/live_call_page.dart';
import 'package:meta_gym_app/features/messaging/data/messaging_service.dart';
import 'package:meta_gym_app/features/messaging/domain/chat_message.dart';
import 'package:meta_gym_app/features/messaging/domain/conversation.dart';
import 'package:meta_gym_app/features/messaging/presentation/chat_message_image.dart';
import 'package:meta_gym_app/features/progress/data/member_photo_service.dart';
import 'package:provider/provider.dart';

const AssetImage _messagingGymBgAsset = AssetImage(
  'assets/images/gym_banner.png',
);

/// Nền ảnh phòng gym + dual ambient glow + scrim nhẹ đồng bộ với Trang chủ.
class _MessagingGymBackground extends StatelessWidget {
  const _MessagingGymBackground();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image(
              image: _messagingGymBgAsset,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  const ColoredBox(color: MetaGymTheme.darkCanvas),
            ),
            Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.85, -0.75),
                  radius: 0.9,
                  colors: [Color(0x2E8EB9E5), Colors.transparent],
                ),
              ),
            ),
            Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(-0.85, 0.75),
                  radius: 0.8,
                  colors: [Color(0x24FF5A36), Colors.transparent],
                ),
              ),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x73080A0D),
                    Color(0x38080A0D),
                    Color(0x8C080A0D),
                  ],
                  stops: [0.0, 0.48, 1.0],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Thẻ Kính Smoked Dark đồng bộ với Member Home (tránh bóng nhựa).
Widget _buildLiquidGlassCard({
  required Widget child,
  BorderRadius? borderRadius,
  EdgeInsetsGeometry? margin,
  bool isHighlighted = false,
}) {
  final radius = borderRadius ?? BorderRadius.circular(MetaGymTheme.radiusCard);
  final enableBlur = isHighlighted && !MetaGymTheme.isFlutterTestEnvironment;

  final cardBody = Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: isHighlighted ? const Color(0xB82D2824) : const Color(0xC42B2622),
      borderRadius: radius,
      border: Border.all(
        color: isHighlighted
            ? const Color(0x8CA79D92)
            : const Color(0x529C9084),
        width: 1.0,
      ),
    ),
    child: isHighlighted
        ? Stack(
            children: [
              const Positioned(
                top: 0,
                left: 18,
                right: 18,
                height: 1,
                child: ColoredBox(color: Color(0x45FFF6EA)),
              ),
              child,
            ],
          )
        : child,
  );

  final result = enableBlur
      ? RepaintBoundary(
          child: ClipRRect(
            borderRadius: radius,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: cardBody,
            ),
          ),
        )
      : cardBody;

  if (margin != null) {
    return Padding(padding: margin, child: result);
  }
  return result;
}

class _CircleGlassIconButton extends StatelessWidget {
  const _CircleGlassIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.isActive = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              child: Center(
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isActive
                        ? const Color(0x2EFF5A36)
                        : const Color(0xA6231F1C),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isActive
                          ? MetaGymTheme.brandOrange
                          : const Color(0x529C9084),
                      width: 1.0,
                    ),
                  ),
                  child: Icon(
                    icon,
                    color: isActive
                        ? MetaGymTheme.brandOrange
                        : const Color(0xFFF7F9FC),
                    size: 19,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

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

class _ConversationThreadCacheEntry {
  const _ConversationThreadCacheEntry({
    required this.messages,
    required this.hasMore,
    this.lastReadId,
  });

  final List<ChatMessage> messages;
  final bool hasMore;
  final String? lastReadId;
}

class _MessagingSessionCache {
  static const int _maxConversationsPerAccount = 24;
  static const int _maxMessagesPerConversation = 100;

  static String? _activeAccountId;
  static final Map<String, Map<String, _ConversationThreadCacheEntry>>
  _threadsByAccount = {};

  static String _accountBucketKey(String userId, MessagingService service) =>
      '$userId:${identityHashCode(service)}';

  static void ensureAccount(String userId) {
    final normalized = userId.trim();
    if (normalized.isEmpty) {
      clearAll();
      return;
    }
    if (_activeAccountId != null && _activeAccountId != normalized) {
      clearAll();
    }
    _activeAccountId = normalized;
  }

  static void clearAll() {
    _activeAccountId = null;
    _threadsByAccount.clear();
  }

  static _ConversationThreadCacheEntry? readThread(
    String userId,
    MessagingService? service,
    String conversationKey,
  ) {
    if (service == null || userId.trim().isEmpty) return null;
    ensureAccount(userId);
    final bucket = _threadsByAccount[_accountBucketKey(userId.trim(), service)];
    return bucket?[conversationKey];
  }

  static void writeThread(
    String userId,
    MessagingService? service,
    String conversationKey, {
    required List<ChatMessage> messages,
    bool? hasMore,
    String? lastReadId,
  }) {
    if (service == null || userId.trim().isEmpty) return;
    final cleanUser = userId.trim();
    ensureAccount(cleanUser);
    final bucketKey = _accountBucketKey(cleanUser, service);
    final bucket = _threadsByAccount.putIfAbsent(bucketKey, () => {});
    final previous = bucket.remove(conversationKey);
    final bounded = messages.length > _maxMessagesPerConversation
        ? messages.sublist(0, _maxMessagesPerConversation)
        : messages;
    bucket[conversationKey] = _ConversationThreadCacheEntry(
      messages: List<ChatMessage>.unmodifiable(bounded),
      hasMore: hasMore ?? previous?.hasMore ?? false,
      lastReadId: lastReadId ?? previous?.lastReadId,
    );
    while (bucket.length > _maxConversationsPerAccount) {
      bucket.remove(bucket.keys.first);
    }
  }
}

class ConversationsPage extends StatefulWidget {
  const ConversationsPage({
    this.service,
    required this.currentUserId,
    this.picker,
    this.bottomPadding,
    this.isActive = true,
    super.key,
  });

  final MessagingService? service;
  final String currentUserId;
  final ProgressPhotoPicker? picker;
  final double? bottomPadding;
  final bool isActive;

  static void clearSessionCache() => _MessagingSessionCache.clearAll();

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
      _MessagingSessionCache.ensureAccount(_activeUserId);
    }
    _mockThreads = _createInitialMockThreads();
    _realtimeMessages = context.read<MetaGymRealtime?>()?.messages.listen((_) {
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

  List<_MockThread> _createInitialMockThreads() {
    final me = widget.currentUserId.isNotEmpty
        ? widget.currentUserId
        : 'member-demo';
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
            content:
                'Tuyệt vời! Nhớ khởi động kỹ khớp vai trước buổi Upper Body 17:30 nhé!',
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
            content:
                'Mình đã cập nhật thực đơn 160g đạm tuần này cho bạn rồi đó. Bạn xem ở mục Dinh dưỡng nhé!',
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
            content:
                'Xin chào! Gói Meta Pro của bạn hiện còn 112 ngày hiệu lực. Nếu cần gia hạn hoặc đổi khung giờ check-in hãy nhắn tại đây nhé.',
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
    SessionController? session;
    try {
      session = context.read<SessionController?>();
    } catch (_) {}
    if (!identical(_sessionController, session)) {
      _sessionController?.removeListener(_handleSessionChanged);
      _sessionController = session;
      _sessionController?.addListener(_handleSessionChanged);
    }
    final nextService = widget.service ?? context.read<MessagingService?>();
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
      _MessagingSessionCache.clearAll();
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
    _MessagingSessionCache.clearAll();
    if (nextUser.isNotEmpty) {
      _MessagingSessionCache.ensureAccount(nextUser);
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
    final cached = _MessagingSessionCache.readThread(
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
        (cachedTime != null && (itemTime == null || cachedTime.isAfter(itemTime)));
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
      _MessagingSessionCache.ensureAccount(requestUserId);
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
        _items = _sortAndDedupeConversations(
          [..._items, ...items],
          requestUserId,
        );
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

  String _userInitials(BuildContext context) {
    try {
      final user = context.watch<SessionController?>()?.user;
      final cleanName = (user?.fullName ?? '').trim();
      if (cleanName.isNotEmpty) {
        final parts = cleanName
            .split(RegExp(r'\s+'))
            .where((e) => e.isNotEmpty)
            .toList();
        if (parts.length >= 2) {
          return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
        }
        return cleanName
            .substring(0, cleanName.length >= 2 ? 2 : 1)
            .toUpperCase();
      }
    } catch (_) {}
    return 'MQ';
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

  Future<void> _openMockThread(_MockThread thread) async {
    setState(() {
      thread.conversation = Conversation(
        id: thread.conversation.id,
        relationshipId: thread.conversation.relationshipId,
        memberId: thread.conversation.memberId,
        coachId: thread.conversation.coachId,
        status: thread.conversation.status,
        unreadCount: 0,
        lastMessageAt: thread.conversation.lastMessageAt,
      );
    });

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ConversationDetailPage(
          conversation: thread.conversation,
          service: _service,
          currentUserId: widget.currentUserId.isNotEmpty
              ? widget.currentUserId
              : 'member-demo',
          picker: widget.picker ?? DeviceProgressPhotoPicker(),
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

  Future<void> _openRealConversation(Conversation item) async {
    final userId = _effectiveUserId;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ConversationDetailPage(
          conversation: item,
          service: _service,
          currentUserId: userId,
          picker: widget.picker ?? DeviceProgressPhotoPicker(),
        ),
      ),
    );
    if (!mounted || userId != _effectiveUserId) return;
    setState(() {
      _items = _sortAndDedupeConversations(_items, userId);
    });
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveBottomPadding =
        widget.bottomPadding ?? MetaGymBottomNav.contentBottomPadding(context);
    final initials = _userInitials(context);

    return Material(
      color: MetaGymTheme.darkCanvas,
      child: Stack(
        children: [
          const _MessagingGymBackground(),
          RefreshIndicator(
            color: MetaGymTheme.brandOrange,
            backgroundColor: MetaGymTheme.darkSurface,
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                MetaGymTheme.pageGutter,
                0,
                MetaGymTheme.pageGutter,
                effectiveBottomPadding,
              ),
              children: [
                const SizedBox(height: 6),
                _buildHeader(context, initials),
                if (_showSearch) ...[
                  const SizedBox(height: 10),
                  _buildSearchBar(),
                ],
                const SizedBox(height: 12),
                _buildQuickFilterDock(),
                const SizedBox(height: 10),
                if (_loading && widget.isActive)
                  _buildLiquidGlassCard(
                    child: const SizedBox(
                      height: 140,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: MetaGymTheme.brandOrange,
                          strokeWidth: 2.4,
                        ),
                      ),
                    ),
                  )
                else if (_error != null && !_usingMockShowcase)
                  _buildErrorCard()
                else if (_usingMockShowcase) ...[
                  if (_filter == _MessageFilter.all ||
                      _filter == _MessageFilter.coach) ...[
                    _buildFeaturedCoachCard(),
                    const SizedBox(height: 10),
                  ],
                  _buildSectionTitle('Cuộc trò chuyện gần đây'),
                  const SizedBox(height: 8),
                  if (_filteredMockThreads.isEmpty)
                    _buildEmptyCard(
                      title: 'Không tìm thấy cuộc trò chuyện phù hợp.',
                      subtitle:
                          'Thử đổi bộ lọc hoặc từ khóa tìm kiếm của bạn.',
                    )
                  else
                    for (final thread in _filteredMockThreads)
                      _buildMockConversationCard(thread),
                ] else ...[
                  if (_items.isEmpty)
                    _buildEmptyCard(
                      title: 'Bạn chưa có cuộc trò chuyện nào.',
                      subtitle:
                          'Khi bạn kết nối với Huấn luyện viên, tin nhắn sẽ hiển thị tại đây.',
                    )
                  else ...[
                    if (_filteredRealItems.isEmpty)
                      _buildEmptyCard(
                        title: 'Không tìm thấy cuộc trò chuyện phù hợp.',
                        subtitle: 'Thử đổi bộ lọc hoặc từ khóa tìm kiếm.',
                      )
                    else
                      for (final item in _filteredRealItems)
                        _buildRealConversationCard(item),
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
                ],
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String initials) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: MetaGymTheme.brandOrange,
                borderRadius: BorderRadius.circular(13),
              ),
              alignment: Alignment.center,
              child: const Text(
                'MG',
                style: TextStyle(
                  color: Color(0xFF111317),
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'META GYM',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: MetaGymTheme.brandOrange,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                      height: 1.2,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Tin nhắn',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Color(0xFFF7F9FC),
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                      height: 1.2,
                    ),
                  ),
                  SizedBox(height: 1),
                  Text(
                    'Trao đổi cùng Coach & hỗ trợ',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Color(0xFF8E9AA8),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _CircleGlassIconButton(
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
            const SizedBox(width: 8),
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: MetaGymTheme.brandOrange,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                initials,
                style: const TextStyle(
                  color: Color(0xFF111317),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return _buildLiquidGlassCard(
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        child: Row(
          children: [
            const Icon(
              Icons.search_rounded,
              color: MetaGymTheme.reflectionBlue,
              size: 19,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _searchQuery = value),
                style: const TextStyle(
                  color: Color(0xFFF7F9FC),
                  fontSize: 13.5,
                ),
                decoration: const InputDecoration(
                  hintText: 'Tìm Coach hoặc nội dung tin nhắn...',
                  hintStyle: TextStyle(
                    color: Color(0xFF8E9AA8),
                    fontSize: 13,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            if (_searchQuery.isNotEmpty)
              IconButton(
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
                icon: const Icon(
                  Icons.clear_rounded,
                  color: Color(0xFF8E9AA8),
                  size: 18,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickFilterDock() {
    return SizedBox(
      height: 36,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterButton(
              label: 'Tất cả',
              filter: _MessageFilter.all,
            ),
            const SizedBox(width: 8),
            _buildFilterButton(
              label: 'Coach',
              filter: _MessageFilter.coach,
            ),
            const SizedBox(width: 8),
            _buildFilterButton(
              label: 'Chưa đọc',
              filter: _MessageFilter.unread,
            ),
            const SizedBox(width: 8),
            _buildFilterButton(
              label: 'Hỗ trợ',
              filter: _MessageFilter.support,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterButton({
    required String label,
    required _MessageFilter filter,
  }) {
    final isActive = _filter == filter;
    final body = Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: isActive ? const Color(0x2EFF5A36) : const Color(0xA6231F1C),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive ? MetaGymTheme.brandOrange : const Color(0x4D9C9084),
          width: isActive ? 1.1 : 0.9,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          color: isActive ? const Color(0xFFF7F9FC) : const Color(0xFFB8C2D0),
          fontSize: 12,
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
          child: body,
        ),
      ),
    );
  }

  Widget _buildFeaturedCoachCard() {
    final coachThread = _mockThreads.first;
    return _buildLiquidGlassCard(
      isHighlighted: true,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: MetaGymTheme.brandOrange,
                  size: 12,
                ),
                const SizedBox(width: 5),
                const Text(
                  'COACH CÁ NHÂN',
                  style: TextStyle(
                    color: Color(0xFFF7F9FC),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 7),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1.5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x2623C997),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0x4D23C997),
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 4.5,
                        height: 4.5,
                        decoration: const BoxDecoration(
                          color: Color(0xFF23C997),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Đang hoạt động',
                        style: TextStyle(
                          color: Color(0xFF23C997),
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0x332A1510),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: MetaGymTheme.brandOrange,
                      width: 1.2,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    coachThread.initials,
                    style: const TextStyle(
                      color: MetaGymTheme.brandOrange,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        coachThread.displayName,
                        style: const TextStyle(
                          color: Color(0xFFF7F9FC),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 1),
                      const Text(
                        'Huấn luyện viên 1-1 · Sẵn sàng hỗ trợ',
                        style: TextStyle(
                          color: Color(0xFF8E9AA8),
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _openMockThread(coachThread),
                  child: Container(
                    height: 28,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: MetaGymTheme.brandOrange,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'Nhắn ngay ▶',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
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
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        const Icon(
          Icons.history_rounded,
          color: MetaGymTheme.reflectionBlue,
          size: 16,
        ),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFFF7F9FC),
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildMockConversationCard(_MockThread thread) {
    final unread = thread.conversation.unreadCount;
    return _buildLiquidGlassCard(
      borderRadius: BorderRadius.circular(14),
      margin: const EdgeInsets.only(bottom: 7),
      child: InkWell(
        onTap: () => _openMockThread(thread),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0x80211E1C),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: thread.category == _MessageFilter.coach
                            ? const Color(0x66FF5A36)
                            : const Color(0x4D9C9084),
                        width: 1.0,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      thread.initials,
                      style: TextStyle(
                        color: thread.category == _MessageFilter.coach
                            ? MetaGymTheme.brandOrange
                            : const Color(0xFFD5DEE8),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (thread.isOnline)
                    Positioned(
                      right: -1,
                      bottom: -1,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: MetaGymTheme.progressGreen,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: MetaGymTheme.darkCanvas,
                            width: 1.5,
                          ),
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
                            style: const TextStyle(
                              color: Color(0xFFF7F9FC),
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0x26A79D92),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            thread.roleLabel,
                            style: const TextStyle(
                              color: Color(0xFFB8C2D0),
                              fontSize: 8.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      thread.lastMessage,
                      style: TextStyle(
                        color: unread > 0
                            ? const Color(0xFFD5DEE8)
                            : const Color(0xFF8E9AA8),
                        fontSize: 11.5,
                        fontWeight: unread > 0
                            ? FontWeight.w500
                            : FontWeight.w400,
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
                      color: unread > 0
                          ? MetaGymTheme.brandOrange
                          : const Color(0xFF8E9AA8),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  if (unread > 0) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: MetaGymTheme.brandOrange,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$unread',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
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
        ),
      ),
    );
  }

  Widget _buildRealConversationCard(Conversation item) {
    final userId = _effectiveUserId;
    final timeLabel = item.formatLastMessageTime();
    return _buildLiquidGlassCard(
      borderRadius: BorderRadius.circular(14),
      margin: const EdgeInsets.only(bottom: 7),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _openRealConversation(item),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0x1F223145),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0x38D4E4FF),
                    width: 1.0,
                  ),
                ),
                child: Center(
                  child: Icon(
                    item.memberId == userId
                        ? Icons.sports_gymnastics_rounded
                        : Icons.person_rounded,
                    color: MetaGymTheme.reflectionBlue,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.displayNameFor(userId),
                      style: const TextStyle(
                        color: MetaGymTheme.darkTextPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
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
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            item.lastMessagePreview,
                            style: TextStyle(
                              color: item.unreadCount > 0
                                  ? const Color(0xFFD5DEE8)
                                  : MetaGymTheme.darkTextSecondary,
                              fontSize: 11.5,
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
                            ? MetaGymTheme.brandOrange
                            : const Color(0xFF8E9AA8),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        fontFeatures: const [FontFeature.tabularFigures()],
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
                  else if (timeLabel.isEmpty)
                    const Icon(
                      Icons.chevron_right,
                      color: MetaGymTheme.darkTextTertiary,
                      size: 20,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    return _buildLiquidGlassCard(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
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
              onPressed: _load,
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
    );
  }

  Widget _buildEmptyCard({required String title, required String subtitle}) {
    return _buildLiquidGlassCard(
      child: Padding(
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
                  border: Border.all(color: const Color(0x2EA9C7E8)),
                ),
                child: const Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: MetaGymTheme.reflectionBlue,
                  size: 26,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: MetaGymTheme.darkTextPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: MetaGymTheme.darkTextTertiary,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ConversationDetailPage extends StatefulWidget {
  const ConversationDetailPage({
    required this.conversation,
    this.service,
    required this.currentUserId,
    required this.picker,
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
  final String? mockTitle;
  final String? mockInitials;
  final String? mockContextTitle;
  final List<ChatMessage>? initialMockMessages;
  final ValueChanged<ChatMessage>? onMockMessageAdded;

  @override
  State<ConversationDetailPage> createState() => _ConversationDetailPageState();
}

class _ConversationDetailPageState extends State<ConversationDetailPage> {
  StreamSubscription<String>? _realtimeMessages;
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  List<ChatMessage> _messages = const [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _sending = false;
  bool _imageSending = false;
  bool _creatingCall = false;
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

  static const _quickReplies = [
    'Lịch tập hôm nay',
    'Đổi giờ tập',
    'Hỏi thực đơn',
    'Cảm ơn Coach!',
  ];

  void _storeCache(
    List<ChatMessage> messages, {
    bool? hasMore,
    String? lastReadId,
  }) {
    _MessagingSessionCache.writeThread(
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
      _MessagingSessionCache.clearAll();
      setState(() {
        _messages = const [];
        _loading = false;
        _loadingMore = false;
        _sending = false;
        _imageSending = false;
        _polling = false;
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
    SessionController? session;
    try {
      session = context.read<SessionController?>();
    } catch (_) {}
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
        _MessagingSessionCache.clearAll();
      }
      final cached = _MessagingSessionCache.readThread(
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
      _realtimeMessages = context.read<MetaGymRealtime?>()?.messages.listen((id) {
        if (mounted && id == widget.conversation.id) unawaited(_refreshLatest());
      });
      final cached = _MessagingSessionCache.readThread(
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
      final messages = await widget.service!.getMessages(
        requestKey,
        1,
      );
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
      final latest = await widget.service!.getMessages(
        requestKey,
        1,
      );
      if (!_isActiveRequest(requestEpoch, requestUserId, requestKey)) return;
      final merged = _mergeMessages(newer: latest, current: _messages);
      setState(() => _messages = merged);
      _storeCache(merged);
      unawaited(_markLatestReceived(merged).catchError((_) {}));
    } catch (_) {
      // Keep the visible message list intact when background refresh fails.
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
      // Leave _lastReadId unchanged so the next sync retries markRead.
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
    });
    widget.onMockMessageAdded?.call(msg);
  }

  Future<void> _send([String? overrideText]) async {
    if (_sending) return;
    final candidate = overrideText ?? _textController.text;
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

    if (_draftContent != text || _draftMessageId == null) {
      _draftContent = text;
      _draftMessageId = newClientMessageId();
    }
    final clientMessageId = _draftMessageId!;
    final requestEpoch = _sessionEpoch;
    final requestUserId = widget.currentUserId;
    final requestKey = widget.conversation.messageKey;
    setState(() {
      _sending = true;
      _sendError = null;
    });
    try {
      final created = await service.sendText(
        requestKey,
        text,
        clientMessageId,
      );
      if (!_isActiveRequest(requestEpoch, requestUserId, requestKey)) return;
      _textController.clear();
      _draftMessageId = null;
      _draftContent = null;
      setState(() {
        _saveMessage(created);
      });
    } on ApiException catch (error) {
      if (!_isActiveRequest(requestEpoch, requestUserId, requestKey)) return;
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chế độ xem trước giao diện — chưa kết nối upload ảnh.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (_imageSending) return;
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
    if (image == null || _imageSending || widget.service == null) return;
    final requestEpoch = _sessionEpoch;
    final requestUserId = widget.currentUserId;
    final requestKey = widget.conversation.messageKey;
    final clientMessageId = _pendingImageMessageId ??= newClientMessageId();
    setState(() {
      _imageSending = true;
      _imageError = null;
    });
    try {
      final mediaId =
          _pendingMediaId ?? await widget.service!.uploadImage(image);
      if (!_isActiveRequest(requestEpoch, requestUserId, requestKey)) return;
      _pendingMediaId = mediaId;
      final created = await widget.service!.sendImage(
        requestKey,
        mediaId,
        clientMessageId,
      );
      if (!_isActiveRequest(requestEpoch, requestUserId, requestKey)) return;
      _pendingImage = null;
      _pendingMediaId = null;
      _pendingImageMessageId = null;
      setState(() => _saveMessage(created));
    } on ApiException catch (error) {
      if (!_isActiveRequest(requestEpoch, requestUserId, requestKey)) return;
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

  void _showCallNotice(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _startCall(String callType) async {
    if (_creatingCall) return;
    final service = context.read<CallsService?>();
    if (_isMockMode || service is! CallsApi) {
      _showCallNotice('Dịch vụ cuộc gọi chưa khả dụng.');
      return;
    }
    final conversation = widget.conversation;
    final relationshipId = conversation.relationshipId;
    if (relationshipId == null || conversation.status != 'ACTIVE') {
      _showCallNotice('Chỉ có thể gọi khi quan hệ huấn luyện đang hoạt động.');
      return;
    }

    final navigator = Navigator.of(context, rootNavigator: true);
    if (LiveCallPage.isOpen(navigator)) return;
    _creatingCall = true;
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
      if (mounted) _showCallNotice('Không tạo được cuộc gọi.');
    } finally {
      _creatingCall = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.mockTitle ??
        widget.conversation.displayNameFor(widget.currentUserId);
    final initials = widget.mockInitials ??
        widget.conversation.initialsFor(widget.currentUserId);

    return Scaffold(
      backgroundColor: MetaGymTheme.darkCanvas,
      body: Stack(
        children: [
          const _MessagingGymBackground(),
          Column(
            children: [
              _buildGlassAppBar(context, title, initials),
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
                            color: MetaGymTheme.brandOrange,
                            strokeWidth: 2.5,
                          ),
                        ),
                      )
                    else ...[
                      if (_error != null)
                        _buildLiquidGlassCard(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
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
                                  onPressed:
                                      _messages.isEmpty ? _load : _loadMore,
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
                        ),
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
                      else ...[
                        for (final message in _messages)
                          KeyedSubtree(
                            key: ValueKey('chat-msg-${message.id}'),
                            child: Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: _buildChatMessageBubble(message),
                            ),
                          ),
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
                        Center(
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0x24223145),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0x33D4E4FF),
                                width: 0.8,
                              ),
                            ),
                            child: const Text(
                              'Hôm nay',
                              style: TextStyle(
                                color: Color(0xFFB8C2D0),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                    _buildLiquidGlassCard(
                      margin: const EdgeInsets.only(bottom: 14),
                      child: Padding(
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
                                        ? MetaGymTheme.progressGreen
                                        : MetaGymTheme.darkTextTertiary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    widget.mockContextTitle ??
                                        'Trò chuyện riêng tư',
                                    style: const TextStyle(
                                      color: MetaGymTheme.darkTextPrimary,
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
                                        ? 'Kết nối trực tiếp với huấn luyện viên'
                                        : (widget.conversation.status == 'ENDED'
                                              ? 'Bạn vẫn có thể tiếp tục nhắn tin.'
                                              : 'Có thể nhắn tin.'))
                                  : 'Không thể gửi tin nhắn.',
                              style: const TextStyle(
                                color: MetaGymTheme.darkTextSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.conversation.canSend) _buildComposerArea(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGlassAppBar(
    BuildContext context,
    String title,
    String initials,
  ) {
    final enableBlur = !MetaGymTheme.isFlutterTestEnvironment;
    final bar = Container(
      decoration: const BoxDecoration(
        color: Color(0x66101622),
        border: Border(
          bottom: BorderSide(color: Color(0x2ED4E4FF), width: 0.8),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 12, 10),
          child: Row(
            children: [
              _CircleGlassIconButton(
                icon: Icons.arrow_back_rounded,
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onTap: () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(width: 8),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0x332A1510),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: MetaGymTheme.brandOrange,
                    width: 1.2,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: MetaGymTheme.brandOrange,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFFF7F9FC),
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: widget.conversation.canSend
                                ? MetaGymTheme.progressGreen
                                : MetaGymTheme.darkTextTertiary,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            widget.conversation.canSend
                                ? 'Đang hoạt động'
                                : 'Chỉ đọc',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: widget.conversation.canSend
                                  ? MetaGymTheme.progressGreen
                                  : const Color(0xFF8E9AA8),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _CircleGlassIconButton(
                icon: Icons.call_outlined,
                tooltip: 'Gọi thoại',
                onTap: () => _startCall('VOICE'),
              ),
              const SizedBox(width: 4),
              _CircleGlassIconButton(
                icon: Icons.videocam_outlined,
                tooltip: 'Gọi video',
                onTap: () => _startCall('VIDEO'),
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

  Widget _buildComposerArea() {
    final enableBlur = !MetaGymTheme.isFlutterTestEnvironment;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
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
            SizedBox(
              height: 32,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: _imageSending ? null : _pickImage,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0x26A9C7E8),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0x4DA9C7E8),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.image_outlined,
                              size: 14,
                              color: MetaGymTheme.reflectionBlue,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              _imageSending ? 'Đang gửi ảnh…' : 'Gửi ảnh',
                              style: const TextStyle(
                                color: MetaGymTheme.reflectionBlue,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    for (final reply in _quickReplies) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => _send(reply),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0x331E293B),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0x38D4E4FF),
                              width: 0.8,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            reply,
                            style: const TextStyle(
                              color: Color(0xFFD5DEE8),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
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
                      child: _buildCapsuleComposerBody(),
                    )
                  : _buildCapsuleComposerBody(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCapsuleComposerBody() {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 5, 6, 5),
      decoration: BoxDecoration(
        color: const Color(0xCC1E1A17),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0x529C9084), width: 1.0),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: _imageSending ? null : _pickImage,
            tooltip: 'Gửi ảnh',
            icon: _imageSending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFFD5DEE8),
                    ),
                  )
                : const Icon(
                    Icons.image_outlined,
                    color: Color(0xFFD5DEE8),
                    size: 21,
                  ),
          ),
          Expanded(
            child: TextField(
              controller: _textController,
              maxLength: 5000,
              minLines: 1,
              maxLines: 4,
              style: const TextStyle(
                color: MetaGymTheme.darkTextPrimary,
                fontSize: 14,
              ),
              decoration: const InputDecoration(
                hintText: 'Nhắn tin cho Coach...',
                hintStyle: TextStyle(color: Color(0xFF8E9AA8), fontSize: 13.5),
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                counterText: '',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
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
              onTap: _sending ? null : _send,
              borderRadius: BorderRadius.circular(20),
              child: Ink(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: MetaGymTheme.brandOrange,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Center(
                  child: Text(
                    'Gửi',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
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

  Widget _buildChatMessageBubble(ChatMessage message) {
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
        color: isMe ? MetaGymTheme.brandOrange : const Color(0xCC2B2622),
        borderRadius: bubbleRadius,
        border: isMe
            ? null
            : Border.all(color: const Color(0x529C9084), width: 1.0),
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
                color: isMe ? Colors.white : MetaGymTheme.darkTextPrimary,
                fontSize: 14,
                height: 1.35,
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
                  message.sentAt,
                  style: TextStyle(
                    color: isMe
                        ? Colors.white.withValues(alpha: 0.78)
                        : MetaGymTheme.darkTextTertiary,
                    fontSize: 10,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.done_all_rounded,
                    size: 13,
                    color: Colors.white.withValues(alpha: 0.85),
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
