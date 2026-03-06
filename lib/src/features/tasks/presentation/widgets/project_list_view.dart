import 'package:flutter/material.dart';

import '../../domain/task_models.dart';

class ProjectListView extends StatelessWidget {
  const ProjectListView({
    super.key,
    required this.projects,
    required this.isReorderMode,
    required this.onEnterReorderMode,
    required this.onReorder,
    required this.onProjectTap,
  });

  final List<ProjectItem> projects;
  final bool isReorderMode;
  final VoidCallback onEnterReorderMode;
  final void Function(int oldIndex, int newIndex) onReorder;
  final Future<void> Function(String) onProjectTap;

  @override
  Widget build(BuildContext context) {
    if (projects.isEmpty) {
      return const Center(child: Text('No projects yet.'));
    }

    if (isReorderMode) {
      return ReorderableListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: projects.length,
        onReorder: onReorder,
        buildDefaultDragHandles: false,
        itemBuilder: (BuildContext context, int index) {
          final ProjectItem project = projects[index];
          final String taskCountLabel =
              '${project.tasks.length} task${project.tasks.length == 1 ? '' : 's'}';
          return Padding(
            key: ValueKey<String>(project.id),
            padding: const EdgeInsets.only(bottom: 4),
            child: Card(
              color: project.colorValue == null
                  ? null
                  : Color(project.colorValue!),
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
                  child: project.body.isEmpty
                      ? Text(taskCountLabel)
                      : Text('${project.body}\n$taskCountLabel'),
                ),
                isThreeLine: project.body.isNotEmpty,
                trailing: ReorderableDragStartListener(
                  index: index,
                  child: const Icon(Icons.drag_indicator_outlined),
                ),
              ),
            ),
          );
        },
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: projects.length,
      itemBuilder: (BuildContext context, int index) {
        final ProjectItem project = projects[index];
        final String taskCountLabel =
            '${project.tasks.length} task${project.tasks.length == 1 ? '' : 's'}';
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Card(
            color:
                project.colorValue == null ? null : Color(project.colorValue!),
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
                child: project.body.isEmpty
                    ? Text(taskCountLabel)
                    : Text('${project.body}\n$taskCountLabel'),
              ),
              isThreeLine: project.body.isNotEmpty,
              onTap: () async => onProjectTap(project.id),
              onLongPress: onEnterReorderMode,
            ),
          ),
        );
      },
    );
  }
}
