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
import 'widgets/card_layout.dart';
import 'widgets/edit_project_sheet.dart';
import 'widgets/edit_project_stack_sheet.dart';
import 'widgets/edit_task_sheet.dart';
import 'widgets/item_icon_picker_sheet.dart';
import 'widgets/item_color_picker_sheet.dart';
import 'widgets/move_project_task_sheet.dart';
import 'widgets/project_list_view.dart';
import 'widgets/select_project_stack_sheet.dart';
import 'widgets/select_project_type_sheet.dart';
import 'widgets/task_list_view.dart';

enum _ProjectMenuAction {
  open,
  edit,
  setType,
  setStack,
  setIcon,
  setColor,
  togglePinned,
  archive,
  restore,
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

enum _ProjectStackMenuAction {
  rename,
  setColor,
  createProject,
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
  late final List<ProjectTypeConfig> _projectTypes;
  final Map<int, String> _colorLabels = <int, String>{};

  late final TabController _tabController;
  int _selectedTabIndex = 0;
  bool _isAddTaskSheetOpen = false;
  bool _isPersistencePaused = false;
  bool _hasShownPersistencePausedMessage = false;
  bool _hideCompletedProjectItems = false;
  CardLayoutPreset _cardLayoutPreset = CardLayoutPreset.standard;

  @override
  void initState() {
    super.initState();
    _incomingTasks = List<TaskItem>.from(_defaultState.incomingTasks);
    _projects = List<ProjectItem>.from(_defaultState.projects);
    _projectStacks = List<ProjectStack>.from(_defaultState.projectStacks);
    _projectTypes = List<ProjectTypeConfig>.from(_defaultState.projectTypes);

    _tabController = TabController(length: 2, vsync: this);
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

  int _indexOfTaskById(List<TaskItem> tasks, String taskId) {
    return tasks.indexWhere((TaskItem task) => task.id == taskId);
  }

  int _indexOfProjectById(String projectId) {
    return _projects
        .indexWhere((ProjectItem project) => project.id == projectId);
  }

  int _indexOfProjectStackById(String stackId) {
    return _projectStacks
        .indexWhere((ProjectStack stack) => stack.id == stackId);
  }

  List<ProjectItem> _cloneProjects(List<ProjectItem> projects) {
    return projects.map((ProjectItem project) => project.clone()).toList();
  }

  List<ProjectStack> _cloneProjectStacks(List<ProjectStack> projectStacks) {
    return projectStacks.map((ProjectStack stack) => stack.clone()).toList();
  }

  List<ProjectTypeConfig> _cloneProjectTypes(
    List<ProjectTypeConfig> projectTypes,
  ) {
    return projectTypes.map((ProjectTypeConfig type) => type.clone()).toList();
  }

  List<ProjectTypeConfig> _normalizeProjectTypes(
    List<ProjectTypeConfig> projectTypes,
  ) {
    final Map<String, ProjectTypeConfig> providedById =
        <String, ProjectTypeConfig>{
      for (final ProjectTypeConfig type in projectTypes) type.id: type.clone(),
    };
    final List<ProjectTypeConfig> normalized = <ProjectTypeConfig>[];
    for (final ProjectTypeConfig defaultType in ProjectTypeConfig.defaults()) {
      normalized.add(providedById.remove(defaultType.id) ?? defaultType);
    }
    normalized.addAll(providedById.values);
    return normalized;
  }

  ({
    List<ProjectItem> projects,
    List<ProjectStack> projectStacks,
    List<ProjectTypeConfig> projectTypes,
  }) _normalizeProjectData({
    required List<ProjectItem> projects,
    required List<ProjectStack> projectStacks,
    required List<ProjectTypeConfig> projectTypes,
  }) {
    final List<ProjectTypeConfig> normalizedProjectTypes =
        _normalizeProjectTypes(projectTypes);
    final Set<String> validStackIds =
        projectStacks.map((ProjectStack stack) => stack.id).toSet();
    final Set<String> validProjectTypeIds =
        normalizedProjectTypes.map((ProjectTypeConfig type) => type.id).toSet();
    final List<ProjectItem> normalizedProjects =
        projects.map((ProjectItem project) {
      final String? normalizedStackId =
          project.stackId == null || validStackIds.contains(project.stackId)
              ? project.stackId
              : null;
      final String? normalizedProjectTypeId = project.projectTypeId == null ||
              validProjectTypeIds.contains(project.projectTypeId)
          ? project.projectTypeId
          : ProjectTypeDefaults.blankId;
      if (normalizedStackId == project.stackId &&
          normalizedProjectTypeId == project.projectTypeId) {
        return project.clone();
      }
      return project.copyWith(
        stackId: normalizedStackId,
        clearStack: normalizedStackId == null,
        projectTypeId: normalizedProjectTypeId,
        clearProjectType: normalizedProjectTypeId == null,
      );
    }).toList(growable: false);

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
      projectTypes: normalizedProjectTypes,
    );
  }

