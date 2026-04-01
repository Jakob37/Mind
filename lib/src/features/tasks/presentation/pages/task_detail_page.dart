import 'package:flutter/material.dart';

import '../../domain/task_models.dart';
import '../widgets/card_layout.dart';
import '../widgets/edit_task_sheet.dart';
import '../widgets/item_color_picker_sheet.dart';
import '../widgets/item_icon_picker_sheet.dart';
import '../widgets/task_image_gallery.dart';
import '../task_text_clipboard.dart';

enum TaskDetailAction {
  edit,
  setIcon,
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

enum _SubTaskMenuAction {
  addChild,
  edit,
  setIcon,
  setColor,
  remove,
}

class _SubTaskDragPayload {
  const _SubTaskDragPayload({
    required this.subTaskId,
  });

  final String subTaskId;
}

class TaskDetailPage extends StatefulWidget {
  const TaskDetailPage({
    super.key,
    required this.task,
    required this.menuItems,
    required this.onTaskChanged,
    required this.cardLayoutPreset,
    this.colorLabels = const <int, String>{},
    this.hideCompletedProjectItems = false,
  });

  final TaskItem task;
  final List<TaskDetailMenuItem> menuItems;
  final ValueChanged<TaskItem> onTaskChanged;
  final CardLayoutPreset cardLayoutPreset;
  final Map<int, String> colorLabels;
  final bool hideCompletedProjectItems;

  @override
  State<TaskDetailPage> createState() => _TaskDetailPageState();
}

class _TaskDetailPageState extends State<TaskDetailPage> {
  late TaskItem _task;
  final Set<String> _expandedSubtaskIds = <String>{};
  String? _draggingSubTaskId;

  CardLayoutSpec get _layout =>
      cardLayoutSpecForPreset(widget.cardLayoutPreset);

  bool get _usesChecklistStyle => _task.type == TaskItemType.planning;

  @override
  void initState() {
    super.initState();
    _task = widget.task.clone();
    _seedExpandedState(_task.subtasks);
  }

  void _seedExpandedState(List<SubTaskItem> subtasks) {
    for (final SubTaskItem subtask in subtasks) {
      if (subtask.children.isNotEmpty) {
        _expandedSubtaskIds.add(subtask.id);
        _seedExpandedState(subtask.children);
      }
    }
  }

  void _applyUpdatedTask(TaskItem updatedTask) {
    setState(() {
      _task = updatedTask;
    });
    widget.onTaskChanged(_task.clone());
  }

  void _toggleExpanded(String subTaskId) {
    setState(() {
      if (_expandedSubtaskIds.contains(subTaskId)) {
        _expandedSubtaskIds.remove(subTaskId);
      } else {
        _expandedSubtaskIds.add(subTaskId);
      }
    });
  }

  TaskItem _copyTaskWithSubtasks(List<SubTaskItem> subtasks) {
    return _task.copyWith(subtasks: subtasks);
  }

