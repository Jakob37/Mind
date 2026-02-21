import 'package:flutter/material.dart';

import 'features/counter/presentation/counter_page.dart';

class SortedOutApp extends StatelessWidget {
  const SortedOutApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sorted Out',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const CounterPage(),
    );
  }
}
