import 'package:flutter/material.dart';

class ProjectEditResult {
  const ProjectEditResult({
    required this.name,
    required this.body,
  });

  final String name;
  final String body;
}

class EditProjectSheet extends StatefulWidget {
  const EditProjectSheet({
    super.key,
    required this.initialName,
    required this.initialBody,
  });

  final String initialName;
  final String initialBody;

  @override
  State<EditProjectSheet> createState() => _EditProjectSheetState();
}

class _EditProjectSheetState extends State<EditProjectSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _bodyController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _bodyController = TextEditingController(text: widget.initialBody);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _save() {
    final String name = _nameController.text.trim();
    if (name.isEmpty) {
      return;
    }
    Navigator.of(context).pop(
      ProjectEditResult(
        name: name,
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
            'Edit Project',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Project name',
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
            child: const Text('Save Project'),
          ),
        ],
      ),
    );
  }
}
