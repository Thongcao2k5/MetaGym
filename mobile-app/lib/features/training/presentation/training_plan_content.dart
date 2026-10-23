import 'package:flutter/material.dart';
import 'package:meta_gym_app/features/training/domain/training_models.dart';

class TrainingPlanContent extends StatelessWidget {
  const TrainingPlanContent({required this.plan, super.key});

  final TrainingPlan plan;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(plan.title, style: Theme.of(context).textTheme.titleLarge),
      Text('${plan.statusLabel} · Phiên bản ${plan.version}'),
      if (plan.goal?.isNotEmpty == true) Text('Mục tiêu: ${plan.goal}'),
      if (plan.startDate != null) Text('Bắt đầu: ${plan.startDate}'),
      if (plan.endDate != null) Text('Kết thúc: ${plan.endDate}'),
      if (plan.publishedAt != null) Text('Công bố: ${plan.publishedAt}'),
      const SizedBox(height: 16),
      for (final day in plan.days) ...[
        Text(
          'Ngày ${day.dayNumber}: ${day.title}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (day.notes?.isNotEmpty == true) Text(day.notes!),
        if (day.exercises.isEmpty) const Text('Chưa có bài tập.'),
        for (final exercise in day.exercises)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(exercise.exerciseName),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (exercise.prescription.isNotEmpty)
                  Text(exercise.prescription),
                if (exercise.weightGuidance?.isNotEmpty == true)
                  Text('Mức tạ: ${exercise.weightGuidance}'),
                if (exercise.instructions?.isNotEmpty == true)
                  Text(exercise.instructions!),
                if (exercise.safetyNotes?.isNotEmpty == true)
                  Text('Lưu ý an toàn: ${exercise.safetyNotes}'),
                if (exercise.notes?.isNotEmpty == true) Text(exercise.notes!),
              ],
            ),
          ),
        const SizedBox(height: 16),
      ],
    ],
  );
}
