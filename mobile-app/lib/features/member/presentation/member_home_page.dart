import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_bottom_nav.dart';
import 'package:meta_gym_app/features/ai/presentation/ai_conversations_page.dart';
import 'package:meta_gym_app/features/auth/presentation/session_controller.dart';
import 'package:meta_gym_app/features/member/presentation/member_dashboard_view.dart';
import 'package:meta_gym_app/features/messaging/presentation/conversations_page.dart';
import 'package:meta_gym_app/features/profile/presentation/profile_page.dart';
import 'package:meta_gym_app/features/training/presentation/member_training_page.dart';
import 'package:provider/provider.dart';

class MemberHomePage extends StatefulWidget {
  const MemberHomePage({super.key});

  @override
  State<MemberHomePage> createState() => _MemberHomePageState();
}

class _MemberHomePageState extends State<MemberHomePage> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final currentUserId = context.watch<SessionController>().user?.id ?? '';
    final bottomPadding = MetaGymBottomNav.contentBottomPadding(context);

    // 5 tabs in exact order: Trang chủ · Tập luyện · AI · Tin nhắn · Hồ sơ
    final pages = [
      MemberDashboardView(
        onNavigateTab: (index) => setState(() => _index = index),
        bottomPadding: bottomPadding,
      ),
      MemberTrainingPage(bottomPadding: bottomPadding),
      const AiConversationsPage(),
      ConversationsPage(
        currentUserId: currentUserId,
        bottomPadding: bottomPadding,
      ),
      ProfilePage(bottomPadding: bottomPadding),
    ];

    return RepaintBoundary(
      child: Scaffold(
        extendBody: true,
        backgroundColor: MetaGymTheme.darkCanvas,
        body: IndexedStack(index: _index, children: pages),
        bottomNavigationBar: MetaGymBottomNav(
          currentIndex: _index,
          onTap: (value) => setState(() => _index = value),
        ),
      ),
    );
  }
}
