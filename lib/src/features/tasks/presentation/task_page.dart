import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/task_storage.dart';
import '../domain/task_models.dart';
import 'pages/project_detail_page.dart';
import 'pages/settings_page.dart';
import 'pages/task_detail_page.dart';
import 'widgets/add_project_sheet.dart';
import 'widgets/add_task_sheet.dart';
import 'widgets/edit_project_sheet.dart';
import 'widgets/edit_task_sheet.dart';
import 'widgets/item_icon_picker_sheet.dart';
import 'widgets/item_color_picker_sheet.dart';
import 'widgets/move_project_task_sheet.dart';
import 'widgets/project_list_view.dart';
import 'widgets/select_project_stack_sheet.dart';
import 'widgets/task_list_view.dart';

enum _ProjectMenuAction {
  open,
  edit,
  setStack,
  setIcon,
  setColor,
  remove,
}

enum _IncomingTaskMenuAction {
  open,
  edit,
  setIcon,
  setColor,
  moveToProject,
  remove,
}

class TaskPage extends StatefulWidget {
  const TaskPage({super.key});

  @override
  State<TaskPage> createState() => _TaskPageState();
}

class _TaskPageState extends State<TaskPage>
    with SingleTickerProviderStateMixin {
  static const MethodChannel _widgetChannel = MethodChannel(
    'mind/widget_actions',
  );

  final TaskStorage _taskStorage = const TaskStorage();
  final TaskBoardState _defaultState = TaskBoardState.defaults();

  late final List<TaskItem> _incomingTasks;
  late final List<ProjectItem> _projects;
  late final List<ProjectStack> _projectStacks;
  final Map<int, String> _colorLabels = <int, String>{};

  late final TabController _tabController;
  int _selectedTabIndex = 0;
  bool _isAddTaskSheetOpen = false;
  bool _isReorderMode = false;
  bool _isPersistencePaused = false;
  bool _hasShownPersistencePausedMessage = false;
  bool _hideCompletedProjectItems = false;

  @override
  void initState() {
    super.initState();
    _incomingTasks = List<TaskItem>.from(_defaultState.incomingTasks);
    _projects = List<ProjectItem>.from(_defaultState.projects);
    _projectStacks = List<ProjectStack>.from(_defaultState.projectStacks);

    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_selectedTabIndex == _tabController.index) {
        return;
      }
      setState(() {
        _selectedTabIndex = _tabController.index;
        _isReorderMode = false;
      });
    });
    _setupWidgetActionHandling();
    _loadPersistedState();
  }

  @override
  void dispose() {
    _widgetChannel.setMethodCallHandler(null);
    _tabController.dispose();
    super.dispose();
  }

  int _indexOfTaskById(List<TaskItem> tasks, String taskId) {
    return tasks.indexWhere((TaskItem task) => task.id == taskId);
  }

  int _indexOfProjectById(String projectId) {
    return _projects
        .indexWhere((ProjectItem project) => project.id == projectId);
  }

  List<ProjectItem> _cloneProjects(List<ProjectItem> projects) {
    return projects
        .map((ProjectItem project) => project.clone())
        .toList();
  }

  List<ProjectStack> _cloneProjectStacks(List<ProjectStack> projectStacks) {
    return projectStacks
        .map((ProjectStack stack) => stack.clone())
        .toList();
  }

  ({List<ProjectItem> projects, List<ProjectStack> projectStacks})
      _normalizeProjectsAndStacks({
    required List<ProjectItem> projects,
    required List<ProjectStack> projectStacks,
  }) {
    final Set<String> validStackIds = projectStacks
        .map((ProjectStack stack) => stack.id)
        .toSet();
    final List<ProjectItem> normalizedProjects = projects
        .map((ProjectItem project) {
          if (project.stackId == null || validStackIds.contains(project.stackId)) {
            return project.clone();
          }
          return project.copyWith(clearStack: true);
        })
        .toList(growable: false);

    final Set<String> referencedStackIds = normalizedProjects
        .map((ProjectItem project) => project.stackId)
        .whereType<String>()
        .toSet();
    final List<ProjectStack> normalizedStacks = projectStacks
        .where((ProjectStack stack) => referencedStackIds.contains(stack.id))
        .map((ProjectStack stack) => stack.clone())
        .toList(growable: false);

    return (
      projects: normalizedProjects,
      projectStacks: normalizedStacks,
    );
  }

  void _replaceProjectsAndStacks({
    required List<ProjectItem> projects,
    required List<ProjectStack> projectStacks,
  }) {
    final ({List<ProjectItem> projects, List<ProjectStack> projectStacks})
        normalized = _normalizeProjectsAndStacks(
      projects: projects,
      projectStacks: projectStacks,
    );
    _projects
      ..clear()
      ..addAll(normalized.projects);
    _projectStacks
      ..clear()
      ..addAll(normalized.projectStacks);
  }

  ProjectItem? _projectById(String projectId) {
    final int projectIndex = _indexOfProjectById(projectId);
    if (projectIndex < 0) {
      return null;
    }
    return _projects[projectIndex];
  }

  ProjectStack? _projectStackByName(
    List<ProjectStack> projectStacks,
    String stackName,
  ) {
    final String normalizedName = stackName.trim().toLowerCase();
    if (normalizedName.isEmpty) {
      return null;
    }

    for (final ProjectStack stack in projectStacks) {
      if (stack.name.trim().toLowerCase() == normalizedName) {
        return stack;
      }
    }
    return null;
  }

  String? _resolveStackIdForSelection({
    required ProjectStackSelection selection,
    required List<ProjectStack> projectStacks,
  }) {
    if (selection.mode == ProjectStackSelectionMode.none) {
      return null;
    }
    if (selection.mode == ProjectStackSelectionMode.existing) {
      return selection.stackId;
    }

    final String stackName = selection.stackName?.trim() ?? '';
    if (stackName.isEmpty) {
      return null;
    }
    final ProjectStack? existingStack = _projectStackByName(
      projectStacks,
      stackName,
    );
    if (existingStack != null) {
      return existingStack.id;
    }

    final ProjectStack newStack = ProjectStack(name: stackName);
    projectStacks.insert(0, newStack);
    return newStack.id;
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
        content: Text('Drag mode enabled. Use drag handles to reorder cards.'),
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

  void _reorderListItems<T>(List<T> items, int oldIndex, int newIndex) {
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

    final T item = items.removeAt(oldIndex);
    items.insert(newIndex, item);
  }

  void _reorderIncomingTasks(int oldIndex, int newIndex) {
    setState(() {
      _reorderListItems<TaskItem>(_incomingTasks, oldIndex, newIndex);
    });
    _persistState();
  }

  void _reorderProjects(int oldIndex, int newIndex) {
    setState(() {
      _reorderListItems<ProjectItem>(_projects, oldIndex, newIndex);
    });
    _persistState();
  }

  TaskItem? _taskById(List<TaskItem> tasks, String taskId) {
    final int index = _indexOfTaskById(tasks, taskId);
    if (index < 0) {
      return null;
    }
    return tasks[index];
  }

  Future<void> _openIncomingTaskView(String taskId) async {
    final TaskItem? task = _taskById(_incomingTasks, taskId);
    if (task == null) {
      return;
    }

    final TaskDetailAction? action = await Navigator.of(
      context,
    ).push<TaskDetailAction>(
      MaterialPageRoute<TaskDetailAction>(
        builder: (_) => TaskDetailPage(
          task: task,
          colorLabels: _colorLabels,
          onTaskChanged: (TaskItem updatedTask) {
            final int sourceTaskIndex =
                _indexOfTaskById(_incomingTasks, taskId);
            if (sourceTaskIndex < 0) {
              return;
            }
            setState(() {
              _incomingTasks[sourceTaskIndex] = updatedTask.clone();
            });
            _persistState();
          },
          menuItems: const <TaskDetailMenuItem>[
            TaskDetailMenuItem(
              action: TaskDetailAction.edit,
              icon: Icons.edit_outlined,
              label: 'Edit task',
            ),
            TaskDetailMenuItem(
              action: TaskDetailAction.setIcon,
              icon: Icons.add_reaction_outlined,
              label: 'Set icon',
            ),
            TaskDetailMenuItem(
              action: TaskDetailAction.setColor,
              icon: Icons.palette_outlined,
              label: 'Set color',
            ),
            TaskDetailMenuItem(
              action: TaskDetailAction.moveToProject,
              icon: Icons.drive_file_move_outlined,
              label: 'Move to project',
            ),
            TaskDetailMenuItem(
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
      await _editTaskInList(_incomingTasks, taskId);
      return;
    }
    if (action == TaskDetailAction.setIcon) {
      await _setTaskIconInList(_incomingTasks, taskId);
      return;
    }
    if (action == TaskDetailAction.setColor) {
      await _setTaskColorInList(_incomingTasks, taskId);
      return;
    }
    if (action == TaskDetailAction.moveToProject) {
      await _moveTaskFromListToProject(_incomingTasks, taskId);
      return;
    }
    if (action == TaskDetailAction.remove) {
      _deleteTaskInList(_incomingTasks, taskId);
    }
  }

  Future<void> _editTaskInList(
      List<TaskItem> sourceTasks, String taskId) async {
    final int sourceTaskIndex = _indexOfTaskById(sourceTasks, taskId);
    if (sourceTaskIndex < 0) {
      return;
    }
    final TaskItem existingTask = sourceTasks[sourceTaskIndex];

    final TaskEditResult? result = await showModalBottomSheet<TaskEditResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => EditTaskSheet(
        initialTitle: existingTask.title,
        initialBody: existingTask.body,
      ),
    );

    if (result == null) {
      return;
    }

    setState(() {
      sourceTasks[sourceTaskIndex] = existingTask.copyWith(
        title: result.title,
        body: result.body,
      );
    });
    _persistState();
  }

  Future<void> _setTaskColorInList(
    List<TaskItem> sourceTasks,
    String taskId,
  ) async {
    final int sourceTaskIndex = _indexOfTaskById(sourceTasks, taskId);
    if (sourceTaskIndex < 0) {
      return;
    }
    final TaskItem task = sourceTasks[sourceTaskIndex];

    final ColorSelection? selection =
        await showModalBottomSheet<ColorSelection>(
      context: context,
      builder: (_) => ItemColorPickerSheet(
        currentColorValue: task.colorValue,
        customLabels: _colorLabels,
      ),
    );

    if (selection == null) {
      return;
    }

    setState(() {
      sourceTasks[sourceTaskIndex] =
          task.copyWith(colorValue: selection.colorValue);
    });
    _persistState();
  }

  Future<void> _setTaskIconInList(
    List<TaskItem> sourceTasks,
    String taskId,
  ) async {
    final int sourceTaskIndex = _indexOfTaskById(sourceTasks, taskId);
    if (sourceTaskIndex < 0) {
      return;
    }
    final TaskItem task = sourceTasks[sourceTaskIndex];

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
      sourceTasks[sourceTaskIndex] = task.copyWith(
        iconKey: iconKey,
        clearIcon: iconKey == null,
      );
    });
    _persistState();
  }

  Future<void> _moveTaskFromListToProject(
    List<TaskItem> sourceTasks,
    String taskId,
  ) async {
    final String? targetProjectId = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => MoveProjectTaskSheet(
        projects: _projects,
        currentProjectId: '',
      ),
    );

    if (targetProjectId == null) {
      return;
    }

    final int sourceTaskIndex = _indexOfTaskById(sourceTasks, taskId);
    if (sourceTaskIndex < 0) {
      return;
    }

    final int targetProjectIndex = _indexOfProjectById(targetProjectId);
    if (targetProjectIndex < 0) {
      return;
    }

    setState(() {
      final TaskItem task = sourceTasks.removeAt(sourceTaskIndex);
      _projects[targetProjectIndex].tasks.insert(0, task);
    });
    _persistState();
  }

  void _deleteTaskInList(List<TaskItem> sourceTasks, String taskId) {
    final int sourceTaskIndex = _indexOfTaskById(sourceTasks, taskId);
    if (sourceTaskIndex < 0) {
      return;
    }

    final TaskItem removedTask = sourceTasks[sourceTaskIndex].clone();
    setState(() {
      sourceTasks.removeAt(sourceTaskIndex);
    });
    _showUndoTaskDeletion(
      message: 'Task removed.',
      onUndo: () {
        setState(() {
          final int insertIndex = sourceTaskIndex <= sourceTasks.length
              ? sourceTaskIndex
              : sourceTasks.length;
          sourceTasks.insert(insertIndex, removedTask);
        });
        _persistState();
      },
    );
    _persistState();
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

  Future<_IncomingTaskMenuAction?> _showIncomingTaskMenu(TaskItem task) {
    return showModalBottomSheet<_IncomingTaskMenuAction>(
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
                    Navigator.of(context).pop(_IncomingTaskMenuAction.open),
              ),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit task'),
                onTap: () =>
                    Navigator.of(context).pop(_IncomingTaskMenuAction.edit),
              ),
              ListTile(
                leading: const Icon(Icons.add_reaction_outlined),
                title: const Text('Set icon'),
                onTap: () =>
                    Navigator.of(context).pop(_IncomingTaskMenuAction.setIcon),
              ),
              ListTile(
                leading: const Icon(Icons.add_reaction_outlined),
                title: const Text('Set icon'),
                onTap: () =>
                    Navigator.of(context).pop(_ProjectMenuAction.setIcon),
              ),
              ListTile(
                leading: const Icon(Icons.palette_outlined),
                title: const Text('Set color'),
                onTap: () =>
                    Navigator.of(context).pop(_IncomingTaskMenuAction.setColor),
              ),
              ListTile(
                leading: const Icon(Icons.drive_file_move_outlined),
                title: const Text('Move to project'),
                onTap: () => Navigator.of(context)
                    .pop(_IncomingTaskMenuAction.moveToProject),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Remove task'),
                onTap: () =>
                    Navigator.of(context).pop(_IncomingTaskMenuAction.remove),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openIncomingTaskMenu(String taskId) async {
    final TaskItem? task = _taskById(_incomingTasks, taskId);
    if (task == null) {
      return;
    }

    final _IncomingTaskMenuAction? action = await _showIncomingTaskMenu(task);
    if (!mounted || action == null) {
      return;
    }

    if (action == _IncomingTaskMenuAction.open) {
      await _openIncomingTaskView(taskId);
      return;
    }
    if (action == _IncomingTaskMenuAction.edit) {
      await _editTaskInList(_incomingTasks, taskId);
      return;
    }
    if (action == _IncomingTaskMenuAction.setIcon) {
      await _setTaskIconInList(_incomingTasks, taskId);
      return;
    }
    if (action == _IncomingTaskMenuAction.setColor) {
      await _setTaskColorInList(_incomingTasks, taskId);
      return;
    }
    if (action == _IncomingTaskMenuAction.moveToProject) {
      await _moveTaskFromListToProject(_incomingTasks, taskId);
      return;
    }
    if (action == _IncomingTaskMenuAction.remove) {
      _deleteTaskInList(_incomingTasks, taskId);
    }
  }

  Future<_ProjectMenuAction?> _showProjectMenu(ProjectItem project) {
    return showModalBottomSheet<_ProjectMenuAction>(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: <Widget>[
              ListTile(
                title: Text(
                  project.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Project options'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.open_in_new_outlined),
                title: const Text('Open project'),
                onTap: () => Navigator.of(context).pop(_ProjectMenuAction.open),
              ),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit project'),
                onTap: () => Navigator.of(context).pop(_ProjectMenuAction.edit),
              ),
              ListTile(
                leading: const Icon(Icons.layers_outlined),
                title: const Text('Set stack'),
                onTap: () =>
                    Navigator.of(context).pop(_ProjectMenuAction.setStack),
              ),
              ListTile(
                leading: const Icon(Icons.palette_outlined),
                title: const Text('Set color'),
                onTap: () =>
                    Navigator.of(context).pop(_ProjectMenuAction.setColor),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Remove project'),
                onTap: () =>
                    Navigator.of(context).pop(_ProjectMenuAction.remove),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openProjectMenu(String projectId) async {
    final int projectIndex = _indexOfProjectById(projectId);
    if (projectIndex < 0) {
      return;
    }
    final ProjectItem project = _projects[projectIndex];
    final _ProjectMenuAction? action = await _showProjectMenu(project);

    if (action == _ProjectMenuAction.open) {
      _openProjectDetail(projectId);
      return;
    }
    if (action == _ProjectMenuAction.edit) {
      await _editProject(projectId);
      return;
    }
    if (action == _ProjectMenuAction.setStack) {
      await _setProjectStack(projectId);
      return;
    }
    if (action == _ProjectMenuAction.setIcon) {
      await _setProjectIcon(projectId);
      return;
    }
    if (action == _ProjectMenuAction.setColor) {
      await _setProjectColor(projectId);
      return;
    }
    if (action == _ProjectMenuAction.remove) {
      final bool shouldDelete = await _confirmProjectRemoval();
      if (shouldDelete) {
        _deleteProject(projectId);
      }
    }
  }

  Future<void> _editProject(String projectId) async {
    final int projectIndex = _indexOfProjectById(projectId);
    if (projectIndex < 0) {
      return;
    }

    final ProjectItem project = _projects[projectIndex];
    final ProjectEditResult? result =
        await showModalBottomSheet<ProjectEditResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => EditProjectSheet(
        initialName: project.name,
        initialBody: project.body,
      ),
    );

    if (result == null) {
      return;
    }

    setState(() {
      _projects[projectIndex] = project.copyWith(
        name: result.name,
        body: result.body,
      );
    });
    _persistState();
  }

  Future<void> _setProjectIcon(String projectId) async {
    final int projectIndex = _indexOfProjectById(projectId);
    if (projectIndex < 0) {
      return;
    }
    final ProjectItem project = _projects[projectIndex];

    final String? iconKey = await showModalBottomSheet<String?>(
      context: context,
      builder: (_) => ItemIconPickerSheet(
        currentIconKey: project.iconKey,
      ),
    );
    if (!mounted) {
      return;
    }
    if (iconKey == project.iconKey) {
      return;
    }

    setState(() {
      _projects[projectIndex] = project.copyWith(
        iconKey: iconKey,
        clearIcon: iconKey == null,
      );
    });
    _persistState();
  }

  Future<void> _setProjectColor(String projectId) async {
    final int projectIndex = _indexOfProjectById(projectId);
    if (projectIndex < 0) {
      return;
    }
    final ProjectItem project = _projects[projectIndex];

    final ColorSelection? selection =
        await showModalBottomSheet<ColorSelection>(
      context: context,
      builder: (_) => ItemColorPickerSheet(
        currentColorValue: project.colorValue,
        customLabels: _colorLabels,
      ),
    );

    if (selection == null) {
      return;
    }

    setState(() {
      _projects[projectIndex] =
          project.copyWith(colorValue: selection.colorValue);
    });
    _persistState();
  }

  Future<void> _setProjectStack(String projectId) async {
    final int projectIndex = _indexOfProjectById(projectId);
    if (projectIndex < 0) {
      return;
    }

    final ProjectItem project = _projects[projectIndex];
    final ProjectStackSelection initialSelection = project.stackId == null
        ? const ProjectStackSelection.none()
        : ProjectStackSelection.existing(stackId: project.stackId!);
    final ProjectStackSelection? selection =
        await showModalBottomSheet<ProjectStackSelection>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SelectProjectStackSheet(
        projectStacks: _projectStacks,
        initialSelection: initialSelection,
      ),
    );

    if (!mounted || selection == null) {
      return;
    }

    final List<ProjectItem> projects = _cloneProjects(_projects);
    final List<ProjectStack> projectStacks = _cloneProjectStacks(_projectStacks);
    final String? stackId = _resolveStackIdForSelection(
      selection: selection,
      projectStacks: projectStacks,
    );

    projects[projectIndex] = project.copyWith(
      stackId: stackId,
      clearStack: stackId == null,
    );

    setState(() {
      _replaceProjectsAndStacks(
        projects: projects,
        projectStacks: projectStacks,
      );
    });
    _persistState();
  }

  void _deleteProject(String projectId) {
    final int projectIndex = _indexOfProjectById(projectId);
    if (projectIndex < 0) {
      return;
    }

    setState(() {
      final List<ProjectItem> projects = _cloneProjects(_projects)
        ..removeAt(projectIndex);
      _replaceProjectsAndStacks(
        projects: projects,
        projectStacks: _cloneProjectStacks(_projectStacks),
      );
    });
    _persistState();
  }

  Future<bool> _confirmProjectRemoval() async {
    final bool? shouldRemove = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Remove project?'),
          content: const Text('Projects always require confirmation.'),
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

  Future<void> _setupWidgetActionHandling() async {
    _widgetChannel.setMethodCallHandler((MethodCall call) async {
      if (call.method == 'openAddEntry') {
        _openAddEntryFromWidget();
      }
    });

    try {
      final bool shouldOpen =
          await _widgetChannel.invokeMethod<bool>('consumePendingAddEntry') ??
              false;
      if (shouldOpen) {
        _openAddEntryFromWidget();
      }
    } on MissingPluginException {
      // iOS/Linux/Web tests and platforms without channel implementation.
    }
  }

  void _openAddEntryFromWidget() {
    if (!mounted) {
      return;
    }

    if (_tabController.index != 0) {
      _tabController.animateTo(0);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _openAddTaskWidget();
    });
  }

  Future<void> _openAddTaskWidget() async {
    if (_isAddTaskSheetOpen) {
      return;
    }

    _isAddTaskSheetOpen = true;
    final AddTaskResult? result = await showModalBottomSheet<AddTaskResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const AddTaskSheet(),
    );
    _isAddTaskSheetOpen = false;

    if (result == null) {
      return;
    }

    setState(() {
      if (result.insertAtTop) {
        _incomingTasks.insert(0, result.task);
      } else {
        _incomingTasks.add(result.task);
      }
    });
    _persistState();
  }

  Future<void> _openAddProjectWidget() async {
    final AddProjectResult? result = await showModalBottomSheet<AddProjectResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => AddProjectSheet(
        projectStacks: _projectStacks,
      ),
    );

    if (result == null) {
      return;
    }

    final List<ProjectItem> projects = _cloneProjects(_projects);
    final List<ProjectStack> projectStacks = _cloneProjectStacks(_projectStacks);
    final String? stackId = _resolveStackIdForSelection(
      selection: result.stackSelection,
      projectStacks: projectStacks,
    );

    setState(() {
      projects.insert(
        0,
        ProjectItem(
          name: result.name,
          stackId: stackId,
        ),
      );
      _replaceProjectsAndStacks(
        projects: projects,
        projectStacks: projectStacks,
      );
    });
    _persistState();
  }

  Future<void> _stackProjectsTogether({
    required String sourceProjectId,
    required String targetProjectId,
  }) async {
    if (sourceProjectId == targetProjectId) {
      return;
    }

    final ProjectItem? sourceProject = _projectById(sourceProjectId);
    final ProjectItem? targetProject = _projectById(targetProjectId);
    if (sourceProject == null || targetProject == null) {
      return;
    }

    final String? suggestedStackId = targetProject.stackId ?? sourceProject.stackId;
    final ProjectStackSelection initialSelection = suggestedStackId == null
        ? const ProjectStackSelection.createNew(stackName: '')
        : ProjectStackSelection.existing(stackId: suggestedStackId);
    final ProjectStackSelection? selection =
        await showModalBottomSheet<ProjectStackSelection>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SelectProjectStackSheet(
        projectStacks: _projectStacks,
        initialSelection: initialSelection,
        allowNoStack: false,
        title: 'Create or Select Stack',
        confirmLabel: 'Group Projects',
      ),
    );

    if (!mounted || selection == null) {
      return;
    }

    final List<ProjectItem> projects = _cloneProjects(_projects);
    final List<ProjectStack> projectStacks = _cloneProjectStacks(_projectStacks);
    final String? stackId = _resolveStackIdForSelection(
      selection: selection,
      projectStacks: projectStacks,
    );
    if (stackId == null) {
      return;
    }

    setState(() {
      for (int index = 0; index < projects.length; index += 1) {
        final ProjectItem project = projects[index];
        if (project.id != sourceProjectId && project.id != targetProjectId) {
          continue;
        }
        projects[index] = project.copyWith(stackId: stackId);
      }
      _replaceProjectsAndStacks(
        projects: projects,
        projectStacks: projectStacks,
      );
    });
    _persistState();
  }

  void _openProjectDetail(String projectId) {
    final List<ProjectItem> projectsSnapshot = _cloneProjects(_projects);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProjectDetailPage(
          projectId: projectId,
          initialProjects: projectsSnapshot,
          colorLabels: _colorLabels,
          hideCompletedProjectItems: _hideCompletedProjectItems,
          onProjectsChanged: (List<ProjectItem> updatedProjects) {
            final List<ProjectItem> projectsCopy =
                _cloneProjects(updatedProjects);
            setState(() {
              _replaceProjectsAndStacks(
                projects: projectsCopy,
                projectStacks: _cloneProjectStacks(_projectStacks),
              );
            });
            _persistState();
          },
        ),
      ),
    );
  }

  Future<void> _loadPersistedState() async {
    final TaskLoadResult loadResult = await _taskStorage.load();
    if (!mounted) {
      return;
    }

    if (loadResult.isSuccess) {
      final TaskBoardState persistedState = loadResult.state!;
      setState(() {
        _incomingTasks
          ..clear()
          ..addAll(persistedState.incomingTasks)
          ..addAll(persistedState.favoriteTasks);
        _replaceProjectsAndStacks(
          projects: persistedState.projects,
          projectStacks: persistedState.projectStacks,
        );
        _colorLabels
          ..clear()
          ..addAll(persistedState.colorLabels);
        _hideCompletedProjectItems = persistedState.hideCompletedProjectItems;
      });
      return;
    }

    if (!loadResult.isFailure) {
      return;
    }

    _isPersistencePaused = true;
    _reportPersistenceError(
      error: loadResult.error!,
      stackTrace: loadResult.stackTrace ?? StackTrace.current,
      context: 'while loading persisted task data',
    );
    _showPersistencePausedMessage(
      'Saved data could not be loaded. Autosave is paused to avoid '
      'overwriting existing local data.',
    );
  }

  void _reportPersistenceError({
    required Object error,
    required StackTrace stackTrace,
    required String context,
  }) {
    debugPrint('Task persistence error ($context): $error\n$stackTrace');
  }

  void _showPersistencePausedMessage(String message) {
    if (!mounted || _hasShownPersistencePausedMessage) {
      return;
    }
    _hasShownPersistencePausedMessage = true;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _persistSnapshot(TaskBoardState snapshot) async {
    try {
      await _taskStorage.save(snapshot);
    } catch (error, stackTrace) {
      _isPersistencePaused = true;
      _reportPersistenceError(
        error: error,
        stackTrace: stackTrace,
        context: 'while saving task data',
      );
      _showPersistencePausedMessage(
        'Changes could not be saved. Autosave is paused until restart.',
      );
    }
  }

  void _persistState() {
    if (_isPersistencePaused) {
      return;
    }
    final TaskBoardState snapshot = _createSnapshot();
    unawaited(_persistSnapshot(snapshot));
  }

  TaskBoardState _createSnapshot() {
    return TaskBoardState(
      incomingTasks:
          _incomingTasks.map((TaskItem task) => task.clone()).toList(),
      favoriteTasks: const <TaskItem>[],
      projects:
          _projects.map((ProjectItem project) => project.clone()).toList(),
      projectStacks: _projectStacks
          .map((ProjectStack stack) => stack.clone())
          .toList(),
      colorLabels: Map<int, String>.from(_colorLabels),
      hideCompletedProjectItems: _hideCompletedProjectItems,
    );
  }

  void _updateColorLabels(Map<int, String> colorLabels) {
    setState(() {
      _colorLabels
        ..clear()
        ..addAll(colorLabels);
    });
    _persistState();
  }

  void _updateHideCompletedProjectItems(bool value) {
    setState(() {
      _hideCompletedProjectItems = value;
    });
    _persistState();
  }

  Future<String?> _importData(String rawJson) async {
    try {
      final TaskBoardState importedState = _taskStorage.import(rawJson);
      setState(() {
        _incomingTasks
          ..clear()
          ..addAll(
            importedState.incomingTasks
                .map((TaskItem task) => task.clone())
                .toList(),
          );
        _replaceProjectsAndStacks(
          projects: importedState.projects
              .map((ProjectItem project) => project.clone())
              .toList(),
          projectStacks: importedState.projectStacks
              .map((ProjectStack stack) => stack.clone())
              .toList(),
        );
        _colorLabels
          ..clear()
          ..addAll(importedState.colorLabels);
        _hideCompletedProjectItems = importedState.hideCompletedProjectItems;
        _isReorderMode = false;
      });
      await _taskStorage.save(_createSnapshot());
      return null;
    } catch (error) {
      return 'Import failed: $error';
    }
  }

  Future<void> _openSettingsPage() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsPage(
          exportData: () => _taskStorage.export(_createSnapshot()),
          exportPlainText: () =>
              _taskStorage.exportPlainText(_createSnapshot()),
          onImportData: _importData,
          colorLabels: _colorLabels,
          onColorLabelsChanged: _updateColorLabels,
          hideCompletedProjectItems: _hideCompletedProjectItems,
          onHideCompletedProjectItemsChanged: _updateHideCompletedProjectItems,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: <Widget>[
            Icon(iconDataForKey(kMindAppIconKey) ??
                Icons.psychology_alt_outlined),
            const SizedBox(width: 10),
            const Text('Mind'),
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
            onPressed: _openSettingsPage,
            tooltip: 'Open settings',
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const <Widget>[
            Tab(text: 'Incoming'),
            Tab(text: 'Projects'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: <Widget>[
          TaskListView(
            tasks: _incomingTasks,
            emptyLabel: 'No incoming tasks yet.',
            isReorderMode: _isReorderMode,
            onReorder: _reorderIncomingTasks,
            onTaskTap: _openIncomingTaskView,
            onTaskLongPress: _openIncomingTaskMenu,
            onMoveTaskToProject: (String taskId) =>
                _moveTaskFromListToProject(_incomingTasks, taskId),
            onRemoveTask: (String taskId) =>
                _deleteTaskInList(_incomingTasks, taskId),
          ),
          ProjectListView(
            projects: _projects,
            projectStacks: _projectStacks,
            isReorderMode: _isReorderMode,
            onReorder: _reorderProjects,
            onProjectTap: (String projectId) async =>
                _openProjectDetail(projectId),
            onProjectRemove: _deleteProject,
            onProjectLongPress: _openProjectMenu,
            onProjectOptionsTap: _openProjectMenu,
            onProjectStackDrop: (
              String sourceProjectId,
              String targetProjectId,
            ) =>
                _stackProjectsTogether(
              sourceProjectId: sourceProjectId,
              targetProjectId: targetProjectId,
            ),
          ),
        ],
      ),
      floatingActionButton: _selectedTabIndex == 0
          ? FloatingActionButton(
              onPressed: _openAddTaskWidget,
              tooltip: 'Add task',
              child: const Icon(Icons.add),
            )
          : _selectedTabIndex == 1
              ? FloatingActionButton(
                  onPressed: _openAddProjectWidget,
                  tooltip: 'Add project',
                  child: const Icon(Icons.add),
                )
              : null,
    );
  }
}
