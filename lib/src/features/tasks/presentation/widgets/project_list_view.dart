import 'package:flutter/material.dart';

import '../../domain/task_models.dart';
import 'item_icon_picker_sheet.dart';

class _ProjectDragPayload {
  const _ProjectDragPayload({
    required this.projectIds,
  });

  final List<String> projectIds;
}

class _ProjectGroup {
  const _ProjectGroup({
    required this.label,
    required this.projects,
    required this.isStack,
    this.stackId,
  });

  final String label;
  final List<ProjectItem> projects;
  final bool isStack;
  final String? stackId;
}

class _ProjectReorderEntry {
  const _ProjectReorderEntry({
    required this.key,
    required this.label,
    required this.projectIds,
    required this.isStack,
    this.project,
    this.stackId,
  });

  final String key;
  final String label;
  final List<String> projectIds;
  final bool isStack;
  final ProjectItem? project;
  final String? stackId;
}

class ProjectListView extends StatefulWidget {
  const ProjectListView({
    super.key,
    required this.projects,
    required this.projectStacks,
    required this.projectTypes,
    required this.isReorderMode,
    required this.onVisibleProjectOrderChanged,
    required this.onProjectTap,
    required this.onProjectArchive,
    required this.onProjectRestore,
    required this.onProjectRemove,
    required this.onProjectLongPress,
    required this.onProjectOptionsTap,
    required this.onProjectStackDrop,
  });

  final List<ProjectItem> projects;
  final List<ProjectStack> projectStacks;
  final List<ProjectTypeConfig> projectTypes;
  final bool isReorderMode;
  final void Function(List<String> projectIds) onVisibleProjectOrderChanged;
  final Future<void> Function(String) onProjectTap;
  final void Function(String) onProjectArchive;
  final void Function(String) onProjectRestore;
  final void Function(String) onProjectRemove;
  final Future<void> Function(String) onProjectLongPress;
  final Future<void> Function(String) onProjectOptionsTap;
  final Future<void> Function(
    List<String> sourceProjectIds,
    List<String> targetProjectIds,
  )
      onProjectStackDrop;

  @override
  State<ProjectListView> createState() => _ProjectListViewState();
}

class _ProjectListViewState extends State<ProjectListView> {
  late final Set<String> _collapsedStackIds = widget.projectStacks
      .map((ProjectStack stack) => stack.id)
      .toSet();
  bool _showArchivedProjects = false;

  @override
  void didUpdateWidget(covariant ProjectListView oldWidget) {
    super.didUpdateWidget(oldWidget);

    final Set<String> validStackIds =
        widget.projectStacks.map((ProjectStack stack) => stack.id).toSet();
    final Set<String> previousStackIds =
        oldWidget.projectStacks.map((ProjectStack stack) => stack.id).toSet();
    _collapsedStackIds.addAll(
      validStackIds.difference(previousStackIds),
    );
    _collapsedStackIds
        .removeWhere((String stackId) => !validStackIds.contains(stackId));
  }

  Widget _buildLeading(ProjectItem project) {
    final IconData? iconData = iconDataForKey(project.iconKey) ??
        iconDataForKey(_projectTypeFor(project).iconKey);
    if (iconData == null) {
      return const Icon(Icons.folder_outlined);
    }
    return Icon(iconData);
  }

  ProjectTypeConfig _projectTypeFor(ProjectItem project) {
    final String targetId = project.projectTypeId ?? ProjectTypeDefaults.blankId;
    for (final ProjectTypeConfig type in widget.projectTypes) {
      if (type.id == targetId) {
        return type;
      }
    }
    return ProjectTypeConfig.defaults().first;
  }

  String? _stackNameForProject(ProjectItem project) {
    final String? stackId = project.stackId;
    if (stackId == null || stackId.isEmpty) {
      return null;
    }

    for (final ProjectStack stack in widget.projectStacks) {
      if (stack.id == stackId) {
        return stack.name;
      }
    }
    return null;
  }

  List<ProjectItem> _visibleProjects() {
    return widget.projects
        .where((ProjectItem project) => !project.isArchived)
        .toList(growable: false);
  }

