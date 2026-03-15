import 'package:flutter/material.dart';

import '../../domain/task_models.dart';
import 'item_icon_picker_sheet.dart';

class MoveProjectTaskSheet extends StatelessWidget {
  const MoveProjectTaskSheet({
    super.key,
    required this.projects,
    required this.projectTypes,
    required this.currentProjectId,
  });

  final List<ProjectItem> projects;
  final List<ProjectTypeConfig> projectTypes;
  final String currentProjectId;

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

  bool _acceptsRootTasks(ProjectItem project) {
    final ProjectTypeConfig projectType = _projectTypeFor(project);
    return projectType.id != ProjectTypeDefaults.peopleId &&
        projectType.supportsAnyEntries;
  }

  @override
  Widget build(BuildContext context) {
    final List<ProjectItem> targetProjects = <ProjectItem>[
      for (final ProjectItem project in projects)
        if (project.id != currentProjectId && _acceptsRootTasks(project))
          project,
    ];

    if (targetProjects.isEmpty) {
      return const SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No other projects available.'),
        ),
      );
    }

    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: <Widget>[
          const ListTile(
            title: Text(
              'Move task to project',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const Divider(height: 1),
          for (final ProjectItem targetProject in targetProjects)
            ListTile(
              leading: Icon(
                iconDataForKey(targetProject.iconKey) ??
                    iconDataForKey(_projectTypeFor(targetProject).iconKey) ??
                    Icons.folder_outlined,
              ),
              title: Text(targetProject.name),
              subtitle: Text(
                '${targetProject.tasks.length} task${targetProject.tasks.length == 1 ? '' : 's'}',
              ),
              onTap: () => Navigator.of(context).pop(targetProject.id),
            ),
        ],
      ),
    );
  }
}
