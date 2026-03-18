import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/task_models.dart';

String taskTextForClipboard(TaskItem task) {
  final String title = task.title.trim();
  final String body = task.body.trim();
  final String prompt = task.prompt.trim();

  return <String>[
    if (title.isNotEmpty) title,
    if (body.isNotEmpty) body,
    if (prompt.isNotEmpty) 'Prompt:\n$prompt',
  ].join('\n\n');
}

Future<void> copyTaskTextToClipboard(
  BuildContext context,
  TaskItem task,
) async {
  await Clipboard.setData(
    ClipboardData(text: taskTextForClipboard(task)),
  );

  if (!context.mounted) {
    return;
  }

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      const SnackBar(content: Text('Task text copied.')),
    );
}
