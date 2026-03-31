import 'package:flutter/material.dart';

class ProjectEntryEditResult {
  const ProjectEntryEditResult({
    required this.name,
    required this.body,
  });

  final String name;
  final String body;
}

class EditProjectEntrySheet extends StatefulWidget {
  const EditProjectEntrySheet({
    super.key,
    required this.initialName,
    required this.initialBody,
    this.itemLabel = 'Person',
    this.nameFieldLabel = 'Name',
    this.notesLabel = 'Notes',
  });

  final String initialName;
  final String initialBody;
  final String itemLabel;
  final String nameFieldLabel;
  final String notesLabel;

  @override
  State<EditProjectEntrySheet> createState() => _EditProjectEntrySheetState();
}

class _EditProjectEntrySheetState extends State<EditProjectEntrySheet> {
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
      ProjectEntryEditResult(
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
            'Edit ${widget.itemLabel}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameController,
            minLines: 1,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: widget.nameFieldLabel,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _bodyController,
            minLines: 2,
            maxLines: 5,
            decoration: InputDecoration(
              labelText: widget.notesLabel,
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _save,
            child: Text('Save ${widget.itemLabel}'),
          ),
        ],
      ),
    );
  }
}
