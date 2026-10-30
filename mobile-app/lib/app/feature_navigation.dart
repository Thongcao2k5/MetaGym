import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class FeatureDestination {
  const FeatureDestination(this.title, this.path, this.task, this.section);

  final String title;
  final String path;
  final String task;
  final String section;
}

const memberDestinations = <FeatureDestination>[
  FeatureDestination(
    'Gói tập',
    '/member/features/membership',
    'UI02',
    'Tài khoản',
  ),
  FeatureDestination(
    'Lịch sử thanh toán',
    '/member/features/payments',
    'UI02',
    'Tài khoản',
  ),
  FeatureDestination(
    'Phòng gym và thiết bị',
    '/member/features/gym',
    'UI03',
    'Khám phá',
  ),
  FeatureDestination(
    'Chọn Coach',
    '/member/features/coaching',
    'UI04–UI05',
    'Coach',
  ),
  FeatureDestination(
    'Coach của tôi',
    '/member/features/my-coach',
    'UI05',
    'Coach',
  ),
  FeatureDestination(
    'Giáo trình',
    '/member/features/training',
    'UI08',
    'Tập luyện',
  ),
  FeatureDestination(
    'Dinh dưỡng',
    '/member/features/nutrition',
    'UI11',
    'Tập luyện',
  ),
  FeatureDestination(
    'Lịch tập',
    '/member/features/sessions',
    'UI13',
    'Tập luyện',
  ),
  FeatureDestination('Tiến độ', '/member/features/progress', 'UI15', 'Tiến độ'),
  FeatureDestination(
    'Nhật ký tập',
    '/member/features/workouts',
    'UI16',
    'Tiến độ',
  ),
  FeatureDestination('Nhật ký ăn', '/member/features/meals', 'UI17', 'Tiến độ'),
  FeatureDestination(
    'Số đo cơ thể',
    '/member/features/measurements',
    'UI18',
    'Tiến độ',
  ),
  FeatureDestination(
    'Ảnh tiến trình',
    '/member/features/photos',
    'UI19',
    'Tiến độ',
  ),
  FeatureDestination(
    'Tin nhắn',
    '/member/features/messages',
    'UI21–UI24',
    'Liên lạc',
  ),
  FeatureDestination('Cuộc gọi', '/member/features/calls', 'UI25', 'Liên lạc'),
  FeatureDestination(
    'Trợ lý AI',
    '/member/features/ai',
    'UI26–UI27',
    'Liên lạc',
  ),
];

const coachDestinations = <FeatureDestination>[
  FeatureDestination(
    'Yêu cầu chọn Coach',
    '/coach/features/requests',
    'UI06',
    'Hội viên',
  ),
  FeatureDestination(
    'Hội viên của tôi',
    '/coach/features/members',
    'UI07',
    'Hội viên',
  ),
  FeatureDestination(
    'Giáo trình',
    '/coach/features/training',
    'UI09–UI10',
    'Hướng dẫn',
  ),
  FeatureDestination(
    'Dinh dưỡng',
    '/coach/features/nutrition',
    'UI12',
    'Hướng dẫn',
  ),
  FeatureDestination(
    'Lịch tập',
    '/coach/features/sessions',
    'UI14',
    'Hướng dẫn',
  ),
  FeatureDestination(
    'Tiến độ hội viên',
    '/coach/features/progress',
    'UI20',
    'Theo dõi',
  ),
  FeatureDestination(
    'Tin nhắn',
    '/coach/features/messages',
    'UI21–UI24',
    'Liên lạc',
  ),
  FeatureDestination('Cuộc gọi', '/coach/features/calls', 'UI25', 'Liên lạc'),
  FeatureDestination(
    'Trợ lý AI',
    '/coach/features/ai',
    'UI26–UI27',
    'Liên lạc',
  ),
  FeatureDestination(
    'Phòng gym và thiết bị',
    '/coach/features/gym',
    'UI03',
    'Khám phá',
  ),
];

class FeatureMenu extends StatelessWidget {
  const FeatureMenu({
    required this.heading,
    required this.destinations,
    this.workbenchPath,
    this.profilePath,
    super.key,
  });

  final String heading;
  final List<FeatureDestination> destinations;
  final String? workbenchPath;
  final String? profilePath;

  @override
  Widget build(BuildContext context) {
    final sections = destinations.map((item) => item.section).toSet();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(heading, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        for (final section in sections) ...[
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 4),
            child: Text(
              section,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          for (final destination in destinations.where(
            (item) => item.section == section,
          ))
            ListTile(
              title: Text(destination.title),
              subtitle: Text('Giao diện cơ bản: ${destination.task}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(destination.path),
            ),
        ],
        if (profilePath != null)
          ListTile(
            title: const Text('Hồ sơ của tôi'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(profilePath!),
          ),
        if (workbenchPath != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: OutlinedButton(
              onPressed: () => context.push(workbenchPath!),
              child: Text(
                workbenchPath!.startsWith('/member')
                    ? 'Kiểm thử các luồng hội viên'
                    : 'Kiểm thử các luồng Coach',
              ),
            ),
          ),
      ],
    );
  }
}
