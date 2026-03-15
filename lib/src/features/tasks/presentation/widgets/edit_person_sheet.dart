import 'package:flutter/material.dart';

class PersonEditResult {
  const PersonEditResult({
    required this.name,
    required this.body,
  });

  final String name;
  final String body;
}

class EditPersonSheet extends StatefulWidget {
  const EditPersonSheet({
    super.key,
    required this.initialName,
    required this.initialBody,
  });

  final String initialName;
  final String initialBody;

  @override
  State<EditPersonSheet> createState() => _EditPersonSheetState();
}

class _EditPersonSheetState extends State<EditPersonSheet> {
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
      PersonEditResult(
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
            'Edit Person',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameController,
            minLines: 1,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Name',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _bodyController,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Notes',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _save,
            child: const Text('Save Person'),
          ),
        ],
      ),
    );
  }
}
