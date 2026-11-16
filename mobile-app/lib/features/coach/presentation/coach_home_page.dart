import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:meta_gym_app/app/app_router.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_bottom_nav.dart';
import 'package:meta_gym_app/features/ai/presentation/ai_conversations_page.dart';
import 'package:meta_gym_app/features/auth/presentation/session_controller.dart';
import 'package:meta_gym_app/features/messaging/presentation/conversations_page.dart';
import 'package:meta_gym_app/features/profile/presentation/profile_page.dart';
import 'package:provider/provider.dart';

/// Không gian làm việc chính của Huấn luyện viên (Coach) đồng bộ layout 5 tab
/// và chất liệu kính tối khói ấm từ Member Home.
class CoachHomePage extends StatefulWidget {
  const CoachHomePage({super.key});

  @override
  State<CoachHomePage> createState() => _CoachHomePageState();
}

class _CoachHomePageState extends State<CoachHomePage> {
  int _index = 0;
  int _workHubInitialTab = 0;
  final Set<int> _visitedTabs = {0};

  void _selectTab(int index) {
    setState(() {
      _visitedTabs.add(index);
      _index = index;
    });
  }

  void _openWorkHubTab(int subTab) {
    setState(() {
      _workHubInitialTab = subTab;
      _visitedTabs.add(1);
      _index = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = context.watch<SessionController>().user?.id ?? '';
    final bottomPadding = MetaGymBottomNav.contentBottomPadding(context);

    final pages = [
      _CoachDashboardView(
        bottomPadding: bottomPadding,
        onNavigateTab: _selectTab,
        onOpenWorkHub: _openWorkHubTab,
      ),
      if (_visitedTabs.contains(1))
        _CoachWorkHubView(
          bottomPadding: bottomPadding,
          initialSegment: _workHubInitialTab,
          onOpenMessages: () => _selectTab(3),
        )
      else
        const SizedBox.shrink(),
      if (_visitedTabs.contains(2))
        AiConversationsPage(bottomPadding: bottomPadding)
      else
        const SizedBox.shrink(),
      if (_visitedTabs.contains(3))
        ConversationsPage(
          currentUserId: currentUserId,
          bottomPadding: bottomPadding,
          isActive: _index == 3,
        )
      else
        const SizedBox.shrink(),
      if (_visitedTabs.contains(4))
        ProfilePage(bottomPadding: bottomPadding)
      else
        const SizedBox.shrink(),
    ];

    return RepaintBoundary(
      child: Scaffold(
        extendBody: true,
        backgroundColor: MetaGymTheme.darkCanvas,
        body: IndexedStack(index: _index, children: pages),
        bottomNavigationBar: MetaGymBottomNav(
          currentIndex: _index,
          warmGlass: true,
          secondTabLabel: 'Lịch dạy',
          secondTabIcon: Icons.calendar_month_outlined,
          onTap: _selectTab,
        ),
      ),
    );
  }
}

// =============================================================================
// Dữ liệu mẫu giao diện (UI Showcase) bám sát schema Backend Coach V2
// =============================================================================

class _CoachBookingItem {
  _CoachBookingItem({
    required this.id,
    required this.memberName,
    required this.memberInitials,
    required this.timeRange,
    required this.focusArea,
    required this.dayLabel,
    required this.status,
  });

  final String id;
  final String memberName;
  final String memberInitials;
  final String timeRange;
  final String focusArea;
  final String dayLabel;
  String status; // CONFIRMED, PENDING, COMPLETED
}

class _CoachRequestItem {
  const _CoachRequestItem({
    required this.id,
    required this.memberName,
    required this.initials,
    required this.goal,
    required this.note,
    required this.timeAgo,
  });

  final String id;
  final String memberName;
  final String initials;
  final String goal;
  final String note;
  final String timeAgo;
}

class _CoachMemberItem {
  const _CoachMemberItem({
    required this.id,
    required this.name,
    required this.initials,
    required this.packageName,
    required this.remainingSessions,
    required this.daysLeft,
    required this.goal,
  });

  final String id;
  final String name;
  final String initials;
  final String packageName;
  final int remainingSessions;
  final int daysLeft;
  final String goal;
}

class _CoachNotificationItem {
  _CoachNotificationItem({
    required this.title,
    required this.body,
    required this.time,
    this.unread = true,
  });

  final String title;
  final String body;
  final String time;
  bool unread;
}

// =============================================================================
// Tab 0: Trang chủ Coach (áp dụng layout MemberDashboardView)
// =============================================================================

class _CoachDashboardView extends StatefulWidget {
  const _CoachDashboardView({
    required this.bottomPadding,
    required this.onNavigateTab,
    required this.onOpenWorkHub,
  });

  final double bottomPadding;
  final ValueChanged<int> onNavigateTab;
  final ValueChanged<int> onOpenWorkHub;

  @override
  State<_CoachDashboardView> createState() => _CoachDashboardViewState();
}

class _CoachDashboardViewState extends State<_CoachDashboardView> {
  static const AssetImage _gymBannerAsset = AssetImage(
    'assets/images/gym_banner.png',
  );

  final List<_CoachBookingItem> _todayBookings = [
    _CoachBookingItem(
      id: 'bk-1',
      memberName: 'Nguyễn Minh Tuấn',
      memberInitials: 'MT',
      timeRange: '09:00 – 10:30',
      focusArea: 'Upper Body · Sức mạnh',
      dayLabel: 'Hôm nay',
      status: 'CONFIRMED',
    ),
    _CoachBookingItem(
      id: 'bk-2',
      memberName: 'Trần Thảo Vy',
      memberInitials: 'TV',
      timeRange: '14:00 – 15:30',
      focusArea: 'Glutes & Core · Giảm mỡ',
      dayLabel: 'Hôm nay',
      status: 'PENDING',
    ),
    _CoachBookingItem(
      id: 'bk-3',
      memberName: 'Phạm Quốc Bảo',
      memberInitials: 'QB',
      timeRange: '17:30 – 19:00',
      focusArea: 'Pull & Mobility',
      dayLabel: 'Hôm nay',
      status: 'COMPLETED',
    ),
  ];

  final List<_CoachNotificationItem> _notifications = [
    _CoachNotificationItem(
      title: 'Yêu cầu chọn Coach mới',
      body: 'Lê Gia Huy đã gửi yêu cầu đồng hành gói 12 buổi.',
      time: '10 phút trước',
    ),
    _CoachNotificationItem(
      title: 'Đặt lịch ca 90 phút',
      body: 'Trần Thảo Vy vừa đặt ca 14:00 – 15:30 hôm nay.',
      time: '45 phút trước',
    ),
    _CoachNotificationItem(
      title: 'Gói Coach sắp hết hạn',
      body: 'Học viên Phạm Quốc Bảo chỉ còn 2 buổi và 4 ngày hiệu lực.',
      time: 'Hôm qua',
      unread: false,
    ),
  ];

  final Map<String, bool> _weeklyWorkDays = {
    'Thứ 2': true,
    'Thứ 3': true,
    'Thứ 4': true,
    'Thứ 5': true,
    'Thứ 6': true,
    'Thứ 7': true,
    'Chủ nhật': false,
  };

  final Set<String> _blockedSlots = {'12:00 – 13:30'};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!MetaGymTheme.isFlutterTestEnvironment) {
      precacheImage(_gymBannerAsset, context).catchError((_) {});
    }
  }

