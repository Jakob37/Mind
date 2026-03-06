import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/task_storage.dart';
import '../domain/task_models.dart';
import 'pages/project_detail_page.dart';
import 'pages/settings_page.dart';
import 'widgets/add_project_sheet.dart';
import 'widgets/add_task_sheet.dart';
import 'widgets/edit_project_sheet.dart';
import 'widgets/edit_task_sheet.dart';
import 'widgets/item_color_picker_sheet.dart';
import 'widgets/move_project_task_sheet.dart';
import 'widgets/move_task_sheet.dart';
import 'widgets/project_list_view.dart';
import 'widgets/task_list_view.dart';

enum _TaskMenuAction {
  edit,
  setColor,
  moveToProject,
  remove,
}

enum _ProjectMenuAction {
  open,
  edit,
  setColor,
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
  final Map<int, String> _colorLabels = <int, String>{};

  late final TabController _tabController;
  int _selectedTabIndex = 0;
  bool _isAddTaskSheetOpen = false;
  bool _isReorderMode = false;
  bool _isPersistencePaused = false;
  bool _hasShownPersistencePausedMessage = false;

  @override
  void initState() {
    super.initState();
    _incomingTasks = List<TaskItem>.from(_defaultState.incomingTasks);
    _projects = List<ProjectItem>.from(_defaultState.projects);

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
        .toList(growable: false);
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

  Future<_TaskMenuAction?> _showTaskMenu(TaskItem task) {
    return showModalBottomSheet<_TaskMenuAction>(
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
                onTap: () => Navigator.of(context).pop(_TaskMenuAction.edit),
              ),
              ListTile(
                leading: const Icon(Icons.palette_outlined),
                title: const Text('Set color'),
                onTap: () =>
                    Navigator.of(context).pop(_TaskMenuAction.setColor),
              ),
              ListTile(
                leading: const Icon(Icons.drive_file_move_outlined),
                title: const Text('Move to project'),
                onTap: () => Navigator.of(
                  context,
                ).pop(_TaskMenuAction.moveToProject),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Remove task'),
                onTap: () => Navigator.of(context).pop(_TaskMenuAction.remove),
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

    final _TaskMenuAction? action = await _showTaskMenu(task);
    if (action == _TaskMenuAction.edit) {
      await _editTaskInList(_incomingTasks, taskId);
      return;
    }
    if (action == _TaskMenuAction.setColor) {
      await _setTaskColorInList(_incomingTasks, taskId);
      return;
    }
    if (action == _TaskMenuAction.moveToProject) {
      await _moveTaskFromListToProject(_incomingTasks, taskId);
      return;
    }
    if (action == _TaskMenuAction.remove) {
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
      sourceTasks[sourceTaskIndex] = TaskItem(
        id: existingTask.id,
        title: result.title,
        body: result.body,
        colorValue: existingTask.colorValue,
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
      sourceTasks[sourceTaskIndex] = TaskItem(
        id: task.id,
        title: task.title,
        body: task.body,
        colorValue: selection.colorValue,
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

    setState(() {
      sourceTasks.removeAt(sourceTaskIndex);
    });
    _persistState();
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
    if (action == _ProjectMenuAction.setColor) {
      await _setProjectColor(projectId);
      return;
    }
    if (action == _ProjectMenuAction.remove) {
      _deleteProject(projectId);
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
      _projects[projectIndex] = ProjectItem(
        id: project.id,
        name: result.name,
        body: result.body,
        colorValue: project.colorValue,
        tasks: List<TaskItem>.from(project.tasks),
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
      _projects[projectIndex] = ProjectItem(
        id: project.id,
        name: project.name,
        body: project.body,
        colorValue: selection.colorValue,
        tasks: List<TaskItem>.from(project.tasks),
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
      _projects.removeAt(projectIndex);
    });
    _persistState();
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
    final TaskItem? newTask = await showModalBottomSheet<TaskItem>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const AddTaskSheet(),
    );
    _isAddTaskSheetOpen = false;

    if (newTask == null) {
      return;
    }

    setState(() {
      _incomingTasks.insert(0, newTask);
    });
    _persistState();
  }

  Future<void> _openAddProjectWidget() async {
    final String? newProjectName = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const AddProjectSheet(),
    );

    if (newProjectName == null) {
      return;
    }

    setState(() {
      _projects.insert(0, ProjectItem(name: newProjectName));
    });
    _persistState();
  }

  Future<void> _moveIncomingTask(String taskId) async {
    final String? targetProjectId = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => MoveTaskSheet(projects: _projects),
    );

    if (targetProjectId == null) {
      return;
    }

    final int sourceTaskIndex = _indexOfTaskById(_incomingTasks, taskId);
    if (sourceTaskIndex < 0) {
      return;
    }
    final int targetProjectIndex = _indexOfProjectById(targetProjectId);
    if (targetProjectIndex < 0) {
      return;
    }

    setState(() {
      final TaskItem task = _incomingTasks.removeAt(sourceTaskIndex);
      _projects[targetProjectIndex].tasks.insert(0, task);
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
          onProjectsChanged: (List<ProjectItem> updatedProjects) {
            final List<ProjectItem> projectsCopy =
                _cloneProjects(updatedProjects);
            setState(() {
              _projects
                ..clear()
                ..addAll(projectsCopy);
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
        _projects
          ..clear()
          ..addAll(persistedState.projects);
        _colorLabels
          ..clear()
          ..addAll(persistedState.colorLabels);
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
      incomingTasks: _incomingTasks
          .map(
            (TaskItem task) => TaskItem(
              id: task.id,
              title: task.title,
              body: task.body,
              colorValue: task.colorValue,
            ),
          )
          .toList(),
      favoriteTasks: const <TaskItem>[],
      projects: _projects
          .map(
            (ProjectItem project) => ProjectItem(
              id: project.id,
              name: project.name,
              body: project.body,
              colorValue: project.colorValue,
              tasks: project.tasks
                  .map(
                    (TaskItem task) => TaskItem(
                      id: task.id,
                      title: task.title,
                      body: task.body,
                      colorValue: task.colorValue,
                    ),
                  )
                  .toList(),
            ),
          )
          .toList(),
      colorLabels: Map<int, String>.from(_colorLabels),
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

  Future<void> _openSettingsPage() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsPage(
          exportData: () => _taskStorage.export(_createSnapshot()),
          colorLabels: _colorLabels,
          onColorLabelsChanged: _updateColorLabels,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mind'),
        actions: <Widget>[
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
            primaryIcon: Icons.drive_file_move_outlined,
            isReorderMode: _isReorderMode,
            onEnterReorderMode: _enterReorderMode,
            onReorder: _reorderIncomingTasks,
            onTaskTap: _openIncomingTaskMenu,
            onPrimaryAction: _moveIncomingTask,
          ),
          ProjectListView(
            projects: _projects,
            isReorderMode: _isReorderMode,
            onEnterReorderMode: _enterReorderMode,
            onReorder: _reorderProjects,
            onProjectTap: _openProjectMenu,
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
