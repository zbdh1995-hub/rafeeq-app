import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'رَفيق AI',
      home: Scaffold(
        appBar: AppBar(title: const Text('رَفيق AI')),
        body: const Center(
          child: Text('التطبيق يعمل بنجاح!', style: TextStyle(fontSize: 24)),
        ),
      ),
    );
  }
}