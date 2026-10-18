import 'package:flutter/material.dart';

void main() {
  runApp(const MetaGymApp());
}

class MetaGymApp extends StatelessWidget {
  const MetaGymApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Meta Gym',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.fitness_center, size: 56),
              SizedBox(height: 16),
              Text('Meta Gym', style: TextStyle(fontSize: 28)),
              SizedBox(height: 8),
              Text('Khung ứng dụng đã sẵn sàng để phát triển.'),
            ],
          ),
        ),
      ),
    );
  }
}
