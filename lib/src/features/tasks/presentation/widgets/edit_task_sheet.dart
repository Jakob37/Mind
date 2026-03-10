import 'package:flutter/material.dart';

class TaskEditResult {
  const TaskEditResult({
    required this.title,
    required this.body,
  });

  final String title;
  final String body;
}

class EditTaskSheet extends StatefulWidget {
  const EditTaskSheet({
    super.key,
    required this.initialTitle,
    required this.initialBody,
  });

  final String initialTitle;
  final String initialBody;

  @override
  State<EditTaskSheet> createState() => _EditTaskSheetState();
}

class _EditTaskSheetState extends State<EditTaskSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
    _bodyController = TextEditingController(text: widget.initialBody);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _save() {
    final String title = _titleController.text.trim();
    if (title.isEmpty) {
      return;
    }
    Navigator.of(context).pop(
      TaskEditResult(
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
            'Edit Task',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _titleController,
            textInputAction: TextInputAction.newline,
            minLines: 1,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Title',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _bodyController,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: 'Body',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _save,
            child: const Text('Save Task'),
          ),
        ],
      ),
    );
  }
}