  void _replaceProjectData({
    required List<ProjectItem> projects,
    required List<ProjectStack> projectStacks,
    required List<ProjectTypeConfig> projectTypes,
  }) {
    final ({
      List<ProjectItem> projects,
      List<ProjectStack> projectStacks,
      List<ProjectTypeConfig> projectTypes,
    }) normalized = _normalizeProjectData(
      projects: projects,
      projectStacks: projectStacks,
      projectTypes: projectTypes,
    );
    _projects
      ..clear()
      ..addAll(normalized.projects);
    _projectStacks
      ..clear()
      ..addAll(normalized.projectStacks);
    _projectTypes
      ..clear()
      ..addAll(normalized.projectTypes);
  }

  ProjectItem? _projectById(String projectId) {
    final int projectIndex = _indexOfProjectById(projectId);
    if (projectIndex < 0) {
      return null;
    }
    return _projects[projectIndex];
  }

  ProjectStack? _projectStackById(String stackId) {
    final int stackIndex = _indexOfProjectStackById(stackId);
    if (stackIndex < 0) {
      return null;
    }
    return _projectStacks[stackIndex];
  }

  String? _stackNameForProject(ProjectItem project) {
    final String? stackId = project.stackId;
    if (stackId == null || stackId.isEmpty) {
      return null;
    }
    return _projectStackById(stackId)?.name;
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

  Future<_ProjectStackMenuAction?> _showProjectStackMenu(
    ProjectStack stack,
  ) {
    return showModalBottomSheet<_ProjectStackMenuAction>(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: <Widget>[
              ListTile(
                title: Text(
                  stack.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Stack settings'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Rename stack'),
                onTap: () =>
                    Navigator.of(context).pop(_ProjectStackMenuAction.rename),
              ),
              ListTile(
                leading: const Icon(Icons.palette_outlined),
                title: const Text('Set color'),
                onTap: () =>
                    Navigator.of(context).pop(_ProjectStackMenuAction.setColor),
              ),
              ListTile(
                leading: const Icon(Icons.add_box_outlined),
                title: const Text('Create project'),
                onTap: () => Navigator.of(context)
                    .pop(_ProjectStackMenuAction.createProject),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openProjectStackMenu(String stackId) async {
    final ProjectStack? stack = _projectStackById(stackId);
    if (stack == null) {
      return;
    }

    final _ProjectStackMenuAction? action = await _showProjectStackMenu(stack);
    if (!mounted || action == null) {
      return;
    }

    if (action == _ProjectStackMenuAction.rename) {
      await _renameProjectStack(stackId);
      return;
    }
    if (action == _ProjectStackMenuAction.setColor) {
      await _setProjectStackColor(stackId);
      return;
    }
    if (action == _ProjectStackMenuAction.createProject) {
      await _openAddProjectWidget(
        initialStackSelection: ProjectStackSelection.existing(stackId: stackId),
      );
    }
  }

  Future<void> _renameProjectStack(String stackId) async {
    final int stackIndex = _indexOfProjectStackById(stackId);
    if (stackIndex < 0) {
      return;
    }

    final ProjectStack stack = _projectStacks[stackIndex];
    final String? updatedName = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => EditProjectStackSheet(initialName: stack.name),
    );

    if (!mounted || updatedName == null) {
      return;
    }

    final String normalizedName = updatedName.trim();
    if (normalizedName.isEmpty || normalizedName == stack.name) {
      return;
    }

    final ProjectStack? existingStack = _projectStackByName(
      _projectStacks,
      normalizedName,
    );
    if (existingStack != null && existingStack.id != stackId) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('A stack with that name already exists.'),
          ),
        );
      return;
    }

    setState(() {
      _projectStacks[stackIndex] = stack.copyWith(name: normalizedName);
    });
    _persistState();
  }

  Future<void> _setProjectStackColor(String stackId) async {
    final int stackIndex = _indexOfProjectStackById(stackId);
    if (stackIndex < 0) {
      return;
    }

    final ProjectStack stack = _projectStacks[stackIndex];
    final ColorSelection? selection =
        await showModalBottomSheet<ColorSelection>(
      context: context,
      builder: (_) => ItemColorPickerSheet(
        currentColorValue: stack.colorValue,
        customLabels: _colorLabels,
      ),
    );

    if (selection == null) {
      return;
    }

    setState(() {
      _projectStacks[stackIndex] = stack.copyWith(
        colorValue: selection.colorValue,
        clearColor: selection.colorValue == null,
      );
    });
    _persistState();
  }

  ProjectTypeConfig _projectTypeById(
    String? projectTypeId, {
    List<ProjectTypeConfig>? projectTypes,
  }) {
    final List<ProjectTypeConfig> source = projectTypes ?? _projectTypes;
    final String targetId = (projectTypeId == null || projectTypeId.isEmpty)
        ? ProjectTypeDefaults.blankId
        : projectTypeId;
    for (final ProjectTypeConfig type in source) {
      if (type.id == targetId) {
        return type;
      }
    }
    return ProjectTypeConfig.defaults().first;
  }

  ProjectTypeConfig _projectTypeForProject(
    ProjectItem project, {
    List<ProjectTypeConfig>? projectTypes,
  }) {
    return _projectTypeById(
      project.projectTypeId,
      projectTypes: projectTypes,
    );
  }

  bool _projectUsesPromptFields(
    ProjectItem project, {
    List<ProjectTypeConfig>? projectTypes,
  }) {
    return _projectTypeForProject(
          project,
          projectTypes: projectTypes,
        ).id ==
        ProjectTypeDefaults.llmId;
  }

  bool _projectAcceptsRootTasks(
    ProjectItem project, {
    List<ProjectTypeConfig>? projectTypes,
  }) {
    return _projectTypeForProject(
              project,
              projectTypes: projectTypes,
            ).id !=
            ProjectTypeDefaults.peopleId &&
        _projectTypeForProject(
          project,
          projectTypes: projectTypes,
        ).supportsAnyEntries;
  }

  List<ProjectItem> _taskCompatibleProjects({
    required String currentProjectId,
  }) {
    return <ProjectItem>[
      for (final ProjectItem project in _projects)
        if (project.id != currentProjectId &&
            !project.isArchived &&
            _projectAcceptsRootTasks(project))
          project
    ];
  }

  List<TaskItem> _projectJournalEntries(
    ProjectItem project, {
    bool includeArchived = false,
  }) {
    return project.tasks
        .where(
          (TaskItem task) =>
              task.entryType == TaskEntryType.journal &&
              (includeArchived || !task.isArchived),
        )
        .toList(growable: false);
  }

  List<TaskItem> _projectThinkingTasks(
    ProjectItem project, {
    bool includeArchived = false,
  }) {
    return project.tasks
        .where(
          (TaskItem task) =>
              task.type == TaskItemType.thinking &&
              task.entryType != TaskEntryType.journal &&
              (includeArchived || !task.isArchived),
        )
        .toList(growable: false);
  }

  List<TaskItem> _projectPlanningTasks(
    ProjectItem project, {
    bool includeArchived = false,
  }) {
    return project.tasks
        .where(
          (TaskItem task) =>
              task.type == TaskItemType.planning &&
              task.entryType != TaskEntryType.journal &&
              (includeArchived || !task.isArchived),
        )
        .toList(growable: false);
  }

  List<TaskItem> _projectArchivedTasks(ProjectItem project) {
    return project.tasks
        .where((TaskItem task) => task.isArchived)
        .toList(growable: false);
  }

  void _replaceProjectTasks({
    required ProjectItem project,
    required List<TaskItem> journalEntries,
    required List<TaskItem> thinkingTasks,
    required List<TaskItem> planningTasks,
    required List<TaskItem> archivedTasks,
  }) {
    project.tasks
      ..clear()
      ..addAll(journalEntries)
      ..addAll(thinkingTasks)
      ..addAll(planningTasks)
      ..addAll(archivedTasks);
  }

  void _insertTaskIntoProject(
    ProjectItem project,
    TaskItem task, {
    required bool insertAtTop,
  }) {
    final List<TaskItem> journalEntries = _projectJournalEntries(project)
        .map((TaskItem item) => item.clone())
        .toList(growable: true);
    final List<TaskItem> thinkingTasks = _projectThinkingTasks(project)
        .map((TaskItem item) => item.clone())
        .toList(growable: true);
    final List<TaskItem> planningTasks = _projectPlanningTasks(project)
        .map((TaskItem item) => item.clone())
        .toList(growable: true);
    final List<TaskItem> archivedTasks = _projectArchivedTasks(project)
        .map((TaskItem item) => item.clone())
        .toList(growable: true);
    final TaskItem adjustedTask = _taskAdjustedForProjectType(
      task,
      _projectTypeForProject(project),
    );

    if (adjustedTask.entryType == TaskEntryType.journal) {
      if (insertAtTop) {
        journalEntries.insert(0, adjustedTask);
      } else {
        journalEntries.add(adjustedTask);
      }
    } else if (adjustedTask.type == TaskItemType.planning) {
      if (insertAtTop) {
        planningTasks.insert(0, adjustedTask);
      } else {
        planningTasks.add(adjustedTask);
      }
    } else {
      if (insertAtTop) {
        thinkingTasks.insert(0, adjustedTask);
      } else {
        thinkingTasks.add(adjustedTask);
      }
    }

    _replaceProjectTasks(
      project: project,
      journalEntries: journalEntries,
      thinkingTasks: thinkingTasks,
      planningTasks: planningTasks,
      archivedTasks: archivedTasks,
    );
  }

  TaskItem _taskAdjustedForProjectType(
    TaskItem task,
    ProjectTypeConfig projectType,
  ) {
    TaskItem adjustedTask = task;

    if (adjustedTask.entryType == TaskEntryType.journal &&
        !projectType.showsJournalEntries) {
      adjustedTask = adjustedTask.copyWith(entryType: TaskEntryType.note);
    }

    if (projectType.showsOnlyJournalEntries &&
        adjustedTask.entryType != TaskEntryType.journal) {
      return adjustedTask.copyWith(
        entryType: TaskEntryType.journal,
        type: TaskItemType.thinking,
        createdAtMicros: adjustedTask.createdAtMicros ??
            DateTime.now().microsecondsSinceEpoch,
      );
    }

    if (adjustedTask.entryType == TaskEntryType.journal &&
        adjustedTask.type != TaskItemType.thinking) {
      adjustedTask = adjustedTask.copyWith(type: TaskItemType.thinking);
    }

    if (projectType.showsIdeas && !projectType.showsPlanningTasks) {
      return adjustedTask.type == TaskItemType.thinking
          ? adjustedTask
          : adjustedTask.copyWith(type: TaskItemType.thinking);
    }
    if (!projectType.showsIdeas && projectType.showsPlanningTasks) {
      return adjustedTask.type == TaskItemType.planning
          ? adjustedTask
          : adjustedTask.copyWith(type: TaskItemType.planning);
    }
    return adjustedTask;
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

  void _moveIncomingTaskToPosition({
    required String taskId,
    required int targetIndex,
  }) {
    final int sourceIndex = _indexOfTaskById(_incomingTasks, taskId);
    if (sourceIndex < 0) {
      return;
    }

    setState(() {
      final TaskItem movedTask = _incomingTasks.removeAt(sourceIndex);
      int insertionIndex = targetIndex;
      if (sourceIndex < insertionIndex) {
        insertionIndex -= 1;
      }
      insertionIndex = insertionIndex.clamp(0, _incomingTasks.length);
      _incomingTasks.insert(insertionIndex, movedTask);
    });
    _persistState();
  }

  void _nestIncomingTaskUnderTask({
    required String sourceTaskId,
    required String targetTaskId,
  }) {
    if (sourceTaskId == targetTaskId) {
      return;
    }

    final int sourceIndex = _indexOfTaskById(_incomingTasks, sourceTaskId);
    final int targetIndex = _indexOfTaskById(_incomingTasks, targetTaskId);
    if (sourceIndex < 0 || targetIndex < 0) {
      return;
    }

    final TaskItem sourceTask = _incomingTasks[sourceIndex];
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
      _incomingTasks.removeAt(sourceIndex);
      final int adjustedTargetIndex =
          sourceIndex < targetIndex ? targetIndex - 1 : targetIndex;
      final TaskItem targetTask = _incomingTasks[adjustedTargetIndex];
      _incomingTasks[adjustedTargetIndex] = targetTask.copyWith(
        subtasks: <SubTaskItem>[
          nestedItem,
          ...targetTask.subtasks.map((SubTaskItem item) => item.clone()),
        ],
      );
    });
    _persistState();
  }

