import 'package:flutter/material.dart';

import '../../domain/task_models.dart';

class TaskListView extends StatelessWidget {
  const TaskListView({
    super.key,
    required this.tasks,
    required this.emptyLabel,
    required this.primaryIcon,
    required this.isReorderMode,
    required this.onEnterReorderMode,
    required this.onReorder,
    required this.onTaskTap,
    required this.onPrimaryAction,
  });

  final List<TaskItem> tasks;
  final String emptyLabel;
  final IconData primaryIcon;
  final bool isReorderMode;
  final VoidCallback onEnterReorderMode;
  final void Function(int oldIndex, int newIndex) onReorder;
  final Future<void> Function(String) onTaskTap;
  final Future<void> Function(String) onPrimaryAction;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return Center(child: Text(emptyLabel));
    }

    if (isReorderMode) {
      return ReorderableListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: tasks.length,
        onReorder: onReorder,
        buildDefaultDragHandles: false,
        itemBuilder: (BuildContext context, int index) {
          final TaskItem task = tasks[index];
          return Padding(
            key: ValueKey<String>(task.id),
            padding: const EdgeInsets.only(bottom: 4),
            child: Card(
              color: task.colorValue == null ? null : Color(task.colorValue!),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                title: Text(
                  task.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                subtitle: task.body.isEmpty
                    ? null
                    : Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(task.body),
                      ),
                trailing: ReorderableDragStartListener(
                  index: index,
                  child: const Icon(Icons.drag_indicator_outlined),
                ),
              ),
            ),
          );
        },
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: tasks.length,
      itemBuilder: (BuildContext context, int index) {
        final TaskItem task = tasks[index];
        return Dismissible(
          key: ValueKey<String>('task-swipe-${task.id}'),
          direction: DismissDirection.startToEnd,
          confirmDismiss: (_) async {
            await onPrimaryAction(task.id);
            return false;
          },
          background: Container(
            margin: const EdgeInsets.only(bottom: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Icon(
              primaryIcon,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Card(
              color: task.colorValue == null ? null : Color(task.colorValue!),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                title: Text(
                  task.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                subtitle: task.body.isEmpty
                    ? null
                    : Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(task.body),
                      ),
                onTap: () async => onTaskTap(task.id),
                onLongPress: onEnterReorderMode,
              ),
            ),
          ),
        );
      },
    );
  }
}
