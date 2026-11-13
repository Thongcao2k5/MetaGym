import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_bottom_nav.dart';
import 'package:meta_gym_app/features/auth/presentation/session_controller.dart';
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

  _MessageFilter _filter = _MessageFilter.all;
  bool _showSearch = false;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _usingMockShowcase = false;
  late List<_MockThread> _mockThreads;

  @override
  void initState() {
    super.initState();
    _mockThreads = _createInitialMockThreads();
  }

  @override
  void dispose() {
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
    if (_service != null) return;
    if (widget.service != null) {
      _service = widget.service;
    } else {
      try {
        _service = context.read<MessagingService>();
      } catch (_) {
        _service = null;
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  bool get _canFallbackToMock =>
      widget.service == null && !MetaGymTheme.isFlutterTestEnvironment;

  Future<void> _load() async {
    if (_service == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _usingMockShowcase = _canFallbackToMock;
        });
      }
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _service!.getConversations(1);
      if (mounted) {
        final useMock = items.isEmpty && _canFallbackToMock;
        setState(() {
          _items = items;
          _page = 1;
          _hasMore = items.length == 20;
          _usingMockShowcase = useMock;
        });
      }
    } on ApiException catch (error) {
      if (mounted) {
        if (_canFallbackToMock) {
          setState(() {
            _error = null;
            _usingMockShowcase = true;
          });
        } else {
          setState(() => _error = error.message);
        }
      }
    } catch (_) {
      if (mounted) {
        if (_canFallbackToMock) {
          setState(() {
            _error = null;
            _usingMockShowcase = true;
          });
        } else {
          setState(() => _error = 'Không tải được cuộc trò chuyện.');
        }
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_service == null) return;
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
    return _items.where((item) {
      if (_filter == _MessageFilter.unread && item.unreadCount == 0) {
        return false;
      }
      if (_filter == _MessageFilter.support) {
        return false;
      }
      if (query.isNotEmpty) {
        final label = item.memberId == widget.currentUserId
            ? 'Coach ${item.coachId}'
            : 'Hội viên ${item.memberId}';
        if (!label.toLowerCase().contains(query)) return false;
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
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ConversationDetailPage(
          conversation: item,
          service: _service,
          currentUserId: widget.currentUserId,
          picker: widget.picker ?? DeviceProgressPhotoPicker(),
        ),
      ),
    );
    if (mounted) _load();
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
                if (_loading)
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
                    item.memberId == widget.currentUserId
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
                      item.memberId == widget.currentUserId
                          ? 'Coach ${item.coachId}'
                          : 'Hội viên ${item.memberId}',
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
                            item.canSend
                                ? 'Đang hoạt động'
                                : 'Quan hệ đã kết thúc · chỉ đọc',
                            style: const TextStyle(
                              color: MetaGymTheme.darkTextSecondary,
                              fontSize: 11.5,
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
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
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

  bool get _isMockMode => widget.initialMockMessages != null;

  static const _quickReplies = [
    'Lịch tập hôm nay',
    'Đổi giờ tập',
    'Hỏi thực đơn',
    'Cảm ơn Coach!',
  ];

  @override
  void dispose() {
    _pollTimer?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    if (_isMockMode) {
      _messages = List<ChatMessage>.from(widget.initialMockMessages!);
      _loading = false;
    } else {
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
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final messages = await widget.service!.getMessages(
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

  Future<void> _refreshLatest() async {
    if (_polling || _loading || widget.service == null) return;
    _polling = true;
    try {
      final latest = await widget.service!.getMessages(
        widget.conversation.relationshipId,
        1,
      );
      if (!mounted) return;
      final existingById = {for (final item in _messages) item.id: item};
      for (final item in latest) {
        existingById[item.id] = item;
      }
      final merged = existingById.values.toList();
      setState(() => _messages = merged);
      await _markLatestReceived(latest);
    } catch (_) {
      // Keep the visible message list intact when background refresh fails.
    } finally {
      _polling = false;
    }
  }

  Future<void> _loadMore() async {
    if (widget.service == null) return;
    setState(() {
      _loadingMore = true;
      _error = null;
    });
    try {
      final messages = await widget.service!.getMessages(
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

  Future<void> _markLatestReceived(List<ChatMessage> messages) async {
    if (widget.service == null) return;
    for (final message in messages) {
      if (message.senderId != widget.currentUserId &&
          message.id != _lastReadId) {
        _lastReadId = message.id;
        await widget.service!.markRead(
          widget.conversation.relationshipId,
          message.id,
        );
        return;
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
      _messages = [..._messages, msg];
    });
    widget.onMockMessageAdded?.call(msg);
  }

  Future<void> _send([String? overrideText]) async {
    if (_sending) return;
    final text = (overrideText ?? _textController.text).trim();
    if (text.isEmpty) return;

    if (_isMockMode || widget.service == null) {
      _sendMockMessage(text);
      return;
    }

    if (_draftContent != text) {
      _draftContent = text;
      _draftMessageId = newClientMessageId();
    }
    final clientMessageId = _draftMessageId!;
    setState(() {
      _sending = true;
      _sendError = null;
    });
    try {
      final created = await widget.service!.sendText(
        widget.conversation.relationshipId,
        text,
        clientMessageId,
      );
      if (mounted) {
        _textController.clear();
        _draftMessageId = null;
        _draftContent = null;
        setState(() {
          _messages = [..._messages, created];
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
    final image = await widget.picker.pick();
    if (image == null || !mounted) return;
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
    setState(() {
      _imageSending = true;
      _imageError = null;
    });
    try {
      final mediaId =
          _pendingMediaId ?? await widget.service!.uploadImage(image);
      _pendingMediaId = mediaId;
      final created = await widget.service!.sendImage(
        widget.conversation.relationshipId,
        mediaId,
        _pendingImageMessageId!,
      );
      if (mounted) {
        _pendingImage = null;
        _pendingMediaId = null;
        _pendingImageMessageId = null;
        setState(() => _messages = [..._messages, created]);
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _imageError = error.message);
    } catch (_) {
      if (mounted) setState(() => _imageError = 'Không gửi được hình ảnh.');
    } finally {
      if (mounted) setState(() => _imageSending = false);
    }
  }

  void _showFeaturePreviewNotice(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label sẽ khả dụng khi nối dịch vụ cuộc gọi.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.mockTitle ??
        (widget.conversation.memberId == widget.currentUserId
            ? 'Coach ${widget.conversation.coachId}'
            : 'Hội viên ${widget.conversation.memberId}');
    final initials = widget.mockInitials ?? 'LN';

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
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  children: [
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
                                        'Quan hệ ${widget.conversation.relationshipId}',
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
                                        : 'Quan hệ đang hoạt động.')
                                  : 'Quan hệ đã kết thúc; lịch sử chỉ đọc.',
                              style: const TextStyle(
                                color: MetaGymTheme.darkTextSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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
                        for (final message in _messages) ...[
                          _buildChatMessageBubble(message),
                          const SizedBox(height: 10),
                        ],
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
                        Text(
                          widget.conversation.canSend
                              ? 'Đang hoạt động'
                              : 'Chỉ đọc',
                          style: TextStyle(
                            color: widget.conversation.canSend
                                ? MetaGymTheme.progressGreen
                                : const Color(0xFF8E9AA8),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
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
                onTap: () => _showFeaturePreviewNotice('Gọi thoại'),
              ),
              const SizedBox(width: 4),
              _CircleGlassIconButton(
                icon: Icons.videocam_outlined,
                tooltip: 'Gọi video',
                onTap: () => _showFeaturePreviewNotice('Gọi video'),
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
                border: InputBorder.none,
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

    final bubbleBody = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
          if (message.messageType == 'IMAGE' &&
              message.mediaId != null &&
              widget.service != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: ChatMessageImage(
                service: widget.service!,
                mediaId: message.mediaId!,
              ),
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
          Row(
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
