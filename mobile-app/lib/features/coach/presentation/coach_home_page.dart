import 'package:flutter/material.dart';

class CoachHomePage extends StatelessWidget {
  const CoachHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Coach')),
      body: const Center(child: Text('Không gian dành cho huấn luyện viên')),
    );
  }
}