  Future<void> _openTaskMenu() async {
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
                  _task.title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Task options'),
                trailing: IconButton(
                  tooltip: 'Copy task text',
                  icon: const Icon(Icons.copy_outlined),
                  onPressed: () {
                    Navigator.of(context).pop();
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      copyTaskTextToClipboard(this.context, _task);
                    });
                  },
                ),
              ),
              const Divider(height: 1),
              for (final TaskDetailMenuItem item in widget.menuItems)
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

    if (selectedAction == null || !mounted) {
      return;
    }

    Navigator.of(context).pop(selectedAction);
  }

  Future<void> _addSubTask({String? parentId}) async {
    final _SubTaskCreateResult? result =
        await showModalBottomSheet<_SubTaskCreateResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddSubTaskSheet(
        addLabel: parentId == null ? 'New nested item' : 'New child item',
      ),
    );

    if (result == null) {
      return;
    }

    if (parentId == null) {
      final List<SubTaskItem> subtasks =
          _task.subtasks.map((SubTaskItem item) => item.clone()).toList();
      if (result.insertAtTop) {
        subtasks.insert(0, result.subTask);
      } else {
        subtasks.add(result.subTask);
      }
      _applyUpdatedTask(_copyTaskWithSubtasks(subtasks));
      return;
    }

    final List<SubTaskItem> updatedSubtasks = _updateSubtaskTree(
      _task.subtasks,
      parentId,
      (SubTaskItem parent) {
        final List<SubTaskItem> children =
            parent.children.map((SubTaskItem item) => item.clone()).toList();
        if (result.insertAtTop) {
          children.insert(0, result.subTask);
        } else {
          children.add(result.subTask);
        }
        return parent.copyWith(children: children);
      },
    );
    _expandedSubtaskIds.add(parentId);
    _applyUpdatedTask(_copyTaskWithSubtasks(updatedSubtasks));
  }

  Future<_SubTaskMenuAction?> _showSubTaskMenu(SubTaskItem subTask) {
    return showModalBottomSheet<_SubTaskMenuAction>(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: <Widget>[
              ListTile(
                title: Text(
                  subTask.title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Nested item options'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.subdirectory_arrow_right_outlined),
                title: Text(_usesChecklistStyle
                    ? 'Add child checkbox'
                    : 'Add child idea'),
                onTap: () =>
                    Navigator.of(context).pop(_SubTaskMenuAction.addChild),
              ),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit item'),
                onTap: () => Navigator.of(context).pop(_SubTaskMenuAction.edit),
              ),
              ListTile(
                leading: const Icon(Icons.add_reaction_outlined),
                title: const Text('Set icon'),
                onTap: () =>
                    Navigator.of(context).pop(_SubTaskMenuAction.setIcon),
              ),
              ListTile(
                leading: const Icon(Icons.palette_outlined),
                title: const Text('Set color'),
                onTap: () =>
                    Navigator.of(context).pop(_SubTaskMenuAction.setColor),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Remove item'),
                onTap: () =>
                    Navigator.of(context).pop(_SubTaskMenuAction.remove),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _editSubTask(String subTaskId) async {
    final SubTaskItem? subTask = _findSubtask(_task.subtasks, subTaskId);
    if (subTask == null) {
      return;
    }

    final TaskEditResult? result = await showModalBottomSheet<TaskEditResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => EditTaskSheet(
        initialTitle: subTask.title,
        initialBody: subTask.body,
      ),
    );
    if (result == null) {
      return;
    }

    final List<SubTaskItem> updatedSubtasks = _updateSubtaskTree(
      _task.subtasks,
      subTaskId,
      (SubTaskItem item) => item.copyWith(
        title: result.title,
        body: result.body,
      ),
    );
    _applyUpdatedTask(_copyTaskWithSubtasks(updatedSubtasks));
  }

  Future<void> _setSubTaskColor(String subTaskId) async {
    final SubTaskItem? subTask = _findSubtask(_task.subtasks, subTaskId);
    if (subTask == null) {
      return;
    }

    final ColorSelection? selection =
        await showModalBottomSheet<ColorSelection>(
      context: context,
      builder: (_) => ItemColorPickerSheet(
        currentColorValue: subTask.colorValue,
        customLabels: widget.colorLabels,
      ),
    );
    if (selection == null) {
      return;
    }

    final List<SubTaskItem> updatedSubtasks = _updateSubtaskTree(
      _task.subtasks,
      subTaskId,
      (SubTaskItem item) => item.copyWith(
        colorValue: selection.colorValue,
        clearColor: selection.colorValue == null,
      ),
    );
    _applyUpdatedTask(_copyTaskWithSubtasks(updatedSubtasks));
  }

  Future<void> _setSubTaskIcon(String subTaskId) async {
    final SubTaskItem? subTask = _findSubtask(_task.subtasks, subTaskId);
    if (subTask == null) {
      return;
    }

    final String? iconKey = await showModalBottomSheet<String?>(
      context: context,
      builder: (_) => ItemIconPickerSheet(
        currentIconKey: subTask.iconKey,
      ),
    );
    if (!mounted) {
      return;
    }
    if (iconKey == subTask.iconKey) {
      return;
    }

    final List<SubTaskItem> updatedSubtasks = _updateSubtaskTree(
      _task.subtasks,
      subTaskId,
      (SubTaskItem item) => item.copyWith(
        iconKey: iconKey,
        clearIcon: iconKey == null,
      ),
    );
    _applyUpdatedTask(_copyTaskWithSubtasks(updatedSubtasks));
  }

  void _toggleSubTaskCompletion(String subTaskId, bool isCompleted) {
    final List<SubTaskItem> updatedSubtasks = _updateSubtaskTree(
      _task.subtasks,
      subTaskId,
      (SubTaskItem item) => item.copyWith(isCompleted: isCompleted),
    );
    _applyUpdatedTask(_copyTaskWithSubtasks(updatedSubtasks));
  }

  Future<void> _openSubTaskMenu(SubTaskItem subTask) async {
    final _SubTaskMenuAction? action = await _showSubTaskMenu(subTask);
    if (action == null || !mounted) {
      return;
    }

    if (action == _SubTaskMenuAction.addChild) {
      await _addSubTask(parentId: subTask.id);
      return;
    }
    if (action == _SubTaskMenuAction.edit) {
      await _editSubTask(subTask.id);
      return;
    }
    if (action == _SubTaskMenuAction.setIcon) {
      await _setSubTaskIcon(subTask.id);
      return;
    }
    if (action == _SubTaskMenuAction.setColor) {
      await _setSubTaskColor(subTask.id);
      return;
    }
    if (action == _SubTaskMenuAction.remove) {
      _removeSubTask(subTask.id);
    }
  }

  void _removeSubTask(String subTaskId) {
    final _SubTaskRemovalResult result =
        _removeSubtaskFromTree(_task.subtasks, subTaskId);
    if (result.removedItem == null) {
      return;
    }
    _applyUpdatedTask(_copyTaskWithSubtasks(result.items));
  }

  bool _subtaskTreeContainsId(SubTaskItem subTask, String candidateId) {
    if (subTask.id == candidateId) {
      return true;
    }
    for (final SubTaskItem child in subTask.children) {
      if (_subtaskTreeContainsId(child, candidateId)) {
        return true;
      }
    }
    return false;
  }

  bool _isStrictDescendantOfSubTask({
    required String ancestorSubTaskId,
    required String candidateSubTaskId,
  }) {
    final SubTaskItem? ancestor =
        _findSubtask(_task.subtasks, ancestorSubTaskId);
    if (ancestor == null) {
      return false;
    }

    for (final SubTaskItem child in ancestor.children) {
      if (_subtaskTreeContainsId(child, candidateSubTaskId)) {
        return true;
      }
    }
    return false;
  }

  List<SubTaskItem> _insertSubtaskIntoTree(
    List<SubTaskItem> items, {
    required String? parentId,
    required int targetIndex,
    required SubTaskItem insertedItem,
  }) {
    if (parentId == null) {
      final List<SubTaskItem> updated =
          items.map((SubTaskItem item) => item.clone()).toList(growable: true);
      updated.insert(targetIndex.clamp(0, updated.length), insertedItem);
      return updated;
    }

    return items.map((SubTaskItem item) {
      if (item.id == parentId) {
        final List<SubTaskItem> updatedChildren = item.children
            .map((SubTaskItem child) => child.clone())
            .toList(growable: true);
        updatedChildren.insert(
          targetIndex.clamp(0, updatedChildren.length),
          insertedItem,
        );
        return item.copyWith(children: updatedChildren);
      }
      if (item.children.isEmpty) {
        return item.clone();
      }
      return item.copyWith(
        children: _insertSubtaskIntoTree(
          item.children,
          parentId: parentId,
          targetIndex: targetIndex,
          insertedItem: insertedItem.clone(),
        ),
      );
    }).toList();
  }

  void _moveSubTaskToPosition({
    required String sourceSubTaskId,
    required String? targetParentId,
    required int targetIndex,
  }) {
    final SubTaskItem? sourceSubTask =
        _findSubtask(_task.subtasks, sourceSubTaskId);
    if (sourceSubTask == null) {
      return;
    }
    if (targetParentId != null &&
        _subtaskTreeContainsId(sourceSubTask, targetParentId)) {
      return;
    }

    final _SubTaskRemovalResult removalResult =
        _removeSubtaskFromTree(_task.subtasks, sourceSubTaskId);
    final SubTaskItem? removedItem = removalResult.removedItem;
    if (removedItem == null) {
      return;
    }

    if (targetParentId != null) {
      _expandedSubtaskIds.add(targetParentId);
    }
    _applyUpdatedTask(
      _copyTaskWithSubtasks(
        _insertSubtaskIntoTree(
          removalResult.items,
          parentId: targetParentId,
          targetIndex: targetIndex,
          insertedItem: removedItem,
        ),
      ),
    );
  }

  void _nestSubTaskUnderSubTask({
    required String sourceSubTaskId,
    required String targetSubTaskId,
  }) {
    if (sourceSubTaskId == targetSubTaskId) {
      return;
    }

    final SubTaskItem? sourceSubTask =
        _findSubtask(_task.subtasks, sourceSubTaskId);
    if (sourceSubTask == null ||
        _subtaskTreeContainsId(sourceSubTask, targetSubTaskId)) {
      return;
    }

    final _SubTaskRemovalResult removalResult =
        _removeSubtaskFromTree(_task.subtasks, sourceSubTaskId);
    final SubTaskItem? removedItem = removalResult.removedItem;
    if (removedItem == null) {
      return;
    }

    final List<SubTaskItem> updatedSubtasks = _updateSubtaskTree(
      removalResult.items,
      targetSubTaskId,
      (SubTaskItem item) => item.copyWith(
        children: <SubTaskItem>[
          removedItem,
          ...item.children.map((SubTaskItem child) => child.clone()),
        ],
      ),
    );
    _expandedSubtaskIds.add(targetSubTaskId);
    _applyUpdatedTask(_copyTaskWithSubtasks(updatedSubtasks));
  }

  SubTaskItem? _findSubtask(List<SubTaskItem> items, String id) {
    for (final SubTaskItem item in items) {
      if (item.id == id) {
        return item;
      }
      final SubTaskItem? nested = _findSubtask(item.children, id);
      if (nested != null) {
        return nested;
      }
    }
    return null;
  }

  List<SubTaskItem> _updateSubtaskTree(
    List<SubTaskItem> items,
    String id,
    SubTaskItem Function(SubTaskItem item) update,
  ) {
    return items.map((SubTaskItem item) {
      if (item.id == id) {
        return update(item.clone());
      }
      if (item.children.isEmpty) {
        return item.clone();
      }
      return item.copyWith(
        children: _updateSubtaskTree(item.children, id, update),
      );
    }).toList();
  }

  _SubTaskRemovalResult _removeSubtaskFromTree(
    List<SubTaskItem> items,
    String id,
  ) {
    final List<SubTaskItem> updatedItems = <SubTaskItem>[];
    SubTaskItem? removedItem;

    for (final SubTaskItem item in items) {
      if (item.id == id) {
        removedItem = item.clone();
        continue;
      }
      if (removedItem == null && item.children.isNotEmpty) {
        final _SubTaskRemovalResult nestedResult =
            _removeSubtaskFromTree(item.children, id);
        if (nestedResult.removedItem != null) {
          removedItem = nestedResult.removedItem;
          updatedItems.add(item.copyWith(children: nestedResult.items));
          continue;
        }
      }
      updatedItems.add(item.clone());
    }

    return _SubTaskRemovalResult(
      items: updatedItems,
      removedItem: removedItem,
    );
  }

  List<SubTaskItem> _visibleChildren(List<SubTaskItem> children) {
    if (!_usesChecklistStyle || !widget.hideCompletedProjectItems) {
      return children;
    }
    return children
        .where((SubTaskItem item) => !item.isCompleted)
        .toList(growable: false);
  }

  Widget _buildSubTaskDropSlot({
    required String? parentId,
    required int targetIndex,
    required int depth,
    required double inactiveHeight,
  }) {
    return DragTarget<_SubTaskDragPayload>(
      onWillAcceptWithDetails: (
        DragTargetDetails<_SubTaskDragPayload> details,
      ) {
        return true;
      },
      onAcceptWithDetails: (DragTargetDetails<_SubTaskDragPayload> details) {
        _moveSubTaskToPosition(
          sourceSubTaskId: details.data.subTaskId,
          targetParentId: parentId,
          targetIndex: targetIndex,
        );
      },
      builder: (
        BuildContext context,
        List<_SubTaskDragPayload?> candidateData,
        List<dynamic> rejectedData,
      ) {
        final bool isActive = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: isActive
              ? 28
              : (_draggingSubTaskId == null ? inactiveHeight : 14),
          margin: EdgeInsets.only(left: depth * 18.0 + 12),
          decoration: BoxDecoration(
            color: isActive
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.22)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
        );
      },
    );
  }

  Widget _buildNestedList(
    List<SubTaskItem> items,
    int depth, {
    String? parentId,
  }) {
    final List<SubTaskItem> visibleItems = _visibleChildren(items);
    if (visibleItems.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: <Widget>[
        _buildSubTaskDropSlot(
          parentId: parentId,
          targetIndex: 0,
          depth: depth,
          inactiveHeight: 0,
        ),
        for (int index = 0;
            index < visibleItems.length;
            index += 1) ...<Widget>[
          _buildSubTaskNode(
            visibleItems[index],
            depth,
            parentId: parentId,
            indexInParent: index,
          ),
          _buildSubTaskDropSlot(
            parentId: parentId,
            targetIndex: index + 1,
            depth: depth,
            inactiveHeight: 4,
          ),
        ],
      ],
    );
  }

  Widget _buildSubTaskPromotionDropSlot({
    required String currentSubTaskId,
    required String? targetParentId,
    required int targetIndex,
    required int depth,
  }) {
    final String? draggingSubTaskId = _draggingSubTaskId;
    if (draggingSubTaskId == null ||
        !_isStrictDescendantOfSubTask(
          ancestorSubTaskId: currentSubTaskId,
          candidateSubTaskId: draggingSubTaskId,
        )) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: EdgeInsets.only(
        left: depth * 18.0 + 12,
        right: 4,
        bottom: _layout.listBottomSpacing,
      ),
      child: DragTarget<_SubTaskDragPayload>(
        onWillAcceptWithDetails: (
          DragTargetDetails<_SubTaskDragPayload> details,
        ) {
          return _isStrictDescendantOfSubTask(
            ancestorSubTaskId: currentSubTaskId,
            candidateSubTaskId: details.data.subTaskId,
          );
        },
        onAcceptWithDetails: (DragTargetDetails<_SubTaskDragPayload> details) {
          _moveSubTaskToPosition(
            sourceSubTaskId: details.data.subTaskId,
            targetParentId: targetParentId,
            targetIndex: targetIndex,
          );
        },
        builder: (
          BuildContext context,
          List<_SubTaskDragPayload?> candidateData,
          List<dynamic> rejectedData,
        ) {
          final bool isActive = candidateData.isNotEmpty;
          final ColorScheme colorScheme = Theme.of(context).colorScheme;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: isActive
                  ? colorScheme.primary.withValues(alpha: 0.18)
                  : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color:
                    isActive ? colorScheme.primary : colorScheme.outlineVariant,
              ),
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.format_indent_decrease_outlined,
                  size: 18,
                  color: isActive
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  'Move to this level',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: isActive
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSubTaskNode(
    SubTaskItem subTask,
    int depth, {
    required String? parentId,
    required int indexInParent,
  }) {
    final bool hasChildren = _visibleChildren(subTask.children).isNotEmpty;
    final bool hasBody = subTask.body.isNotEmpty;
    final bool isExpanded = _expandedSubtaskIds.contains(subTask.id);
    final double baseTitleFontSize =
        Theme.of(context).textTheme.titleMedium?.fontSize ?? 16;
    final TextStyle? titleStyle = Theme.of(context)
        .textTheme
        .titleMedium
        ?.copyWith(
          decoration: subTask.isCompleted ? TextDecoration.lineThrough : null,
          color: subTask.isCompleted
              ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55)
              : null,
        );

    final List<Widget> trailingWidgets = <Widget>[
      if (subTask.body.isNotEmpty)
        const Tooltip(
          message: 'Has text content',
          child: Icon(Icons.notes_outlined, size: 18),
        ),
      if (subTask.iconKey != null && !_usesChecklistStyle)
        Icon(
          iconDataForKey(subTask.iconKey),
          size: 18,
        ),
    ];
    final Widget card = Card(
      color: subTask.colorValue == null ? null : Color(subTask.colorValue!),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openSubTaskMenu(subTask),
        child: Padding(
          padding: _layout.contentPadding,
          child: Row(
            crossAxisAlignment:
                hasBody ? CrossAxisAlignment.start : CrossAxisAlignment.center,
            children: <Widget>[
              if (_usesChecklistStyle)
                Checkbox(
                  value: subTask.isCompleted,
                  onChanged: (bool? value) =>
                      _toggleSubTaskCompletion(subTask.id, value ?? false),
                )
              else
                SizedBox(
                  width: 40,
                  child: hasChildren
                      ? IconButton(
                          onPressed: () => _toggleExpanded(subTask.id),
                          icon: Icon(
                            isExpanded
                                ? Icons.expand_more_outlined
                                : Icons.chevron_right_outlined,
                          ),
                        )
                      : Icon(
                          iconDataForKey(subTask.iconKey) ??
                              Icons.subdirectory_arrow_right_outlined,
                        ),
                ),
              if (_usesChecklistStyle && hasChildren)
                IconButton(
                  onPressed: () => _toggleExpanded(subTask.id),
                  icon: Icon(
                    isExpanded
                        ? Icons.expand_more_outlined
                        : Icons.chevron_right_outlined,
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      subTask.title,
                      style: titleStyle?.copyWith(
                        fontSize: baseTitleFontSize * _layout.titleScale,
                      ),
                    ),
                    if (hasBody) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        subTask.body,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              if (trailingWidgets.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    for (int i = 0;
                        i < trailingWidgets.length;
                        i++) ...<Widget>[
                      if (i > 0) const SizedBox(width: 8),
                      trailingWidgets[i],
                    ],
                  ],
                ),
            ],
          ),
        ),
      ),
    );

    return DragTarget<_SubTaskDragPayload>(
      onWillAcceptWithDetails: (
        DragTargetDetails<_SubTaskDragPayload> details,
      ) {
        if (details.data.subTaskId == subTask.id) {
          return false;
        }
        final SubTaskItem? source =
            _findSubtask(_task.subtasks, details.data.subTaskId);
        return source == null || !_subtaskTreeContainsId(source, subTask.id);
      },
      onAcceptWithDetails: (DragTargetDetails<_SubTaskDragPayload> details) {
        _nestSubTaskUnderSubTask(
          sourceSubTaskId: details.data.subTaskId,
          targetSubTaskId: subTask.id,
        );
      },
      builder: (
        BuildContext context,
        List<_SubTaskDragPayload?> candidateData,
        List<dynamic> rejectedData,
      ) {
        final bool isHovering = candidateData.isNotEmpty;
        final Widget tile = Padding(
          padding: EdgeInsets.only(
              left: depth * 18.0, bottom: _layout.listBottomSpacing),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: isHovering
                  ? Border.all(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    )
                  : null,
            ),
            child: card,
          ),
        );
        final Widget dismissibleTile = Dismissible(
          key: ValueKey<String>('subtask-swipe-${subTask.id}'),
          direction: DismissDirection.endToStart,
          onDismissed: (_) => _removeSubTask(subTask.id),
          background: Padding(
            padding: EdgeInsets.only(
              left: depth * 18.0,
              bottom: _layout.listBottomSpacing,
            ),
            child: const SizedBox.expand(),
          ),
          secondaryBackground: Padding(
            padding: EdgeInsets.only(
              left: depth * 18.0,
              bottom: _layout.listBottomSpacing,
            ),
            child: Container(
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
          ),
          child: tile,
        );

        return Column(
          children: <Widget>[
            LongPressDraggable<_SubTaskDragPayload>(
              data: _SubTaskDragPayload(subTaskId: subTask.id),
              onDragStarted: () {
                setState(() {
                  _draggingSubTaskId = subTask.id;
                });
              },
              onDragEnd: (_) {
                if (_draggingSubTaskId == subTask.id) {
                  setState(() {
                    _draggingSubTaskId = null;
                  });
                }
              },
              feedback: Material(
                color: Colors.transparent,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: Padding(
                    padding: EdgeInsets.only(left: depth * 18.0),
                    child: card,
                  ),
                ),
              ),
              childWhenDragging: Opacity(
                opacity: 0.45,
                child: tile,
              ),
              child: dismissibleTile,
            ),
            if (hasChildren && isExpanded)
              _buildNestedList(
                subTask.children,
                depth + 1,
                parentId: subTask.id,
              ),
            if (hasChildren && isExpanded)
              _buildSubTaskPromotionDropSlot(
                currentSubTaskId: subTask.id,
                targetParentId: parentId,
                targetIndex: indexInParent + 1,
                depth: depth,
              ),
          ],
        );
      },
    );
  }

  Widget _buildTaskHeader() {
    final IconData? iconData = iconDataForKey(_task.iconKey);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (iconData != null) ...<Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Icon(iconData),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Text(
            _task.title,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hasBody = _task.body.trim().isNotEmpty;
    final bool hasImages = _task.imagePaths.isNotEmpty;
    final bool hasPrompt = _task.prompt.trim().isNotEmpty;
    final String sectionLabel = _usesChecklistStyle ? 'Checklist' : 'Ideas';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Task'),
        actions: <Widget>[
          IconButton(
            onPressed: _openTaskMenu,
            tooltip: 'Task options',
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          _buildTaskHeader(),
          const SizedBox(height: 16),
          if (hasBody)
            Text(
              _task.body,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          if (hasImages) ...<Widget>[
            if (hasBody) const SizedBox(height: 16),
            Text(
              _task.imagePaths.length == 1 ? 'Image' : 'Images',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TaskImageGallery(imagePaths: _task.imagePaths, height: 160),
          ],
          if (hasPrompt) ...<Widget>[
            const SizedBox(height: 16),
            Text(
              'Prompt',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            SelectableText(
              _task.prompt,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          const SizedBox(height: 20),
          Text(
            '$sectionLabel (${_task.subtasks.length})',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (_task.subtasks.isNotEmpty) _buildNestedList(_task.subtasks, 0),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addSubTask,
        tooltip: _usesChecklistStyle ? 'Add checklist item' : 'Add nested idea',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _SubTaskCreateResult {
  const _SubTaskCreateResult({
    required this.subTask,
    required this.insertAtTop,
  });

  final SubTaskItem subTask;
  final bool insertAtTop;
}

class _SubTaskRemovalResult {
  const _SubTaskRemovalResult({
    required this.items,
    required this.removedItem,
  });

  final List<SubTaskItem> items;
  final SubTaskItem? removedItem;
}

class _AddSubTaskSheet extends StatefulWidget {
  const _AddSubTaskSheet({
    required this.addLabel,
  });

  final String addLabel;

  @override
  State<_AddSubTaskSheet> createState() => _AddSubTaskSheetState();
}

class _AddSubTaskSheetState extends State<_AddSubTaskSheet> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  final FocusNode _titleFocusNode = FocusNode();
  bool _insertAtTop = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _titleFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _titleFocusNode.dispose();
    super.dispose();
  }

  void _saveSubTask() {
    final String title = _titleController.text.trim();
    if (title.isEmpty) {
      return;
    }

    Navigator.of(context).pop(
      _SubTaskCreateResult(
        subTask: SubTaskItem(
          title: title,
          body: _bodyController.text.trim(),
        ),
        insertAtTop: _insertAtTop,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        12,
        12,
        12,
        12 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            widget.addLabel,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _titleController,
            focusNode: _titleFocusNode,
            autofocus: true,
            textInputAction: TextInputAction.newline,
            keyboardType: TextInputType.multiline,
            minLines: 1,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Title',
              alignLabelWithHint: true,
              hintText: 'Follow-up thought or step',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _bodyController,
            textInputAction: TextInputAction.done,
            minLines: 2,
            maxLines: 4,
            onSubmitted: (_) => _saveSubTask(),
            decoration: const InputDecoration(
              labelText: 'Details (optional)',
            ),
          ),
          const SizedBox(height: 12),
          SegmentedButton<bool>(
            segments: const <ButtonSegment<bool>>[
              ButtonSegment<bool>(
                value: true,
                label: Text('Add at top'),
                icon: Icon(Icons.vertical_align_top_outlined),
              ),
              ButtonSegment<bool>(
                value: false,
                label: Text('Add at bottom'),
                icon: Icon(Icons.vertical_align_bottom_outlined),
              ),
            ],
            selected: <bool>{_insertAtTop},
            onSelectionChanged: (Set<bool> selection) {
              setState(() {
                _insertAtTop = selection.first;
              });
            },
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _saveSubTask,
            child: const Text('Save Item'),
          ),
        ],
      ),
    );
  }
}
