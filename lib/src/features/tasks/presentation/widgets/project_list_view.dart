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
    required this.onProjectRemove,
  });

  final List<ProjectItem> projects;
  final bool isReorderMode;
  final VoidCallback onEnterReorderMode;
  final void Function(int oldIndex, int newIndex) onReorder;
  final Future<void> Function(String) onProjectTap;
  final void Function(String) onProjectRemove;

  Future<bool> _confirmProjectRemoval(BuildContext context) async {
    final bool? shouldRemove = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Remove project?'),
          content: const Text('This action cannot be undone.'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );
    return shouldRemove ?? false;
  }

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
        return Dismissible(
          key: ValueKey<String>('project-swipe-${project.id}'),
          direction: DismissDirection.endToStart,
          confirmDismiss: (_) => _confirmProjectRemoval(context),
          onDismissed: (_) => onProjectRemove(project.id),
          background: Container(),
          secondaryBackground: Container(
            margin: const EdgeInsets.only(bottom: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Icon(
              Icons.delete_outline,
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
          ),
          child: Padding(
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
                onTap: () async => onProjectTap(project.id),
                onLongPress: onEnterReorderMode,
              ),
            ),
          ),
        );
      },
    );
  }
}
