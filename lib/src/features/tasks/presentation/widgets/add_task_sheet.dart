import 'package:flutter/material.dart';

import '../../domain/task_models.dart';
import 'item_color_picker_sheet.dart';
import 'item_icon_picker_sheet.dart';

class AddTaskResult {
  const AddTaskResult({
    required this.task,
    required this.insertAtTop,
    this.targetProjectId,
  });

  final TaskItem task;
  final bool insertAtTop;
  final String? targetProjectId;
}

class AddTaskSheet extends StatefulWidget {
  const AddTaskSheet({
    super.key,
    this.projects = const <ProjectItem>[],
    this.projectTypes = const <ProjectTypeConfig>[],
  });

  final List<ProjectItem> projects;
  final List<ProjectTypeConfig> projectTypes;

  @override
  State<AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends State<AddTaskSheet> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  final TextEditingController _promptController = TextEditingController();
  final FocusNode _titleFocusNode = FocusNode();
  bool _insertAtTop = true;
  bool _showBodyField = false;
  bool _showPromptField = false;
  int? _colorValue;
  String? _iconKey;
  String? _targetProjectId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _titleFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _promptController.dispose();
    _titleFocusNode.dispose();
    super.dispose();
  }

  Future<void> _pickIcon() async {
    final String? iconKey = await showModalBottomSheet<String?>(
      context: context,
      builder: (_) => ItemIconPickerSheet(
        currentIconKey: _iconKey,
      ),
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _iconKey = iconKey;
    });
  }

  Future<void> _pickColor() async {
    final ColorSelection? selection =
        await showModalBottomSheet<ColorSelection>(
      context: context,
      builder: (_) => ItemColorPickerSheet(
        currentColorValue: _colorValue,
      ),
    );
    if (selection == null || !mounted) {
      return;
    }
    setState(() {
      _colorValue = selection.colorValue;
    });
  }

  Future<void> _selectProject() async {
    final String? projectId = await showModalBottomSheet<String?>(
      context: context,
      builder: (_) => _SelectProjectSheet(
        projects: widget.projects,
        projectTypes: widget.projectTypes,
        currentProjectId: _targetProjectId,
      ),
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _targetProjectId = projectId;
    });
  }

  String _projectLabel() {
    if (_targetProjectId == null || _targetProjectId!.isEmpty) {
      return 'Incoming';
    }

    for (final ProjectItem project in widget.projects) {
      if (project.id == _targetProjectId) {
        return project.name;
      }
    }
    return 'Incoming';
  }

  Widget _buildColorPreview(BuildContext context) {
    if (_colorValue == null) {
      return Icon(
        Icons.palette_outlined,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      );
    }
    return CircleAvatar(
      radius: 10,
      backgroundColor: Color(_colorValue!),
    );
  }

  String _iconLabel() {
    final String? label = iconLabelForKey(_iconKey);
    if (label == null || label.isEmpty) {
      return 'No icon';
    }
    return label;
  }

  void _saveTask() {
    final String title = _titleController.text.trim();
    if (title.isEmpty) {
      return;
    }

    Navigator.of(context).pop(
      AddTaskResult(
        task: TaskItem(
          title: title,
          body: _bodyController.text.trim(),
          prompt: _promptController.text.trim(),
          colorValue: _colorValue,
          iconKey: _iconKey,
        ),
        insertAtTop: _insertAtTop,
        targetProjectId: _targetProjectId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
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
            focusNode: _titleFocusNode,
            autofocus: true,
            textInputAction: TextInputAction.newline,
            keyboardType: TextInputType.multiline,
            minLines: 1,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Title',
              alignLabelWithHint: true,
              hintText: 'Capture a new idea or action',
            ),
          ),
          const SizedBox(height: 12),
          if (widget.projects.isNotEmpty) ...<Widget>[
            OutlinedButton.icon(
              onPressed: _selectProject,
              icon: const Icon(Icons.folder_open_outlined),
              label: Text('Project: ${_projectLabel()}'),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickIcon,
                  icon: Icon(
                    iconDataForKey(_iconKey) ?? Icons.add_reaction_outlined,
                  ),
                  label: Text('Icon: ${_iconLabel()}'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickColor,
                  icon: _buildColorPreview(context),
                  label: const Text('Color'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              children: <Widget>[
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _showBodyField = !_showBodyField;
                    });
                  },
                  icon: Icon(
                    _showBodyField
                        ? Icons.visibility_off_outlined
                        : Icons.notes_outlined,
                  ),
                  label: Text(_showBodyField ? 'Hide body' : 'Show body'),
                ),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _showPromptField = !_showPromptField;
                    });
                  },
                  icon: Icon(
                    _showPromptField
                        ? Icons.visibility_off_outlined
                        : Icons.memory_outlined,
                  ),
                  label: Text(_showPromptField ? 'Hide prompt' : 'Show prompt'),
                ),
              ],
            ),
          ),
          if (_showBodyField) ...<Widget>[
            const SizedBox(height: 4),
            TextField(
              controller: _bodyController,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Body',
                alignLabelWithHint: true,
              ),
            ),
          ],
          if (_showPromptField) ...<Widget>[
            const SizedBox(height: 12),
            TextField(
              controller: _promptController,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Prompt',
                alignLabelWithHint: true,
              ),
            ),
          ],
          const SizedBox(height: 12),
          SegmentedButton<bool>(
            segments: const <ButtonSegment<bool>>[
              ButtonSegment<bool>(
                value: true,
                label: Text('Add at top'),
                icon: Icon(Icons.vertical_align_top_outlined),
              ),
              ButtonSegment<bool>(
                value: false,
                label: Text('Add at bottom'),
                icon: Icon(Icons.vertical_align_bottom_outlined),
              ),
            ],
            selected: <bool>{_insertAtTop},
            onSelectionChanged: (Set<bool> selection) {
              setState(() {
                _insertAtTop = selection.first;
              });
            },
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _saveTask,
            child: Text(
              _targetProjectId == null ? 'Save Task' : 'Save to Project',
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectProjectSheet extends StatelessWidget {
  const _SelectProjectSheet({
    required this.projects,
    required this.projectTypes,
    required this.currentProjectId,
  });

  final List<ProjectItem> projects;
  final List<ProjectTypeConfig> projectTypes;
  final String? currentProjectId;

  ProjectTypeConfig _projectTypeFor(ProjectItem project) {
    final String targetId =
        project.projectTypeId ?? ProjectTypeDefaults.blankId;
    for (final ProjectTypeConfig type in projectTypes) {
      if (type.id == targetId) {
        return type;
      }
    }
    return ProjectTypeConfig.defaults().first;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: <Widget>[
          const ListTile(
            title: Text(
              'Add task to',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.inbox_outlined),
            title: const Text('Incoming'),
            trailing: currentProjectId == null
                ? const Icon(Icons.check_outlined)
                : null,
            onTap: () => Navigator.of(context).pop<String?>(null),
          ),
          const Divider(height: 1),
          for (final ProjectItem project in projects)
            ListTile(
              leading: Icon(
                iconDataForKey(project.iconKey) ??
                    iconDataForKey(_projectTypeFor(project).iconKey) ??
                    Icons.folder_outlined,
              ),
              title: Text(project.name),
              trailing: currentProjectId == project.id
                  ? const Icon(Icons.check_outlined)
                  : null,
              onTap: () => Navigator.of(context).pop<String?>(project.id),
            ),
        ],
      ),
    );
  }
}
