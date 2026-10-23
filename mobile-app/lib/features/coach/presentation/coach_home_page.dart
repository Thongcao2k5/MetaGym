import 'package:flutter/material.dart';
import 'package:meta_gym_app/app/app_router.dart';
import 'package:meta_gym_app/app/feature_navigation.dart';
import 'package:meta_gym_app/features/workbench/flow_workbench_config.dart';

class CoachHomePage extends StatelessWidget {
  const CoachHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Coach')),
      body: FeatureMenu(
        heading: 'Không gian dành cho huấn luyện viên',
        destinations: coachDestinations,
        profilePath: AppRoutes.profile,
        workbenchPath: FlowWorkbenchConfig.enabled
            ? AppRoutes.coachWorkbench
            : null,
      ),
    );
  }
}
