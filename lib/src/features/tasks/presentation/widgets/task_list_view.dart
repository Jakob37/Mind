import 'package:flutter/material.dart';

import '../../domain/task_models.dart';
import 'item_icon_picker_sheet.dart';

class TaskListView extends StatelessWidget {
  const TaskListView({
    super.key,
    required this.tasks,
    required this.emptyLabel,
    required this.isReorderMode,
    required this.onReorder,
    required this.onTaskTap,
    required this.onTaskLongPress,
    required this.onMoveTaskToProject,
    required this.onRemoveTask,
  });

  final List<TaskItem> tasks;
  final String emptyLabel;
  final bool isReorderMode;
  final void Function(int oldIndex, int newIndex) onReorder;
  final Future<void> Function(String) onTaskTap;
  final Future<void> Function(String) onTaskLongPress;
  final Future<void> Function(String) onMoveTaskToProject;
  final void Function(String) onRemoveTask;

  Widget? _buildLeading(TaskItem task) {
    final IconData? iconData = iconDataForKey(task.iconKey);
    if (iconData == null) {
      return null;
    }
    return Icon(iconData);
  }

  Widget _buildContentIndicator() {
    return const Tooltip(
      message: 'Has text content',
      child: Icon(
        Icons.notes_outlined,
        size: 18,
      ),
    );
  }

  Widget _buildSubtaskCountIndicator(BuildContext context, int count) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: count == 1 ? '1 subtask' : '$count subtasks',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          '$count',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colorScheme.onSecondaryContainer,
                fontWeight: FontWeight.w600,
              ),
        ),
      ),
    );
  }

  Widget? _buildTrailing(
    BuildContext context,
    TaskItem task, {
    Widget? trailing,
  }) {
    final List<Widget> parts = <Widget>[
      if (task.subtasks.isNotEmpty)
        _buildSubtaskCountIndicator(context, task.subtasks.length),
      if (task.body.isNotEmpty) _buildContentIndicator(),
      if (trailing != null) trailing,
    ];

    if (parts.isEmpty) {
      return null;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int i = 0; i < parts.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(width: 8),
          parts[i],
        ],
      ],
    );
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
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: Card(
              color: task.colorValue == null ? null : Color(task.colorValue!),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                leading: _buildLeading(task),
                title: Text(
                  task.title,
                  style: Theme.of(context).textTheme.titleMedium,
                  maxLines: null,
                ),
                trailing: _buildTrailing(
                  context,
                  task,
                  trailing: ReorderableDragStartListener(
                    index: index,
                    child: const Icon(Icons.drag_indicator_outlined),
                  ),
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
          direction: DismissDirection.horizontal,
          confirmDismiss: (DismissDirection direction) async {
            if (direction == DismissDirection.startToEnd) {
              await onMoveTaskToProject(task.id);
              return false;
            }
            return true;
          },
          onDismissed: (_) => onRemoveTask(task.id),
          background: Container(
            margin: const EdgeInsets.only(bottom: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Icon(
              Icons.drive_file_move_outlined,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
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
                leading: _buildLeading(task),
                title: Text(
                  task.title,
                  style: Theme.of(context).textTheme.titleMedium,
                  maxLines: null,
                ),
                trailing: _buildTrailing(context, task),
                onTap: () async => onTaskTap(task.id),
                onLongPress: () async => onTaskLongPress(task.id),
              ),
            ),
          ),
        );
      },
    );
  }
}
