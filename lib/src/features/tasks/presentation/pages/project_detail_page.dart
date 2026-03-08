import 'package:flutter/material.dart';

import '../../domain/task_models.dart';
import '../widgets/add_task_sheet.dart';
import '../widgets/edit_task_sheet.dart';
import '../widgets/item_color_picker_sheet.dart';
import '../widgets/move_project_task_sheet.dart';
import 'task_detail_page.dart';

class _TaskSectionDragPayload {
  const _TaskSectionDragPayload({
    required this.taskId,
  });

  final String taskId;
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

  void _replaceProjectTasksBySections({
    required ProjectItem project,
    required List<TaskItem> thinkingTasks,
    required List<TaskItem> planningTasks,
  }) {
    project.tasks
      ..clear()
      ..addAll(thinkingTasks)
      ..addAll(planningTasks);
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
        content: Text(
          'Drag mode enabled. Drag tasks between sections.',
        ),
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

  Future<void> _openTaskView(String taskId) async {
    final ProjectItem? project = _findProject();
    if (project == null) {
      return;
    }

    final int taskIndex = _findTaskIndex(project, taskId);
    if (taskIndex < 0) {
      return;
    }

    final TaskItem task = project.tasks[taskIndex];
    final TaskDetailAction? action = await Navigator.of(
      context,
    ).push<TaskDetailAction>(
      MaterialPageRoute<TaskDetailAction>(
        builder: (_) => TaskDetailPage(
          task: task,
          onTaskChanged: (TaskItem updatedTask) {
            final ProjectItem? activeProject = _findProject();
            if (activeProject == null) {
              return;
            }
            final int sourceTaskIndex = _findTaskIndex(activeProject, taskId);
            if (sourceTaskIndex < 0) {
              return;
            }
            setState(() {
              activeProject.tasks[sourceTaskIndex] = updatedTask.clone();
            });
            _notifyProjectsChanged();
          },
          menuItems: <TaskDetailMenuItem>[
            const TaskDetailMenuItem(
              action: TaskDetailAction.edit,
              icon: Icons.edit_outlined,
              label: 'Edit task',
            ),
            const TaskDetailMenuItem(
              action: TaskDetailAction.setColor,
              icon: Icons.palette_outlined,
              label: 'Set color',
            ),
            TaskDetailMenuItem(
              action: task.type == TaskItemType.thinking
                  ? TaskDetailAction.moveToPlanning
                  : TaskDetailAction.moveToThinking,
              icon: task.type == TaskItemType.thinking
                  ? Icons.checklist_rtl_outlined
                  : Icons.lightbulb_outline,
              label: task.type == TaskItemType.thinking
                  ? 'Move to planning'
                  : 'Move to thinking',
            ),
            const TaskDetailMenuItem(
              action: TaskDetailAction.moveToProject,
              icon: Icons.drive_file_move_outlined,
              label: 'Move to project',
            ),
            const TaskDetailMenuItem(
              action: TaskDetailAction.remove,
              icon: Icons.delete_outline,
              label: 'Remove task',
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) {
      return;
    }

    if (action == TaskDetailAction.edit) {
      await _editTask(taskId);
      return;
    }
    if (action == TaskDetailAction.setColor) {
      await _setTaskColor(taskId);
      return;
    }
    if (action == TaskDetailAction.moveToThinking) {
      _setTaskType(taskId, TaskItemType.thinking);
      return;
    }
    if (action == TaskDetailAction.moveToPlanning) {
      _setTaskType(taskId, TaskItemType.planning);
      return;
    }
    if (action == TaskDetailAction.moveToProject) {
      await _moveTaskToAnotherProject(taskId);
      return;
    }
    if (action == TaskDetailAction.remove) {
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
        subtasks: task.subtasks
            .map((SubTaskItem subtask) => subtask.clone())
            .toList(),
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
        subtasks: task.subtasks
            .map((SubTaskItem subtask) => subtask.clone())
            .toList(),
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
        subtasks: task.subtasks
            .map((SubTaskItem subtask) => subtask.clone())
            .toList(),
      );
    });
    _notifyProjectsChanged();
  }

  void _moveTaskToPosition({
    required String taskId,
    required TaskItemType targetType,
    required int targetIndex,
  }) {
    final ProjectItem? project = _findProject();
    if (project == null) {
      return;
    }

    final List<TaskItem> thinkingTasks = _tasksByType(
      project,
      TaskItemType.thinking,
    ).toList(growable: true);
    final List<TaskItem> planningTasks = _tasksByType(
      project,
      TaskItemType.planning,
    ).toList(growable: true);

    TaskItem? sourceTask;
    TaskItemType? sourceType;
    int sourceIndex =
        thinkingTasks.indexWhere((TaskItem task) => task.id == taskId);
    if (sourceIndex >= 0) {
      sourceTask = thinkingTasks.removeAt(sourceIndex);
      sourceType = TaskItemType.thinking;
    } else {
      sourceIndex =
          planningTasks.indexWhere((TaskItem task) => task.id == taskId);
      if (sourceIndex >= 0) {
        sourceTask = planningTasks.removeAt(sourceIndex);
        sourceType = TaskItemType.planning;
      }
    }

    if (sourceTask == null || sourceType == null) {
      return;
    }

    final List<TaskItem> destinationTasks =
        targetType == TaskItemType.thinking ? thinkingTasks : planningTasks;

    int insertionIndex = targetIndex;
    if (sourceType == targetType && sourceIndex < insertionIndex) {
      insertionIndex -= 1;
    }
    insertionIndex = insertionIndex.clamp(0, destinationTasks.length);

    final TaskItem movedTask = sourceTask.type == targetType
        ? sourceTask
        : TaskItem(
            id: sourceTask.id,
            title: sourceTask.title,
            body: sourceTask.body,
            colorValue: sourceTask.colorValue,
            type: targetType,
            subtasks: sourceTask.subtasks
                .map((SubTaskItem subtask) => subtask.clone())
                .toList(),
          );

    destinationTasks.insert(insertionIndex, movedTask);

    setState(() {
      _replaceProjectTasksBySections(
        project: project,
        thinkingTasks: thinkingTasks,
        planningTasks: planningTasks,
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

  Future<TaskItemType?> _chooseTaskTypeForCreate() {
    return showModalBottomSheet<TaskItemType>(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: <Widget>[
              const ListTile(
                title: Text(
                  'Create task in',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.lightbulb_outline),
                title: const Text('Thinking (ideas)'),
                onTap: () => Navigator.of(context).pop(TaskItemType.thinking),
              ),
              ListTile(
                leading: const Icon(Icons.checklist_rtl_outlined),
                title: const Text('Planning (action items)'),
                onTap: () => Navigator.of(context).pop(TaskItemType.planning),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _addTaskToProject() async {
    final TaskItemType? selectedType = await _chooseTaskTypeForCreate();
    if (selectedType == null) {
      return;
    }
    if (!mounted) {
      return;
    }

    final TaskItem? createdTask = await showModalBottomSheet<TaskItem>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const AddTaskSheet(),
    );

    if (createdTask == null) {
      return;
    }
    if (!mounted) {
      return;
    }

    final ProjectItem? project = _findProject();
    if (project == null) {
      return;
    }

    final List<TaskItem> thinkingTasks = _tasksByType(
      project,
      TaskItemType.thinking,
    ).toList(growable: true);
    final List<TaskItem> planningTasks = _tasksByType(
      project,
      TaskItemType.planning,
    ).toList(growable: true);

    final TaskItem insertedTask = TaskItem(
      id: createdTask.id,
      title: createdTask.title,
      body: createdTask.body,
      colorValue: createdTask.colorValue,
      type: selectedType,
      subtasks: createdTask.subtasks
          .map((SubTaskItem subtask) => subtask.clone())
          .toList(),
    );

    if (selectedType == TaskItemType.thinking) {
      thinkingTasks.insert(0, insertedTask);
    } else {
      planningTasks.insert(0, insertedTask);
    }

    setState(() {
      _replaceProjectTasksBySections(
        project: project,
        thinkingTasks: thinkingTasks,
        planningTasks: planningTasks,
      );
    });
    _notifyProjectsChanged();
  }

  Widget _buildTaskCard({
    required TaskItem task,
    required VoidCallback? onTap,
    required VoidCallback? onLongPress,
    Widget? trailing,
    double bottomPadding = 4,
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
      padding: EdgeInsets.only(bottom: bottomPadding),
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
              onTap: () => _openTaskView(task.id),
              onLongPress: _enterReorderMode,
            ),
          ),
      ],
    );
  }

  Widget _buildDropSlot({
    required TaskItemType sectionType,
    required int targetIndex,
    required double inactiveHeight,
  }) {
    return DragTarget<_TaskSectionDragPayload>(
      onWillAcceptWithDetails: (
        DragTargetDetails<_TaskSectionDragPayload> details,
      ) {
        return true;
      },
      onAcceptWithDetails: (
        DragTargetDetails<_TaskSectionDragPayload> details,
      ) {
        _moveTaskToPosition(
          taskId: details.data.taskId,
          targetType: sectionType,
          targetIndex: targetIndex,
        );
      },
      builder: (
        BuildContext context,
        List<_TaskSectionDragPayload?> candidateData,
        List<dynamic> rejectedData,
      ) {
        final bool isActiveDropTarget = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: isActiveDropTarget ? 24 : inactiveHeight,
          decoration: BoxDecoration(
            color: isActiveDropTarget
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.22)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
        );
      },
    );
  }

  Widget _buildDraggableTaskCard(TaskItem task) {
    return Draggable<_TaskSectionDragPayload>(
      data: _TaskSectionDragPayload(taskId: task.id),
      feedback: Material(
        color: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Card(
            color: task.colorValue == null ? null : Color(task.colorValue!),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              child: Text(
                task.title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.45,
        child: _buildTaskCard(
          task: task,
          onTap: null,
          onLongPress: null,
          trailing: const Icon(Icons.drag_indicator_outlined),
          bottomPadding: 0,
        ),
      ),
      child: _buildTaskCard(
        task: task,
        onTap: null,
        onLongPress: null,
        trailing: const Tooltip(
          message: 'Drag',
          child: Icon(Icons.drag_indicator_outlined),
        ),
        bottomPadding: 0,
      ),
    );
  }

  Widget _buildReorderTaskSection({
    required String title,
    required String emptyLabel,
    required List<TaskItem> tasks,
    required TaskItemType sectionType,
  }) {
    return DragTarget<_TaskSectionDragPayload>(
      onWillAcceptWithDetails: (
        DragTargetDetails<_TaskSectionDragPayload> details,
      ) {
        return true;
      },
      onAcceptWithDetails: (
        DragTargetDetails<_TaskSectionDragPayload> details,
      ) {
        _moveTaskToPosition(
          taskId: details.data.taskId,
          targetType: sectionType,
          targetIndex: tasks.length,
        );
      },
      builder: (
        BuildContext context,
        List<_TaskSectionDragPayload?> candidateData,
        List<dynamic> rejectedData,
      ) {
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
            _buildDropSlot(
              sectionType: sectionType,
              targetIndex: 0,
              inactiveHeight: tasks.isEmpty ? 4 : 0,
            ),
            for (int i = 0; i < tasks.length; i++) ...<Widget>[
              _buildDraggableTaskCard(tasks[i]),
              _buildDropSlot(
                sectionType: sectionType,
                targetIndex: i + 1,
                inactiveHeight: 4,
              ),
            ],
          ],
        );
      },
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
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: <Widget>[
          if (_isReorderMode)
            _buildReorderTaskSection(
              title: 'Thinking (ideas)',
              emptyLabel: 'Drop ideas here.',
              tasks: thinkingTasks,
              sectionType: TaskItemType.thinking,
            )
          else
            _buildTaskSection(
              title: 'Thinking (ideas)',
              emptyLabel: 'No ideas in this project yet.',
              tasks: thinkingTasks,
            ),
          const SizedBox(height: 8),
          if (_isReorderMode)
            _buildReorderTaskSection(
              title: 'Planning (action items)',
              emptyLabel: 'Drop action items here.',
              tasks: planningTasks,
              sectionType: TaskItemType.planning,
            )
          else
            _buildTaskSection(
              title: 'Planning (action items)',
              emptyLabel: 'No action items in this project yet.',
              tasks: planningTasks,
            ),
        ],
      ),
      floatingActionButton: _isReorderMode
          ? null
          : FloatingActionButton(
              onPressed: _addTaskToProject,
              tooltip: 'Add project task',
              child: const Icon(Icons.add),
            ),
    );
  }
}
