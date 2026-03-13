import 'package:flutter/material.dart';

import '../../domain/task_models.dart';
import 'card_layout.dart';
import 'item_icon_picker_sheet.dart';

class _TaskDragPayload {
  const _TaskDragPayload({
    required this.taskId,
  });

  final String taskId;
}

class TaskListView extends StatelessWidget {
  const TaskListView({
    super.key,
    required this.tasks,
    required this.emptyLabel,
    required this.cardLayoutPreset,
    required this.onTaskTap,
    required this.onTaskOptionsTap,
    required this.onMoveTaskToProject,
    required this.onRemoveTask,
    required this.onMoveTask,
    required this.onNestTask,
  });

  final List<TaskItem> tasks;
  final String emptyLabel;
  final CardLayoutPreset cardLayoutPreset;
  final Future<void> Function(String) onTaskTap;
  final Future<void> Function(String) onTaskOptionsTap;
  final Future<void> Function(String) onMoveTaskToProject;
  final void Function(String) onRemoveTask;
  final void Function({
    required String taskId,
    required int targetIndex,
  }) onMoveTask;
  final void Function({
    required String sourceTaskId,
    required String targetTaskId,
  }) onNestTask;

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
    TaskItem task,
    Future<void> Function() onOptionsTap,
  ) {
    final List<Widget> parts = <Widget>[
      if (task.subtasks.isNotEmpty)
        _buildSubtaskCountIndicator(context, task.subtasks.length),
      if (task.body.isNotEmpty) _buildContentIndicator(),
      IconButton(
        tooltip: 'Task options',
        onPressed: onOptionsTap,
        icon: const Icon(Icons.more_vert),
      ),
    ];

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

  Widget _buildDropSlot(
    BuildContext context, {
    required int targetIndex,
    required double inactiveHeight,
  }) {
    return DragTarget<_TaskDragPayload>(
      onWillAcceptWithDetails: (
        DragTargetDetails<_TaskDragPayload> details,
      ) {
        return true;
      },
      onAcceptWithDetails: (DragTargetDetails<_TaskDragPayload> details) {
        onMoveTask(taskId: details.data.taskId, targetIndex: targetIndex);
      },
      builder: (
        BuildContext context,
        List<_TaskDragPayload?> candidateData,
        List<dynamic> rejectedData,
      ) {
        final bool isActiveDropTarget = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: isActiveDropTarget ? 22 : inactiveHeight,
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: isActiveDropTarget
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.22)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
        );
      },
    );
  }

  Widget _buildTaskTile(
    BuildContext context,
    TaskItem task, {
    required CardLayoutSpec layout,
    required bool isDropTarget,
  }) {
    final TextStyle? titleStyle =
        Theme.of(context).textTheme.titleMedium?.copyWith(
              fontSize:
                  (Theme.of(context).textTheme.titleMedium?.fontSize ?? 16) *
                      layout.titleScale,
            );
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: isDropTarget
            ? Border.all(
                color: Theme.of(context).colorScheme.primary,
                width: 2,
              )
            : null,
      ),
      child: Card(
        color: task.colorValue == null ? null : Color(task.colorValue!),
        child: ListTile(
          contentPadding: layout.contentPadding,
          leading: _buildLeading(task),
          title: Text(
            task.title,
            style: titleStyle,
            maxLines: null,
          ),
          trailing: _buildTrailing(
            context,
            task,
            () => onTaskOptionsTap(task.id),
          ),
          onTap: () async => onTaskTap(task.id),
        ),
      ),
    );
  }

  Widget _buildDraggableTaskCard(
    BuildContext context,
    TaskItem task, {
    required CardLayoutSpec layout,
  }) {
    return DragTarget<_TaskDragPayload>(
      onWillAcceptWithDetails: (
        DragTargetDetails<_TaskDragPayload> details,
      ) {
        return details.data.taskId != task.id;
      },
      onAcceptWithDetails: (DragTargetDetails<_TaskDragPayload> details) {
        onNestTask(
          sourceTaskId: details.data.taskId,
          targetTaskId: task.id,
        );
      },
      builder: (
        BuildContext context,
        List<_TaskDragPayload?> candidateData,
        List<dynamic> rejectedData,
      ) {
        final bool isDropTarget = candidateData.isNotEmpty;
        final Widget tile = _buildTaskTile(
          context,
          task,
          layout: layout,
          isDropTarget: isDropTarget,
        );
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
            margin: EdgeInsets.only(bottom: layout.listBottomSpacing),
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
            margin: EdgeInsets.only(bottom: layout.listBottomSpacing),
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
            padding: EdgeInsets.only(bottom: layout.listBottomSpacing),
            child: LongPressDraggable<_TaskDragPayload>(
              data: _TaskDragPayload(taskId: task.id),
              feedback: Material(
                color: Colors.transparent,
                child: SizedBox(
                  width: MediaQuery.sizeOf(context).width - 24,
                  child: _buildTaskTile(
                    context,
                    task,
                    layout: layout,
                    isDropTarget: false,
                  ),
                ),
              ),
              childWhenDragging: Opacity(
                opacity: 0.35,
                child: tile,
              ),
              child: tile,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final CardLayoutSpec layout = cardLayoutSpecForPreset(cardLayoutPreset);

    if (tasks.isEmpty) {
      return Center(child: Text(emptyLabel));
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: <Widget>[
        _buildDropSlot(
          context,
          targetIndex: 0,
          inactiveHeight: 0,
        ),
        for (int i = 0; i < tasks.length; i++) ...<Widget>[
          _buildDraggableTaskCard(
            context,
            tasks[i],
            layout: layout,
          ),
          _buildDropSlot(
            context,
            targetIndex: i + 1,
            inactiveHeight: 4,
          ),
        ],
      ],
    );
  }
}