  int _visibleTaskCount(ProjectItem project) {
    return project.tasks.where((TaskItem task) => !task.isArchived).length;
  }

  List<_ProjectGroup> _buildGroups(List<ProjectItem> sourceProjects) {
    final List<_ProjectGroup> groups = <_ProjectGroup>[];
    final Set<String> handledProjectIds = <String>{};

    for (final ProjectStack stack in widget.projectStacks) {
      final List<ProjectItem> stackProjects = sourceProjects
          .where((ProjectItem project) => project.stackId == stack.id)
          .toList(growable: false);
      if (stackProjects.isEmpty) {
        continue;
      }
      handledProjectIds
          .addAll(stackProjects.map((ProjectItem project) => project.id));
      groups.add(
        _ProjectGroup(
          label: stack.name,
          projects: stackProjects,
          isStack: true,
          stackId: stack.id,
        ),
      );
    }

    final List<ProjectItem> unstackedProjects = sourceProjects
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

  void _toggleStack(String stackId) {
    setState(() {
      if (_collapsedStackIds.contains(stackId)) {
        _collapsedStackIds.remove(stackId);
      } else {
        _collapsedStackIds.add(stackId);
      }
    });
  }

  void _reorderListItems<T>(
    List<T> items,
    int oldIndex,
    int newIndex,
  ) {
    if (oldIndex < 0 || oldIndex >= items.length) {
      return;
    }
    if (newIndex < 0 || newIndex > items.length) {
      return;
    }
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    if (newIndex == oldIndex) {
      return;
    }

    final T movedItem = items.removeAt(oldIndex);
    items.insert(newIndex, movedItem);
  }

  List<_ProjectReorderEntry> _buildReorderEntries(
    List<ProjectItem> sourceProjects,
  ) {
    final List<_ProjectReorderEntry> entries = <_ProjectReorderEntry>[];
    final Set<String> handledStackIds = <String>{};

    for (final ProjectItem project in sourceProjects) {
      final String? stackId = project.stackId;
      if (stackId == null || stackId.isEmpty) {
        entries.add(
          _ProjectReorderEntry(
            key: project.id,
            label: project.name,
            projectIds: <String>[project.id],
            isStack: false,
            project: project,
          ),
        );
        continue;
      }

      if (!handledStackIds.add(stackId)) {
        continue;
      }

      final String stackLabel = _stackNameForProject(project) ?? 'Stack';
      final List<String> stackProjectIds = sourceProjects
          .where((ProjectItem item) => item.stackId == stackId)
          .map((ProjectItem item) => item.id)
          .toList(growable: false);
      entries.add(
        _ProjectReorderEntry(
          key: 'stack-$stackId',
          label: stackLabel,
          projectIds: stackProjectIds,
          isStack: true,
          stackId: stackId,
        ),
      );
    }

    return entries;
  }

  Widget _buildGroupHeader(
    BuildContext context,
    _ProjectGroup group,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
      child: Text(
        group.label,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }

  Widget _buildSubtitle(
    BuildContext context,
    ProjectItem project, {
    bool showStackLabel = false,
  }) {
    final int taskCount =
        project.isArchived ? project.tasks.length : _visibleTaskCount(project);
    final String taskCountLabel =
        '$taskCount task${taskCount == 1 ? '' : 's'}';
    final String? stackName =
        showStackLabel ? _stackNameForProject(project) : null;
    final List<String> lines = <String>[
      if (stackName != null) 'Stack: $stackName',
      if (project.isArchived) 'Archived project',
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
    bool isArchivedView = false,
  }) {
    return Opacity(
      opacity: isArchivedView ? 0.82 : 1,
      child: AnimatedContainer(
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
            isThreeLine:
                showStackLabel || project.body.isNotEmpty || project.isArchived,
            trailing: IconButton(
              onPressed: onOptionsTap,
              tooltip: 'Project options',
              icon: const Icon(Icons.settings_outlined),
            ),
            onTap: onTap,
            onLongPress: onLongPress,
          ),
        ),
      ),
    );
  }

