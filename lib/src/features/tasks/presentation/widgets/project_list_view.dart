import 'package:flutter/material.dart';

import '../../domain/task_models.dart';
import 'card_layout.dart';
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

class ProjectListView extends StatefulWidget {
  const ProjectListView({
    super.key,
    required this.projects,
    required this.projectStacks,
    required this.projectTypes,
    required this.cardLayoutPreset,
    required this.onVisibleProjectOrderChanged,
    required this.onProjectTap,
    required this.onProjectArchive,
    required this.onProjectRestore,
    required this.onProjectRemove,
    required this.onProjectOptionsTap,
    required this.onProjectStackOptionsTap,
    required this.onProjectStackDrop,
  });

  final List<ProjectItem> projects;
  final List<ProjectStack> projectStacks;
  final List<ProjectTypeConfig> projectTypes;
  final CardLayoutPreset cardLayoutPreset;
  final void Function(List<String> projectIds) onVisibleProjectOrderChanged;
  final Future<void> Function(String) onProjectTap;
  final void Function(String) onProjectArchive;
  final void Function(String) onProjectRestore;
  final void Function(String) onProjectRemove;
  final Future<void> Function(String) onProjectOptionsTap;
  final Future<void> Function(String) onProjectStackOptionsTap;
  final Future<void> Function(
    List<String> sourceProjectIds,
    List<String> targetProjectIds,
  ) onProjectStackDrop;

  @override
  State<ProjectListView> createState() => _ProjectListViewState();
}

class _ProjectListViewState extends State<ProjectListView> {
  late final Set<String> _collapsedStackIds =
      widget.projectStacks.map((ProjectStack stack) => stack.id).toSet();
  bool _showArchivedProjects = false;

  CardLayoutSpec get _layout =>
      cardLayoutSpecForPreset(widget.cardLayoutPreset);

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
    final String targetId =
        project.projectTypeId ?? ProjectTypeDefaults.blankId;
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

