import 'package:flutter/material.dart';

import '../../domain/task_models.dart';
import '../widgets/add_task_sheet.dart';
import '../widgets/edit_task_sheet.dart';
import '../widgets/item_color_picker_sheet.dart';
import '../widgets/item_icon_picker_sheet.dart';
import '../widgets/move_project_task_sheet.dart';
import 'task_detail_page.dart';

class _TaskSectionDragPayload {
  const _TaskSectionDragPayload({
    required this.taskId,
  });

  final String taskId;
}

enum _ProjectTaskMenuAction {
  open,
  edit,
  setIcon,
  setColor,
  moveBetweenSections,
  moveToProject,
  archive,
  restore,
  remove,
}

class ProjectDetailPage extends StatefulWidget {
  const ProjectDetailPage({
    super.key,
    required this.projectId,
    required this.initialProjects,
    required this.projectTypes,
    required this.colorLabels,
    required this.hideCompletedProjectItems,
    required this.onProjectsChanged,
  });

  final String projectId;
  final List<ProjectItem> initialProjects;
  final List<ProjectTypeConfig> projectTypes;
  final Map<int, String> colorLabels;
  final bool hideCompletedProjectItems;
  final ValueChanged<List<ProjectItem>> onProjectsChanged;

  @override
  State<ProjectDetailPage> createState() => _ProjectDetailPageState();
}

class _ProjectDetailPageState extends State<ProjectDetailPage> {
  late final List<ProjectItem> _projects;
  bool _isReorderMode = false;
  bool _showArchivedTasks = false;
  final Set<String> _expandedProjectTaskIds = <String>{};
  final Set<String> _expandedPreviewSubtaskIds = <String>{};

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

  List<TaskItem> _tasksByType(
    ProjectItem project,
    TaskItemType type, {
    bool includeArchived = false,
  }) {
    return project.tasks
        .where(
          (TaskItem task) => task.type == type &&
              (includeArchived || !task.isArchived),
        )
        .toList(growable: false);
  }

