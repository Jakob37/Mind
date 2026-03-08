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

class TaskDetailPage extends StatefulWidget {
  const TaskDetailPage({
    super.key,
    required this.task,
    required this.menuItems,
    required this.onTaskChanged,
  });

  final TaskItem task;
  final List<TaskDetailMenuItem> menuItems;
  final ValueChanged<TaskItem> onTaskChanged;

  @override
  State<TaskDetailPage> createState() => _TaskDetailPageState();
}

class _TaskDetailPageState extends State<TaskDetailPage> {
  late TaskItem _task;

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

    final TaskItem updatedTask = TaskItem(
      id: _task.id,
      title: _task.title,
      body: _task.body,
      colorValue: _task.colorValue,
      type: _task.type,
      subtasks: <SubTaskItem>[
        createdSubTask,
        ..._task.subtasks.map((SubTaskItem subtask) => subtask.clone()),
      ],
    );
    _applyUpdatedTask(updatedTask);
  }

  Widget _buildSubTaskCard(SubTaskItem subTask) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Card(
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 6,
          ),
          title: Text(
            subTask.title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          trailing: subTask.body.isEmpty
              ? null
              : const Tooltip(
                  message: 'Has text content',
                  child: Icon(
                    Icons.notes_outlined,
                    size: 18,
                  ),
                ),
        ),
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
            'Subtasks',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (_task.subtasks.isEmpty)
            Text(
              'No subtasks yet.',
              style: Theme.of(context).textTheme.bodyMedium,
            )
          else
            for (final SubTaskItem subTask in _task.subtasks)
              _buildSubTaskCard(subTask),
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
