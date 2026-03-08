import 'package:flutter/material.dart';

import '../../domain/task_models.dart';
import '../widgets/edit_task_sheet.dart';
import '../widgets/item_color_picker_sheet.dart';
import '../widgets/move_project_task_sheet.dart';

enum _ProjectTaskMenuAction {
  edit,
  setColor,
  moveToThinking,
  moveToPlanning,
  moveToProject,
  remove,
}

class ProjectDetailPage extends StatefulWidget {
  const ProjectDetailPage({
    super.key,
    required this.projectId,
    required this.initialProjects,
    required this.colorLabels,
    required this.onProjectsChanged,
  });

  final String projectId;
  final List<ProjectItem> initialProjects;
  final Map<int, String> colorLabels;
  final ValueChanged<List<ProjectItem>> onProjectsChanged;

  @override
  State<ProjectDetailPage> createState() => _ProjectDetailPageState();
}

class _ProjectDetailPageState extends State<ProjectDetailPage> {
  late final List<ProjectItem> _projects;
  bool _isReorderMode = false;

  @override
  void initState() {
    super.initState();
    _projects = _cloneProjects(widget.initialProjects);
  }

  List<ProjectItem> _cloneProjects(List<ProjectItem> projects) {
    return projects
        .map((ProjectItem project) => project.clone())
        .toList(growable: false);
  }

  void _notifyProjectsChanged() {
    widget.onProjectsChanged(_cloneProjects(_projects));
  }

  ProjectItem? _findProject() {
    for (final ProjectItem project in _projects) {
      if (project.id == widget.projectId) {
        return project;
      }
    }
    return null;
  }

  List<TaskItem> _tasksByType(ProjectItem project, TaskItemType type) {
    return project.tasks
        .where((TaskItem task) => task.type == type)
        .toList(growable: false);
  }

  int _findTaskIndex(ProjectItem project, String taskId) {
    return project.tasks.indexWhere((TaskItem task) => task.id == taskId);
  }

