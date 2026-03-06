import 'package:flutter/material.dart';

import '../../domain/task_models.dart';

class AddTaskSheet extends StatefulWidget {
  const AddTaskSheet({super.key});

  @override
  State<AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends State<AddTaskSheet> {
  final TextEditingController _titleController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _saveTask() {
    final String title = _titleController.text.trim();
    if (title.isEmpty) {
      return;
    }

    Navigator.of(context).pop(TaskItem(title: title));
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
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _saveTask(),
            decoration: const InputDecoration(
              labelText: 'Title',
              hintText: 'Buy groceries',
            ),
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