  ProjectStack? _projectStackById(String stackId) {
    for (final ProjectStack stack in widget.projectStacks) {
      if (stack.id == stackId) {
        return stack;
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
    final Set<String> handledStackIds = <String>{};

    for (final ProjectItem project in sourceProjects) {
      final String? stackId = project.stackId;
      if (stackId == null || stackId.isEmpty) {
        groups.add(
          _ProjectGroup(
            label: project.name,
            projects: <ProjectItem>[project],
            isStack: false,
          ),
        );
        continue;
      }

      if (!handledStackIds.add(stackId)) {
        continue;
      }

      final List<ProjectItem> stackProjects = sourceProjects
          .where((ProjectItem item) => item.stackId == stackId)
          .toList(growable: false);
      groups.add(
        _ProjectGroup(
          label: _stackNameForProject(project) ?? project.name,
          projects: stackProjects,
          isStack: true,
          stackId: stackId,
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

  List<String> _reorderedProjectIdsForDrop({
    required List<_ProjectGroup> groups,
    required List<String> draggedProjectIds,
    required int targetGroupIndex,
  }) {
    final Set<String> draggedIdSet = draggedProjectIds.toSet();
    int insertionIndex = 0;
    for (int index = 0;
        index < targetGroupIndex && index < groups.length;
        index += 1) {
      insertionIndex += groups[index]
          .projects
          .where((ProjectItem project) => !draggedIdSet.contains(project.id))
          .length;
    }
    final List<String> reorderedIds = groups
        .expand(
          (_ProjectGroup group) => group.projects
              .map((ProjectItem project) => project.id)
              .where((String projectId) => !draggedIdSet.contains(projectId)),
        )
        .toList(growable: true);
    reorderedIds.insertAll(
      insertionIndex.clamp(0, reorderedIds.length),
      draggedProjectIds,
    );
    return reorderedIds;
  }

  Widget _buildGroupDropSlot(
    BuildContext context, {
    required List<_ProjectGroup> groups,
    required int targetGroupIndex,
    required double inactiveHeight,
  }) {
    return DragTarget<_ProjectDragPayload>(
      onWillAcceptWithDetails: (
        DragTargetDetails<_ProjectDragPayload> details,
      ) {
        return true;
      },
      onAcceptWithDetails: (DragTargetDetails<_ProjectDragPayload> details) {
        widget.onVisibleProjectOrderChanged(
          _reorderedProjectIdsForDrop(
            groups: groups,
            draggedProjectIds: details.data.projectIds,
            targetGroupIndex: targetGroupIndex,
          ),
        );
      },
      builder: (
        BuildContext context,
        List<_ProjectDragPayload?> candidateData,
        List<dynamic> rejectedData,
      ) {
        final bool isActive = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: isActive ? 22 : inactiveHeight,
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: isActive
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.22)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
        );
      },
    );
  }

  Widget _buildSubtitle(
    BuildContext context,
    ProjectItem project, {
    bool showStackLabel = false,
  }) {
    final int taskCount =
        project.isArchived ? project.tasks.length : _visibleTaskCount(project);
    final String taskCountLabel = '$taskCount task${taskCount == 1 ? '' : 's'}';
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
    bool isDropTarget = false,
    bool isArchivedView = false,
    bool showOptionsButton = false,
  }) {
    final TextStyle? titleStyle =
        Theme.of(context).textTheme.titleMedium?.copyWith(
              fontSize:
                  (Theme.of(context).textTheme.titleMedium?.fontSize ?? 16) *
                      _layout.titleScale,
            );
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
            contentPadding: _layout.contentPadding,
            leading: _buildLeading(project),
            title: Text(
              project.name,
              style: titleStyle,
              maxLines: null,
            ),
            subtitle: _buildSubtitle(
              context,
              project,
              showStackLabel: showStackLabel,
            ),
            isThreeLine:
                showStackLabel || project.body.isNotEmpty || project.isArchived,
            trailing: showOptionsButton
                ? IconButton(
                    tooltip: 'Project options',
                    onPressed: () async =>
                        widget.onProjectOptionsTap(project.id),
                    icon: const Icon(Icons.more_vert),
                  )
                : null,
            onTap: onTap,
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
      margin: EdgeInsets.only(bottom: _layout.listBottomSpacing),
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
      margin: EdgeInsets.only(bottom: _layout.listBottomSpacing),
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
      key:
          ValueKey<String>('project-swipe-${project.id}-${project.isArchived}'),
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
        padding: EdgeInsets.only(bottom: _layout.listBottomSpacing),
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
        contentPadding: _layout.contentPadding,
        leading: _buildLeading(project),
        title: Text(
          project.name,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize:
                    (Theme.of(context).textTheme.titleMedium?.fontSize ?? 16) *
                        _layout.titleScale,
              ),
          maxLines: null,
        ),
        subtitle: _buildSubtitle(
          context,
          project,
          showStackLabel: false,
        ),
        isThreeLine: project.body.isNotEmpty || project.isArchived,
        trailing: IconButton(
          tooltip: 'Project options',
          onPressed: () async => widget.onProjectOptionsTap(project.id),
          icon: const Icon(Icons.more_vert),
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
            contentPadding: _layout.contentPadding,
            leading: _buildLeading(project),
            title: Text(
              project.name,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize:
                        (Theme.of(context).textTheme.titleMedium?.fontSize ??
                                16) *
                            _layout.titleScale,
                  ),
              maxLines: null,
            ),
            subtitle: _buildSubtitle(
              context,
              project,
              showStackLabel: false,
            ),
            isThreeLine: project.body.isNotEmpty,
            trailing: IconButton(
              tooltip: 'Project options',
              onPressed: () async => widget.onProjectOptionsTap(project.id),
              icon: const Icon(Icons.more_vert),
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
    final ProjectStack? stack = _projectStackById(stackId);
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
      color: stack?.colorValue == null ? null : Color(stack!.colorValue!),
      child: Opacity(
        opacity: isArchivedView ? 0.82 : 1,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              onTap: () => _toggleStack(stackId),
              contentPadding: _layout.contentPadding,
              leading: Icon(
                isCollapsed
                    ? Icons.folder_copy_outlined
                    : Icons.folder_open_outlined,
              ),
              title: Text(
                group.label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontSize:
                          (Theme.of(context).textTheme.titleMedium?.fontSize ??
                                  16) *
                              _layout.titleScale,
                    ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(countLabel),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  IconButton(
                    tooltip: 'Stack settings',
                    onPressed: () async =>
                        widget.onProjectStackOptionsTap(stackId),
                    icon: const Icon(Icons.more_vert),
                  ),
                  Icon(
                    isCollapsed
                        ? Icons.chevron_right_outlined
                        : Icons.expand_more_outlined,
                  ),
                ],
              ),
            ),
            if (!isCollapsed) const Divider(height: 1),
            if (!isCollapsed)
              for (final ProjectItem project in group.projects)
                _buildStackProjectRow(context, project),
          ],
        ),
      ),
    );

    return Padding(
      padding: EdgeInsets.only(bottom: _layout.listBottomSpacing + 6),
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
                await widget.onProjectStackDrop(
                    details.data.projectIds, projectIds);
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
                          contentPadding: _layout.contentPadding,
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

  Widget _buildProjectCard(
    BuildContext context,
    ProjectItem project, {
    required bool isDropTarget,
    bool isArchivedView = false,
    bool showOptionsButton = false,
  }) {
    return _buildProjectTile(
      context,
      project,
      showStackLabel: false,
      onTap: () async => widget.onProjectTap(project.id),
      isDropTarget: isDropTarget,
      isArchivedView: isArchivedView,
      showOptionsButton: showOptionsButton,
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
          showOptionsButton: true,
        ),
      );
    }

    final Widget tile = _buildProjectCard(
      context,
      project,
      isDropTarget: false,
      showOptionsButton: true,
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
              showOptionsButton: true,
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
              contentPadding: _layout.contentPadding,
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
                      _buildGroupedProjectItem(context, group.projects.single),
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
        if (activeGroups.isNotEmpty)
          _buildGroupDropSlot(
            context,
            groups: activeGroups,
            targetGroupIndex: 0,
            inactiveHeight: 0,
          ),
        for (int index = 0;
            index < activeGroups.length;
            index += 1) ...<Widget>[
          activeGroups[index].isStack
              ? _buildStackCard(context, activeGroups[index])
              : _buildGroupedProjectItem(
                  context,
                  activeGroups[index].projects.single,
                ),
          _buildGroupDropSlot(
            context,
            groups: activeGroups,
            targetGroupIndex: index + 1,
            inactiveHeight: 4,
          ),
        ],
        if (archivedGroups.isNotEmpty)
          _buildArchivedSection(context, archivedGroups),
      ],
    );
  }
}