  void _enterReorderMode() {
    if (_isReorderMode) {
      return;
    }
    setState(() {
      _isReorderMode = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Drag mode enabled. Use drag handles to reorder tasks.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _exitReorderMode() {
    if (!_isReorderMode) {
      return;
    }
    setState(() {
      _isReorderMode = false;
    });
  }

  void _reorderTasks(ProjectItem project, int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= project.tasks.length) {
      return;
    }
    if (newIndex < 0 || newIndex > project.tasks.length) {
      return;
    }
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    if (newIndex == oldIndex) {
      return;
    }

    setState(() {
      final TaskItem movedTask = project.tasks.removeAt(oldIndex);
      project.tasks.insert(newIndex, movedTask);
    });
    _notifyProjectsChanged();
  }

  Future<_ProjectTaskMenuAction?> _showTaskMenu(TaskItem task) {
    final bool isThinking = task.type == TaskItemType.thinking;
    return showModalBottomSheet<_ProjectTaskMenuAction>(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: <Widget>[
              ListTile(
                title: Text(
                  task.title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Task options'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit task'),
                onTap: () =>
                    Navigator.of(context).pop(_ProjectTaskMenuAction.edit),
              ),
              ListTile(
                leading: const Icon(Icons.palette_outlined),
                title: const Text('Set color'),
                onTap: () =>
                    Navigator.of(context).pop(_ProjectTaskMenuAction.setColor),
              ),
              ListTile(
                leading: Icon(
                  isThinking
                      ? Icons.checklist_rtl_outlined
                      : Icons.lightbulb_outline,
                ),
                title: Text(
                  isThinking ? 'Move to planning' : 'Move to thinking',
                ),
                onTap: () => Navigator.of(context).pop(
                  isThinking
                      ? _ProjectTaskMenuAction.moveToPlanning
                      : _ProjectTaskMenuAction.moveToThinking,
                ),
              ),
              ListTile(
                leading: const Icon(Icons.drive_file_move_outlined),
                title: const Text('Move to project'),
                onTap: () => Navigator.of(context)
                    .pop(_ProjectTaskMenuAction.moveToProject),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Remove task'),
                onTap: () =>
                    Navigator.of(context).pop(_ProjectTaskMenuAction.remove),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openTaskMenu(String taskId) async {
    final ProjectItem? project = _findProject();
    if (project == null) {
      return;
    }

    final int taskIndex = _findTaskIndex(project, taskId);
    if (taskIndex < 0) {
      return;
    }

    final TaskItem task = project.tasks[taskIndex];
    final _ProjectTaskMenuAction? action = await _showTaskMenu(task);
    if (action == _ProjectTaskMenuAction.edit) {
      await _editTask(taskId);
      return;
    }
    if (action == _ProjectTaskMenuAction.setColor) {
      await _setTaskColor(taskId);
      return;
    }
    if (action == _ProjectTaskMenuAction.moveToThinking) {
      _setTaskType(taskId, TaskItemType.thinking);
      return;
    }
    if (action == _ProjectTaskMenuAction.moveToPlanning) {
      _setTaskType(taskId, TaskItemType.planning);
      return;
    }
    if (action == _ProjectTaskMenuAction.moveToProject) {
      await _moveTaskToAnotherProject(taskId);
      return;
    }
    if (action == _ProjectTaskMenuAction.remove) {
      _deleteTask(taskId);
    }
  }

  Future<void> _editTask(String taskId) async {
    final ProjectItem? project = _findProject();
    if (project == null) {
      return;
    }

    final int taskIndex = _findTaskIndex(project, taskId);
    if (taskIndex < 0) {
      return;
    }

    final TaskItem task = project.tasks[taskIndex];
    final TaskEditResult? result = await showModalBottomSheet<TaskEditResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => EditTaskSheet(
        initialTitle: task.title,
        initialBody: task.body,
      ),
    );

    if (result == null) {
      return;
    }

    setState(() {
      project.tasks[taskIndex] = TaskItem(
        id: task.id,
        title: result.title,
        body: result.body,
        colorValue: task.colorValue,
        type: task.type,
      );
    });
    _notifyProjectsChanged();
  }

  Future<void> _setTaskColor(String taskId) async {
    final ProjectItem? project = _findProject();
    if (project == null) {
      return;
    }

    final int taskIndex = _findTaskIndex(project, taskId);
    if (taskIndex < 0) {
      return;
    }
    final TaskItem task = project.tasks[taskIndex];

    final ColorSelection? selection =
        await showModalBottomSheet<ColorSelection>(
      context: context,
      builder: (_) => ItemColorPickerSheet(
        currentColorValue: task.colorValue,
        customLabels: widget.colorLabels,
      ),
    );

    if (selection == null) {
      return;
    }

    setState(() {
      project.tasks[taskIndex] = TaskItem(
        id: task.id,
        title: task.title,
        body: task.body,
        colorValue: selection.colorValue,
        type: task.type,
      );
    });
    _notifyProjectsChanged();
  }

  void _setTaskType(String taskId, TaskItemType type) {
    final ProjectItem? project = _findProject();
    if (project == null) {
      return;
    }

    final int taskIndex = _findTaskIndex(project, taskId);
    if (taskIndex < 0) {
      return;
    }

    final TaskItem task = project.tasks[taskIndex];
    if (task.type == type) {
      return;
    }

    setState(() {
      project.tasks[taskIndex] = TaskItem(
        id: task.id,
        title: task.title,
        body: task.body,
        colorValue: task.colorValue,
        type: type,
      );
    });
    _notifyProjectsChanged();
  }

  void _deleteTask(String taskId) {
    final ProjectItem? project = _findProject();
    if (project == null) {
      return;
    }

    final int taskIndex = _findTaskIndex(project, taskId);
    if (taskIndex < 0) {
      return;
    }

    setState(() {
      project.tasks.removeAt(taskIndex);
    });
    _notifyProjectsChanged();
  }

  Future<void> _moveTaskToAnotherProject(String taskId) async {
    final ProjectItem? sourceProject = _findProject();
    if (sourceProject == null) {
      return;
    }

    final String? targetProjectId = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => MoveProjectTaskSheet(
        projects: _projects,
        currentProjectId: widget.projectId,
      ),
    );

    if (targetProjectId == null) {
      return;
    }

    final int targetProjectIndex = _projects.indexWhere(
      (ProjectItem project) => project.id == targetProjectId,
    );
    if (targetProjectIndex < 0) {
      return;
    }

    final int sourceTaskIndex = _findTaskIndex(sourceProject, taskId);
    if (sourceTaskIndex < 0) {
      return;
    }

    setState(() {
      final TaskItem task = sourceProject.tasks.removeAt(sourceTaskIndex);
      _projects[targetProjectIndex].tasks.insert(0, task);
    });
    _notifyProjectsChanged();
  }

  Future<bool> _confirmTaskRemoval() async {
    final bool? shouldRemove = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Remove task?'),
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

  Widget _buildTaskCard({
    required TaskItem task,
    required VoidCallback? onTap,
    required VoidCallback? onLongPress,
    Widget? trailing,
  }) {
    final Widget? effectiveTrailing =
        switch ((task.body.isNotEmpty, trailing)) {
      (false, final Widget? customTrailing) => customTrailing,
      (true, null) => const Tooltip(
          message: 'Has text content',
          child: Icon(
            Icons.notes_outlined,
            size: 18,
          ),
        ),
      (true, final Widget customTrailing) => Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Tooltip(
              message: 'Has text content',
              child: Icon(
                Icons.notes_outlined,
                size: 18,
              ),
            ),
            customTrailing,
          ],
        ),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Card(
        color: task.colorValue == null ? null : Color(task.colorValue!),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 6,
          ),
          title: Text(
            task.title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          trailing: effectiveTrailing,
          onTap: onTap,
          onLongPress: onLongPress,
        ),
      ),
    );
  }

  Widget _buildTaskSection({
    required String title,
    required String emptyLabel,
    required List<TaskItem> tasks,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (tasks.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              emptyLabel,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        for (final TaskItem task in tasks)
          Dismissible(
            key: ValueKey<String>('project-task-swipe-${task.id}'),
            direction: DismissDirection.endToStart,
            confirmDismiss: (_) => _confirmTaskRemoval(),
            onDismissed: (_) => _deleteTask(task.id),
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
            child: _buildTaskCard(
              task: task,
              onTap: () => _openTaskMenu(task.id),
              onLongPress: _enterReorderMode,
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final ProjectItem? project = _findProject();
    if (project == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Project')),
        body: const Center(child: Text('Project not found.')),
      );
    }

    final List<TaskItem> thinkingTasks = _tasksByType(
      project,
      TaskItemType.thinking,
    );
    final List<TaskItem> planningTasks = _tasksByType(
      project,
      TaskItemType.planning,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(project.name),
        actions: <Widget>[
          if (_isReorderMode)
            IconButton(
              onPressed: _exitReorderMode,
              tooltip: 'Done reordering',
              icon: const Icon(Icons.check),
            ),
        ],
      ),
      body: project.tasks.isEmpty
          ? const Center(
              child: Text('No tasks in this project yet.'),
            )
          : _isReorderMode
              ? ReorderableListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: project.tasks.length,
                  onReorder: (int oldIndex, int newIndex) =>
                      _reorderTasks(project, oldIndex, newIndex),
                  buildDefaultDragHandles: false,
                  itemBuilder: (BuildContext context, int index) {
                    final TaskItem task = project.tasks[index];
                    return Container(
                      key: ValueKey<String>(task.id),
                      child: _buildTaskCard(
                        task: task,
                        onTap: null,
                        onLongPress: null,
                        trailing: ReorderableDragStartListener(
                          index: index,
                          child: const Icon(Icons.drag_indicator_outlined),
                        ),
                      ),
                    );
                  },
                )
              : ListView(
                  padding: const EdgeInsets.all(12),
                  children: <Widget>[
                    _buildTaskSection(
                      title: 'Thinking (ideas)',
                      emptyLabel: 'No ideas in this project yet.',
                      tasks: thinkingTasks,
                    ),
                    const SizedBox(height: 8),
                    _buildTaskSection(
                      title: 'Planning (action items)',
                      emptyLabel: 'No action items in this project yet.',
                      tasks: planningTasks,
                    ),
                  ],
                ),
    );
  }
}
