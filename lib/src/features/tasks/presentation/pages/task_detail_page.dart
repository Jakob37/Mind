import 'package:flutter/material.dart';

import '../../domain/task_models.dart';
import '../widgets/edit_task_sheet.dart';
import '../widgets/item_color_picker_sheet.dart';
import '../widgets/item_icon_picker_sheet.dart';

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

class TaskDetailPage extends StatefulWidget {
  const TaskDetailPage({
    super.key,
    required this.task,
    required this.menuItems,
    required this.onTaskChanged,
    this.colorLabels = const <int, String>{},
    this.hideCompletedProjectItems = false,
  });

  final TaskItem task;
  final List<TaskDetailMenuItem> menuItems;
  final ValueChanged<TaskItem> onTaskChanged;
  final Map<int, String> colorLabels;
  final bool hideCompletedProjectItems;

  @override
  State<TaskDetailPage> createState() => _TaskDetailPageState();
}

class _TaskDetailPageState extends State<TaskDetailPage> {
  late TaskItem _task;
  bool _isSubtaskReorderMode = false;
  final Set<String> _expandedSubtaskIds = <String>{};

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

  void _enterSubtaskReorderMode() {
    if (_isSubtaskReorderMode) {
      return;
    }
    setState(() {
      _isSubtaskReorderMode = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Drag mode enabled for top-level nested items.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _exitSubtaskReorderMode() {
    if (!_isSubtaskReorderMode) {
      return;
    }
    setState(() {
      _isSubtaskReorderMode = false;
    });
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

  void _reorderSubTasks(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _task.subtasks.length) {
      return;
    }
    if (newIndex < 0 || newIndex > _task.subtasks.length) {
      return;
    }

    int insertionIndex = newIndex;
    if (insertionIndex > oldIndex) {
      insertionIndex -= 1;
    }
    if (insertionIndex == oldIndex) {
      return;
    }

    final List<SubTaskItem> updatedSubtasks =
        _task.subtasks.map((SubTaskItem subTask) => subTask.clone()).toList();
    final SubTaskItem moved = updatedSubtasks.removeAt(oldIndex);
    final int safeInsertionIndex =
        insertionIndex.clamp(0, updatedSubtasks.length);
    updatedSubtasks.insert(safeInsertionIndex, moved);
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

  Widget _buildNestedList(List<SubTaskItem> items, int depth) {
    final List<SubTaskItem> visibleItems = _visibleChildren(items);
    if (visibleItems.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: visibleItems
          .map((SubTaskItem item) => _buildSubTaskNode(item, depth))
          .toList(growable: false),
    );
  }

  Widget _buildSubTaskNode(SubTaskItem subTask, int depth) {
    final bool hasChildren = _visibleChildren(subTask.children).isNotEmpty;
    final bool isExpanded = _expandedSubtaskIds.contains(subTask.id);
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

    return Padding(
      padding: EdgeInsets.only(left: depth * 18.0, bottom: 4),
      child: Column(
        children: <Widget>[
          Card(
            color:
                subTask.colorValue == null ? null : Color(subTask.colorValue!),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _openSubTaskMenu(subTask),
              onLongPress: () => _openSubTaskMenu(subTask),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (_usesChecklistStyle)
                      Checkbox(
                        value: subTask.isCompleted,
                        onChanged: (bool? value) => _toggleSubTaskCompletion(
                            subTask.id, value ?? false),
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
                            style: titleStyle,
                          ),
                          if (subTask.body.isNotEmpty) ...<Widget>[
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
          ),
          if (hasChildren && isExpanded)
            _buildNestedList(subTask.children, depth + 1),
        ],
      ),
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
    final bool hasPrompt = _task.prompt.trim().isNotEmpty;
    final String sectionLabel =
        _usesChecklistStyle ? 'Nested checklist' : 'Nested ideas';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Task'),
        actions: <Widget>[
          if (!_isSubtaskReorderMode)
            IconButton(
              onPressed: _enterSubtaskReorderMode,
              tooltip: 'Enter drag mode',
              icon: const Icon(Icons.drag_indicator_outlined),
            ),
          if (_isSubtaskReorderMode)
            IconButton(
              onPressed: _exitSubtaskReorderMode,
              tooltip: 'Done reordering nested items',
              icon: const Icon(Icons.check),
            ),
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
            )
          else
            Text(
              'No details added yet.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
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
          if (_task.subtasks.isEmpty)
            Text(
              _usesChecklistStyle
                  ? 'No checklist items yet.'
                  : 'No nested ideas yet.',
              style: Theme.of(context).textTheme.bodyMedium,
            )
          else if (_isSubtaskReorderMode)
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _task.subtasks.length,
              onReorder: _reorderSubTasks,
              buildDefaultDragHandles: false,
              itemBuilder: (BuildContext context, int index) {
                final SubTaskItem subTask = _task.subtasks[index];
                return Padding(
                  key: ValueKey<String>('subtask-reorder-${subTask.id}'),
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
                  child: Card(
                    color: subTask.colorValue == null
                        ? null
                        : Color(subTask.colorValue!),
                    child: ListTile(
                      title: Text(
                        subTask.title,
                        maxLines: null,
                      ),
                      trailing: ReorderableDragStartListener(
                        index: index,
                        child: const Icon(Icons.drag_indicator_outlined),
                      ),
                    ),
                  ),
                );
              },
            )
          else
            _buildNestedList(_task.subtasks, 0),
          const SizedBox(height: 4),
          Text(
            _isSubtaskReorderMode
                ? 'Drag top-level nested items to reorder. Nested child placement uses the item menu.'
                : _usesChecklistStyle
                    ? 'Use the checkbox to complete items. Long press opens item options.'
                    : 'Use the arrow to fold or expand child ideas. Long press opens item options.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
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
  bool _insertAtTop = true;

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
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Title',
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
