import 'package:flutter/material.dart';

import '../../domain/task_models.dart';

class MoveProjectTaskSheet extends StatelessWidget {
  const MoveProjectTaskSheet({
    super.key,
    required this.projects,
    required this.currentProjectId,
  });

  final List<ProjectItem> projects;
  final String currentProjectId;

  @override
  Widget build(BuildContext context) {
    final List<ProjectItem> targetProjects = <ProjectItem>[
      for (final ProjectItem project in projects)
        if (project.id != currentProjectId) project,
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
              leading: const Icon(Icons.folder_outlined),
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
