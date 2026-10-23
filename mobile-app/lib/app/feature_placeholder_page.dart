import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:meta_gym_app/app/feature_navigation.dart';

class FeaturePlaceholderPage extends StatelessWidget {
  const FeaturePlaceholderPage({
    required this.destination,
    required this.homePath,
    super.key,
  });

  final FeatureDestination destination;
  final String homePath;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(destination.title)),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              destination.title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text('Trang nghiệp vụ ${destination.task} chưa được triển khai.'),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => context.go(homePath),
              child: const Text('Về trang chính'),
            ),
          ],
        ),
      ),
    ),
  );
}
