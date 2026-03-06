import 'package:flutter/material.dart';

class AddProjectSheet extends StatefulWidget {
  const AddProjectSheet({super.key});

  @override
  State<AddProjectSheet> createState() => _AddProjectSheetState();
}

class _AddProjectSheetState extends State<AddProjectSheet> {
  final TextEditingController _projectNameController = TextEditingController();

  @override
  void dispose() {
    _projectNameController.dispose();
    super.dispose();
  }

  void _createProject() {
    final String name = _projectNameController.text.trim();
    if (name.isEmpty) {
      return;
    }
    Navigator.of(context).pop(name);
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
            'New Project',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _projectNameController,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _createProject(),
            decoration: const InputDecoration(
              labelText: 'Project name',
              hintText: 'Deep Focus',
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _createProject,
            child: const Text('Create Project'),
          ),
        ],
      ),
    );
  }
}