  void _reorderVisibleProjects(List<String> reorderedProjectIds) {
    final Set<String> reorderedIdSet = reorderedProjectIds.toSet();
    final Map<String, ProjectItem> activeProjectsById = <String, ProjectItem>{
      for (final ProjectItem project in _projects)
        if (!project.isArchived) project.id: project.clone(),
    };
    final List<ProjectItem> reorderedProjects = <ProjectItem>[
      for (final String projectId in reorderedProjectIds)
        if (activeProjectsById.containsKey(projectId))
          activeProjectsById.remove(projectId)!,
    ];
    reorderedProjects.addAll(
      _projects.where(
        (ProjectItem project) =>
            !project.isArchived && !reorderedIdSet.contains(project.id),
      ),
    );
    reorderedProjects.addAll(
      _projects
          .where((ProjectItem project) => project.isArchived)
          .map((ProjectItem project) => project.clone()),
    );

    setState(() {
      _replaceProjectData(
        projects: reorderedProjects,
        projectStacks: _cloneProjectStacks(_projectStacks),
        projectTypes: _cloneProjectTypes(_projectTypes),
      );
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
          cardLayoutPreset: _cardLayoutPreset,
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
        initialPrompt: existingTask.prompt,
      ),
    );

    if (result == null) {
      return;
    }

    setState(() {
      sourceTasks[sourceTaskIndex] = existingTask.copyWith(
        title: result.title,
        body: result.body,
        prompt: result.prompt,
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
      sourceTasks[sourceTaskIndex] = task.copyWith(
        colorValue: selection.colorValue,
        clearColor: selection.colorValue == null,
      );
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
    final List<ProjectItem> targetProjects = _taskCompatibleProjects(
      currentProjectId: '',
    );
    final String? targetProjectId = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => MoveProjectTaskSheet(
        projects: targetProjects,
        projectTypes: _projectTypes,
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
      final ProjectItem targetProject = _projects[targetProjectIndex];
      _insertTaskIntoProject(
        targetProject,
        task,
        insertAtTop: true,
      );
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

    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: <Widget>[
              IconButton(
                onPressed: messenger.hideCurrentSnackBar,
                tooltip: 'Dismiss',
                icon: const Icon(Icons.close),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 32,
                  height: 32,
                ),
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(message)),
            ],
          ),
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
                leading: const Icon(Icons.label_outline),
                title: const Text('Set project type'),
                onTap: () =>
                    Navigator.of(context).pop(_ProjectMenuAction.setType),
              ),
              ListTile(
                leading: const Icon(Icons.layers_outlined),
                title: const Text('Set stack'),
                onTap: () =>
                    Navigator.of(context).pop(_ProjectMenuAction.setStack),
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
                    Navigator.of(context).pop(_ProjectMenuAction.setColor),
              ),
              if (!project.isArchived)
                ListTile(
                  leading: Icon(
                    project.isPinned ? Icons.push_pin_outlined : Icons.push_pin,
                  ),
                  title: Text(
                    project.isPinned ? 'Unpin project' : 'Pin project',
                  ),
                  onTap: () => Navigator.of(context)
                      .pop(_ProjectMenuAction.togglePinned),
                ),
              ListTile(
                leading: Icon(
                  project.isArchived
                      ? Icons.unarchive_outlined
                      : Icons.archive_outlined,
                ),
                title: Text(
                  project.isArchived ? 'Restore project' : 'Archive project',
                ),
                onTap: () => Navigator.of(context).pop(
                  project.isArchived
                      ? _ProjectMenuAction.restore
                      : _ProjectMenuAction.archive,
                ),
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
    if (action == _ProjectMenuAction.setType) {
      await _setProjectType(projectId);
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
    if (action == _ProjectMenuAction.togglePinned) {
      _toggleProjectPinned(projectId);
      return;
    }
    if (action == _ProjectMenuAction.archive) {
      _archiveProject(projectId);
      return;
    }
    if (action == _ProjectMenuAction.restore) {
      _restoreProject(projectId);
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
        initialPrompt: project.prompt,
        showPromptField: _projectUsesPromptFields(project),
      ),
    );

    if (result == null) {
      return;
    }

    setState(() {
      _projects[projectIndex] = project.copyWith(
        name: result.name,
        body: result.body,
        prompt: result.prompt,
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
      _projects[projectIndex] = project.copyWith(
        colorValue: selection.colorValue,
        clearColor: selection.colorValue == null,
      );
    });
    _persistState();
  }

  Future<void> _setProjectType(String projectId) async {
    final int projectIndex = _indexOfProjectById(projectId);
    if (projectIndex < 0) {
      return;
    }

    final ProjectItem project = _projects[projectIndex];
    final String? projectTypeId = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SelectProjectTypeSheet(
        projectTypes: _projectTypes,
        currentProjectTypeId:
            project.projectTypeId ?? ProjectTypeDefaults.blankId,
      ),
    );
    if (!mounted || projectTypeId == null) {
      return;
    }

    setState(() {
      _projects[projectIndex] = project.copyWith(projectTypeId: projectTypeId);
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
    final List<ProjectStack> projectStacks =
        _cloneProjectStacks(_projectStacks);
    final List<ProjectTypeConfig> projectTypes =
        _cloneProjectTypes(_projectTypes);
    final String? stackId = _resolveStackIdForSelection(
      selection: selection,
      projectStacks: projectStacks,
    );

    projects[projectIndex] = project.copyWith(
      stackId: stackId,
      clearStack: stackId == null,
    );

    setState(() {
      _replaceProjectData(
        projects: projects,
        projectStacks: projectStacks,
        projectTypes: projectTypes,
      );
    });
    _persistState();
  }

  void _toggleProjectPinned(String projectId) {
    final int projectIndex = _indexOfProjectById(projectId);
    if (projectIndex < 0) {
      return;
    }

    final ProjectItem project = _projects[projectIndex];
    setState(() {
      _projects[projectIndex] = project.copyWith(isPinned: !project.isPinned);
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
      _replaceProjectData(
        projects: projects,
        projectStacks: _cloneProjectStacks(_projectStacks),
        projectTypes: _cloneProjectTypes(_projectTypes),
      );
    });
    _persistState();
  }

  void _archiveProject(String projectId) {
    final int projectIndex = _indexOfProjectById(projectId);
    if (projectIndex < 0) {
      return;
    }

    final ProjectItem archivedProject = _projects[projectIndex].clone();
    if (archivedProject.isArchived) {
      return;
    }

    setState(() {
      _projects[projectIndex] = archivedProject.copyWith(isArchived: true);
    });
    _persistState();
    _showUndoTaskDeletion(
      message: 'Project archived.',
      onUndo: () {
        final int currentIndex = _indexOfProjectById(projectId);
        if (currentIndex < 0) {
          return;
        }
        setState(() {
          _projects[currentIndex] = _projects[currentIndex].copyWith(
            isArchived: false,
          );
        });
        _persistState();
      },
    );
  }

  void _restoreProject(String projectId) {
    final int projectIndex = _indexOfProjectById(projectId);
    if (projectIndex < 0) {
      return;
    }

    final ProjectItem project = _projects[projectIndex];
    if (!project.isArchived) {
      return;
    }

    setState(() {
      _projects[projectIndex] = project.copyWith(isArchived: false);
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
      builder: (_) => AddTaskSheet(
        projects: _taskCompatibleProjects(currentProjectId: ''),
        projectTypes: _projectTypes,
      ),
    );
    _isAddTaskSheetOpen = false;

    if (result == null) {
      return;
    }

    setState(() {
      final String? targetProjectId = result.targetProjectId;
      final int targetProjectIndex =
          targetProjectId == null ? -1 : _indexOfProjectById(targetProjectId);
      if (targetProjectIndex >= 0) {
        _insertTaskIntoProject(
          _projects[targetProjectIndex],
          result.task,
          insertAtTop: result.insertAtTop,
        );
      } else if (result.insertAtTop) {
        _incomingTasks.insert(0, result.task);
      } else {
        _incomingTasks.add(result.task);
      }
    });
    _persistState();
  }

  Future<void> _openAddProjectWidget({
    ProjectStackSelection initialStackSelection =
        const ProjectStackSelection.none(),
  }) async {
    final AddProjectResult? result =
        await showModalBottomSheet<AddProjectResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => AddProjectSheet(
        projectStacks: _projectStacks,
        projectTypes: _projectTypes,
        initialStackSelection: initialStackSelection,
      ),
    );

    if (result == null) {
      return;
    }

    final List<ProjectItem> projects = _cloneProjects(_projects);
    final List<ProjectStack> projectStacks =
        _cloneProjectStacks(_projectStacks);
    final List<ProjectTypeConfig> projectTypes =
        _cloneProjectTypes(_projectTypes);
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
          projectTypeId: result.projectTypeId,
        ),
      );
      _replaceProjectData(
        projects: projects,
        projectStacks: projectStacks,
        projectTypes: projectTypes,
      );
    });
    _persistState();
  }

