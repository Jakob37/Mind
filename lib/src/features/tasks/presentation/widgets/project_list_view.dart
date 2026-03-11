import 'package:flutter/material.dart';

import '../../domain/task_models.dart';
import 'item_icon_picker_sheet.dart';

class _ProjectGroup {
  const _ProjectGroup({
    required this.label,
    required this.projects,
    required this.isStack,
  });

  final String label;
  final List<ProjectItem> projects;
  final bool isStack;
}

class ProjectListView extends StatelessWidget {
  const ProjectListView({
    super.key,
    required this.projects,
    required this.projectStacks,
    required this.isReorderMode,
    required this.onReorder,
    required this.onProjectTap,
    required this.onProjectRemove,
    required this.onProjectLongPress,
    required this.onProjectOptionsTap,
    required this.onProjectStackDrop,
  });

  final List<ProjectItem> projects;
  final List<ProjectStack> projectStacks;
  final bool isReorderMode;
  final void Function(int oldIndex, int newIndex) onReorder;
  final Future<void> Function(String) onProjectTap;
  final void Function(String) onProjectRemove;
  final Future<void> Function(String) onProjectLongPress;
  final Future<void> Function(String) onProjectOptionsTap;
  final Future<void> Function(String sourceProjectId, String targetProjectId)
      onProjectStackDrop;

  Widget _buildLeading(ProjectItem project) {
    final IconData? iconData = iconDataForKey(project.iconKey);
    if (iconData == null) {
      return const Icon(Icons.folder_outlined);
    }
    return Icon(iconData);
  }

  String? _stackNameForProject(ProjectItem project) {
    final String? stackId = project.stackId;
    if (stackId == null || stackId.isEmpty) {
      return null;
    }

    for (final ProjectStack stack in projectStacks) {
      if (stack.id == stackId) {
        return stack.name;
      }
    }
    return null;
  }

  List<_ProjectGroup> _buildGroups() {
    final List<_ProjectGroup> groups = <_ProjectGroup>[];
    final Set<String> handledProjectIds = <String>{};

    for (final ProjectStack stack in projectStacks) {
      final List<ProjectItem> stackProjects = projects
          .where((ProjectItem project) => project.stackId == stack.id)
          .toList(growable: false);
      if (stackProjects.isEmpty) {
        continue;
      }
      handledProjectIds.addAll(
        stackProjects.map((ProjectItem project) => project.id),
      );
      groups.add(
        _ProjectGroup(
          label: stack.name,
          projects: stackProjects,
          isStack: true,
        ),
      );
    }

    final List<ProjectItem> unstackedProjects = projects
        .where((ProjectItem project) => !handledProjectIds.contains(project.id))
        .toList(growable: false);
    if (unstackedProjects.isNotEmpty) {
      groups.add(
        _ProjectGroup(
          label: 'Unstacked',
          projects: unstackedProjects,
          isStack: false,
        ),
      );
    }

    return groups;
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

  Widget _buildSubtitle(
    BuildContext context,
    ProjectItem project, {
    bool showStackLabel = false,
  }) {
    final String taskCountLabel =
        '${project.tasks.length} task${project.tasks.length == 1 ? '' : 's'}';
    final String? stackName = showStackLabel ? _stackNameForProject(project) : null;
    final List<String> lines = <String>[
      if (stackName != null) 'Stack: $stackName',
      if (project.body.isNotEmpty) project.body,
      taskCountLabel,
    ];

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(lines.join('\n')),
    );
  }

  Widget _buildProjectTile(
    BuildContext context,
    ProjectItem project, {
    required bool showStackLabel,
    required VoidCallback onTap,
    required VoidCallback onOptionsTap,
    VoidCallback? onLongPress,
    bool isDropTarget = false,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: isDropTarget
            ? Border.all(
                color: Theme.of(context).colorScheme.primary,
                width: 2,
              )
            : null,
      ),
      child: Card(
        color: project.colorValue == null ? null : Color(project.colorValue!),
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
          subtitle: _buildSubtitle(
            context,
            project,
            showStackLabel: showStackLabel,
          ),
          isThreeLine: showStackLabel || project.body.isNotEmpty,
          trailing: IconButton(
            onPressed: onOptionsTap,
            tooltip: 'Project options',
            icon: const Icon(Icons.settings_outlined),
          ),
          onTap: onTap,
          onLongPress: onLongPress,
        ),
      ),
    );
  }

  Widget _buildReorderItem(BuildContext context, int index) {
    final ProjectItem project = projects[index];
    return Padding(
      key: ValueKey<String>(project.id),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
      child: Card(
        color: project.colorValue == null ? null : Color(project.colorValue!),
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
          subtitle: _buildSubtitle(
            context,
            project,
            showStackLabel: project.stackId != null,
          ),
          isThreeLine: project.stackId != null || project.body.isNotEmpty,
          trailing: ReorderableDragStartListener(
            index: index,
            child: const Icon(Icons.drag_indicator_outlined),
          ),
        ),
      ),
    );
  }

  Widget _buildProjectCard(
    BuildContext context,
    ProjectItem project, {
    required bool isDropTarget,
  }) {
    return _buildProjectTile(
      context,
      project,
      showStackLabel: false,
      onTap: () async => onProjectTap(project.id),
      onOptionsTap: () async => onProjectOptionsTap(project.id),
      isDropTarget: isDropTarget,
    );
  }

  Widget _buildGroupedProjectItem(BuildContext context, ProjectItem project) {
    final Widget tile = _buildProjectCard(
      context,
      project,
      isDropTarget: false,
    );

    return DragTarget<String>(
      onWillAcceptWithDetails: (DragTargetDetails<String> details) {
        return details.data != project.id;
      },
      onAcceptWithDetails: (DragTargetDetails<String> details) async {
        await onProjectStackDrop(details.data, project.id);
      },
      builder: (
        BuildContext context,
        List<String?> candidateData,
        List<dynamic> rejectedData,
      ) {
        final bool isDropTarget = candidateData.isNotEmpty;
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
            child: LongPressDraggable<String>(
              data: project.id,
              feedback: Material(
                color: Colors.transparent,
                child: SizedBox(
                  width: MediaQuery.sizeOf(context).width - 24,
                  child: _buildProjectCard(
                    context,
                    project,
                    isDropTarget: false,
                  ),
                ),
              ),
              childWhenDragging: Opacity(
                opacity: 0.35,
                child: tile,
              ),
              child: _buildProjectCard(
                context,
                project,
                isDropTarget: isDropTarget,
              ),
            ),
          ),
        );
      },
    );
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
        itemBuilder: _buildReorderItem,
      );
    }

    final List<_ProjectGroup> groups = _buildGroups();
    final bool showAllHeaders = groups.length > 1 || groups.any((group) => group.isStack);

    return ListView(
      padding: const EdgeInsets.all(12),
      children: groups.expand(( _ProjectGroup group) {
        return <Widget>[
          if (showAllHeaders)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
              child: Text(
                group.label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ...group.projects.map(
            (ProjectItem project) => _buildGroupedProjectItem(context, project),
          ),
        ];
      }).toList(growable: false),
    );
  }
}
