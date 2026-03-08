import 'package:flutter/material.dart';

import '../../domain/task_models.dart';

enum TaskDetailAction {
  edit,
  setColor,
  moveToProject,
  moveToThinking,
  moveToPlanning,
  remove,
}

class TaskDetailMenuItem {
  const TaskDetailMenuItem({
    required this.action,
    required this.icon,
    required this.label,
  });

  final TaskDetailAction action;
  final IconData icon;
  final String label;
}

class TaskDetailPage extends StatelessWidget {
  const TaskDetailPage({
    super.key,
    required this.task,
    required this.menuItems,
  });

  final TaskItem task;
  final List<TaskDetailMenuItem> menuItems;

  Future<void> _openTaskMenu(BuildContext context) async {
    final TaskDetailAction? selectedAction =
        await showModalBottomSheet<TaskDetailAction>(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: <Widget>[
              ListTile(
                title: Text(
                  task.title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Task options'),
              ),
              const Divider(height: 1),
              for (final TaskDetailMenuItem item in menuItems)
                ListTile(
                  leading: Icon(item.icon),
                  title: Text(item.label),
                  onTap: () => Navigator.of(context).pop(item.action),
                ),
            ],
          ),
        );
      },
    );

    if (selectedAction == null || !context.mounted) {
      return;
    }

    Navigator.of(context).pop(selectedAction);
  }

  @override
  Widget build(BuildContext context) {
    final bool hasBody = task.body.trim().isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Task'),
        actions: <Widget>[
          IconButton(
            onPressed: () => _openTaskMenu(context),
            tooltip: 'Task options',
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Text(
            task.title,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          if (hasBody)
            Text(
              task.body,
              style: Theme.of(context).textTheme.bodyLarge,
            )
          else
            Text(
              'No details added yet.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
        ],
      ),
    );
  }
}
