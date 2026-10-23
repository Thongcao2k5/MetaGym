import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:meta_gym_app/app/app_router.dart';
import 'package:meta_gym_app/features/catalog/presentation/catalog_page.dart';
import 'package:meta_gym_app/features/membership/presentation/membership_page.dart';
import 'package:meta_gym_app/features/workbench/flow_workbench_config.dart';

class MemberHomePage extends StatefulWidget {
  const MemberHomePage({super.key});

  @override
  State<MemberHomePage> createState() => _MemberHomePageState();
}

class _MemberHomePageState extends State<MemberHomePage> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Không gian dành cho hội viên'),
            const SizedBox(height: 16),
            if (FlowWorkbenchConfig.enabled)
              FilledButton(
                onPressed: () => context.push(AppRoutes.memberWorkbench),
                child: const Text('Kiểm thử các luồng hội viên'),
              ),
          ],
        ),
      ),
      const CatalogPage(),
      const MembershipPage(),
      Center(
        child: FilledButton(
          onPressed: () => context.push(AppRoutes.profile),
          child: const Text('Mở hồ sơ của tôi'),
        ),
      ),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Meta Gym')),
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            label: 'Trang chủ',
          ),
          NavigationDestination(
            icon: Icon(Icons.fitness_center),
            label: 'Khám phá',
          ),
          NavigationDestination(
            icon: Icon(Icons.card_membership),
            label: 'Gói tập',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Hồ sơ',
          ),
        ],
      ),
    );
  }
}
