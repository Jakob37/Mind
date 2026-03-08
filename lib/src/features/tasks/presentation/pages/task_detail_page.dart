import 'package:flutter/material.dart';

import '../../domain/task_models.dart';
import '../widgets/edit_task_sheet.dart';
import '../widgets/item_color_picker_sheet.dart';

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

enum _SubTaskMenuAction {
  edit,
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
  });

  final TaskItem task;
  final List<TaskDetailMenuItem> menuItems;
  final ValueChanged<TaskItem> onTaskChanged;
  final Map<int, String> colorLabels;

  @override
  State<TaskDetailPage> createState() => _TaskDetailPageState();
}

class _TaskDetailPageState extends State<TaskDetailPage> {
  late TaskItem _task;
  bool _isSubtaskReorderMode = false;

  @override
  void initState() {
    super.initState();
    _task = widget.task.clone();
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
        content: Text('Subtask drag mode enabled. Drag using handles.'),
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

  TaskItem _copyTaskWithSubtasks(List<SubTaskItem> subtasks) {
    return TaskItem(
      id: _task.id,
      title: _task.title,
      body: _task.body,
      colorValue: _task.colorValue,
      type: _task.type,
      subtasks: subtasks.map((SubTaskItem subtask) => subtask.clone()).toList(),
    );
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

  Future<void> _addSubTask() async {
    final SubTaskItem? createdSubTask = await showModalBottomSheet<SubTaskItem>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _AddSubTaskSheet(),
    );

    if (createdSubTask == null) {
      return;
    }

    _applyUpdatedTask(
      _copyTaskWithSubtasks(
        <SubTaskItem>[
          createdSubTask,
          ..._task.subtasks,
        ],
      ),
    );
  }

  void _removeSubTask(String subTaskId) {
    final List<SubTaskItem> updatedSubtasks = _task.subtasks
        .where((SubTaskItem subTask) => subTask.id != subTaskId)
        .map((SubTaskItem subTask) => subTask.clone())
        .toList();
    if (updatedSubtasks.length == _task.subtasks.length) {
      return;
    }
    _applyUpdatedTask(_copyTaskWithSubtasks(updatedSubtasks));
  }

  int _indexOfSubTaskById(String subTaskId) {
    return _task.subtasks
        .indexWhere((SubTaskItem subTask) => subTask.id == subTaskId);
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
                subtitle: const Text('Subtask options'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit subtask'),
                onTap: () => Navigator.of(context).pop(_SubTaskMenuAction.edit),
              ),
              ListTile(
                leading: const Icon(Icons.palette_outlined),
                title: const Text('Set color'),
                onTap: () =>
                    Navigator.of(context).pop(_SubTaskMenuAction.setColor),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Remove subtask'),
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
    final int index = _indexOfSubTaskById(subTaskId);
    if (index < 0) {
      return;
    }
    final SubTaskItem subTask = _task.subtasks[index];

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

    final List<SubTaskItem> updatedSubtasks =
        _task.subtasks.map((SubTaskItem item) => item.clone()).toList();
    updatedSubtasks[index] = SubTaskItem(
      id: subTask.id,
      title: result.title,
      body: result.body,
      colorValue: subTask.colorValue,
    );
    _applyUpdatedTask(_copyTaskWithSubtasks(updatedSubtasks));
  }

  Future<void> _setSubTaskColor(String subTaskId) async {
    final int index = _indexOfSubTaskById(subTaskId);
    if (index < 0) {
      return;
    }
    final SubTaskItem subTask = _task.subtasks[index];

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

    final List<SubTaskItem> updatedSubtasks =
        _task.subtasks.map((SubTaskItem item) => item.clone()).toList();
    updatedSubtasks[index] = SubTaskItem(
      id: subTask.id,
      title: subTask.title,
      body: subTask.body,
      colorValue: selection.colorValue,
    );
    _applyUpdatedTask(_copyTaskWithSubtasks(updatedSubtasks));
  }

  Future<void> _openSubTaskMenu(SubTaskItem subTask) async {
    final _SubTaskMenuAction? action = await _showSubTaskMenu(subTask);
    if (action == null || !mounted) {
      return;
    }

    if (action == _SubTaskMenuAction.edit) {
      await _editSubTask(subTask.id);
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

  Widget _buildSubTaskCard(
    SubTaskItem subTask, {
    Widget? trailing,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
  }) {
    final List<Widget> trailingWidgets = <Widget>[
      if (subTask.body.isNotEmpty)
        const Tooltip(
          message: 'Has text content',
          child: Icon(
            Icons.notes_outlined,
            size: 18,
          ),
        ),
      if (trailing != null) trailing,
    ];

    return Card(
      color: subTask.colorValue == null ? null : Color(subTask.colorValue!),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 6,
        ),
        title: Text(
          subTask.title,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        trailing: trailingWidgets.isEmpty
            ? null
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  for (int i = 0; i < trailingWidgets.length; i++) ...<Widget>[
                    if (i > 0) const SizedBox(width: 8),
                    trailingWidgets[i],
                  ],
                ],
              ),
        onTap: onTap,
        onLongPress: onLongPress,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hasBody = _task.body.trim().isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Task'),
        actions: <Widget>[
          if (_isSubtaskReorderMode)
            IconButton(
              onPressed: _exitSubtaskReorderMode,
              tooltip: 'Done reordering subtasks',
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
          Text(
            _task.title,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
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
          const SizedBox(height: 20),
          Text(
            'Subtasks (${_task.subtasks.length})',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (_task.subtasks.isEmpty)
            Text(
              'No subtasks yet.',
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
                  padding: const EdgeInsets.only(bottom: 4),
                  child: _buildSubTaskCard(
                    subTask,
                    trailing: ReorderableDragStartListener(
                      index: index,
                      child: const Icon(Icons.drag_indicator_outlined),
                    ),
                  ),
                );
              },
            )
          else
            for (final SubTaskItem subTask in _task.subtasks)
              Dismissible(
                key: ValueKey<String>('subtask-swipe-${subTask.id}'),
                direction: DismissDirection.endToStart,
                onDismissed: (_) => _removeSubTask(subTask.id),
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
                  child: _buildSubTaskCard(
                    subTask,
                    onTap: () => _openSubTaskMenu(subTask),
                    onLongPress: _enterSubtaskReorderMode,
                  ),
                ),
              ),
          const SizedBox(height: 4),
          Text(
            _isSubtaskReorderMode
                ? 'Drag subtasks to reorder. Tap check when done.'
                : 'Tap for options. Swipe left to remove. Long press to reorder.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addSubTask,
        tooltip: 'Add subtask',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _AddSubTaskSheet extends StatefulWidget {
  const _AddSubTaskSheet();

  @override
  State<_AddSubTaskSheet> createState() => _AddSubTaskSheetState();
}

class _AddSubTaskSheetState extends State<_AddSubTaskSheet> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  final FocusNode _titleFocusNode = FocusNode();

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
      SubTaskItem(
        title: title,
        body: _bodyController.text.trim(),
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
            'New Subtask',
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
              hintText: 'Follow-up step',
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
          FilledButton(
            onPressed: _saveSubTask,
            child: const Text('Save Subtask'),
          ),
        ],
      ),
    );
  }
}
