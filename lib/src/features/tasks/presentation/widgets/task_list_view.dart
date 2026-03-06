import 'package:flutter/material.dart';

import '../../domain/task_models.dart';

class TaskListView extends StatelessWidget {
  const TaskListView({
    super.key,
    required this.tasks,
    required this.emptyLabel,
    required this.primaryIcon,
    required this.primaryTooltip,
    required this.onPrimaryAction,
    required this.onDelete,
  });

  final List<TaskItem> tasks;
  final String emptyLabel;
  final IconData primaryIcon;
  final String primaryTooltip;
  final Future<void> Function(String) onPrimaryAction;
  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return Center(child: Text(emptyLabel));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: tasks.length,
      itemBuilder: (BuildContext context, int index) {
        final TaskItem task = tasks[index];
        return Dismissible(
          key: ValueKey<String>(task.id),
          direction: DismissDirection.endToStart,
          background: Container(
            margin: const EdgeInsets.only(bottom: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Icon(
              Icons.delete_outline,
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
          ),
          onDismissed: (_) => onDelete(task.id),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Card(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                title: Text(
                  task.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                trailing: IconButton(
                  icon: Icon(primaryIcon),
                  onPressed: () async => onPrimaryAction(task.id),
                  tooltip: primaryTooltip,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
