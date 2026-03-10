import 'package:flutter/material.dart';

import '../../domain/task_models.dart';
import 'item_icon_picker_sheet.dart';

class ProjectListView extends StatelessWidget {
  const ProjectListView({
    super.key,
    required this.projects,
    required this.isReorderMode,
    required this.onReorder,
    required this.onProjectTap,
    required this.onProjectRemove,
    required this.onProjectLongPress,
    required this.onProjectOptionsTap,
  });

  final List<ProjectItem> projects;
  final bool isReorderMode;
  final void Function(int oldIndex, int newIndex) onReorder;
  final Future<void> Function(String) onProjectTap;
  final void Function(String) onProjectRemove;
  final Future<void> Function(String) onProjectLongPress;
  final Future<void> Function(String) onProjectOptionsTap;

  Widget _buildLeading(ProjectItem project) {
    final IconData? iconData = iconDataForKey(project.iconKey);
    if (iconData == null) {
      return const Icon(Icons.folder_outlined);
    }
    return Icon(iconData);
  }

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
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: Card(
              color: project.colorValue == null
                  ? null
                  : Color(project.colorValue!),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                leading: _buildLeading(project),
                title: Text(
                  project.name,
                  style: Theme.of(context).textTheme.titleMedium,
                  maxLines: null,
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
                leading: _buildLeading(project),
                title: Text(
                  project.name,
                  style: Theme.of(context).textTheme.titleMedium,
                  maxLines: null,
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: project.body.isEmpty
                      ? Text(taskCountLabel)
                      : Text('${project.body}\n$taskCountLabel'),
                ),
                isThreeLine: project.body.isNotEmpty,
                trailing: IconButton(
                  onPressed: () async => onProjectOptionsTap(project.id),
                  tooltip: 'Project options',
                  icon: const Icon(Icons.settings_outlined),
                ),
                onTap: () async => onProjectTap(project.id),
                onLongPress: () async => onProjectLongPress(project.id),
              ),
            ),
          ),
        );
      },
    );
  }
}
