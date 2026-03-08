import 'package:flutter/material.dart';

import '../../domain/task_models.dart';

class TaskListView extends StatelessWidget {
  const TaskListView({
    super.key,
    required this.tasks,
    required this.emptyLabel,
    required this.isReorderMode,
    required this.onEnterReorderMode,
    required this.onReorder,
    required this.onTaskTap,
    required this.onRemoveTask,
  });

  final List<TaskItem> tasks;
  final String emptyLabel;
  final bool isReorderMode;
  final VoidCallback onEnterReorderMode;
  final void Function(int oldIndex, int newIndex) onReorder;
  final Future<void> Function(String) onTaskTap;
  final void Function(String) onRemoveTask;

  Widget _buildContentIndicator() {
    return const Tooltip(
      message: 'Has text content',
      child: Icon(
        Icons.notes_outlined,
        size: 18,
      ),
    );
  }

  Future<bool> _confirmTaskRemoval(BuildContext context) async {
    final bool? shouldRemove = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Remove task?'),
          content: const Text('This action cannot be undone.'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );
    return shouldRemove ?? false;
  }

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
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (task.body.isNotEmpty) _buildContentIndicator(),
                    ReorderableDragStartListener(
                      index: index,
                      child: const Icon(Icons.drag_indicator_outlined),
                    ),
                  ],
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
          direction: DismissDirection.endToStart,
          confirmDismiss: (_) => _confirmTaskRemoval(context),
          onDismissed: (_) => onRemoveTask(task.id),
          background: Container(),
          secondaryBackground: Container(
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
                trailing: task.body.isEmpty ? null : _buildContentIndicator(),
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
