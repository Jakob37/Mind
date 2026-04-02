import 'package:flutter/material.dart';

import '../../domain/task_models.dart';
import 'item_icon_picker_sheet.dart';
import 'select_project_stack_sheet.dart';
import 'select_project_type_sheet.dart';

class AddProjectResult {
  const AddProjectResult({
    required this.name,
    required this.stackSelection,
    required this.projectTypeId,
  });

  final String name;
  final ProjectStackSelection stackSelection;
  final String projectTypeId;
}

class AddProjectSheet extends StatefulWidget {
  const AddProjectSheet({
    super.key,
    required this.projectStacks,
    required this.projectTypes,
    this.initialStackSelection = const ProjectStackSelection.none(),
  });

  final List<ProjectStack> projectStacks;
  final List<ProjectTypeConfig> projectTypes;
  final ProjectStackSelection initialStackSelection;

  @override
  State<AddProjectSheet> createState() => _AddProjectSheetState();
}

class _AddProjectSheetState extends State<AddProjectSheet> {
  final TextEditingController _projectNameController = TextEditingController();
  late ProjectStackSelection _stackSelection;
  String _projectTypeId = ProjectTypeDefaults.projectId;

  @override
  void initState() {
    super.initState();
    _stackSelection = widget.initialStackSelection;
  }

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
        projectTypeId: _projectTypeId,
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

  Future<void> _selectProjectType() async {
    final String? projectTypeId = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SelectProjectTypeSheet(
        projectTypes: widget.projectTypes,
        currentProjectTypeId: _projectTypeId,
      ),
    );
    if (!mounted || projectTypeId == null) {
      return;
    }
    setState(() {
      _projectTypeId = projectTypeId;
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

  ProjectTypeConfig _projectType() {
    for (final ProjectTypeConfig type in widget.projectTypes) {
      if (type.id == _projectTypeId) {
        return type;
      }
    }
    return ProjectTypeConfig.defaults().first;
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
          OutlinedButton.icon(
            onPressed: _selectStack,
            icon: const Icon(Icons.layers_outlined),
            label: Text('Stack: ${_stackLabel()}'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _selectProjectType,
            icon: Icon(
              iconDataForKey(_projectType().iconKey) ?? Icons.label_outline,
            ),
            label: Text('Type: ${_projectType().name}'),
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