  String _initialsFromName(String fullName) {
    final clean = fullName.trim();
    final parts = clean.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    if (clean.isNotEmpty) {
      return clean.substring(0, clean.length >= 2 ? 2 : 1).toUpperCase();
    }
    return 'HL';
  }

  void _showToast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF2B2622),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0x529C9084)),
          ),
          content: Text(
            message,
            style: const TextStyle(color: Color(0xFFF7F9FC), fontSize: 13),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<SessionController>().user;
    final coachName = (user?.fullName.trim().isNotEmpty ?? false)
        ? user!.fullName
        : 'Huấn luyện viên';
    final unreadCount = _notifications.where((n) => n.unread).length;

    return Stack(
      fit: StackFit.expand,
      children: [
        const _CoachGymBackground(),
        SafeArea(
          bottom: false,
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              10,
              16,
              widget.bottomPadding + 24,
            ),
            children: [
              _buildHeader(coachName, unreadCount),
              const SizedBox(height: 6),
              const Text(
                'Không gian dành cho huấn luyện viên',
                style: TextStyle(
                  color: Color(0xFF9BA5B4),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              _buildHeroSessionCard(),
              const SizedBox(height: 16),
              _buildSectionTitle('Truy cập nhanh'),
              const SizedBox(height: 10),
              _buildQuickActionsRow(),
              const SizedBox(height: 16),
              _buildSectionTitle('Quản lý & Thiết lập lịch'),
              const SizedBox(height: 8),
              _buildScheduleToolsCard(),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSectionTitle('Lịch dạy hôm nay'),
                  GestureDetector(
                    onTap: () => widget.onOpenWorkHub(0),
                    child: const Text(
                      'Xem tất cả',
                      style: TextStyle(
                        color: MetaGymTheme.brandOrange,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (final booking in _todayBookings) _buildBookingCard(booking),
              const SizedBox(height: 12),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFB8C2D0),
                  side: const BorderSide(color: Color(0x409C9084)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => context.push(AppRoutes.coachWorkbench),
                child: const Text('Kiểm thử các luồng Coach'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(String coachName, int unreadCount) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: MetaGymTheme.brandOrange,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: const Text(
            'MG',
            style: TextStyle(
              color: Color(0xFF111317),
              fontSize: 13.5,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'META GYM · COACH',
                style: TextStyle(
                  color: MetaGymTheme.brandOrange,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.3,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                'Xin chào, $coachName',
                style: const TextStyle(
                  color: Color(0xFFF7F9FC),
                  fontSize: 17.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        Stack(
          clipBehavior: Clip.none,
          children: [
            _CoachCircleButton(
              icon: Icons.notifications_none_rounded,
              tooltip: 'Thông báo Coach',
              onTap: _openNotificationsSheet,
            ),
            if (unreadCount > 0)
              Positioned(
                right: 2,
                top: 2,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: const BoxDecoration(
                    color: MetaGymTheme.brandOrange,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => widget.onNavigateTab(4),
          child: Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: MetaGymTheme.brandOrange,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              _initialsFromName(coachName),
              style: const TextStyle(
                color: Color(0xFF111317),
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroSessionCard() {
    final nextBooking = _todayBookings.first;
    final confirmedCount =
        _todayBookings.where((b) => b.status != 'COMPLETED').length;

    return _CoachSmokedCard(
      featured: true,
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.schedule_rounded,
                color: MetaGymTheme.brandOrange,
                size: 14,
              ),
              const SizedBox(width: 6),
              const Text(
                'CA DẠY TIẾP THEO · 90 PHÚT',
                style: TextStyle(
                  color: Color(0xFFF7F9FC),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0x2423C997),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0x4D23C997),
                    width: 0.6,
                  ),
                ),
                child: const Text(
                  'Sắp diễn ra',
                  style: TextStyle(
                    color: MetaGymTheme.progressGreen,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0x24FF5A36),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0x80FF5A36),
                    width: 1.2,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  nextBooking.memberInitials,
                  style: const TextStyle(
                    color: MetaGymTheme.brandOrange,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nextBooking.memberName,
                      style: const TextStyle(
                        color: Color(0xFFF7F9FC),
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${nextBooking.timeRange} · ${nextBooking.focusArea}',
                      style: const TextStyle(
                        color: Color(0xFFB8C2D0),
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => widget.onOpenWorkHub(0),
                child: Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: MetaGymTheme.brandOrange,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'Lịch dạy',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, thickness: 0.7, color: Color(0x1FFFFFFF)),
          const SizedBox(height: 10),
          Row(
            children: [
              const Expanded(
                child: _CoachHeroMetric(label: 'Học viên', value: '8 đang theo'),
              ),
              Container(width: 1, height: 26, color: const Color(0x1FFFFFFF)),
              Expanded(
                child: _CoachHeroMetric(
                  label: 'Ca hôm nay',
                  value: '$confirmedCount ca chờ',
                ),
              ),
              Container(width: 1, height: 26, color: const Color(0x1FFFFFFF)),
              const Expanded(
                child: _CoachHeroMetric(label: 'Yêu cầu mới', value: '2 chờ duyệt'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsRow() {
    return Row(
      children: [
        Expanded(
          child: _CoachQuickAction(
            icon: Icons.people_alt_outlined,
            accent: MetaGymTheme.reflectionBlue,
            label: 'Học viên',
            onTap: () => widget.onOpenWorkHub(1),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _CoachQuickAction(
            icon: Icons.pending_actions_rounded,
            accent: MetaGymTheme.brandOrange,
            label: 'Yêu cầu',
            badgeText: '2',
            onTap: () => widget.onOpenWorkHub(1),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _CoachQuickAction(
            icon: Icons.menu_book_rounded,
            accent: MetaGymTheme.progressGreen,
            label: 'Giáo trình',
            onTap: () => context.push('/coach/features/training'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _CoachQuickAction(
            icon: Icons.restaurant_menu_rounded,
            accent: const Color(0xFFF6B756),
            label: 'Dinh dưỡng',
            onTap: () => context.push('/coach/features/nutrition'),
          ),
        ),
      ],
    );
  }

  Widget _buildBookingCard(_CoachBookingItem booking) {
    final isConfirmed = booking.status == 'CONFIRMED';
    final isCompleted = booking.status == 'COMPLETED';
    final statusColor = isCompleted
        ? const Color(0xFF8E9AA8)
        : (isConfirmed
              ? MetaGymTheme.progressGreen
              : MetaGymTheme.warningAmber);
    final statusText = isCompleted
        ? 'Hoàn thành'
        : (isConfirmed ? 'Đã xác nhận' : 'Chờ xác nhận');

    return _CoachSmokedCard(
      borderRadius: BorderRadius.circular(14),
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _openBookingDetailSheet(booking),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0x801E1A17),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0x409C9084),
                    width: 0.8,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  booking.memberInitials,
                  style: const TextStyle(
                    color: Color(0xFFD5DEE8),
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
                      booking.memberName,
                      style: const TextStyle(
                        color: Color(0xFFF7F9FC),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${booking.timeRange} · ${booking.focusArea}',
                      style: const TextStyle(
                        color: Color(0xFF9BA5B4),
                        fontSize: 11.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScheduleToolsCard() {
    final activeDays = _weeklyWorkDays.values.where((v) => v).length;
    return _CoachSmokedCard(
      borderRadius: BorderRadius.circular(16),
      child: Column(
        children: [
          _CoachMenuRow(
            icon: Icons.people_alt_outlined,
            accent: MetaGymTheme.progressGreen,
            title: 'Hội viên của tôi',
            subtitle: 'Danh sách học viên đang phụ trách',
            onTap: () => context.push('/coach/features/members'),
          ),
          const Divider(height: 1, thickness: 0.7, color: Color(0x2E9C9084)),
          _CoachMenuRow(
            icon: Icons.event_repeat_rounded,
            accent: MetaGymTheme.reflectionBlue,
            title: 'Lịch làm việc cố định theo tuần',
            subtitle: 'Đang mở $activeDays/7 ngày · Khung 06:00 – 20:00',
            onTap: _openWeeklyScheduleSheet,
          ),
          const Divider(height: 1, thickness: 0.7, color: Color(0x2E9C9084)),
          _CoachMenuRow(
            icon: Icons.block_rounded,
            accent: MetaGymTheme.warningAmber,
            title: 'Chặn khung giờ bận',
            subtitle: _blockedSlots.isEmpty
                ? 'Chưa chặn khung giờ nào'
                : 'Đang chặn ${_blockedSlots.length} khung giờ (${_blockedSlots.first})',
            onTap: _openBlockedSlotsSheet,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        color: Color(0xFF9BA5B4),
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.9,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Bottom Sheets tương tác giao diện (UI-only)
  // ---------------------------------------------------------------------------

  Future<void> _openNotificationsSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CoachModalSheet(
        title: 'Thông báo Coach',
        subtitle: 'Cập nhật yêu cầu chọn Coach, lịch đặt ca và hạn gói',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final item in _notifications)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: item.unread
                      ? const Color(0x1FFF5A36)
                      : const Color(0x66151210),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: item.unread
                        ? const Color(0x4DFF5A36)
                        : const Color(0x2E9C9084),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          item.title,
                          style: const TextStyle(
                            color: Color(0xFFF7F9FC),
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          item.time,
                          style: const TextStyle(
                            color: Color(0xFF8E9AA8),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.body,
                      style: const TextStyle(
                        color: Color(0xFFB8C2D0),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: MetaGymTheme.brandOrange,
                ),
                onPressed: () {
                  setState(() {
                    for (final item in _notifications) {
                      item.unread = false;
                    }
                  });
                  Navigator.pop(ctx);
                },
                child: const Text('Đánh dấu tất cả đã đọc'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openBookingDetailSheet(_CoachBookingItem booking) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CoachModalSheet(
        title: booking.memberName,
        subtitle: '${booking.dayLabel} · ${booking.timeRange} (90 phút)',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nội dung buổi tập: ${booking.focusArea}',
              style: const TextStyle(color: Color(0xFFD5DEE8), fontSize: 13.5),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFD5DEE8),
                      side: const BorderSide(color: Color(0x4D9C9084)),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      widget.onNavigateTab(3);
                    },
                    child: const Text('Nhắn học viên'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: MetaGymTheme.brandOrange,
                    ),
                    onPressed: () {
                      setState(() {
                        booking.status = booking.status == 'PENDING'
                            ? 'CONFIRMED'
                            : 'COMPLETED';
                      });
                      Navigator.pop(ctx);
                      _showToast('Đã cập nhật trạng thái buổi dạy');
                    },
                    child: Text(
                      booking.status == 'PENDING'
                          ? 'Xác nhận ca'
                          : 'Hoàn tất buổi',
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

  Future<void> _openWeeklyScheduleSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => _CoachModalSheet(
          title: 'Lịch làm việc cố định',
          subtitle: 'Chọn các ngày mở nhận lịch đặt ca 90 phút',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final entry in _weeklyWorkDays.entries)
                    FilterChip(
                      label: Text(entry.key),
                      selected: entry.value,
                      selectedColor: const Color(0x3DFF5A36),
                      checkmarkColor: MetaGymTheme.brandOrange,
                      backgroundColor: const Color(0x80151210),
                      labelStyle: TextStyle(
                        color: entry.value
                            ? const Color(0xFFF7F9FC)
                            : const Color(0xFF9BA5B4),
                      ),
                      onSelected: (val) {
                        setModalState(() => _weeklyWorkDays[entry.key] = val);
                        setState(() {});
                      },
                    ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: MetaGymTheme.brandOrange,
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showToast('Đã lưu lịch làm việc tuần (giao diện)');
                  },
                  child: const Text('Lưu lịch làm việc'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openBlockedSlotsSheet() async {
    const allSlots = [
      '07:30 – 09:00',
      '09:00 – 10:30',
      '12:00 – 13:30',
      '14:00 – 15:30',
      '17:30 – 19:00',
      '19:00 – 20:30',
    ];
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => _CoachModalSheet(
          title: 'Chặn khung giờ bận',
          subtitle: 'Học viên sẽ không đặt được các khung giờ bạn đã chặn',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final slot in allSlots)
                    FilterChip(
                      label: Text(slot),
                      selected: _blockedSlots.contains(slot),
                      selectedColor: const Color(0x3DF59E0B),
                      checkmarkColor: MetaGymTheme.warningAmber,
                      backgroundColor: const Color(0x80151210),
                      labelStyle: TextStyle(
                        color: _blockedSlots.contains(slot)
                            ? const Color(0xFFF7F9FC)
                            : const Color(0xFF9BA5B4),
                      ),
                      onSelected: (val) {
                        setModalState(() {
                          if (val) {
                            _blockedSlots.add(slot);
                          } else {
                            _blockedSlots.remove(slot);
                          }
                        });
                        setState(() {});
                      },
                    ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: MetaGymTheme.brandOrange,
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showToast('Đã cập nhật khung giờ chặn (giao diện)');
                  },
                  child: const Text('Xác nhận'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Tab 1: Quản lý Lịch dạy 90p & Học viên / Yêu cầu
// =============================================================================

class _CoachWorkHubView extends StatefulWidget {
  const _CoachWorkHubView({
    required this.bottomPadding,
    required this.initialSegment,
    required this.onOpenMessages,
  });

  final double bottomPadding;
  final int initialSegment;
  final VoidCallback onOpenMessages;

  @override
  State<_CoachWorkHubView> createState() => _CoachWorkHubViewState();
}

class _CoachWorkHubViewState extends State<_CoachWorkHubView> {
  late int _segment;
  int _selectedDayIndex = 0;

  static const _days = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

  final List<_CoachBookingItem> _bookings = [
    _CoachBookingItem(
      id: 'w1',
      memberName: 'Nguyễn Minh Tuấn',
      memberInitials: 'MT',
      timeRange: '09:00 – 10:30',
      focusArea: 'Upper Body · Sức mạnh',
      dayLabel: 'T2',
      status: 'CONFIRMED',
    ),
    _CoachBookingItem(
      id: 'w2',
      memberName: 'Trần Thảo Vy',
      memberInitials: 'TV',
      timeRange: '14:00 – 15:30',
      focusArea: 'Glutes & Core · Giảm mỡ',
      dayLabel: 'T2',
      status: 'PENDING',
    ),
    _CoachBookingItem(
      id: 'w3',
      memberName: 'Phạm Quốc Bảo',
      memberInitials: 'QB',
      timeRange: '17:30 – 19:00',
      focusArea: 'Pull & Mobility',
      dayLabel: 'T2',
      status: 'COMPLETED',
    ),
    _CoachBookingItem(
      id: 'w4',
      memberName: 'Lê Hoàng Anh',
      memberInitials: 'HA',
      timeRange: '10:30 – 12:00',
      focusArea: 'Lower Body · Squat',
      dayLabel: 'T3',
      status: 'CONFIRMED',
    ),
  ];

  final List<_CoachRequestItem> _requests = [
    const _CoachRequestItem(
      id: 'req-1',
      memberName: 'Lê Gia Huy',
      initials: 'GH',
      goal: 'Tăng cơ 4 buổi/tuần · Gói 12 buổi',
      note: 'Mình muốn tập khung 18h các ngày 2-4-6.',
      timeAgo: '10 phút trước',
    ),
    const _CoachRequestItem(
      id: 'req-2',
      memberName: 'Vũ Ngọc Ánh',
      initials: 'NA',
      goal: 'Giảm mỡ & cải thiện tư thế · Gói 8 buổi',
      note: 'Người mới bắt đầu, cần hướng dẫn kỹ thuật cơ bản.',
      timeAgo: '2 giờ trước',
    ),
  ];

  final List<_CoachMemberItem> _members = const [
    _CoachMemberItem(
      id: 'm1',
      name: 'Nguyễn Minh Tuấn',
      initials: 'MT',
      packageName: 'Gói Coach 12 buổi',
      remainingSessions: 7,
      daysLeft: 18,
      goal: 'Tăng cơ · Hypertrophy',
    ),
    _CoachMemberItem(
      id: 'm2',
      name: 'Trần Thảo Vy',
      initials: 'TV',
      packageName: 'Gói Coach 8 buổi',
      remainingSessions: 4,
      daysLeft: 12,
      goal: 'Giảm mỡ · Săn chắc',
    ),
    _CoachMemberItem(
      id: 'm3',
      name: 'Phạm Quốc Bảo',
      initials: 'QB',
      packageName: 'Gói Coach 12 buổi',
      remainingSessions: 2,
      daysLeft: 4,
      goal: 'Cải thiện sức bền & vai',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _segment = widget.initialSegment;
  }

  @override
  void didUpdateWidget(covariant _CoachWorkHubView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSegment != widget.initialSegment) {
      _segment = widget.initialSegment;
    }
  }

  void _showToast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF2B2622),
          content: Text(
            message,
            style: const TextStyle(color: Color(0xFFF7F9FC), fontSize: 13),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final selectedDay = _days[_selectedDayIndex];
    final dayBookings =
        _bookings.where((b) => b.dayLabel == selectedDay).toList();

    return Stack(
      fit: StackFit.expand,
      children: [
        const _CoachGymBackground(),
        SafeArea(
          bottom: false,
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              10,
              16,
              widget.bottomPadding + 24,
            ),
            children: [
              const Text(
                'META GYM · QUẢN LÝ',
                style: TextStyle(
                  color: MetaGymTheme.brandOrange,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.3,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Lịch dạy & Học viên',
                style: TextStyle(
                  color: Color(0xFFF7F9FC),
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _SegmentPill(
                    label: 'Lịch dạy (90p)',
                    selected: _segment == 0,
                    onTap: () => setState(() => _segment = 0),
                  ),
                  const SizedBox(width: 8),
                  _SegmentPill(
                    label: 'Học viên & Yêu cầu (${_requests.length})',
                    selected: _segment == 1,
                    onTap: () => setState(() => _segment = 1),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (_segment == 0) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (var i = 0; i < _days.length; i++)
                      GestureDetector(
                        onTap: () => setState(() => _selectedDayIndex = i),
                        child: Container(
                          width: 42,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _selectedDayIndex == i
                                ? MetaGymTheme.brandOrange
                                : const Color(0xB8211C19),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _selectedDayIndex == i
                                  ? MetaGymTheme.brandOrange
                                  : const Color(0x389C9084),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            _days[i],
                            style: TextStyle(
                              color: _selectedDayIndex == i
                                  ? Colors.white
                                  : const Color(0xFFB8C2D0),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                if (dayBookings.isEmpty)
                  _CoachSmokedCard(
                    borderRadius: BorderRadius.circular(16),
                    padding: const EdgeInsets.all(20),
                    child: const Center(
                      child: Text(
                        'Chưa có ca dạy nào trong ngày này.',
                        style: TextStyle(color: Color(0xFF9BA5B4), fontSize: 13),
                      ),
                    ),
                  )
                else
                  for (final b in dayBookings)
                    _CoachSmokedCard(
                      borderRadius: BorderRadius.circular(16),
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                b.timeRange,
                                style: const TextStyle(
                                  color: MetaGymTheme.brandOrange,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                b.status == 'COMPLETED'
                                    ? 'Hoàn thành'
                                    : (b.status == 'CONFIRMED'
                                          ? 'Đã xác nhận'
                                          : 'Chờ xác nhận'),
                                style: TextStyle(
                                  color: b.status == 'COMPLETED'
                                      ? const Color(0xFF8E9AA8)
                                      : (b.status == 'CONFIRMED'
                                            ? MetaGymTheme.progressGreen
                                            : MetaGymTheme.warningAmber),
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            b.memberName,
                            style: const TextStyle(
                              color: Color(0xFFF7F9FC),
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            b.focusArea,
                            style: const TextStyle(
                              color: Color(0xFF9BA5B4),
                              fontSize: 12.5,
                            ),
                          ),
                          if (b.status != 'COMPLETED') ...[
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFFD5DEE8),
                                      side: const BorderSide(
                                        color: Color(0x409C9084),
                                      ),
                                    ),
                                    onPressed: widget.onOpenMessages,
                                    child: const Text('Nhắn tin'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: FilledButton(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: MetaGymTheme.brandOrange,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        b.status = b.status == 'PENDING'
                                            ? 'CONFIRMED'
                                            : 'COMPLETED';
                                      });
                                      _showToast('Đã cập nhật ca dạy');
                                    },
                                    child: Text(
                                      b.status == 'PENDING'
                                          ? 'Xác nhận'
                                          : 'Hoàn tất',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
              ] else ...[
                if (_requests.isNotEmpty) ...[
                  const Text(
                    'YÊU CẦU CHỌN COACH CHỜ DUYỆT',
                    style: TextStyle(
                      color: Color(0xFF9BA5B4),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final req in _requests)
                    _CoachSmokedCard(
                      featured: true,
                      borderRadius: BorderRadius.circular(16),
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: const Color(0x2EFF5A36),
                                child: Text(
                                  req.initials,
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
                                      req.memberName,
                                      style: const TextStyle(
                                        color: Color(0xFFF7F9FC),
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      req.goal,
                                      style: const TextStyle(
                                        color: Color(0xFF9BA5B4),
                                        fontSize: 11.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                req.timeAgo,
                                style: const TextStyle(
                                  color: Color(0xFF8E9AA8),
                                  fontSize: 10.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '"${req.note}"',
                            style: const TextStyle(
                              color: Color(0xFFD5DEE8),
                              fontSize: 12.5,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: MetaGymTheme.dangerCoral,
                                    side: const BorderSide(
                                      color: Color(0x4DF15B64),
                                    ),
                                  ),
                                  onPressed: () {
                                    setState(() => _requests.remove(req));
                                    _showToast('Đã từ chối yêu cầu');
                                  },
                                  child: const Text('Từ chối'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: MetaGymTheme.brandOrange,
                                  ),
                                  onPressed: () {
                                    setState(() => _requests.remove(req));
                                    _showToast(
                                      'Đã nhận học viên ${req.memberName}',
                                    );
                                  },
                                  child: const Text('Chấp nhận'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),
                ],
                const Text(
                  'HỌC VIÊN ĐANG ĐỒNG HÀNH',
                  style: TextStyle(
                    color: Color(0xFF9BA5B4),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 8),
                for (final member in _members)
                  _CoachSmokedCard(
                    borderRadius: BorderRadius.circular(16),
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: const Color(0x801E1A17),
                          child: Text(
                            member.initials,
                            style: const TextStyle(
                              color: Color(0xFFD5DEE8),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                member.name,
                                style: const TextStyle(
                                  color: Color(0xFFF7F9FC),
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${member.packageName} · Còn ${member.remainingSessions} buổi (${member.daysLeft} ngày)',
                                style: TextStyle(
                                  color: member.daysLeft <= 5
                                      ? MetaGymTheme.warningAmber
                                      : const Color(0xFF9BA5B4),
                                  fontSize: 11.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                member.goal,
                                style: const TextStyle(
                                  color: Color(0xFF8E9AA8),
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Nhắn tin',
                          onPressed: widget.onOpenMessages,
                          icon: const Icon(
                            Icons.chat_bubble_outline_rounded,
                            color: MetaGymTheme.brandOrange,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// Shared Smoked Glass Components (đồng bộ Member Home)
// =============================================================================

class _CoachGymBackground extends StatelessWidget {
  const _CoachGymBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: MetaGymTheme.darkCanvas),
        if (!MetaGymTheme.isFlutterTestEnvironment)
          Opacity(
            opacity: 0.72,
            child: Image.asset(
              'assets/images/gym_banner.png',
              fit: BoxFit.cover,
              alignment: const Alignment(0, -0.25),
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xD90E0C0A),
                Color(0x9E14110E),
                Color(0xF00B0A08),
              ],
              stops: [0.0, 0.45, 1.0],
            ),
          ),
        ),
      ],
    );
  }
}

class _CoachSmokedCard extends StatelessWidget {
  const _CoachSmokedCard({
    required this.child,
    this.borderRadius,
    this.padding,
    this.margin,
    this.featured = false,
  });

  final Widget child;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final bool featured;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(MetaGymTheme.radiusCard);
    final enableBlur = featured && !MetaGymTheme.isFlutterTestEnvironment;

    final body = Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: featured ? const Color(0xB325201C) : const Color(0xB8211C19),
        borderRadius: radius,
        border: Border.all(
          color: featured ? const Color(0x4DA79D92) : const Color(0x2E9C9084),
          width: 0.85,
        ),
      ),
      child: Stack(
        children: [
          if (featured)
            const Positioned(
              top: 0,
              left: 18,
              right: 18,
              height: 1,
              child: ColoredBox(color: Color(0x45FFF6EA)),
            ),
          if (padding != null) Padding(padding: padding!, child: child) else child,
        ],
      ),
    );

    final result = enableBlur
        ? RepaintBoundary(
            child: ClipRRect(
              borderRadius: radius,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: body,
              ),
            ),
          )
        : body;

    if (margin != null) {
      return Padding(padding: margin!, child: result);
    }
    return result;
  }
}

class _CoachCircleButton extends StatelessWidget {
  const _CoachCircleButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xA6231F1C),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0x529C9084), width: 1.0),
            ),
            child: Icon(icon, color: const Color(0xFFF7F9FC), size: 19),
          ),
        ),
      ),
    );
  }
}

class _CoachHeroMetric extends StatelessWidget {
  const _CoachHeroMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFF9BA5B4), fontSize: 10.5),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFFF7F9FC),
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _CoachQuickAction extends StatelessWidget {
  const _CoachQuickAction({
    required this.icon,
    required this.accent,
    required this.label,
    required this.onTap,
    this.badgeText,
  });

  final IconData icon;
  final Color accent;
  final String label;
  final VoidCallback onTap;
  final String? badgeText;

  @override
  Widget build(BuildContext context) {
    return _CoachSmokedCard(
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: accent, size: 18),
                  ),
                  if (badgeText != null)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: MetaGymTheme.brandOrange,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          badgeText!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 7),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFFF7F9FC),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CoachMenuRow extends StatelessWidget {
  const _CoachMenuRow({
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: accent, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFFF7F9FC),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF9BA5B4),
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF7B8794),
              size: 19,
            ),
          ],
        ),
      ),
    );
  }
}

class _SegmentPill extends StatelessWidget {
  const _SegmentPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: selected ? const Color(0x2EFF5A36) : const Color(0xA6231F1C),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? MetaGymTheme.brandOrange
                : const Color(0x4D9C9084),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: selected ? const Color(0xFFF7F9FC) : const Color(0xFFB8C2D0),
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _CoachModalSheet extends StatelessWidget {
  const _CoachModalSheet({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 22),
      decoration: const BoxDecoration(
        color: Color(0xFF211D1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: Color(0x669C9084), width: 1.0)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0x529C9084),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFFF7F9FC),
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: const TextStyle(color: Color(0xFF9BA5B4), fontSize: 12.5),
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}
