import 'package:flutter/material.dart';

import '../../domain/task_models.dart';
import 'select_project_stack_sheet.dart';

class AddProjectResult {
  const AddProjectResult({
    required this.name,
    required this.stackSelection,
  });

  final String name;
  final ProjectStackSelection stackSelection;
}

class AddProjectSheet extends StatefulWidget {
  const AddProjectSheet({
    super.key,
    required this.projectStacks,
  });

  final List<ProjectStack> projectStacks;

  @override
  State<AddProjectSheet> createState() => _AddProjectSheetState();
}

class _AddProjectSheetState extends State<AddProjectSheet> {
  final TextEditingController _projectNameController = TextEditingController();
  ProjectStackSelection _stackSelection = const ProjectStackSelection.none();

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
    Navigator.of(context).pop(
      AddProjectResult(
        name: name,
        stackSelection: _stackSelection,
      ),
    );
  }

  Future<void> _selectStack() async {
    final ProjectStackSelection? selection =
        await showModalBottomSheet<ProjectStackSelection>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SelectProjectStackSheet(
        projectStacks: widget.projectStacks,
        initialSelection: _stackSelection,
      ),
    );

    if (!mounted || selection == null) {
      return;
    }

    setState(() {
      _stackSelection = selection;
    });
  }

  String _stackLabel() {
    if (_stackSelection.mode == ProjectStackSelectionMode.none) {
      return 'No stack';
    }
    if (_stackSelection.mode == ProjectStackSelectionMode.createNew) {
      return _stackSelection.stackName ?? 'Create stack';
    }

    for (final ProjectStack stack in widget.projectStacks) {
      if (stack.id == _stackSelection.stackId) {
        return stack.name;
      }
    }
    return 'Select stack';
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
          OutlinedButton.icon(
            onPressed: _selectStack,
            icon: const Icon(Icons.layers_outlined),
            label: Text('Stack: ${_stackLabel()}'),
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
