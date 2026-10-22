import 'package:flutter/material.dart';

class MemberHomePage extends StatelessWidget {
  const MemberHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Member')),
      body: const Center(child: Text('Không gian dành cho hội viên')),
    );
  }
}