  Future<void> _stackProjectGroupsTogether({
    required List<String> sourceProjectIds,
    required List<String> targetProjectIds,
  }) async {
    final Set<String> combinedIds = <String>{
      ...sourceProjectIds,
      ...targetProjectIds,
    };
    if (combinedIds.length < 2) {
      return;
    }

    final List<ProjectItem> selectedProjects = combinedIds
        .map(_projectById)
        .whereType<ProjectItem>()
        .toList(growable: false);
    if (selectedProjects.length < 2) {
      return;
    }

    final String? suggestedStackId = selectedProjects
        .map((ProjectItem project) => project.stackId)
        .whereType<String>()
        .cast<String?>()
        .firstWhere((String? value) => value != null, orElse: () => null);
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
    final List<ProjectStack> projectStacks =
        _cloneProjectStacks(_projectStacks);
    final List<ProjectTypeConfig> projectTypes =
        _cloneProjectTypes(_projectTypes);
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
        if (!combinedIds.contains(project.id)) {
          continue;
        }
        projects[index] = project.copyWith(stackId: stackId);
      }
      _replaceProjectData(
        projects: projects,
        projectStacks: projectStacks,
        projectTypes: projectTypes,
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
          projectStacks: _cloneProjectStacks(_projectStacks),
          projectTypes: _cloneProjectTypes(_projectTypes),
          colorLabels: _colorLabels,
          hideCompletedProjectItems: _hideCompletedProjectItems,
          cardLayoutPreset: _cardLayoutPreset,
          onProjectDataChanged: (
            List<ProjectItem> updatedProjects,
            List<ProjectStack> updatedProjectStacks,
          ) {
            final List<ProjectItem> projectsCopy =
                _cloneProjects(updatedProjects);
            final List<ProjectStack> projectStacksCopy =
                _cloneProjectStacks(updatedProjectStacks);
            setState(() {
              _replaceProjectData(
                projects: projectsCopy,
                projectStacks: projectStacksCopy,
                projectTypes: _cloneProjectTypes(_projectTypes),
              );
            });
            _persistState();
          },
        ),
      ),
    );
  }

  List<ProjectItem> _visiblePinnedProjects() {
    return _projects
        .where(
          (ProjectItem project) => project.isPinned && !project.isArchived,
        )
        .toList(growable: false);
  }

  IconData _incomingPinnedProjectIcon(ProjectItem project) {
    final IconData? explicitIcon = iconDataForKey(project.iconKey);
    if (explicitIcon != null) {
      return explicitIcon;
    }
    final IconData? typeIcon =
        iconDataForKey(_projectTypeForProject(project).iconKey);
    return typeIcon ?? Icons.folder_outlined;
  }

  int _visibleProjectTaskCount(ProjectItem project) {
    if (_projectTypeForProject(project).id == ProjectTypeDefaults.peopleId) {
      return project.people
          .where((PersonItem person) => !person.isArchived)
          .length;
    }
    return project.tasks.where((TaskItem task) => !task.isArchived).length;
  }

  Widget _buildPinnedProjectsSection() {
    final List<ProjectItem> pinnedProjects = _visiblePinnedProjects();
    if (pinnedProjects.isEmpty) {
      return const SizedBox.shrink();
    }

    final CardLayoutSpec layout = cardLayoutSpecForPreset(_cardLayoutPreset);
    final TextStyle? titleStyle = Theme.of(context).textTheme.titleMedium;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: <Widget>[
              const Icon(Icons.push_pin_outlined, size: 20),
              const SizedBox(width: 8),
              Text(
                'Pinned projects',
                style: titleStyle,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        for (final ProjectItem project in pinnedProjects) ...<Widget>[
          Builder(
            builder: (BuildContext context) {
              final int visibleTaskCount = _visibleProjectTaskCount(project);
              final bool isPeopleProject =
                  _projectTypeForProject(project).id ==
                      ProjectTypeDefaults.peopleId;
              return Card(
                color: project.colorValue == null
                    ? null
                    : Color(project.colorValue!),
                child: ListTile(
                  contentPadding: layout.contentPadding,
                  leading: Icon(_incomingPinnedProjectIcon(project)),
                  title: Text(
                    project.name,
                    maxLines: null,
                    style: titleStyle?.copyWith(
                      fontSize: (titleStyle.fontSize ?? 16) * layout.titleScale,
                    ),
                  ),
                  subtitle: Text(
                    <String>[
                      if (_stackNameForProject(project)
                          case final String stackName)
                        'Stack: $stackName',
                      if (project.body.isNotEmpty) project.body,
                      isPeopleProject
                          ? '$visibleTaskCount active '
                              'person${visibleTaskCount == 1 ? '' : 's'}'
                          : '$visibleTaskCount active task'
                              '${visibleTaskCount == 1 ? '' : 's'}',
                    ].join('\n'),
                  ),
                  isThreeLine: project.body.isNotEmpty ||
                      _stackNameForProject(project) != null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Icon(Icons.push_pin_outlined, size: 18),
                      IconButton(
                        tooltip: 'Project options',
                        onPressed: () => _openProjectMenu(project.id),
                        icon: const Icon(Icons.more_vert),
                      ),
                    ],
                  ),
                  onTap: () => _openProjectDetail(project.id),
                ),
              );
            },
          ),
          SizedBox(height: layout.listBottomSpacing),
        ],
      ],
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
          ..addAll(persistedState.incomingTasks);
        _replaceProjectData(
          projects: persistedState.projects,
          projectStacks: persistedState.projectStacks,
          projectTypes: persistedState.projectTypes,
        );
        _colorLabels
          ..clear()
          ..addAll(persistedState.colorLabels);
        _hideCompletedProjectItems = persistedState.hideCompletedProjectItems;
        _cardLayoutPreset = persistedState.cardLayoutPreset;
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
      projects:
          _projects.map((ProjectItem project) => project.clone()).toList(),
      projectStacks:
          _projectStacks.map((ProjectStack stack) => stack.clone()).toList(),
      projectTypes:
          _projectTypes.map((ProjectTypeConfig type) => type.clone()).toList(),
      colorLabels: Map<int, String>.from(_colorLabels),
      hideCompletedProjectItems: _hideCompletedProjectItems,
      cardLayoutPreset: _cardLayoutPreset,
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

  void _updateCardLayoutPreset(CardLayoutPreset value) {
    setState(() {
      _cardLayoutPreset = value;
    });
    _persistState();
  }

  void _updateProjectTypes(List<ProjectTypeConfig> projectTypes) {
    setState(() {
      _replaceProjectData(
        projects: _cloneProjects(_projects),
        projectStacks: _cloneProjectStacks(_projectStacks),
        projectTypes: _cloneProjectTypes(projectTypes),
      );
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
        _replaceProjectData(
          projects: importedState.projects
              .map((ProjectItem project) => project.clone())
              .toList(),
          projectStacks: importedState.projectStacks
              .map((ProjectStack stack) => stack.clone())
              .toList(),
          projectTypes: importedState.projectTypes
              .map((ProjectTypeConfig type) => type.clone())
              .toList(),
        );
        _colorLabels
          ..clear()
          ..addAll(importedState.colorLabels);
        _hideCompletedProjectItems = importedState.hideCompletedProjectItems;
        _cardLayoutPreset = importedState.cardLayoutPreset;
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
          projectTypes: _projectTypes,
          onProjectTypesChanged: _updateProjectTypes,
          colorLabels: _colorLabels,
          onColorLabelsChanged: _updateColorLabels,
          hideCompletedProjectItems: _hideCompletedProjectItems,
          onHideCompletedProjectItemsChanged: _updateHideCompletedProjectItems,
          cardLayoutPreset: _cardLayoutPreset,
          onCardLayoutPresetChanged: _updateCardLayoutPreset,
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
            header: _visiblePinnedProjects().isEmpty
                ? null
                : _buildPinnedProjectsSection(),
            tasks: _incomingTasks,
            emptyLabel: 'No incoming tasks yet.',
            cardLayoutPreset: _cardLayoutPreset,
            onTaskTap: _openIncomingTaskView,
            onTaskOptionsTap: _openIncomingTaskMenu,
            onMoveTaskToProject: (String taskId) =>
                _moveTaskFromListToProject(_incomingTasks, taskId),
            onRemoveTask: (String taskId) =>
                _deleteTaskInList(_incomingTasks, taskId),
            onMoveTask: ({
              required String taskId,
              required int targetIndex,
            }) =>
                _moveIncomingTaskToPosition(
              taskId: taskId,
              targetIndex: targetIndex,
            ),
            onNestTask: ({
              required String sourceTaskId,
              required String targetTaskId,
            }) =>
                _nestIncomingTaskUnderTask(
              sourceTaskId: sourceTaskId,
              targetTaskId: targetTaskId,
            ),
          ),
          ProjectListView(
            projects: _projects,
            projectStacks: _projectStacks,
            projectTypes: _projectTypes,
            cardLayoutPreset: _cardLayoutPreset,
            onVisibleProjectOrderChanged: _reorderVisibleProjects,
            onProjectTap: (String projectId) async =>
                _openProjectDetail(projectId),
            onProjectArchive: _archiveProject,
            onProjectRestore: _restoreProject,
            onProjectRemove: _deleteProject,
            onProjectOptionsTap: _openProjectMenu,
            onProjectStackOptionsTap: _openProjectStackMenu,
            onProjectStackDrop: (
              List<String> sourceProjectIds,
              List<String> targetProjectIds,
            ) =>
                _stackProjectGroupsTogether(
              sourceProjectIds: sourceProjectIds,
              targetProjectIds: targetProjectIds,
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