  Widget _buildArchiveBackground(
    BuildContext context, {
    required bool isArchivedView,
  }) {
    final bool restore = isArchivedView;
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: restore
            ? Theme.of(context).colorScheme.secondaryContainer
            : Theme.of(context).colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Icon(
        restore ? Icons.unarchive_outlined : Icons.archive_outlined,
        color: restore
            ? Theme.of(context).colorScheme.onSecondaryContainer
            : Theme.of(context).colorScheme.onTertiaryContainer,
      ),
    );
  }

  Widget _buildDeleteBackground(BuildContext context) {
    return Container(
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
    );
  }

  Widget _wrapProjectDismissible(
    BuildContext context, {
    required ProjectItem project,
    required Widget child,
  }) {
    return Dismissible(
      key: ValueKey<String>('project-swipe-${project.id}-${project.isArchived}'),
      direction: DismissDirection.horizontal,
      confirmDismiss: (DismissDirection direction) async {
        if (direction == DismissDirection.startToEnd) {
          if (project.isArchived) {
            widget.onProjectRestore(project.id);
          } else {
            widget.onProjectArchive(project.id);
          }
          return true;
        }
        return _confirmProjectRemoval(context);
      },
      onDismissed: (DismissDirection direction) {
        if (direction == DismissDirection.endToStart) {
          widget.onProjectRemove(project.id);
        }
      },
      background: _buildArchiveBackground(
        context,
        isArchivedView: project.isArchived,
      ),
      secondaryBackground: _buildDeleteBackground(context),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: child,
      ),
    );
  }

  Widget _buildArchivedStackProjectRow(
    BuildContext context,
    ProjectItem project,
  ) {
    final Widget row = Material(
      color: Colors.transparent,
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
          showStackLabel: false,
        ),
        isThreeLine: project.body.isNotEmpty || project.isArchived,
        trailing: IconButton(
          onPressed: () async => widget.onProjectOptionsTap(project.id),
          tooltip: 'Project options',
          icon: const Icon(Icons.settings_outlined),
        ),
        onTap: () async => widget.onProjectTap(project.id),
      ),
    );

    return _wrapProjectDismissible(
      context,
      project: project,
      child: Opacity(
        opacity: 0.82,
        child: row,
      ),
    );
  }

  Widget _buildStackProjectRow(
    BuildContext context,
    ProjectItem project,
  ) {
    if (project.isArchived) {
      return _buildArchivedStackProjectRow(context, project);
    }

    return DragTarget<_ProjectDragPayload>(
      onWillAcceptWithDetails: (
        DragTargetDetails<_ProjectDragPayload> details,
      ) {
        return !details.data.projectIds.contains(project.id);
      },
      onAcceptWithDetails: (
        DragTargetDetails<_ProjectDragPayload> details,
      ) async {
        await widget.onProjectStackDrop(details.data.projectIds, <String>[
          project.id,
        ]);
      },
      builder: (
        BuildContext context,
        List<_ProjectDragPayload?> candidateData,
        List<dynamic> rejectedData,
      ) {
        final bool isDropTarget = candidateData.isNotEmpty;
        final Widget row = Material(
          color: isDropTarget
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.10)
              : Colors.transparent,
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
              showStackLabel: false,
            ),
            isThreeLine: project.body.isNotEmpty,
            trailing: IconButton(
              onPressed: () async => widget.onProjectOptionsTap(project.id),
              tooltip: 'Project options',
              icon: const Icon(Icons.settings_outlined),
            ),
            onTap: () async => widget.onProjectTap(project.id),
          ),
        );

        return _wrapProjectDismissible(
          context,
          project: project,
          child: LongPressDraggable<_ProjectDragPayload>(
            data: _ProjectDragPayload(projectIds: <String>[project.id]),
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
              child: row,
            ),
            child: row,
          ),
        );
      },
    );
  }

  Widget _buildStackCard(
    BuildContext context,
    _ProjectGroup group,
  ) {
    final String stackId = group.stackId!;
    final bool isCollapsed = _collapsedStackIds.contains(stackId);
    final bool isArchivedView =
        group.projects.every((ProjectItem project) => project.isArchived);
    final String countLabel =
        '${group.projects.length} project${group.projects.length == 1 ? '' : 's'}';
    final List<String> projectIds = group.projects
        .map((ProjectItem project) => project.id)
        .toList(growable: false);

    final Widget stackCard = Card(
      margin: EdgeInsets.zero,
      child: Opacity(
        opacity: isArchivedView ? 0.82 : 1,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            InkWell(
              onTap: () => _toggleStack(stackId),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                leading: isCollapsed
                    ? const Icon(Icons.folder_copy_outlined)
                    : const SizedBox.square(dimension: 24),
                title: Text(
                  group.label,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(countLabel),
                ),
                trailing: Icon(
                  isCollapsed
                      ? Icons.chevron_right_outlined
                      : Icons.expand_more_outlined,
                ),
              ),
            ),
            if (!isCollapsed)
              for (final ProjectItem project in group.projects)
                _buildStackProjectRow(context, project),
          ],
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: isArchivedView
          ? stackCard
          : DragTarget<_ProjectDragPayload>(
              onWillAcceptWithDetails: (
                DragTargetDetails<_ProjectDragPayload> details,
              ) {
                return !details.data.projectIds.every(projectIds.contains);
              },
              onAcceptWithDetails: (
                DragTargetDetails<_ProjectDragPayload> details,
              ) async {
                await widget.onProjectStackDrop(details.data.projectIds, projectIds);
              },
              builder: (
                BuildContext context,
                List<_ProjectDragPayload?> candidateData,
                List<dynamic> rejectedData,
              ) {
                final bool isDropTarget = candidateData.isNotEmpty;
                final Widget highlighted = AnimatedContainer(
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
                  child: stackCard,
                );

                return LongPressDraggable<_ProjectDragPayload>(
                  data: _ProjectDragPayload(projectIds: projectIds),
                  feedback: Material(
                    color: Colors.transparent,
                    child: SizedBox(
                      width: MediaQuery.sizeOf(context).width - 24,
                      child: Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          leading: Icon(
                            isCollapsed
                                ? Icons.folder_copy_outlined
                                : Icons.folder_open_outlined,
                          ),
                          title: Text(group.label),
                          subtitle: Text(countLabel),
                        ),
                      ),
                    ),
                  ),
                  childWhenDragging: Opacity(
                    opacity: 0.35,
                    child: highlighted,
                  ),
                  child: highlighted,
                );
              },
            ),
    );
  }

  Widget _buildReorderItem(
    BuildContext context,
    List<_ProjectReorderEntry> entries,
    int index,
  ) {
    final _ProjectReorderEntry entry = entries[index];
    if (entry.isStack) {
      final int projectCount = entry.projectIds.length;
      return Padding(
        key: ValueKey<String>(entry.key),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
        child: Card(
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 6,
            ),
            leading: const Icon(Icons.folder_copy_outlined),
            title: Text(
              entry.label,
              style: Theme.of(context).textTheme.titleMedium,
              maxLines: null,
            ),
            subtitle: Text(
              '$projectCount project${projectCount == 1 ? '' : 's'}',
            ),
            trailing: ReorderableDragStartListener(
              index: index,
              child: const Icon(Icons.drag_indicator_outlined),
            ),
          ),
        ),
      );
    }

    final ProjectItem project = entry.project!;
    return Padding(
      key: ValueKey<String>(entry.key),
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
    bool isArchivedView = false,
  }) {
    return _buildProjectTile(
      context,
      project,
      showStackLabel: false,
      onTap: () async => widget.onProjectTap(project.id),
      onOptionsTap: () async => widget.onProjectOptionsTap(project.id),
      isDropTarget: isDropTarget,
      isArchivedView: isArchivedView,
    );
  }

  Widget _buildGroupedProjectItem(BuildContext context, ProjectItem project) {
    if (project.isArchived) {
      return _wrapProjectDismissible(
        context,
        project: project,
        child: _buildProjectCard(
          context,
          project,
          isDropTarget: false,
          isArchivedView: true,
        ),
      );
    }

    final Widget tile = _buildProjectCard(
      context,
      project,
      isDropTarget: false,
    );

    return DragTarget<_ProjectDragPayload>(
      onWillAcceptWithDetails: (
        DragTargetDetails<_ProjectDragPayload> details,
      ) {
        return !details.data.projectIds.contains(project.id);
      },
      onAcceptWithDetails: (
        DragTargetDetails<_ProjectDragPayload> details,
      ) async {
        await widget.onProjectStackDrop(details.data.projectIds, <String>[
          project.id,
        ]);
      },
      builder: (
        BuildContext context,
        List<_ProjectDragPayload?> candidateData,
        List<dynamic> rejectedData,
      ) {
        final bool isDropTarget = candidateData.isNotEmpty;
        return _wrapProjectDismissible(
          context,
          project: project,
          child: LongPressDraggable<_ProjectDragPayload>(
            data: _ProjectDragPayload(projectIds: <String>[project.id]),
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
        );
      },
    );
  }

  Widget _buildArchivedSection(
    BuildContext context,
    List<_ProjectGroup> archivedGroups,
  ) {
    final int archivedCount = archivedGroups.fold<int>(
      0,
      (int total, _ProjectGroup group) => total + group.projects.length,
    );

    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          InkWell(
            onTap: () {
              setState(() {
                _showArchivedProjects = !_showArchivedProjects;
              });
            },
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              leading: const Icon(Icons.archive_outlined),
              title: const Text('Archived projects'),
              subtitle: Text(
                '$archivedCount project${archivedCount == 1 ? '' : 's'}',
              ),
              trailing: Icon(
                _showArchivedProjects
                    ? Icons.expand_more_outlined
                    : Icons.chevron_right_outlined,
              ),
            ),
          ),
          if (_showArchivedProjects)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Column(
                children: archivedGroups.expand((_ProjectGroup group) {
                  return <Widget>[
                    if (group.isStack)
                      _buildStackCard(context, group)
                    else
                      _buildGroupHeader(context, group),
                    if (!group.isStack)
                      ...group.projects.map(
                        (ProjectItem project) =>
                            _buildGroupedProjectItem(context, project),
                      ),
                  ];
                }).toList(growable: false),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.projects.isEmpty) {
      return const Center(child: Text('No projects yet.'));
    }

    if (widget.isReorderMode) {
      final List<_ProjectReorderEntry> reorderEntries =
          _buildReorderEntries(_visibleProjects()).toList(growable: true);
      if (reorderEntries.isEmpty) {
        return const Center(child: Text('No active projects to reorder.'));
      }
      return ReorderableListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: reorderEntries.length,
        onReorder: (int oldIndex, int newIndex) {
          _reorderListItems<_ProjectReorderEntry>(
            reorderEntries,
            oldIndex,
            newIndex,
          );
          widget.onVisibleProjectOrderChanged(
            reorderEntries
                .expand(
                  (_ProjectReorderEntry entry) => entry.projectIds,
                )
                .toList(growable: false),
          );
        },
        buildDefaultDragHandles: false,
        itemBuilder: (BuildContext context, int index) =>
            _buildReorderItem(context, reorderEntries, index),
      );
    }

    final List<ProjectItem> activeProjects = _visibleProjects();
    final List<ProjectItem> archivedProjects = widget.projects
        .where((ProjectItem project) => project.isArchived)
        .toList(growable: false);
    final List<_ProjectGroup> activeGroups = _buildGroups(activeProjects);
    final List<_ProjectGroup> archivedGroups = _buildGroups(archivedProjects);

    return ListView(
      padding: const EdgeInsets.all(12),
      children: <Widget>[
        if (activeGroups.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'No active projects.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ...activeGroups.expand((_ProjectGroup group) {
          return <Widget>[
            if (group.isStack)
              _buildStackCard(context, group)
            else
              _buildGroupHeader(context, group),
            if (!group.isStack)
              ...group.projects.map(
                (ProjectItem project) => _buildGroupedProjectItem(context, project),
              ),
          ];
        }),
        if (archivedGroups.isNotEmpty)
          _buildArchivedSection(context, archivedGroups),
      ],
    );
  }
}
