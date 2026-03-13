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

class TaskListView extends StatefulWidget {
  const TaskListView({
    super.key,
    this.header,
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

  final Widget? header;
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

  @override
  State<TaskListView> createState() => _TaskListViewState();
}

class _TaskListViewState extends State<TaskListView> {
  final Set<String> _expandedTaskIds = <String>{};
  final Set<String> _expandedPreviewSubtaskIds = <String>{};

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

  void _toggleTaskExpanded(String taskId) {
    setState(() {
      if (_expandedTaskIds.contains(taskId)) {
        _expandedTaskIds.remove(taskId);
      } else {
        _expandedTaskIds.add(taskId);
      }
    });
  }

  void _togglePreviewSubtaskExpanded(String subTaskId) {
    setState(() {
      if (_expandedPreviewSubtaskIds.contains(subTaskId)) {
        _expandedPreviewSubtaskIds.remove(subTaskId);
      } else {
        _expandedPreviewSubtaskIds.add(subTaskId);
      }
    });
  }

  Widget _buildPreviewSubtaskList(List<SubTaskItem> items, int depth) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: items
          .map(
            (SubTaskItem item) => _buildPreviewSubtaskNode(item, depth),
          )
          .toList(growable: false),
    );
  }

  Widget _buildPreviewSubtaskNode(SubTaskItem subTask, int depth) {
    final bool hasChildren = subTask.children.isNotEmpty;
    final bool isExpanded = _expandedPreviewSubtaskIds.contains(subTask.id);
    final IconData? iconData = iconDataForKey(subTask.iconKey);
    final List<Widget> trailingParts = <Widget>[
      if (subTask.body.isNotEmpty)
        const Tooltip(
          message: 'Has text content',
          child: Icon(
            Icons.notes_outlined,
            size: 18,
          ),
        ),
      if (iconData != null)
        Icon(
          iconData,
          size: 18,
        ),
    ];

    return Padding(
      padding: EdgeInsets.only(left: depth * 18.0, top: 4),
      child: Column(
        children: <Widget>[
          Card(
            margin: EdgeInsets.zero,
            color:
                subTask.colorValue == null ? null : Color(subTask.colorValue!),
            child: ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 2,
              ),
              leading: hasChildren
                  ? IconButton(
                      onPressed: () =>
                          _togglePreviewSubtaskExpanded(subTask.id),
                      tooltip: isExpanded
                          ? 'Collapse nested ideas'
                          : 'Expand nested ideas',
                      icon: Icon(
                        isExpanded
                            ? Icons.expand_more_outlined
                            : Icons.chevron_right_outlined,
                      ),
                    )
                  : Icon(
                      iconData ?? Icons.subdirectory_arrow_right_outlined,
                      size: 20,
                    ),
              title: Text(
                subTask.title,
                maxLines: null,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              subtitle: subTask.body.isEmpty
                  ? null
                  : Text(
                      subTask.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
              trailing: trailingParts.isEmpty
                  ? null
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        for (int i = 0;
                            i < trailingParts.length;
                            i++) ...<Widget>[
                          if (i > 0) const SizedBox(width: 8),
                          trailingParts[i],
                        ],
                      ],
                    ),
            ),
          ),
          if (hasChildren && isExpanded)
            _buildPreviewSubtaskList(subTask.children, depth + 1),
        ],
      ),
    );
  }

  Widget? _buildTrailing(
    BuildContext context,
    TaskItem task,
    Future<void> Function() onOptionsTap,
  ) {
    final bool hasSubtasks = task.subtasks.isNotEmpty;
    final bool isExpanded = _expandedTaskIds.contains(task.id);
    final List<Widget> parts = <Widget>[
      if (hasSubtasks)
        IconButton(
          onPressed: () => _toggleTaskExpanded(task.id),
          tooltip: isExpanded ? 'Collapse subtasks' : 'Expand subtasks',
          icon: Icon(
            isExpanded
                ? Icons.expand_more_outlined
                : Icons.chevron_right_outlined,
          ),
        ),
      if (hasSubtasks)
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
        widget.onMoveTask(
          taskId: details.data.taskId,
          targetIndex: targetIndex,
        );
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
    bool showExpandedPreview = true,
  }) {
    final bool hasSubtasks = task.subtasks.isNotEmpty;
    final bool isExpanded = _expandedTaskIds.contains(task.id);
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
      child: Column(
        children: <Widget>[
          Card(
            margin: EdgeInsets.zero,
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
                () => widget.onTaskOptionsTap(task.id),
              ),
              onTap: () async => widget.onTaskTap(task.id),
            ),
          ),
          if (showExpandedPreview && hasSubtasks && isExpanded)
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 8, bottom: 8),
              child: _buildPreviewSubtaskList(task.subtasks, 0),
            ),
        ],
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
        _expandedTaskIds.add(task.id);
        widget.onNestTask(
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
              await widget.onMoveTaskToProject(task.id);
              return false;
            }
            return true;
          },
          onDismissed: (_) => widget.onRemoveTask(task.id),
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
                    showExpandedPreview: false,
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
    final CardLayoutSpec layout =
        cardLayoutSpecForPreset(widget.cardLayoutPreset);
    return ListView(
      padding: const EdgeInsets.all(12),
      children: <Widget>[
        if (widget.header != null) ...<Widget>[
          widget.header!,
          const SizedBox(height: 12),
        ],
        if (widget.tasks.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(child: Text(widget.emptyLabel)),
          )
        else ...<Widget>[
          _buildDropSlot(
            context,
            targetIndex: 0,
            inactiveHeight: 0,
          ),
          for (int i = 0; i < widget.tasks.length; i++) ...<Widget>[
            _buildDraggableTaskCard(
              context,
              widget.tasks[i],
              layout: layout,
            ),
            _buildDropSlot(
              context,
              targetIndex: i + 1,
              inactiveHeight: 4,
            ),
          ],
        ],
      ],
    );
  }
}
