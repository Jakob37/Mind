import 'package:flutter/material.dart';

import '../../domain/task_models.dart';

class ProjectListView extends StatelessWidget {
  const ProjectListView({
    super.key,
    required this.projects,
    required this.onProjectTap,
  });

  final List<ProjectItem> projects;
  final ValueChanged<int> onProjectTap;

  @override
  Widget build(BuildContext context) {
    if (projects.isEmpty) {
      return const Center(child: Text('No projects yet.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: projects.length,
      itemBuilder: (BuildContext context, int index) {
        final ProjectItem project = projects[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              leading: const Icon(Icons.folder_outlined),
              title: Text(
                project.name,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${project.tasks.length} task${project.tasks.length == 1 ? '' : 's'}',
                ),
              ),
              onTap: () => onProjectTap(index),
            ),
          ),
        );
      },
    );
  }
}
