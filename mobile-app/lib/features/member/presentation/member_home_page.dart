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

    // 5 tabs in exact order: Trang chủ · Tập luyện · AI · Tin nhắn · Hồ sơ
    final pages = [
      MemberDashboardView(
        onNavigateTab: (index) => setState(() => _index = index),
        bottomPadding: MetaGymBottomNav.contentBottomPadding(context),
      ),
      const MemberTrainingPage(),
      const AiConversationsPage(),
      ConversationsPage(currentUserId: currentUserId),
      const ProfilePage(),
    ];

    return RepaintBoundary(
      child: Scaffold(
        extendBody: _index == 0,
        backgroundColor: _index == 0
            ? MetaGymTheme.darkCanvas
            : Theme.of(context).scaffoldBackgroundColor,
        body: IndexedStack(index: _index, children: pages),
        bottomNavigationBar: MetaGymBottomNav(
          currentIndex: _index,
          onTap: (value) => setState(() => _index = value),
        ),
      ),
    );
  }
}
