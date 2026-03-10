import 'package:flutter/material.dart';

import '../../domain/task_models.dart';

class AddTaskResult {
  const AddTaskResult({
    required this.task,
    required this.insertAtTop,
  });

  final TaskItem task;
  final bool insertAtTop;
}

class AddTaskSheet extends StatefulWidget {
  const AddTaskSheet({super.key});

  @override
  State<AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends State<AddTaskSheet> {
  final TextEditingController _titleController = TextEditingController();
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
    _titleFocusNode.dispose();
    super.dispose();
  }

  void _saveTask() {
    final String title = _titleController.text.trim();
    if (title.isEmpty) {
      return;
    }

    Navigator.of(context).pop(
      AddTaskResult(
        task: TaskItem(title: title),
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
            'New Task',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _titleController,
            focusNode: _titleFocusNode,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _saveTask(),
            decoration: const InputDecoration(
              labelText: 'Title',
              hintText: 'Capture a new idea or action',
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
            onPressed: _saveTask,
            child: const Text('Save Task'),
          ),
        ],
      ),
    );
  }
}
