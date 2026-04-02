import 'package:flutter/material.dart';

import '../../domain/task_models.dart';
import 'item_icon_picker_sheet.dart';

class MoveProjectTaskSheet extends StatefulWidget {
  const MoveProjectTaskSheet({
    super.key,
    required this.projects,
    required this.projectStacks,
    required this.projectTypes,
    required this.currentProjectId,
  });

  final List<ProjectItem> projects;
  final List<ProjectStack> projectStacks;
  final List<ProjectTypeConfig> projectTypes;
  final String currentProjectId;

  @override
  State<MoveProjectTaskSheet> createState() => _MoveProjectTaskSheetState();
}

class _MoveProjectTaskSheetState extends State<MoveProjectTaskSheet> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _expandedStackIds = <String>{};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  ProjectTypeConfig _projectTypeFor(ProjectItem project) {
    return ProjectRules.resolveProjectType(
      project.projectTypeId,
      widget.projectTypes,
    );
  }

  bool _acceptsRootTasks(ProjectItem project) {
    return ProjectRules.forProject(
      project: project,
      projectTypes: widget.projectTypes,
    ).acceptsRootTasks;
  }

  List<ProjectItem> _targetProjects() {
    return <ProjectItem>[
      for (final ProjectItem project in widget.projects)
        if (project.id != widget.currentProjectId && _acceptsRootTasks(project))
          project,
    ];
  }

  ProjectStack? _stackById(String stackId) {
    for (final ProjectStack stack in widget.projectStacks) {
      if (stack.id == stackId) {
        return stack;
      }
    }
    return null;
  }

  String? _stackNameForProject(ProjectItem project) {
    final String? stackId = project.stackId;
    if (stackId == null || stackId.isEmpty) {
      return null;
    }
    return _stackById(stackId)?.name;
  }

  String _projectSubtitle(ProjectItem project) {
    final String taskLabel =
        '${project.tasks.length} task${project.tasks.length == 1 ? '' : 's'}';
    final String? stackName = _stackNameForProject(project);
    if (stackName == null || stackName.isEmpty) {
      return taskLabel;
    }
    return 'Stack: $stackName\n$taskLabel';
  }

  List<ProjectItem> _projectsInStack(
      String stackId, List<ProjectItem> projects) {
    return projects
        .where((ProjectItem project) => project.stackId == stackId)
        .toList(growable: false);
  }

  List<ProjectItem> _filteredProjects(List<ProjectItem> targetProjects) {
    final String query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return targetProjects;
    }

    return targetProjects.where((ProjectItem project) {
      final String projectName = project.name.toLowerCase();
      final String stackName =
          (_stackNameForProject(project) ?? '').toLowerCase();
      return projectName.contains(query) || stackName.contains(query);
    }).toList(growable: false);
  }

  List<ProjectStack> _matchingStacks(List<ProjectItem> targetProjects) {
    final String query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return widget.projectStacks
          .where(
            (ProjectStack stack) =>
                _projectsInStack(stack.id, targetProjects).isNotEmpty,
          )
          .toList(growable: false);
    }

    return widget.projectStacks.where((ProjectStack stack) {
      if (stack.name.toLowerCase().contains(query)) {
        return _projectsInStack(stack.id, targetProjects).isNotEmpty;
      }
      return false;
    }).toList(growable: false);
  }

  Widget _buildProjectTile(ProjectItem project) {
    return ListTile(
      leading: Icon(
        iconDataForKey(project.iconKey) ??
            iconDataForKey(_projectTypeFor(project).iconKey) ??
            Icons.folder_outlined,
      ),
      title: Text(project.name),
      subtitle: Text(_projectSubtitle(project)),
      isThreeLine: _stackNameForProject(project) != null,
      onTap: () => Navigator.of(context).pop(project.id),
    );
  }

  Widget _buildStackTile(ProjectStack stack, List<ProjectItem> targetProjects) {
    final List<ProjectItem> stackProjects =
        _projectsInStack(stack.id, targetProjects);
    final bool isExpanded = _expandedStackIds.contains(stack.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ListTile(
          leading: const Icon(Icons.layers_outlined),
          title: Text(stack.name),
          subtitle: Text(
            '${stackProjects.length} project${stackProjects.length == 1 ? '' : 's'}',
          ),
          trailing: Icon(
            isExpanded
                ? Icons.expand_less_outlined
                : Icons.expand_more_outlined,
          ),
          onTap: () {
            setState(() {
              if (isExpanded) {
                _expandedStackIds.remove(stack.id);
              } else {
                _expandedStackIds.add(stack.id);
              }
            });
          },
        ),
        if (isExpanded)
          for (final ProjectItem project in stackProjects)
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: _buildProjectTile(project),
            ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<ProjectItem> targetProjects = _targetProjects();

    if (targetProjects.isEmpty) {
      return const SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No other projects available.'),
        ),
      );
    }

    final List<ProjectItem> filteredProjects =
        _filteredProjects(targetProjects);
    final List<ProjectStack> matchingStacks = _matchingStacks(targetProjects);
    final bool hasQuery = _searchController.text.trim().isNotEmpty;

    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: 0.82,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const ListTile(
                title: Text(
                  'Move task to project',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Search projects or stacks',
                    prefixIcon: Icon(Icons.search_outlined),
                  ),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  children: <Widget>[
                    if (filteredProjects.isEmpty && matchingStacks.isEmpty)
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 16, 16, 24),
                        child: Text('No results'),
                      ),
                    if (filteredProjects.isNotEmpty) ...<Widget>[
                      if (hasQuery)
                        const ListTile(
                          title: Text(
                            'Matching projects',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      for (final ProjectItem project in filteredProjects)
                        _buildProjectTile(project),
                    ],
                    if (matchingStacks.isNotEmpty) ...<Widget>[
                      ListTile(
                        title: Text(
                          hasQuery ? 'Matching stacks' : 'Browse stacks',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: const Text(
                          'Tap a stack to show its projects.',
                        ),
                      ),
                      for (final ProjectStack stack in matchingStacks)
                        _buildStackTile(stack, targetProjects),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
