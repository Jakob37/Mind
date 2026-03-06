import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/task_storage.dart';
import '../domain/task_models.dart';
import 'pages/project_detail_page.dart';
import 'pages/settings_page.dart';
import 'widgets/add_project_sheet.dart';
import 'widgets/add_task_sheet.dart';
import 'widgets/move_task_sheet.dart';
import 'widgets/project_list_view.dart';
import 'widgets/task_list_view.dart';

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
  late final List<TaskItem> _favoriteTasks;
  late final List<ProjectItem> _projects;

  late final TabController _tabController;
  int _selectedTabIndex = 0;
  bool _isAddTaskSheetOpen = false;

  @override
  void initState() {
    super.initState();
    _incomingTasks = List<TaskItem>.from(_defaultState.incomingTasks);
    _favoriteTasks = List<TaskItem>.from(_defaultState.favoriteTasks);
    _projects = List<ProjectItem>.from(_defaultState.projects);

    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_selectedTabIndex == _tabController.index) {
        return;
      }
      setState(() {
        _selectedTabIndex = _tabController.index;
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

  Future<void> _moveIncomingTask(int index) async {
    final MoveTarget? target = await showModalBottomSheet<MoveTarget>(
      context: context,
      builder: (_) => MoveTaskSheet(projects: _projects),
    );

    if (target == null) {
      return;
    }

    setState(() {
      final TaskItem task = _incomingTasks.removeAt(index);
      if (target.projectIndex == null) {
        _favoriteTasks.insert(0, task);
      } else {
        _projects[target.projectIndex!].tasks.insert(0, task);
      }
    });
    _persistState();
  }

  Future<void> _moveFavoriteToIncoming(int index) async {
    setState(() {
      final TaskItem task = _favoriteTasks.removeAt(index);
      _incomingTasks.insert(0, task);
    });
    _persistState();
  }

  void _deleteIncomingTask(int index) {
    setState(() {
      _incomingTasks.removeAt(index);
    });
    _persistState();
  }

  void _deleteFavoriteTask(int index) {
    setState(() {
      _favoriteTasks.removeAt(index);
    });
    _persistState();
  }

  void _openProjectDetail(int projectIndex) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProjectDetailPage(
          projectIndex: projectIndex,
          projects: _projects,
          onProjectsUpdated: () {
            setState(() {});
            _persistState();
          },
        ),
      ),
    );
  }

  Future<void> _loadPersistedState() async {
    final TaskBoardState? persistedState = await _taskStorage.load();
    if (!mounted || persistedState == null) {
      return;
    }

    setState(() {
      _incomingTasks
        ..clear()
        ..addAll(persistedState.incomingTasks);
      _favoriteTasks
        ..clear()
        ..addAll(persistedState.favoriteTasks);
      _projects
        ..clear()
        ..addAll(persistedState.projects);
    });
  }

  void _persistState() {
    unawaited(_taskStorage.save(_createSnapshot()));
  }

  TaskBoardState _createSnapshot() {
    return TaskBoardState(
      incomingTasks: List<TaskItem>.from(_incomingTasks),
      favoriteTasks: List<TaskItem>.from(_favoriteTasks),
      projects: _projects
          .map(
            (ProjectItem project) => ProjectItem(
              name: project.name,
              tasks: List<TaskItem>.from(project.tasks),
            ),
          )
          .toList(),
    );
  }

  Future<void> _openSettingsPage() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsPage(
          exportData: () => _taskStorage.export(_createSnapshot()),
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
            Tab(text: 'Favorites'),
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
            primaryTooltip: 'Move task',
            onPrimaryAction: _moveIncomingTask,
            onDelete: _deleteIncomingTask,
          ),
          TaskListView(
            tasks: _favoriteTasks,
            emptyLabel: 'No favorite tasks yet.',
            primaryIcon: Icons.undo_outlined,
            primaryTooltip: 'Move to incoming',
            onPrimaryAction: _moveFavoriteToIncoming,
            onDelete: _deleteFavoriteTask,
          ),
          ProjectListView(
            projects: _projects,
            onProjectTap: _openProjectDetail,
          ),
        ],
      ),
      floatingActionButton: _selectedTabIndex == 0
          ? FloatingActionButton(
              onPressed: _openAddTaskWidget,
              tooltip: 'Add task',
              child: const Icon(Icons.add),
            )
          : _selectedTabIndex == 2
              ? FloatingActionButton(
                  onPressed: _openAddProjectWidget,
                  tooltip: 'Add project',
                  child: const Icon(Icons.add),
                )
              : null,
    );
  }
}
