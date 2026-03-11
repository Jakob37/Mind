import 'package:flutter/material.dart';

import '../../domain/task_models.dart';

enum ProjectStackSelectionMode {
  none,
  existing,
  createNew,
}

class ProjectStackSelection {
  const ProjectStackSelection.none()
      : mode = ProjectStackSelectionMode.none,
        stackId = null,
        stackName = null;

  const ProjectStackSelection.existing({
    required this.stackId,
  })  : mode = ProjectStackSelectionMode.existing,
        stackName = null;

  const ProjectStackSelection.createNew({
    required this.stackName,
  })  : mode = ProjectStackSelectionMode.createNew,
        stackId = null;

  final ProjectStackSelectionMode mode;
  final String? stackId;
  final String? stackName;
}

class SelectProjectStackSheet extends StatefulWidget {
  const SelectProjectStackSheet({
    super.key,
    required this.projectStacks,
    this.initialSelection = const ProjectStackSelection.none(),
    this.allowNoStack = true,
    this.title = 'Select Stack',
    this.confirmLabel = 'Save Stack',
  });

  final List<ProjectStack> projectStacks;
  final ProjectStackSelection initialSelection;
  final bool allowNoStack;
  final String title;
  final String confirmLabel;

  @override
  State<SelectProjectStackSheet> createState() => _SelectProjectStackSheetState();
}

class _SelectProjectStackSheetState extends State<SelectProjectStackSheet> {
  late ProjectStackSelectionMode _selectionMode;
  String? _selectedStackId;
  late final TextEditingController _newStackNameController;

  @override
  void initState() {
    super.initState();
    _selectionMode = widget.initialSelection.mode;
    _selectedStackId = widget.initialSelection.stackId;
    _newStackNameController = TextEditingController(
      text: widget.initialSelection.stackName ?? '',
    );
    if (!widget.allowNoStack &&
        _selectionMode == ProjectStackSelectionMode.none) {
      _selectionMode = widget.projectStacks.isEmpty
          ? ProjectStackSelectionMode.createNew
          : ProjectStackSelectionMode.existing;
      _selectedStackId = widget.projectStacks.isEmpty
          ? null
          : widget.projectStacks.first.id;
    }
  }

  @override
  void dispose() {
    _newStackNameController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_selectionMode == ProjectStackSelectionMode.none) {
      Navigator.of(context).pop(const ProjectStackSelection.none());
      return;
    }

    if (_selectionMode == ProjectStackSelectionMode.existing) {
      if (_selectedStackId == null || _selectedStackId!.isEmpty) {
        return;
      }
      Navigator.of(
        context,
      ).pop(ProjectStackSelection.existing(stackId: _selectedStackId!));
      return;
    }

    final String stackName = _newStackNameController.text.trim();
    if (stackName.isEmpty) {
      return;
    }
    Navigator.of(
      context,
    ).pop(ProjectStackSelection.createNew(stackName: stackName));
  }

  Widget _buildSelectionTile({
    required IconData icon,
    required String label,
    required ProjectStackSelectionMode mode,
    required VoidCallback onTap,
  }) {
    final bool isSelected = _selectionMode == mode;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(label),
      trailing: isSelected ? const Icon(Icons.check) : null,
      selected: isSelected,
      onTap: onTap,
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
            widget.title,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          if (widget.allowNoStack)
            _buildSelectionTile(
              icon: Icons.layers_clear_outlined,
              label: 'No stack',
              mode: ProjectStackSelectionMode.none,
              onTap: () {
                setState(() {
                  _selectionMode = ProjectStackSelectionMode.none;
                });
              },
            ),
          if (widget.projectStacks.isNotEmpty)
            _buildSelectionTile(
              icon: Icons.layers_outlined,
              label: 'Existing stack',
              mode: ProjectStackSelectionMode.existing,
              onTap: () {
                setState(() {
                  _selectionMode = ProjectStackSelectionMode.existing;
                  _selectedStackId ??= widget.projectStacks.first.id;
                });
              },
            ),
          if (widget.projectStacks.isNotEmpty &&
              _selectionMode == ProjectStackSelectionMode.existing)
            Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 12),
              child: DropdownButtonFormField<String>(
                initialValue: _selectedStackId == null ||
                        !widget.projectStacks.any(
                          (ProjectStack stack) => stack.id == _selectedStackId,
                        )
                    ? widget.projectStacks.first.id
                    : _selectedStackId,
                items: widget.projectStacks
                    .map(
                      (ProjectStack stack) => DropdownMenuItem<String>(
                        value: stack.id,
                        child: Text(stack.name),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (String? value) {
                  setState(() {
                    _selectedStackId = value;
                  });
                },
                decoration: const InputDecoration(
                  labelText: 'Stack',
                ),
              ),
            ),
          _buildSelectionTile(
            icon: Icons.add_box_outlined,
            label: 'Create stack',
            mode: ProjectStackSelectionMode.createNew,
            onTap: () {
              setState(() {
                _selectionMode = ProjectStackSelectionMode.createNew;
              });
            },
          ),
          if (_selectionMode == ProjectStackSelectionMode.createNew)
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: TextField(
                controller: _newStackNameController,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                decoration: const InputDecoration(
                  labelText: 'Stack name',
                  hintText: 'Focus Systems',
                ),
              ),
            ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _submit,
            child: Text(widget.confirmLabel),
          ),
        ],
      ),
    );
  }
}
