import 'package:flutter/material.dart';

class ProjectEditResult {
  const ProjectEditResult({
    required this.name,
    required this.body,
    required this.prompt,
  });

  final String name;
  final String body;
  final String prompt;
}

class EditProjectSheet extends StatefulWidget {
  const EditProjectSheet({
    super.key,
    required this.initialName,
    required this.initialBody,
    this.initialPrompt = '',
    this.showPromptField = false,
  });

  final String initialName;
  final String initialBody;
  final String initialPrompt;
  final bool showPromptField;

  @override
  State<EditProjectSheet> createState() => _EditProjectSheetState();
}

class _EditProjectSheetState extends State<EditProjectSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _bodyController;
  late final TextEditingController _promptController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _bodyController = TextEditingController(text: widget.initialBody);
    _promptController = TextEditingController(text: widget.initialPrompt);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bodyController.dispose();
    _promptController.dispose();
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
        prompt: _promptController.text.trim(),
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
            textInputAction: TextInputAction.newline,
            keyboardType: TextInputType.multiline,
            minLines: 1,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Project name',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _bodyController,
            minLines: 3,
            maxLines: 6,
            decoration: InputDecoration(
              labelText: widget.showPromptField ? 'Description' : 'Body',
              alignLabelWithHint: true,
            ),
          ),
          if (widget.showPromptField) ...<Widget>[
            const SizedBox(height: 12),
            TextField(
              controller: _promptController,
              minLines: 4,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: 'Prompt',
                alignLabelWithHint: true,
              ),
            ),
          ],
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