  List<TaskItem> _archivedTasks(ProjectItem project) {
    return project.tasks
        .where((TaskItem task) => task.isArchived)
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

  bool _showsIdeasSection(ProjectItem project) {
    final ProjectTypeConfig projectType = _projectTypeFor(project);
    return projectType.showsIdeas ||
        _tasksByType(project, TaskItemType.thinking).isNotEmpty;
  }

  bool _showsPlanningSection(ProjectItem project) {
    final ProjectTypeConfig projectType = _projectTypeFor(project);
    return projectType.showsPlanningTasks ||
        _tasksByType(project, TaskItemType.planning).isNotEmpty;
  }

  bool _canCreateTasks(ProjectItem project) {
    return _projectTypeFor(project).supportsAnyTasks;
  }

  TaskItem _taskAdjustedForProjectType(
    TaskItem task,
    ProjectTypeConfig projectType,
  ) {
    if (projectType.showsIdeas && !projectType.showsPlanningTasks) {
      return task.type == TaskItemType.thinking
          ? task
          : task.copyWith(type: TaskItemType.thinking);
    }
    if (!projectType.showsIdeas && projectType.showsPlanningTasks) {
      return task.type == TaskItemType.planning
          ? task
          : task.copyWith(type: TaskItemType.planning);
    }
    return task;
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

  void _toggleProjectTaskExpanded(String taskId) {
    setState(() {
      if (_expandedProjectTaskIds.contains(taskId)) {
        _expandedProjectTaskIds.remove(taskId);
      } else {
        _expandedProjectTaskIds.add(taskId);
      }
    });
  }

  void _togglePreviewSubtaskExpanded(String subTaskId) {
    setState(() {
      if (_expandedPreviewSubtaskIds.contains(subTaskId)) {
        _expandedPreviewSubtaskIds.remove(subTaskId);
      } else {
        _expandedPreviewSubtaskIds.add(subTaskId);
      }
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
    final bool canMoveBetweenSections =
        _projectTypeFor(project).showsIdeas &&
        _projectTypeFor(project).showsPlanningTasks;
    final TaskDetailAction? action = await Navigator.of(
      context,
    ).push<TaskDetailAction>(
      MaterialPageRoute<TaskDetailAction>(
        builder: (_) => TaskDetailPage(
          task: task,
          colorLabels: widget.colorLabels,
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
              action: TaskDetailAction.setIcon,
              icon: Icons.add_reaction_outlined,
              label: 'Set icon',
            ),
            const TaskDetailMenuItem(
              action: TaskDetailAction.setColor,
              icon: Icons.palette_outlined,
              label: 'Set color',
            ),
            if (canMoveBetweenSections)
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
          hideCompletedProjectItems: widget.hideCompletedProjectItems,
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
    if (action == TaskDetailAction.setIcon) {
      await _setTaskIcon(taskId);
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

  Future<_ProjectTaskMenuAction?> _showTaskMenu(TaskItem task) {
    final ProjectItem? project = _findProject();
    final bool canMoveToOtherSection = project != null &&
        _projectTypeFor(project).showsIdeas &&
        _projectTypeFor(project).showsPlanningTasks;
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
                leading: const Icon(Icons.open_in_new_outlined),
                title: const Text('Open task'),
                onTap: () =>
                    Navigator.of(context).pop(_ProjectTaskMenuAction.open),
              ),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit task'),
                onTap: () =>
                    Navigator.of(context).pop(_ProjectTaskMenuAction.edit),
              ),
              ListTile(
                leading: const Icon(Icons.add_reaction_outlined),
                title: const Text('Set icon'),
                onTap: () =>
                    Navigator.of(context).pop(_ProjectTaskMenuAction.setIcon),
              ),
              ListTile(
                leading: const Icon(Icons.palette_outlined),
                title: const Text('Set color'),
                onTap: () =>
                    Navigator.of(context).pop(_ProjectTaskMenuAction.setColor),
              ),
              if (canMoveToOtherSection)
                ListTile(
                  leading: Icon(
                    task.type == TaskItemType.thinking
                        ? Icons.checklist_rtl_outlined
                        : Icons.lightbulb_outline,
                  ),
                  title: Text(
                    task.type == TaskItemType.thinking
                        ? 'Move to action items'
                        : 'Move to ideas',
                  ),
                  onTap: () => Navigator.of(context)
                      .pop(_ProjectTaskMenuAction.moveBetweenSections),
                ),
              ListTile(
                leading: const Icon(Icons.drive_file_move_outlined),
                title: const Text('Move to project'),
                onTap: () => Navigator.of(context)
                    .pop(_ProjectTaskMenuAction.moveToProject),
              ),
              ListTile(
                leading: Icon(
                  task.isArchived
                      ? Icons.unarchive_outlined
                      : Icons.archive_outlined,
                ),
                title: Text(
                  task.isArchived ? 'Restore task' : 'Archive task',
                ),
                onTap: () => Navigator.of(context).pop(
                  task.isArchived
                      ? _ProjectTaskMenuAction.restore
                      : _ProjectTaskMenuAction.archive,
                ),
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

  Future<void> _openTaskQuickMenu(String taskId) async {
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
    if (!mounted || action == null) {
      return;
    }

    if (action == _ProjectTaskMenuAction.open) {
      await _openTaskView(taskId);
      return;
    }
    if (action == _ProjectTaskMenuAction.edit) {
      await _editTask(taskId);
      return;
    }
    if (action == _ProjectTaskMenuAction.setIcon) {
      await _setTaskIcon(taskId);
      return;
    }
    if (action == _ProjectTaskMenuAction.setColor) {
      await _setTaskColor(taskId);
      return;
    }
    if (action == _ProjectTaskMenuAction.moveBetweenSections) {
      _setTaskType(
        taskId,
        task.type == TaskItemType.thinking
            ? TaskItemType.planning
            : TaskItemType.thinking,
      );
      return;
    }
    if (action == _ProjectTaskMenuAction.moveToProject) {
      await _moveTaskToAnotherProject(taskId);
      return;
    }
    if (action == _ProjectTaskMenuAction.archive) {
      _archiveTask(taskId);
      return;
    }
    if (action == _ProjectTaskMenuAction.restore) {
      _restoreTask(taskId);
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
      project.tasks[taskIndex] = task.copyWith(
        title: result.title,
        body: result.body,
      );
    });
    _notifyProjectsChanged();
  }

  Future<void> _setTaskIcon(String taskId) async {
    final ProjectItem? project = _findProject();
    if (project == null) {
      return;
    }

    final int taskIndex = _findTaskIndex(project, taskId);
    if (taskIndex < 0) {
      return;
    }
    final TaskItem task = project.tasks[taskIndex];

    final String? iconKey = await showModalBottomSheet<String?>(
      context: context,
      builder: (_) => ItemIconPickerSheet(
        currentIconKey: task.iconKey,
      ),
    );

    if (!mounted) {
      return;
    }
    if (iconKey == task.iconKey) {
      return;
    }

    setState(() {
      project.tasks[taskIndex] = task.copyWith(
        iconKey: iconKey,
        clearIcon: iconKey == null,
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
      project.tasks[taskIndex] =
          task.copyWith(colorValue: selection.colorValue);
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
      project.tasks[taskIndex] = task.copyWith(type: type);
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

  void _nestTaskUnderTask({
    required String sourceTaskId,
    required String targetTaskId,
  }) {
    if (sourceTaskId == targetTaskId) {
      return;
    }

    final ProjectItem? project = _findProject();
    if (project == null) {
      return;
    }

    final int sourceIndex = _findTaskIndex(project, sourceTaskId);
    final int targetIndex = _findTaskIndex(project, targetTaskId);
    if (sourceIndex < 0 || targetIndex < 0) {
      return;
    }

    final TaskItem sourceTask = project.tasks[sourceIndex];
    final SubTaskItem nestedItem = SubTaskItem(
      title: sourceTask.title,
      body: sourceTask.body,
      colorValue: sourceTask.colorValue,
      iconKey: sourceTask.iconKey,
      children: sourceTask.subtasks
          .map((SubTaskItem item) => item.clone())
          .toList(growable: false),
    );

    setState(() {
      project.tasks.removeAt(sourceIndex);
      final int adjustedTargetIndex =
          sourceIndex < targetIndex ? targetIndex - 1 : targetIndex;
      final TaskItem adjustedTarget = project.tasks[adjustedTargetIndex];
      project.tasks[adjustedTargetIndex] = adjustedTarget.copyWith(
        subtasks: <SubTaskItem>[
          nestedItem,
          ...adjustedTarget.subtasks.map((SubTaskItem item) => item.clone()),
        ],
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

    final TaskItem removedTask = project.tasks[taskIndex].clone();
    setState(() {
      project.tasks.removeAt(taskIndex);
    });
    _showUndoTaskDeletion(
      message: 'Task removed from project.',
      onUndo: () {
        final ProjectItem? activeProject = _findProject();
        if (activeProject == null) {
          return;
        }
        setState(() {
          final int insertIndex = taskIndex <= activeProject.tasks.length
              ? taskIndex
              : activeProject.tasks.length;
          activeProject.tasks.insert(insertIndex, removedTask);
        });
        _notifyProjectsChanged();
      },
    );
    _notifyProjectsChanged();
  }

  void _archiveTask(String taskId) {
    final ProjectItem? project = _findProject();
    if (project == null) {
      return;
    }

    final int taskIndex = _findTaskIndex(project, taskId);
    if (taskIndex < 0) {
      return;
    }

    final TaskItem task = project.tasks[taskIndex];
    if (task.isArchived) {
      return;
    }

    setState(() {
      project.tasks[taskIndex] = task.copyWith(isArchived: true);
      _isReorderMode = false;
    });
    _notifyProjectsChanged();
    _showUndoTaskDeletion(
      message: 'Task archived.',
      onUndo: () {
        final ProjectItem? activeProject = _findProject();
        if (activeProject == null) {
          return;
        }
        final int currentIndex = _findTaskIndex(activeProject, taskId);
        if (currentIndex < 0) {
          return;
        }
        setState(() {
          activeProject.tasks[currentIndex] = activeProject.tasks[currentIndex]
              .copyWith(isArchived: false);
        });
        _notifyProjectsChanged();
      },
    );
  }

  void _restoreTask(String taskId) {
    final ProjectItem? project = _findProject();
    if (project == null) {
      return;
    }

    final int taskIndex = _findTaskIndex(project, taskId);
    if (taskIndex < 0) {
      return;
    }

    final TaskItem task = project.tasks[taskIndex];
    if (!task.isArchived) {
      return;
    }

    setState(() {
      project.tasks[taskIndex] = task.copyWith(isArchived: false);
    });
    _notifyProjectsChanged();
  }

  void _toggleProjectArchived() {
    final ProjectItem? project = _findProject();
    if (project == null) {
      return;
    }

    final bool nextArchived = !project.isArchived;
    setState(() {
      final int projectIndex =
          _projects.indexWhere((ProjectItem item) => item.id == project.id);
      if (projectIndex < 0) {
        return;
      }
      _projects[projectIndex] = project.copyWith(isArchived: nextArchived);
      if (nextArchived) {
        _isReorderMode = false;
      }
    });
    _notifyProjectsChanged();
  }

  void _showUndoTaskDeletion({
    required String message,
    required VoidCallback onUndo,
  }) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          action: SnackBarAction(
            label: 'Revert?',
            onPressed: onUndo,
          ),
        ),
      );
  }

  Future<void> _moveTaskToAnotherProject(String taskId) async {
    final ProjectItem? sourceProject = _findProject();
    if (sourceProject == null) {
      return;
    }

    final List<ProjectItem> targetProjects = <ProjectItem>[
      for (final ProjectItem project in _projects)
        if (project.id != widget.projectId &&
            !project.isArchived &&
            _projectTypeFor(project).supportsAnyTasks)
          project,
    ];

    final String? targetProjectId = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => MoveProjectTaskSheet(
        projects: targetProjects,
        projectTypes: widget.projectTypes,
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
      final ProjectItem targetProject = _projects[targetProjectIndex];
      final TaskItem adjustedTask = _taskAdjustedForProjectType(
        task,
        _projectTypeFor(targetProject),
      );
      _projects[targetProjectIndex].tasks.insert(0, adjustedTask);
    });
    _notifyProjectsChanged();
  }

  Future<TaskItemType?> _chooseTaskTypeForCreate() {
    final ProjectItem? project = _findProject();
    if (project == null) {
      return Future<TaskItemType?>.value(null);
    }
    final ProjectTypeConfig projectType = _projectTypeFor(project);
    if (projectType.showsIdeas && !projectType.showsPlanningTasks) {
      return Future<TaskItemType?>.value(TaskItemType.thinking);
    }
    if (!projectType.showsIdeas && projectType.showsPlanningTasks) {
      return Future<TaskItemType?>.value(TaskItemType.planning);
    }
    if (!projectType.supportsAnyTasks) {
      return Future<TaskItemType?>.value(null);
    }

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

    final AddTaskResult? createdTask =
        await showModalBottomSheet<AddTaskResult>(
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
      id: createdTask.task.id,
      title: createdTask.task.title,
      body: createdTask.task.body,
      colorValue: createdTask.task.colorValue,
      type: selectedType,
      iconKey: createdTask.task.iconKey,
      subtasks: createdTask.task.subtasks
          .map((SubTaskItem subtask) => subtask.clone())
          .toList(),
    );

    if (selectedType == TaskItemType.thinking) {
      if (createdTask.insertAtTop) {
        thinkingTasks.insert(0, insertedTask);
      } else {
        thinkingTasks.add(insertedTask);
      }
    } else {
      if (createdTask.insertAtTop) {
        planningTasks.insert(0, insertedTask);
      } else {
        planningTasks.add(insertedTask);
      }
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
    bool showNestedPreview = false,
    Widget? trailing,
    double bottomPadding = 4,
  }) {
    final IconData? iconData = iconDataForKey(task.iconKey);
    final bool hasNestedItems = task.subtasks.isNotEmpty;
    final bool isExpanded = _expandedProjectTaskIds.contains(task.id);
    final List<Widget> trailingParts = <Widget>[
      if (showNestedPreview && hasNestedItems)
        IconButton(
          onPressed: () => _toggleProjectTaskExpanded(task.id),
          tooltip: isExpanded ? 'Collapse ideas' : 'Expand ideas',
          icon: Icon(
            isExpanded
                ? Icons.expand_more_outlined
                : Icons.chevron_right_outlined,
          ),
        ),
      if (task.subtasks.isNotEmpty)
        Tooltip(
          message: task.subtasks.length == 1
              ? '1 subtask'
              : '${task.subtasks.length} subtasks',
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '${task.subtasks.length}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ),
      if (task.body.isNotEmpty)
        const Tooltip(
          message: 'Has text content',
          child: Icon(
            Icons.notes_outlined,
            size: 18,
          ),
        ),
      if (trailing != null) trailing,
    ];

    final Widget? effectiveTrailing = trailingParts.isEmpty
        ? null
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (int i = 0; i < trailingParts.length; i++) ...<Widget>[
                if (i > 0) const SizedBox(width: 8),
                trailingParts[i],
              ],
            ],
          );

    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Column(
        children: <Widget>[
          Opacity(
            opacity: task.isArchived ? 0.78 : 1,
            child: Card(
              color: task.colorValue == null ? null : Color(task.colorValue!),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                leading: iconData == null ? null : Icon(iconData),
                title: Text(
                  task.title,
                  style: Theme.of(context).textTheme.titleMedium,
                  maxLines: null,
                ),
                trailing: effectiveTrailing,
                onTap: onTap,
                onLongPress: onLongPress,
              ),
            ),
          ),
          if (showNestedPreview && hasNestedItems && isExpanded)
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 8, bottom: 8),
              child: _buildPreviewSubtaskList(task.subtasks, 0),
            ),
        ],
      ),
    );
  }

  Widget _buildPreviewSubtaskList(List<SubTaskItem> items, int depth) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: items
          .map(
            (SubTaskItem item) => _buildPreviewSubtaskNode(item, depth),
          )
          .toList(growable: false),
    );
  }

  Widget _buildPreviewSubtaskNode(SubTaskItem subTask, int depth) {
    final bool hasChildren = subTask.children.isNotEmpty;
    final bool isExpanded = _expandedPreviewSubtaskIds.contains(subTask.id);
    final IconData? iconData = iconDataForKey(subTask.iconKey);
    final List<Widget> trailingParts = <Widget>[
      if (subTask.body.isNotEmpty)
        const Tooltip(
          message: 'Has text content',
          child: Icon(
            Icons.notes_outlined,
            size: 18,
          ),
        ),
      if (iconData != null)
        Icon(
          iconData,
          size: 18,
        ),
    ];

    return Padding(
      padding: EdgeInsets.only(left: depth * 18.0, top: 4),
      child: Column(
        children: <Widget>[
          Card(
            margin: EdgeInsets.zero,
            color:
                subTask.colorValue == null ? null : Color(subTask.colorValue!),
            child: ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 2,
              ),
              leading: hasChildren
                  ? IconButton(
                      onPressed: () => _togglePreviewSubtaskExpanded(subTask.id),
                      tooltip:
                          isExpanded ? 'Collapse nested ideas' : 'Expand nested ideas',
                      icon: Icon(
                        isExpanded
                            ? Icons.expand_more_outlined
                            : Icons.chevron_right_outlined,
                      ),
                    )
                  : Icon(
                      iconData ?? Icons.subdirectory_arrow_right_outlined,
                      size: 20,
                    ),
              title: Text(
                subTask.title,
                maxLines: null,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              subtitle: subTask.body.isEmpty
                  ? null
                  : Text(
                      subTask.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
              trailing: trailingParts.isEmpty
                  ? null
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        for (int i = 0; i < trailingParts.length; i++) ...<Widget>[
                          if (i > 0) const SizedBox(width: 8),
                          trailingParts[i],
                        ],
                      ],
                    ),
            ),
          ),
          if (hasChildren && isExpanded)
            _buildPreviewSubtaskList(subTask.children, depth + 1),
        ],
      ),
    );
  }

  Widget _buildTaskSection({
    required String title,
    required String emptyLabel,
    required List<TaskItem> tasks,
    bool showNestedPreview = false,
    bool isArchivedSection = false,
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
            direction: DismissDirection.horizontal,
            confirmDismiss: (DismissDirection direction) async {
              if (direction == DismissDirection.startToEnd) {
                if (task.isArchived) {
                  _restoreTask(task.id);
                } else {
                  _archiveTask(task.id);
                }
                return true;
              }
              return true;
            },
            onDismissed: (DismissDirection direction) {
              if (direction == DismissDirection.endToStart) {
                _deleteTask(task.id);
              }
            },
            background: Container(
              margin: const EdgeInsets.only(bottom: 4),
              decoration: BoxDecoration(
                color: task.isArchived
                    ? Theme.of(context).colorScheme.secondaryContainer
                    : Theme.of(context).colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Icon(
                task.isArchived
                    ? Icons.unarchive_outlined
                    : Icons.archive_outlined,
                color: task.isArchived
                    ? Theme.of(context).colorScheme.onSecondaryContainer
                    : Theme.of(context).colorScheme.onTertiaryContainer,
              ),
            ),
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
              onLongPress: () => _openTaskQuickMenu(task.id),
              showNestedPreview: showNestedPreview && !isArchivedSection,
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
    return DragTarget<_TaskSectionDragPayload>(
      onWillAcceptWithDetails:
          (DragTargetDetails<_TaskSectionDragPayload> details) {
        return details.data.taskId != task.id;
      },
      onAcceptWithDetails:
          (DragTargetDetails<_TaskSectionDragPayload> details) {
        _nestTaskUnderTask(
          sourceTaskId: details.data.taskId,
          targetTaskId: task.id,
        );
      },
      builder: (
        BuildContext context,
        List<_TaskSectionDragPayload?> candidateData,
        List<dynamic> rejectedData,
      ) {
        final bool isHovering = candidateData.isNotEmpty;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: isHovering
                  ? Border.all(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    )
                  : null,
            ),
            child: Draggable<_TaskSectionDragPayload>(
              data: _TaskSectionDragPayload(taskId: task.id),
              feedback: Material(
                color: Colors.transparent,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 280),
                  child: Card(
                    color: task.colorValue == null
                        ? null
                        : Color(task.colorValue!),
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
                trailing: Tooltip(
                  message: isHovering ? 'Drop to nest' : 'Drag',
                  child: const Icon(Icons.drag_indicator_outlined),
                ),
                bottomPadding: 0,
              ),
            ),
          ),
        );
      },
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

  Widget _buildArchivedTaskSection(List<TaskItem> archivedTasks) {
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          InkWell(
            onTap: () {
              setState(() {
                _showArchivedTasks = !_showArchivedTasks;
              });
            },
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              leading: const Icon(Icons.archive_outlined),
              title: const Text('Archived'),
              subtitle: Text(
                '${archivedTasks.length} task${archivedTasks.length == 1 ? '' : 's'}',
              ),
              trailing: Icon(
                _showArchivedTasks
                    ? Icons.expand_more_outlined
                    : Icons.chevron_right_outlined,
              ),
            ),
          ),
          if (_showArchivedTasks)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: _buildTaskSection(
                title: 'Archived',
                emptyLabel: 'No archived tasks.',
                tasks: archivedTasks,
                isArchivedSection: true,
              ),
            ),
        ],
      ),
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
    final List<TaskItem> archivedTasks = _archivedTasks(project);
    final bool showsIdeasSection = _showsIdeasSection(project);
    final bool showsPlanningSection = _showsPlanningSection(project);
    final bool canCreateTasks = _canCreateTasks(project);
    final IconData? projectIconData =
        iconDataForKey(project.iconKey) ??
        iconDataForKey(_projectTypeFor(project).iconKey);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: <Widget>[
            if (projectIconData != null) ...<Widget>[
              Icon(projectIconData),
              const SizedBox(width: 10),
            ],
            Expanded(child: Text(project.name)),
          ],
        ),
        actions: <Widget>[
          if (!_isReorderMode)
            IconButton(
              onPressed: _enterReorderMode,
              tooltip: 'Enter drag mode',
              icon: const Icon(Icons.drag_indicator_outlined),
            ),
          if (_isReorderMode)
            IconButton(
              onPressed: _exitReorderMode,
              tooltip: 'Done reordering',
              icon: const Icon(Icons.check),
            ),
          IconButton(
            onPressed: _toggleProjectArchived,
            tooltip:
                project.isArchived ? 'Restore project' : 'Archive project',
            icon: Icon(
              project.isArchived
                  ? Icons.unarchive_outlined
                  : Icons.archive_outlined,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: <Widget>[
          if (project.isArchived)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'This project is archived. Restore it to bring it back into the main project list.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          if (showsIdeasSection && _isReorderMode)
            _buildReorderTaskSection(
              title: 'Thinking (ideas)',
              emptyLabel: 'Drop ideas here.',
              tasks: thinkingTasks,
              sectionType: TaskItemType.thinking,
            )
          else if (showsIdeasSection)
            _buildTaskSection(
              title: 'Thinking (ideas)',
              emptyLabel: 'No ideas in this project yet.',
              tasks: thinkingTasks,
              showNestedPreview: true,
            ),
          if (showsIdeasSection && showsPlanningSection) const SizedBox(height: 8),
          if (showsPlanningSection && _isReorderMode)
            _buildReorderTaskSection(
              title: 'Planning (action items)',
              emptyLabel: 'Drop action items here.',
              tasks: planningTasks,
              sectionType: TaskItemType.planning,
            )
          else if (showsPlanningSection)
            _buildTaskSection(
              title: 'Planning (action items)',
              emptyLabel: 'No action items in this project yet.',
              tasks: planningTasks,
            ),
          if (!showsIdeasSection && !showsPlanningSection)
            Text(
              'This project type is blank. Enable ideas or tasks in project type settings to add sections.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          if (archivedTasks.isNotEmpty) _buildArchivedTaskSection(archivedTasks),
        ],
      ),
      floatingActionButton: _isReorderMode || !canCreateTasks || project.isArchived
          ? null
          : FloatingActionButton(
              onPressed: _addTaskToProject,
              tooltip: 'Add project task',
              child: const Icon(Icons.add),
            ),
    );
  }
}
