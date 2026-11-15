import 'package:flutter/material.dart';
import 'package:meta_gym_app/features/training/data/member_training_service.dart';
import 'package:meta_gym_app/features/training/presentation/member_curriculum_detail_page.dart';
import 'package:provider/provider.dart';

/// Entry point for the Member's current Coach curriculum.
///
/// The detail layout also owns the empty state when the Coach has not yet
/// published a plan. Gym attendance belongs to the Training hub, not here.
class MemberTrainingPage extends StatelessWidget {
  const MemberTrainingPage({this.service, this.bottomPadding, super.key});

  final MemberTrainingService? service;
  final double? bottomPadding;

  @override
  Widget build(BuildContext context) => MemberCurriculumDetailPage(
    service: service ?? context.read<MemberTrainingService>(),
  );
}
