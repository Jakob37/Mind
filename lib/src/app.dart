import 'package:flutter/material.dart';

import 'features/tasks/presentation/task_page.dart';

class SortedOutApp extends StatelessWidget {
  const SortedOutApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sorted Out',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const TaskPage(),
    );
  }
}
