import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/list_reorder.dart';
import '../../domain/task_models.dart';
import '../task_text_clipboard.dart';
import '../widgets/add_journal_entry_sheet.dart';
import '../widgets/add_project_entry_sheet.dart';
import '../widgets/add_session_sheet.dart';
import '../widgets/add_task_sheet.dart';
import '../widgets/card_layout.dart';
import '../widgets/edit_project_entry_sheet.dart';
import '../widgets/edit_project_sheet.dart';
import '../widgets/edit_task_sheet.dart';
import '../widgets/item_color_picker_sheet.dart';
import '../widgets/item_icon_picker_sheet.dart';
import '../widgets/move_project_task_sheet.dart';
import '../widgets/quick_capture_sheet.dart';
import '../widgets/select_project_stack_sheet.dart';
import '../widgets/select_project_type_sheet.dart';
import '../widgets/subtask_preview_tree.dart';
import '../widgets/task_image_gallery.dart';
import 'project_entry_detail_page.dart';
import 'task_detail_page.dart';

class _TaskSectionDragPayload {
  const _TaskSectionDragPayload({required this.taskId});

  final String taskId;
}

class _PersonDragPayload {
  const _PersonDragPayload({required this.personId});

  final String personId;
}

enum _ProjectTaskMenuAction {
  open,
  edit,
  setIcon,
  setColor,
  moveToTop,
  moveToBottom,
  moveBetweenSections,
  moveToProject,
  togglePinned,
  archive,
  restore,
  remove,
}

enum _ProjectMenuAction {
  edit,
  setType,
  setStack,
  setIcon,
  setColor,
  archive,
  restore,
  remove,
}

enum _GeneratePromptAction { allTasks, filterByColor }

enum _ProjectEntryKind { journal, thinking, planning }

enum _PersonCardMenuAction {
  open,
  edit,
  setIcon,
  setColor,
  moveToTop,
  moveToBottom,
  remove,
}

class ProjectDetailPage extends StatefulWidget {
  const ProjectDetailPage({
    super.key,
    required this.projectId,
    required this.initialProjects,
    required this.projectStacks,
    required this.projectTypes,
    required this.colorLabels,
    required this.hideCompletedProjectItems,
    required this.cardLayoutPreset,
    required this.onProjectDataChanged,
  });

  final String projectId;
  final List<ProjectItem> initialProjects;
  final List<ProjectStack> projectStacks;
  final List<ProjectTypeConfig> projectTypes;
  final Map<int, String> colorLabels;
  final bool hideCompletedProjectItems;
  final CardLayoutPreset cardLayoutPreset;
  final void Function(
    List<ProjectItem> projects,
    List<ProjectStack> projectStacks,
  ) onProjectDataChanged;

  @override
  State<ProjectDetailPage> createState() => _ProjectDetailPageState();
}

class _ProjectDetailPageState extends State<ProjectDetailPage> {
  late final List<ProjectItem> _projects;
  late final List<ProjectStack> _projectStacks;
  bool _showArchivedTasks = false;
  final Set<String> _expandedProjectTaskIds = <String>{};
  String? _draggingProjectTaskId;
  String? _draggingPersonId;

  CardLayoutSpec get _layout =>
      cardLayoutSpecForPreset(widget.cardLayoutPreset);

  @override
  void initState() {
    super.initState();
    _projects = _cloneProjects(widget.initialProjects);
    _projectStacks = _cloneProjectStacks(widget.projectStacks);
  }

  List<ProjectItem> _cloneProjects(List<ProjectItem> projects) {
    return projects
        .map((ProjectItem project) => project.clone())
        .toList(growable: true);
  }

  List<ProjectStack> _cloneProjectStacks(List<ProjectStack> projectStacks) {
    return projectStacks
        .map((ProjectStack stack) => stack.clone())
        .toList(growable: true);
  }

  void _notifyProjectDataChanged() {
    widget.onProjectDataChanged(
      _cloneProjects(_projects),
      _cloneProjectStacks(_projectStacks),
    );
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
          (TaskItem task) =>
              task.type == type && (includeArchived || !task.isArchived),
        )
        .toList(growable: false);
  }

  List<TaskItem> _journalEntries(
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

  List<TaskItem> _thinkingTasks(
    ProjectItem project, {
    bool includeArchived = false,
  }) {
    return _tasksByType(
      project,
      TaskItemType.thinking,
      includeArchived: includeArchived,
    )
        .where((TaskItem task) => task.entryType != TaskEntryType.journal)
        .toList(growable: false);
  }

  List<TaskItem> _planningTasks(
    ProjectItem project, {
    bool includeArchived = false,
  }) {
    return _tasksByType(
      project,
      TaskItemType.planning,
      includeArchived: includeArchived,
    )
        .where((TaskItem task) => task.entryType != TaskEntryType.journal)
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

  void _replaceProjectTasks({
    required ProjectItem project,
    required List<TaskItem> journalEntries,
    required List<TaskItem> thinkingTasks,
    required List<TaskItem> planningTasks,
    required List<TaskItem> archivedTasks,
  }) {
    project.tasks
      ..clear()
      ..addAll(_withPinnedTasksFirst(journalEntries))
      ..addAll(_withPinnedTasksFirst(thinkingTasks))
      ..addAll(_withPinnedTasksFirst(planningTasks))
      ..addAll(_withPinnedTasksFirst(archivedTasks));
  }

  List<TaskItem> _withPinnedTasksFirst(List<TaskItem> tasks) {
    return <TaskItem>[
      ...tasks
          .where((TaskItem task) => task.isPinned)
          .map((TaskItem task) => task.clone()),
      ...tasks
          .where((TaskItem task) => !task.isPinned)
          .map((TaskItem task) => task.clone()),
    ];
  }

  ProjectTypeConfig _projectTypeFor(ProjectItem project) {
    return ProjectRules.resolveProjectType(
      project.projectTypeId,
      widget.projectTypes,
    );
  }

  ProjectRules _projectRulesFor(ProjectItem project) {
    return ProjectRules.forProject(
      project: project,
      projectTypes: widget.projectTypes,
    );
  }

  bool _isLlmProject(ProjectItem project) {
    return _projectTypeFor(project).id == ProjectTypeDefaults.llmId;
  }

  bool _isKnowledgeProject(ProjectItem project) {
    return _projectTypeFor(project).id == ProjectTypeDefaults.knowledgeId;
  }

  List<TaskItem> _sessionTasks(ProjectItem project) {
    return _thinkingTasks(project)
        .where((TaskItem task) => task.entryType == TaskEntryType.session)
        .toList(growable: false);
  }

  List<TaskItem> _promptEligibleTasks(ProjectItem project) {
    return project.tasks
        .where(
          (TaskItem task) => !task.isArchived && task.prompt.trim().isNotEmpty,
        )
        .toList(growable: false);
  }

  List<int> _availablePromptTaskColors(ProjectItem project) {
    final Set<int> seenColors = <int>{};
    final List<int> colors = <int>[];
    for (final TaskItem task in _promptEligibleTasks(project)) {
      final int? colorValue = task.colorValue;
      if (colorValue == null || !seenColors.add(colorValue)) {
        continue;
      }
      colors.add(colorValue);
    }
    return colors;
  }

  String _colorLabel(int colorValue) {
    final String? customLabel = widget.colorLabels[colorValue];
    if (customLabel != null && customLabel.trim().isNotEmpty) {
      return customLabel.trim();
    }

    final String hexValue =
        colorValue.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase();
    return '#$hexValue';
  }

  ProjectStack? _projectStackByName(String stackName) {
    final String normalizedName = stackName.trim().toLowerCase();
    if (normalizedName.isEmpty) {
      return null;
    }

    for (final ProjectStack stack in _projectStacks) {
      if (stack.name.trim().toLowerCase() == normalizedName) {
        return stack;
      }
    }
    return null;
  }

  String? _resolveStackIdForSelection(ProjectStackSelection selection) {
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
    final ProjectStack? existingStack = _projectStackByName(stackName);
    if (existingStack != null) {
      return existingStack.id;
    }

    final ProjectStack newStack = ProjectStack(name: stackName);
    _projectStacks.insert(0, newStack);
    return newStack.id;
  }

  bool _showsJournalSection(ProjectItem project) {
    final ProjectTypeConfig projectType = _projectTypeFor(project);
    return projectType.showsJournalEntries ||
        _journalEntries(project).isNotEmpty;
  }

  bool _showsIdeasSection(ProjectItem project) {
    final ProjectTypeConfig projectType = _projectTypeFor(project);
    return projectType.showsIdeas || _thinkingTasks(project).isNotEmpty;
  }

  bool _showsPlanningSection(ProjectItem project) {
    final ProjectTypeConfig projectType = _projectTypeFor(project);
    return projectType.showsPlanningTasks || _planningTasks(project).isNotEmpty;
  }

  bool _canCreateEntries(ProjectItem project) {
    return _projectRulesFor(project).acceptsRootTasks;
  }

  bool _projectAcceptsRootTasks(ProjectItem project) {
    return _projectRulesFor(project).acceptsRootTasks;
  }

  String _peopleItemLabel(ProjectItem project) {
    return _projectTypeFor(project).childItemLabel;
  }

  String _peopleItemsLabel(ProjectItem project) {
    return _projectTypeFor(project).childItemsLabel;
  }

  List<PersonItem> _visiblePeople(ProjectItem project) {
    return project.people
        .where((PersonItem person) => !person.isArchived)
        .toList(growable: false);
  }

  int _findPersonIndex(ProjectItem project, String personId) {
    return project.people.indexWhere(
      (PersonItem person) => person.id == personId,
    );
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

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _createSession() async {
    final ProjectItem? project = _findProject();
    if (project == null || !_isKnowledgeProject(project)) {
      return;
    }

    final AddSessionResult? result =
        await showModalBottomSheet<AddSessionResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const AddSessionSheet(),
    );

    if (!mounted || result == null) {
      return;
    }

    final List<TaskItem> thinkingTasks =
        _tasksByType(project, TaskItemType.thinking, includeArchived: false)
            .where((TaskItem task) => task.entryType != TaskEntryType.journal)
            .toList(growable: true);
    final List<TaskItem> planningTasks = _planningTasks(
      project,
    ).toList(growable: true);
    final List<TaskItem> journalEntries = _journalEntries(
      project,
    ).toList(growable: true);
    final List<TaskItem> archivedTasks = _archivedTasks(
      project,
    ).toList(growable: true);

    final TaskItem sessionTask = TaskItem(
      title: result.title,
      body: result.body,
      type: TaskItemType.thinking,
      entryType: TaskEntryType.session,
      iconKey: 'book-open',
    );

    if (result.insertAtTop) {
      thinkingTasks.insert(0, sessionTask);
    } else {
      thinkingTasks.add(sessionTask);
    }

    setState(() {
      _replaceProjectTasks(
        project: project,
        journalEntries: journalEntries,
        thinkingTasks: thinkingTasks,
        planningTasks: planningTasks,
        archivedTasks: archivedTasks,
      );
      _expandedProjectTaskIds.add(sessionTask.id);
    });
    _notifyProjectDataChanged();
  }

  Future<void> _quickCaptureToLatestSession() async {
    final ProjectItem? project = _findProject();
    if (project == null || !_isKnowledgeProject(project)) {
      return;
    }

    final List<TaskItem> sessions = _sessionTasks(project);
    if (sessions.isEmpty) {
      _showMessage('Create a session first to use quick capture.');
      return;
    }

    final TaskItem targetSession = sessions.first;
    final QuickCaptureResult? result =
        await showModalBottomSheet<QuickCaptureResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => QuickCaptureSheet(sessionTitle: targetSession.title),
    );

    if (!mounted || result == null) {
      return;
    }

    final int sessionIndex = _findTaskIndex(project, targetSession.id);
    if (sessionIndex < 0) {
      return;
    }

    setState(() {
      final TaskItem sessionTask = project.tasks[sessionIndex];
      project.tasks[sessionIndex] = sessionTask.copyWith(
        subtasks: <SubTaskItem>[
          SubTaskItem(title: result.title, body: result.body),
          ...sessionTask.subtasks.map((SubTaskItem item) => item.clone()),
        ],
      );
      _expandedProjectTaskIds.add(targetSession.id);
    });
    _notifyProjectDataChanged();
  }

  String _createJournalEntryTitle(int createdAtMicros) {
    final DateTime createdAt = DateTime.fromMicrosecondsSinceEpoch(
      createdAtMicros,
    );
    final String month = createdAt.month.toString().padLeft(2, '0');
    final String day = createdAt.day.toString().padLeft(2, '0');
    final String hour = createdAt.hour.toString().padLeft(2, '0');
    final String minute = createdAt.minute.toString().padLeft(2, '0');
    return 'Journal entry ${createdAt.year}-$month-$day $hour:$minute';
  }

  String _journalTimestampLabel(TaskItem task) {
    final DateTime? createdAt = task.createdAt;
    if (createdAt == null) {
      return task.title;
    }

    final MaterialLocalizations localizations = MaterialLocalizations.of(
      context,
    );
    final String dateLabel = localizations.formatFullDate(createdAt);
    final String timeLabel = localizations.formatTimeOfDay(
      TimeOfDay.fromDateTime(createdAt),
    );
    return '$dateLabel at $timeLabel';
  }

  String _journalBodyText(TaskItem task) {
    if (task.body.trim().isNotEmpty) {
      return task.body.trim();
    }
    return task.title.trim();
  }

  void _insertTaskIntoProject(
    ProjectItem project,
    TaskItem task, {
    required bool insertAtTop,
  }) {
    final List<TaskItem> journalEntries = _journalEntries(
      project,
    ).toList(growable: true);
    final List<TaskItem> thinkingTasks = _thinkingTasks(
      project,
    ).toList(growable: true);
    final List<TaskItem> planningTasks = _planningTasks(
      project,
    ).toList(growable: true);
    final List<TaskItem> archivedTasks = _archivedTasks(
      project,
    ).toList(growable: true);
    final TaskItem adjustedTask = _projectRulesFor(project).normalizeTask(task);

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

  Future<_GeneratePromptAction?> _showGeneratePromptMenu() {
    return showModalBottomSheet<_GeneratePromptAction>(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: <Widget>[
              const ListTile(
                leading: Icon(Icons.memory_outlined),
                title: Text(
                  'Generate Prompt',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.memory_outlined),
                title: const Text('Use all prompt tasks'),
                subtitle: const Text(
                  'Include every non-archived task with a prompt.',
                ),
                onTap: () =>
                    Navigator.of(context).pop(_GeneratePromptAction.allTasks),
              ),
              ListTile(
                leading: const Icon(Icons.palette_outlined),
                title: const Text('Filter by colors'),
                subtitle: const Text(
                  'Generate from prompt tasks matching selected card colors.',
                ),
                onTap: () => Navigator.of(
                  context,
                ).pop(_GeneratePromptAction.filterByColor),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<Set<int>?> _selectPromptColors(ProjectItem project) async {
    final List<int> availableColors = _availablePromptTaskColors(project);
    if (availableColors.isEmpty) {
      _showMessage(
        'No colored tasks with prompts are available for this project.',
      );
      return null;
    }

    final Set<int> initialSelection = availableColors.toSet();
    return showModalBottomSheet<Set<int>>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        final Set<int> selectedColors = <int>{...initialSelection};
        return StatefulBuilder(
          builder: (
            BuildContext context,
            void Function(void Function()) setModalState,
          ) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  16 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const Row(
                      children: <Widget>[
                        Icon(Icons.memory_outlined),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Filter Prompt Tasks',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        children: <Widget>[
                          for (final int colorValue in availableColors)
                            CheckboxListTile(
                              value: selectedColors.contains(colorValue),
                              contentPadding: EdgeInsets.zero,
                              secondary: CircleAvatar(
                                radius: 10,
                                backgroundColor: Color(colorValue),
                              ),
                              title: Text(_colorLabel(colorValue)),
                              onChanged: (bool? value) {
                                setModalState(() {
                                  if (value ?? false) {
                                    selectedColors.add(colorValue);
                                  } else {
                                    selectedColors.remove(colorValue);
                                  }
                                });
                              },
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: selectedColors.isEmpty
                          ? null
                          : () => Navigator.of(
                                context,
                              ).pop(<int>{...selectedColors}),
                      icon: const Icon(Icons.memory_outlined),
                      label: const Text('Generate Prompt'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _buildGeneratedPrompt({
    required ProjectItem project,
    required List<TaskItem> tasks,
    Set<int>? selectedColors,
  }) {
    final StringBuffer buffer = StringBuffer()
      ..writeln('Project: ${project.name}')
      ..writeln();

    final String projectBody = project.body.trim();
    final String projectPrompt = project.prompt.trim();
    if (projectBody.isNotEmpty) {
      buffer
        ..writeln('Project description:')
        ..writeln(projectBody)
        ..writeln();
    }
    if (projectPrompt.isNotEmpty) {
      buffer
        ..writeln('Project prompt:')
        ..writeln(projectPrompt)
        ..writeln();
    }
    if (selectedColors != null && selectedColors.isNotEmpty) {
      final List<String> labels =
          selectedColors.map(_colorLabel).toList(growable: false);
      buffer
        ..writeln('Selected colors: ${labels.join(', ')}')
        ..writeln();
    }

    buffer.writeln('Selected tasks:');
    for (int index = 0; index < tasks.length; index += 1) {
      final TaskItem task = tasks[index];
      buffer.writeln('${index + 1}. ${task.title}');
      final String taskBody = task.body.trim();
      if (taskBody.isNotEmpty) {
        buffer
          ..writeln('Body:')
          ..writeln(taskBody)
          ..writeln();
      }
      buffer
        ..writeln('Prompt:')
        ..writeln(task.prompt.trim());
      if (index < tasks.length - 1) {
        buffer.writeln();
      }
    }

    buffer
      ..writeln()
      ..writeln(
        'Using the project context and selected tasks above, generate a clear '
        'implementation prompt for building this feature. Include scope, '
        'constraints, edge cases, suggested steps, and expected output.',
      );

    return buffer.toString().trimRight();
  }

  Future<void> _showGeneratedPromptSheet(String generatedPrompt) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return FractionallySizedBox(
          heightFactor: 0.9,
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                16 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const Row(
                    children: <Widget>[
                      Icon(Icons.memory_outlined),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Generated Prompt',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: SingleChildScrollView(
                      child: SelectableText(generatedPrompt),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(text: generatedPrompt),
                            );
                            if (!context.mounted) {
                              return;
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Prompt copied to clipboard.'),
                              ),
                            );
                          },
                          icon: const Icon(Icons.copy_outlined),
                          label: const Text('Copy'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () async {
                            await SharePlus.instance.share(
                              ShareParams(
                                text: generatedPrompt,
                                subject: 'Generated prompt',
                              ),
                            );
                          },
                          icon: const Icon(Icons.share_outlined),
                          label: const Text('Share'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openGeneratePromptFlow() async {
    final ProjectItem? project = _findProject();
    if (project == null || !_isLlmProject(project)) {
      return;
    }

    final _GeneratePromptAction? action = await _showGeneratePromptMenu();
    if (!mounted || action == null) {
      return;
    }

    final List<TaskItem> promptTasks = _promptEligibleTasks(project);
    if (promptTasks.isEmpty) {
      _showMessage('No tasks with prompts are available for this project.');
      return;
    }

    if (action == _GeneratePromptAction.allTasks) {
      await _showGeneratedPromptSheet(
        _buildGeneratedPrompt(project: project, tasks: promptTasks),
      );
      return;
    }

    final Set<int>? selectedColors = await _selectPromptColors(project);
    if (!mounted || selectedColors == null) {
      return;
    }

    final List<TaskItem> filteredTasks = promptTasks
        .where(
          (TaskItem task) =>
              task.colorValue != null &&
              selectedColors.contains(task.colorValue),
        )
        .toList(growable: false);
    if (filteredTasks.isEmpty) {
      _showMessage('No tasks with prompts match the selected colors.');
      return;
    }

    await _showGeneratedPromptSheet(
      _buildGeneratedPrompt(
        project: project,
        tasks: filteredTasks,
        selectedColors: selectedColors,
      ),
    );
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
    final ProjectRules projectRules = _projectRulesFor(project);
    final bool canMoveBetweenSections =
        task.entryType != TaskEntryType.session &&
            task.entryType != TaskEntryType.journal &&
            projectRules.canMoveBetweenTaskSections;
    final TaskDetailAction? action =
        await Navigator.of(context).push<TaskDetailAction>(
      MaterialPageRoute<TaskDetailAction>(
        builder: (_) => TaskDetailPage(
          task: task,
          cardLayoutPreset: widget.cardLayoutPreset,
          colorLabels: widget.colorLabels,
          onTaskChanged: (TaskItem updatedTask) {
            final ProjectItem? activeProject = _findProject();
            if (activeProject == null) {
              return;
            }
            final int sourceTaskIndex = _findTaskIndex(
              activeProject,
              taskId,
            );
            if (sourceTaskIndex < 0) {
              return;
            }
            setState(() {
              activeProject.tasks[sourceTaskIndex] = updatedTask.clone();
            });
            _notifyProjectDataChanged();
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
    final ProjectRules? projectRules =
        project == null ? null : _projectRulesFor(project);
    final bool canMoveToOtherSection = project != null &&
        task.entryType != TaskEntryType.session &&
        task.entryType != TaskEntryType.journal &&
        projectRules!.canMoveBetweenTaskSections;
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
                trailing: IconButton(
                  tooltip: 'Copy task text',
                  icon: const Icon(Icons.copy_outlined),
                  onPressed: () {
                    Navigator.of(context).pop();
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      copyTaskTextToClipboard(this.context, task);
                    });
                  },
                ),
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
              if (!task.isArchived)
                ListTile(
                  leading: const Icon(Icons.vertical_align_top_outlined),
                  title: const Text('Move to top'),
                  onTap: () => Navigator.of(
                    context,
                  ).pop(_ProjectTaskMenuAction.moveToTop),
                ),
              if (!task.isArchived)
                ListTile(
                  leading: const Icon(Icons.vertical_align_bottom_outlined),
                  title: const Text('Move to bottom'),
                  onTap: () => Navigator.of(
                    context,
                  ).pop(_ProjectTaskMenuAction.moveToBottom),
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
                  onTap: () => Navigator.of(
                    context,
                  ).pop(_ProjectTaskMenuAction.moveBetweenSections),
                ),
              ListTile(
                leading: const Icon(Icons.drive_file_move_outlined),
                title: const Text('Move to project'),
                onTap: () => Navigator.of(
                  context,
                ).pop(_ProjectTaskMenuAction.moveToProject),
              ),
              if (!task.isArchived)
                ListTile(
                  leading: Icon(
                    task.isPinned ? Icons.push_pin_outlined : Icons.push_pin,
                  ),
                  title: Text(task.isPinned ? 'Unpin task' : 'Pin task'),
                  onTap: () => Navigator.of(
                    context,
                  ).pop(_ProjectTaskMenuAction.togglePinned),
                ),
              ListTile(
                leading: Icon(
                  task.isArchived
                      ? Icons.unarchive_outlined
                      : Icons.archive_outlined,
                ),
                title: Text(task.isArchived ? 'Restore task' : 'Archive task'),
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
    if (action == _ProjectTaskMenuAction.moveToTop) {
      _moveTaskToBoundary(taskId, toTop: true);
      return;
    }
    if (action == _ProjectTaskMenuAction.moveToBottom) {
      _moveTaskToBoundary(taskId, toTop: false);
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
    if (action == _ProjectTaskMenuAction.togglePinned) {
      _toggleTaskPinned(taskId);
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
        initialPrompt: task.prompt,
        initialFlashcardPrompt: task.flashcardPrompt,
        initialImagePaths: task.imagePaths,
        showPromptField: _isLlmProject(project),
        showFlashcardField: true,
      ),
    );

    if (result == null) {
      return;
    }

    setState(() {
      project.tasks[taskIndex] = task.copyWith(
        title: result.title,
        body: result.body,
        prompt: result.prompt,
        flashcardPrompt: result.flashcardPrompt,
        imagePaths: result.imagePaths,
      );
    });
    _notifyProjectDataChanged();
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
      builder: (_) => ItemIconPickerSheet(currentIconKey: task.iconKey),
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
    _notifyProjectDataChanged();
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
      project.tasks[taskIndex] = task.copyWith(
        colorValue: selection.colorValue,
        clearColor: selection.colorValue == null,
      );
    });
    _notifyProjectDataChanged();
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
    if (task.entryType == TaskEntryType.session &&
        type != TaskItemType.thinking) {
      return;
    }

    final List<TaskItem> journalEntries = _journalEntries(
      project,
    ).toList(growable: true);
    final List<TaskItem> thinkingTasks = _thinkingTasks(
      project,
    ).toList(growable: true);
    final List<TaskItem> planningTasks = _planningTasks(
      project,
    ).toList(growable: true);
    final List<TaskItem> archivedTasks = _archivedTasks(
      project,
    ).toList(growable: true);

    if (task.type == TaskItemType.thinking) {
      thinkingTasks.removeWhere((TaskItem entry) => entry.id == taskId);
    } else {
      planningTasks.removeWhere((TaskItem entry) => entry.id == taskId);
    }
    final TaskItem updatedTask = task.copyWith(type: type);
    if (type == TaskItemType.thinking) {
      thinkingTasks.add(updatedTask);
    } else {
      planningTasks.add(updatedTask);
    }

    setState(() {
      _replaceProjectTasks(
        project: project,
        journalEntries: journalEntries,
        thinkingTasks: thinkingTasks,
        planningTasks: planningTasks,
        archivedTasks: archivedTasks,
      );
    });
    _notifyProjectDataChanged();
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

    final List<TaskItem> thinkingTasks =
        _tasksByType(project, TaskItemType.thinking)
            .where((TaskItem task) => task.entryType != TaskEntryType.journal)
            .toList(growable: true);
    final List<TaskItem> planningTasks = _planningTasks(
      project,
    ).toList(growable: true);
    final List<TaskItem> journalEntries = _journalEntries(
      project,
    ).toList(growable: true);
    final List<TaskItem> archivedTasks = _archivedTasks(
      project,
    ).toList(growable: true);

    TaskItem? sourceTask;
    TaskItemType? sourceType;
    int sourceIndex = thinkingTasks.indexWhere(
      (TaskItem task) => task.id == taskId,
    );
    if (sourceIndex >= 0) {
      sourceTask = thinkingTasks.removeAt(sourceIndex);
      sourceType = TaskItemType.thinking;
    } else {
      sourceIndex = planningTasks.indexWhere(
        (TaskItem task) => task.id == taskId,
      );
      if (sourceIndex >= 0) {
        sourceTask = planningTasks.removeAt(sourceIndex);
        sourceType = TaskItemType.planning;
      }
    }

    if (sourceTask == null || sourceType == null) {
      return;
    }

    final TaskItemType effectiveTargetType =
        sourceTask.entryType == TaskEntryType.session
            ? TaskItemType.thinking
            : targetType;
    final List<TaskItem> destinationTasks =
        effectiveTargetType == TaskItemType.thinking
            ? thinkingTasks
            : planningTasks;

    final int insertionIndex = reorderInsertionIndex(
      targetIndex: targetIndex,
      destinationLength: destinationTasks.length,
      sourceIndexInSameList:
          sourceType == effectiveTargetType ? sourceIndex : null,
    );

    final TaskItem movedTask = sourceTask.type == effectiveTargetType
        ? sourceTask
        : TaskItem(
            id: sourceTask.id,
            title: sourceTask.title,
            body: sourceTask.body,
            prompt: sourceTask.prompt,
            flashcardPrompt: sourceTask.flashcardPrompt,
            createdAtMicros: sourceTask.createdAtMicros,
            colorValue: sourceTask.colorValue,
            type: effectiveTargetType,
            entryType: sourceTask.entryType,
            isArchived: sourceTask.isArchived,
            isPinned: sourceTask.isPinned,
            iconKey: sourceTask.iconKey,
            subtasks: sourceTask.subtasks
                .map((SubTaskItem subtask) => subtask.clone())
                .toList(),
          );

    destinationTasks.insert(insertionIndex, movedTask);

    setState(() {
      _replaceProjectTasks(
        project: project,
        journalEntries: journalEntries,
        thinkingTasks: thinkingTasks,
        planningTasks: planningTasks,
        archivedTasks: archivedTasks,
      );
    });
    _notifyProjectDataChanged();
  }

  void _moveTaskToBoundary(String taskId, {required bool toTop}) {
    final ProjectItem? project = _findProject();
    if (project == null) {
      return;
    }

    final List<TaskItem> journalEntries = _journalEntries(
      project,
    ).toList(growable: true);
    final List<TaskItem> thinkingTasks = _thinkingTasks(
      project,
    ).toList(growable: true);
    final List<TaskItem> planningTasks = _planningTasks(
      project,
    ).toList(growable: true);
    final List<TaskItem> archivedTasks = _archivedTasks(
      project,
    ).toList(growable: true);

    List<TaskItem>? sourceList;
    final int journalIndex = journalEntries.indexWhere(
      (TaskItem task) => task.id == taskId,
    );
    if (journalIndex >= 0) {
      sourceList = journalEntries;
    } else {
      final int thinkingIndex = thinkingTasks.indexWhere(
        (TaskItem task) => task.id == taskId,
      );
      if (thinkingIndex >= 0) {
        sourceList = thinkingTasks;
      } else {
        final int planningIndex = planningTasks.indexWhere(
          (TaskItem task) => task.id == taskId,
        );
        if (planningIndex >= 0) {
          sourceList = planningTasks;
        }
      }
    }

    if (sourceList == null) {
      return;
    }

    final int sourceIndex = sourceList.indexWhere(
      (TaskItem task) => task.id == taskId,
    );
    if (sourceIndex < 0) {
      return;
    }

    moveItemToBoundary(sourceList, sourceIndex: sourceIndex, toTop: toTop);

    setState(() {
      _replaceProjectTasks(
        project: project,
        journalEntries: journalEntries,
        thinkingTasks: thinkingTasks,
        planningTasks: planningTasks,
        archivedTasks: archivedTasks,
      );
    });
    _notifyProjectDataChanged();
  }

  void _toggleTaskPinned(String taskId) {
    final ProjectItem? project = _findProject();
    if (project == null) {
      return;
    }

    final int taskIndex = _findTaskIndex(project, taskId);
    if (taskIndex < 0) {
      return;
    }

    setState(() {
      project.tasks[taskIndex] = project.tasks[taskIndex].copyWith(
        isPinned: !project.tasks[taskIndex].isPinned,
      );
      final List<TaskItem> journalEntries = _journalEntries(
        project,
      ).toList(growable: true);
      final List<TaskItem> thinkingTasks = _thinkingTasks(
        project,
      ).toList(growable: true);
      final List<TaskItem> planningTasks = _planningTasks(
        project,
      ).toList(growable: true);
      final List<TaskItem> archivedTasks = _archivedTasks(
        project,
      ).toList(growable: true);
      _replaceProjectTasks(
        project: project,
        journalEntries: journalEntries,
        thinkingTasks: thinkingTasks,
        planningTasks: planningTasks,
        archivedTasks: archivedTasks,
      );
    });
    _notifyProjectDataChanged();
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
    _notifyProjectDataChanged();
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
        _notifyProjectDataChanged();
      },
    );
    _notifyProjectDataChanged();
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

    final List<TaskItem> journalEntries = _journalEntries(
      project,
    ).toList(growable: true);
    final List<TaskItem> thinkingTasks = _thinkingTasks(
      project,
    ).toList(growable: true);
    final List<TaskItem> planningTasks = _planningTasks(
      project,
    ).toList(growable: true);
    final List<TaskItem> archivedTasks = _archivedTasks(
      project,
    ).toList(growable: true);
    journalEntries.removeWhere((TaskItem entry) => entry.id == taskId);
    thinkingTasks.removeWhere((TaskItem entry) => entry.id == taskId);
    planningTasks.removeWhere((TaskItem entry) => entry.id == taskId);
    archivedTasks.add(task.copyWith(isArchived: true));

    setState(() {
      _replaceProjectTasks(
        project: project,
        journalEntries: journalEntries,
        thinkingTasks: thinkingTasks,
        planningTasks: planningTasks,
        archivedTasks: archivedTasks,
      );
    });
    _notifyProjectDataChanged();
    _showUndoTaskDeletion(
      message: 'Task archived.',
      onUndo: () {
        _restoreTask(taskId);
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

    final List<TaskItem> journalEntries = _journalEntries(
      project,
    ).toList(growable: true);
    final List<TaskItem> thinkingTasks = _thinkingTasks(
      project,
    ).toList(growable: true);
    final List<TaskItem> planningTasks = _planningTasks(
      project,
    ).toList(growable: true);
    final List<TaskItem> archivedTasks = _archivedTasks(
      project,
    ).toList(growable: true);
    archivedTasks.removeWhere((TaskItem entry) => entry.id == taskId);
    final TaskItem restoredTask = task.copyWith(isArchived: false);
    if (restoredTask.entryType == TaskEntryType.journal) {
      journalEntries.add(restoredTask);
    } else if (restoredTask.type == TaskItemType.planning) {
      planningTasks.add(restoredTask);
    } else {
      thinkingTasks.add(restoredTask);
    }

    setState(() {
      _replaceProjectTasks(
        project: project,
        journalEntries: journalEntries,
        thinkingTasks: thinkingTasks,
        planningTasks: planningTasks,
        archivedTasks: archivedTasks,
      );
    });
    _notifyProjectDataChanged();
  }

  void _toggleProjectArchived() {
    final ProjectItem? project = _findProject();
    if (project == null) {
      return;
    }

    final bool nextArchived = !project.isArchived;
    setState(() {
      final int projectIndex = _projects.indexWhere(
        (ProjectItem item) => item.id == project.id,
      );
      if (projectIndex < 0) {
        return;
      }
      _projects[projectIndex] = project.copyWith(isArchived: nextArchived);
    });
    _notifyProjectDataChanged();
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
                subtitle: const Text('Project settings'),
              ),
              const Divider(height: 1),
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

  Future<void> _openProjectSettings() async {
    final ProjectItem? project = _findProject();
    if (project == null) {
      return;
    }

    final _ProjectMenuAction? action = await _showProjectMenu(project);
    if (!mounted || action == null) {
      return;
    }

    if (action == _ProjectMenuAction.edit) {
      await _editProject();
      return;
    }
    if (action == _ProjectMenuAction.setType) {
      await _setProjectType();
      return;
    }
    if (action == _ProjectMenuAction.setStack) {
      await _setProjectStack();
      return;
    }
    if (action == _ProjectMenuAction.setIcon) {
      await _setProjectIcon();
      return;
    }
    if (action == _ProjectMenuAction.setColor) {
      await _setProjectColor();
      return;
    }
    if (action == _ProjectMenuAction.archive ||
        action == _ProjectMenuAction.restore) {
      _toggleProjectArchived();
      return;
    }
    if (action == _ProjectMenuAction.remove) {
      final bool shouldRemove = await _confirmProjectRemoval();
      if (shouldRemove) {
        _removeProject();
      }
    }
  }

  Future<void> _editProject() async {
    final ProjectItem? project = _findProject();
    if (project == null) {
      return;
    }

    final ProjectEditResult? result =
        await showModalBottomSheet<ProjectEditResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => EditProjectSheet(
        initialName: project.name,
        initialBody: project.body,
        initialPrompt: project.prompt,
        showPromptField: _isLlmProject(project),
      ),
    );

    if (result == null) {
      return;
    }

    setState(() {
      final int projectIndex = _projects.indexWhere(
        (ProjectItem item) => item.id == project.id,
      );
      if (projectIndex < 0) {
        return;
      }
      _projects[projectIndex] = project.copyWith(
        name: result.name,
        body: result.body,
        prompt: result.prompt,
      );
    });
    _notifyProjectDataChanged();
  }

  Future<void> _setProjectIcon() async {
    final ProjectItem? project = _findProject();
    if (project == null) {
      return;
    }

    final String? iconKey = await showModalBottomSheet<String?>(
      context: context,
      builder: (_) => ItemIconPickerSheet(currentIconKey: project.iconKey),
    );

    if (!mounted || iconKey == project.iconKey) {
      return;
    }

    setState(() {
      final int projectIndex = _projects.indexWhere(
        (ProjectItem item) => item.id == project.id,
      );
      if (projectIndex < 0) {
        return;
      }
      _projects[projectIndex] = project.copyWith(
        iconKey: iconKey,
        clearIcon: iconKey == null,
      );
    });
    _notifyProjectDataChanged();
  }

  Future<void> _setProjectColor() async {
    final ProjectItem? project = _findProject();
    if (project == null) {
      return;
    }

    final ColorSelection? selection =
        await showModalBottomSheet<ColorSelection>(
      context: context,
      builder: (_) => ItemColorPickerSheet(
        currentColorValue: project.colorValue,
        customLabels: widget.colorLabels,
      ),
    );

    if (selection == null) {
      return;
    }

    setState(() {
      final int projectIndex = _projects.indexWhere(
        (ProjectItem item) => item.id == project.id,
      );
      if (projectIndex < 0) {
        return;
      }
      _projects[projectIndex] = project.copyWith(
        colorValue: selection.colorValue,
        clearColor: selection.colorValue == null,
      );
    });
    _notifyProjectDataChanged();
  }

  Future<void> _setProjectType() async {
    final ProjectItem? project = _findProject();
    if (project == null) {
      return;
    }

    final String? projectTypeId = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SelectProjectTypeSheet(
        projectTypes: widget.projectTypes,
        currentProjectTypeId:
            project.projectTypeId ?? ProjectTypeDefaults.blankId,
      ),
    );

    if (!mounted || projectTypeId == null) {
      return;
    }

    setState(() {
      final int projectIndex = _projects.indexWhere(
        (ProjectItem item) => item.id == project.id,
      );
      if (projectIndex < 0) {
        return;
      }
      _projects[projectIndex] = project.copyWith(projectTypeId: projectTypeId);
    });
    _notifyProjectDataChanged();
  }

  Future<void> _setProjectStack() async {
    final ProjectItem? project = _findProject();
    if (project == null) {
      return;
    }

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

    final String? stackId = _resolveStackIdForSelection(selection);
    setState(() {
      final int projectIndex = _projects.indexWhere(
        (ProjectItem item) => item.id == project.id,
      );
      if (projectIndex < 0) {
        return;
      }
      _projects[projectIndex] = project.copyWith(
        stackId: stackId,
        clearStack: stackId == null,
      );
    });
    _notifyProjectDataChanged();
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

  void _removeProject() {
    final int projectIndex = _projects.indexWhere(
      (ProjectItem project) => project.id == widget.projectId,
    );
    if (projectIndex < 0) {
      return;
    }

    setState(() {
      _projects.removeAt(projectIndex);
    });
    _notifyProjectDataChanged();
    Navigator.of(context).pop();
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
          action: SnackBarAction(label: 'Revert?', onPressed: onUndo),
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
            _projectAcceptsRootTasks(project))
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
      _insertTaskIntoProject(targetProject, task, insertAtTop: true);
    });
    _notifyProjectDataChanged();
  }

  Future<_ProjectEntryKind?> _chooseEntryKindForCreate() {
    final ProjectItem? project = _findProject();
    if (project == null) {
      return Future<_ProjectEntryKind?>.value(null);
    }
    final ProjectTypeConfig projectType = _projectTypeFor(project);
    final ProjectRules projectRules = _projectRulesFor(project);
    if (projectRules.defaultsToJournalEntry) {
      return Future<_ProjectEntryKind?>.value(_ProjectEntryKind.journal);
    }
    if (projectRules.defaultsToThinkingEntry) {
      return Future<_ProjectEntryKind?>.value(_ProjectEntryKind.thinking);
    }
    if (projectRules.defaultsToPlanningEntry) {
      return Future<_ProjectEntryKind?>.value(_ProjectEntryKind.planning);
    }
    if (!projectRules.acceptsRootTasks) {
      return Future<_ProjectEntryKind?>.value(null);
    }

    return showModalBottomSheet<_ProjectEntryKind>(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: <Widget>[
              const ListTile(
                title: Text(
                  'Create entry in',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const Divider(height: 1),
              if (projectType.showsJournalEntries)
                ListTile(
                  leading: const Icon(Icons.menu_book_outlined),
                  title: Text(
                    projectRules.isEntryContainer
                        ? projectType.childJournalEntryLabel
                        : 'Diary entry',
                  ),
                  onTap: () =>
                      Navigator.of(context).pop(_ProjectEntryKind.journal),
                ),
              if (projectType.showsIdeas)
                ListTile(
                  leading: const Icon(Icons.lightbulb_outline),
                  title: const Text('Ideas'),
                  onTap: () =>
                      Navigator.of(context).pop(_ProjectEntryKind.thinking),
                ),
              if (projectType.showsPlanningTasks)
                ListTile(
                  leading: const Icon(Icons.checklist_rtl_outlined),
                  title: const Text('Tasks'),
                  onTap: () =>
                      Navigator.of(context).pop(_ProjectEntryKind.planning),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _addTaskToProject() async {
    final _ProjectEntryKind? selectedKind = await _chooseEntryKindForCreate();
    if (selectedKind == null) {
      return;
    }
    if (!mounted) {
      return;
    }

    if (selectedKind == _ProjectEntryKind.journal) {
      final ProjectItem? project = _findProject();
      if (project == null) {
        return;
      }
      final ProjectTypeConfig projectType = _projectTypeFor(project);
      final ProjectRules projectRules = _projectRulesFor(project);

      final AddJournalEntryResult? createdEntry =
          await showModalBottomSheet<AddJournalEntryResult>(
        context: context,
        isScrollControlled: true,
        builder: (_) => AddJournalEntrySheet(
          title: projectRules.isEntryContainer
              ? 'New ${projectType.childJournalEntryLabel}'
              : 'New Diary Entry',
          hintText: projectRules.isEntryContainer
              ? 'Capture the interaction, context, and anything to follow up.'
              : 'Write what happened, what you noticed, or what you want to keep.',
          saveLabel: projectRules.isEntryContainer
              ? 'Save ${projectType.childJournalEntryLabel}'
              : 'Save Entry',
        ),
      );

      if (createdEntry == null || !mounted) {
        return;
      }

      setState(() {
        _insertTaskIntoProject(
          project,
          TaskItem(
            title: _createJournalEntryTitle(createdEntry.createdAtMicros),
            body: createdEntry.body,
            type: TaskItemType.thinking,
            entryType: TaskEntryType.journal,
            createdAtMicros: createdEntry.createdAtMicros,
          ),
          insertAtTop: false,
        );
      });
      _notifyProjectDataChanged();
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

    final TaskItem insertedTask = TaskItem(
      id: createdTask.task.id,
      title: createdTask.task.title,
      body: createdTask.task.body,
      prompt: createdTask.task.prompt,
      flashcardPrompt: createdTask.task.flashcardPrompt,
      imagePaths: createdTask.task.imagePaths,
      createdAtMicros: createdTask.task.createdAtMicros,
      colorValue: createdTask.task.colorValue,
      type: selectedKind == _ProjectEntryKind.planning
          ? TaskItemType.planning
          : TaskItemType.thinking,
      entryType: createdTask.task.entryType,
      iconKey: createdTask.task.iconKey,
      subtasks: createdTask.task.subtasks
          .map((SubTaskItem subtask) => subtask.clone())
          .toList(),
    );

    setState(() {
      _insertTaskIntoProject(
        project,
        insertedTask,
        insertAtTop: createdTask.insertAtTop,
      );
    });
    _notifyProjectDataChanged();
  }

  Future<void> _addPerson() async {
    final ProjectItem? project = _findProject();
    if (project == null ||
        !_projectRulesFor(project).isEntryContainer ||
        project.isArchived) {
      return;
    }

    final AddProjectEntryResult? result =
        await showModalBottomSheet<AddProjectEntryResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => AddProjectEntrySheet(
        itemLabel: _peopleItemLabel(project),
        notesLabel: _projectTypeFor(project).childItemBodyLabel,
        nameHint: _projectTypeFor(project).childItemNameHint,
        notesHint: _projectTypeFor(project).childItemBodyHint,
      ),
    );

    if (result == null) {
      return;
    }

    setState(() {
      project.people.add(PersonItem(name: result.name, body: result.body));
    });
    _notifyProjectDataChanged();
  }

  Future<void> _openPersonDetail(String personId) async {
    final int projectIndex = _projects.indexWhere(
      (ProjectItem project) => project.id == widget.projectId,
    );
    if (projectIndex < 0) {
      return;
    }

    final ProjectItem project = _projects[projectIndex];
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ProjectEntryDetailPage(
          personId: personId,
          initialPeople: project.people,
          projectType: _projectTypeFor(project),
          colorLabels: widget.colorLabels,
          hideCompletedProjectItems: widget.hideCompletedProjectItems,
          cardLayoutPreset: widget.cardLayoutPreset,
          onPeopleChanged: (List<PersonItem> updatedPeople) {
            setState(() {
              _projects[projectIndex] = project.copyWith(people: updatedPeople);
            });
            _notifyProjectDataChanged();
          },
        ),
      ),
    );
  }

  Future<_PersonCardMenuAction?> _showPersonCardMenu(PersonItem person) {
    final ProjectItem? project = _findProject();
    final String itemLabel =
        project == null ? 'Item' : _peopleItemLabel(project);
    return showModalBottomSheet<_PersonCardMenuAction>(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: <Widget>[
              ListTile(
                title: Text(
                  person.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text('$itemLabel options'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.open_in_new_outlined),
                title: Text('Open ${itemLabel.toLowerCase()}'),
                onTap: () =>
                    Navigator.of(context).pop(_PersonCardMenuAction.open),
              ),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: Text('Edit ${itemLabel.toLowerCase()}'),
                onTap: () =>
                    Navigator.of(context).pop(_PersonCardMenuAction.edit),
              ),
              ListTile(
                leading: const Icon(Icons.add_reaction_outlined),
                title: const Text('Set icon'),
                onTap: () =>
                    Navigator.of(context).pop(_PersonCardMenuAction.setIcon),
              ),
              ListTile(
                leading: const Icon(Icons.palette_outlined),
                title: const Text('Set color'),
                onTap: () =>
                    Navigator.of(context).pop(_PersonCardMenuAction.setColor),
              ),
              ListTile(
                leading: const Icon(Icons.vertical_align_top_outlined),
                title: const Text('Move to top'),
                onTap: () =>
                    Navigator.of(context).pop(_PersonCardMenuAction.moveToTop),
              ),
              ListTile(
                leading: const Icon(Icons.vertical_align_bottom_outlined),
                title: const Text('Move to bottom'),
                onTap: () => Navigator.of(
                  context,
                ).pop(_PersonCardMenuAction.moveToBottom),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: Text('Remove ${itemLabel.toLowerCase()}'),
                onTap: () =>
                    Navigator.of(context).pop(_PersonCardMenuAction.remove),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openPersonCardMenu(String personId) async {
    final ProjectItem? project = _findProject();
    if (project == null) {
      return;
    }

    final int personIndex = _findPersonIndex(project, personId);
    if (personIndex < 0) {
      return;
    }

    final _PersonCardMenuAction? action = await _showPersonCardMenu(
      project.people[personIndex],
    );
    if (action == null || !mounted) {
      return;
    }

    if (action == _PersonCardMenuAction.open) {
      await _openPersonDetail(personId);
      return;
    }
    if (action == _PersonCardMenuAction.edit) {
      await _editPersonInProject(personId);
      return;
    }
    if (action == _PersonCardMenuAction.setIcon) {
      await _setPersonIconInProject(personId);
      return;
    }
    if (action == _PersonCardMenuAction.setColor) {
      await _setPersonColorInProject(personId);
      return;
    }
    if (action == _PersonCardMenuAction.moveToTop) {
      _movePersonToBoundary(personId, toTop: true);
      return;
    }
    if (action == _PersonCardMenuAction.moveToBottom) {
      _movePersonToBoundary(personId, toTop: false);
      return;
    }
    if (action == _PersonCardMenuAction.remove) {
      _removePersonFromProject(personId);
    }
  }

  Future<void> _editPersonInProject(String personId) async {
    final ProjectItem? project = _findProject();
    if (project == null) {
      return;
    }

    final int personIndex = _findPersonIndex(project, personId);
    if (personIndex < 0) {
      return;
    }

    final PersonItem person = project.people[personIndex];
    final ProjectEntryEditResult? result =
        await showModalBottomSheet<ProjectEntryEditResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => EditProjectEntrySheet(
        initialName: person.name,
        initialBody: person.body,
        itemLabel: _peopleItemLabel(project),
        notesLabel: _projectTypeFor(project).childItemBodyLabel,
      ),
    );

    if (result == null) {
      return;
    }

    setState(() {
      project.people[personIndex] = person.copyWith(
        name: result.name,
        body: result.body,
      );
    });
    _notifyProjectDataChanged();
  }

  Future<void> _setPersonIconInProject(String personId) async {
    final ProjectItem? project = _findProject();
    if (project == null) {
      return;
    }

    final int personIndex = _findPersonIndex(project, personId);
    if (personIndex < 0) {
      return;
    }

    final PersonItem person = project.people[personIndex];
    final String? iconKey = await showModalBottomSheet<String?>(
      context: context,
      builder: (_) => ItemIconPickerSheet(currentIconKey: person.iconKey),
    );
    if (!mounted || iconKey == person.iconKey) {
      return;
    }

    setState(() {
      project.people[personIndex] = person.copyWith(
        iconKey: iconKey,
        clearIcon: iconKey == null,
      );
    });
    _notifyProjectDataChanged();
  }

  Future<void> _setPersonColorInProject(String personId) async {
    final ProjectItem? project = _findProject();
    if (project == null) {
      return;
    }

    final int personIndex = _findPersonIndex(project, personId);
    if (personIndex < 0) {
      return;
    }

    final PersonItem person = project.people[personIndex];
    final ColorSelection? selection =
        await showModalBottomSheet<ColorSelection>(
      context: context,
      builder: (_) => ItemColorPickerSheet(
        currentColorValue: person.colorValue,
        customLabels: widget.colorLabels,
      ),
    );
    if (selection == null) {
      return;
    }

    setState(() {
      project.people[personIndex] = person.copyWith(
        colorValue: selection.colorValue,
        clearColor: selection.colorValue == null,
      );
    });
    _notifyProjectDataChanged();
  }

  void _removePersonFromProject(String personId) {
    final ProjectItem? project = _findProject();
    if (project == null) {
      return;
    }

    setState(() {
      project.people.removeWhere((PersonItem person) => person.id == personId);
    });
    _notifyProjectDataChanged();
  }

  void _movePersonToPosition({
    required String personId,
    required int targetIndex,
  }) {
    final ProjectItem? project = _findProject();
    if (project == null) {
      return;
    }

    final int sourceIndex = _findPersonIndex(project, personId);
    if (sourceIndex < 0) {
      return;
    }

    setState(() {
      moveItemWithinList(
        project.people,
        sourceIndex: sourceIndex,
        targetIndex: targetIndex,
      );
    });
    _notifyProjectDataChanged();
  }

  void _movePersonToBoundary(String personId, {required bool toTop}) {
    final ProjectItem? project = _findProject();
    if (project == null) {
      return;
    }

    final int sourceIndex = _findPersonIndex(project, personId);
    if (sourceIndex < 0) {
      return;
    }

    setState(() {
      moveItemToBoundary(
        project.people,
        sourceIndex: sourceIndex,
        toTop: toTop,
      );
    });
    _notifyProjectDataChanged();
  }

  Widget _buildPersonDropSlot({
    required int targetIndex,
    required double inactiveHeight,
  }) {
    return DragTarget<_PersonDragPayload>(
      onWillAcceptWithDetails: (DragTargetDetails<_PersonDragPayload> details) {
        return true;
      },
      onAcceptWithDetails: (DragTargetDetails<_PersonDragPayload> details) {
        _movePersonToPosition(
          personId: details.data.personId,
          targetIndex: targetIndex,
        );
      },
      builder: (
        BuildContext context,
        List<_PersonDragPayload?> candidateData,
        List<dynamic> rejectedData,
      ) {
        final bool isActive = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height:
              isActive ? 28 : (_draggingPersonId == null ? inactiveHeight : 14),
          decoration: BoxDecoration(
            color: isActive
                ? Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.22)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
        );
      },
    );
  }

  Widget _buildPeopleProjectCard(ProjectItem project, PersonItem person) {
    final String itemLabel = _peopleItemLabel(project);
    final Widget tile = Card(
      color: person.colorValue == null ? null : Color(person.colorValue!),
      child: ListTile(
        contentPadding: _layout.contentPadding,
        leading: Icon(iconDataForKey(person.iconKey) ?? Icons.label_outline),
        title: Text(
          person.name,
          maxLines: null,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize:
                    (Theme.of(context).textTheme.titleMedium?.fontSize ?? 16) *
                        _layout.titleScale,
              ),
        ),
        trailing: IconButton(
          onPressed: () => _openPersonCardMenu(person.id),
          tooltip: '$itemLabel options',
          icon: const Icon(Icons.more_vert),
        ),
        onTap: () => _openPersonDetail(person.id),
      ),
    );

    return Dismissible(
      key: ValueKey<String>('people-project-person-${person.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _removePersonFromProject(person.id),
      background: const SizedBox.shrink(),
      secondaryBackground: Container(
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
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: _layout.listBottomSpacing),
        child: LongPressDraggable<_PersonDragPayload>(
          data: _PersonDragPayload(personId: person.id),
          onDragStarted: () {
            setState(() {
              _draggingPersonId = person.id;
            });
          },
          onDragEnd: (_) {
            if (_draggingPersonId == person.id) {
              setState(() {
                _draggingPersonId = null;
              });
            }
          },
          feedback: Material(
            color: Colors.transparent,
            child: SizedBox(
              width: MediaQuery.sizeOf(context).width - 24,
              child: tile,
            ),
          ),
          childWhenDragging: Opacity(opacity: 0.35, child: tile),
          child: tile,
        ),
      ),
    );
  }

  Widget _buildPeopleProjectBody(ProjectItem project) {
    final List<PersonItem> people = _visiblePeople(project);
    final String itemsLabel = _peopleItemsLabel(project);
    return ListView(
      padding: EdgeInsets.fromLTRB(
        12,
        12,
        12,
        104 + MediaQuery.paddingOf(context).bottom,
      ),
      children: <Widget>[
        if (project.isArchived)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'This project is archived. Restore it to bring it back into the main project list.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        if (project.body.isNotEmpty)
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                project.body,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ),
        Text(itemsLabel, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (people.isEmpty)
          Text(
            'No ${itemsLabel.toLowerCase()} in this project yet.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        if (people.isNotEmpty)
          _buildPersonDropSlot(targetIndex: 0, inactiveHeight: 0),
        for (int index = 0; index < people.length; index += 1) ...<Widget>[
          _buildPeopleProjectCard(project, people[index]),
          _buildPersonDropSlot(targetIndex: index + 1, inactiveHeight: 4),
        ],
      ],
    );
  }

  Widget _buildTaskCard({
    required TaskItem task,
    required VoidCallback? onTap,
    bool showNestedPreview = false,
    bool showOptionsButton = false,
    double bottomPadding = 4,
  }) {
    final IconData? iconData = iconDataForKey(task.iconKey) ??
        (task.entryType == TaskEntryType.session
            ? Icons.headset_outlined
            : task.entryType == TaskEntryType.journal
                ? Icons.menu_book_outlined
                : null);
    final bool hasNestedItems = task.subtasks.isNotEmpty;
    final bool isExpanded = _expandedProjectTaskIds.contains(task.id);
    final List<Widget> trailingParts = <Widget>[
      if (task.isPinned)
        const Tooltip(
          message: 'Pinned to top of this section',
          child: Icon(Icons.push_pin_outlined, size: 18),
        ),
      if (task.entryType == TaskEntryType.session)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.tertiaryContainer,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            'Session',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onTertiaryContainer,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
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
      if (task.entryType == TaskEntryType.journal)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            'Journal',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      if (task.body.isNotEmpty)
        const Tooltip(
          message: 'Has text content',
          child: Icon(Icons.notes_outlined, size: 18),
        ),
      if (task.prompt.isNotEmpty)
        const Tooltip(
          message: 'Has prompt',
          child: Icon(Icons.memory_outlined, size: 18),
        ),
      if (task.imagePaths.isNotEmpty)
        Tooltip(
          message: task.imagePaths.length == 1
              ? '1 attached image'
              : '${task.imagePaths.length} attached images',
          child: const Icon(Icons.image_outlined, size: 18),
        ),
      if (showOptionsButton)
        IconButton(
          onPressed: () => _openTaskQuickMenu(task.id),
          tooltip: 'Task options',
          icon: const Icon(Icons.more_vert),
        ),
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
                contentPadding: _layout.contentPadding,
                leading: iconData == null ? null : Icon(iconData),
                title: Text(
                  task.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: (Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.fontSize ??
                                16) *
                            _layout.titleScale,
                      ),
                  maxLines: null,
                ),
                trailing: effectiveTrailing,
                onTap: onTap,
              ),
            ),
          ),
          if (showNestedPreview && hasNestedItems && isExpanded)
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 8, bottom: 8),
              child: SubtaskPreviewTree(
                key: ValueKey<String>('project-task-preview-${task.id}'),
                items: task.subtasks,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildJournalEntryCard(
    TaskItem task, {
    required bool isArchivedSection,
  }) {
    final String bodyText = _journalBodyText(task);
    final IconData? iconData = iconDataForKey(task.iconKey);

    return Card(
      margin: EdgeInsets.only(bottom: _layout.listBottomSpacing),
      color: task.colorValue == null ? null : Color(task.colorValue!),
      child: InkWell(
        onTap: () => _openTaskView(task.id),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: _layout.contentPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (iconData != null) ...<Widget>[
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(iconData, size: 18),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      _journalTimestampLabel(task),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _openTaskQuickMenu(task.id),
                    tooltip: 'Task options',
                    icon: const Icon(Icons.more_vert),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(bodyText, style: Theme.of(context).textTheme.bodyLarge),
              if (task.imagePaths.isNotEmpty) ...<Widget>[
                const SizedBox(height: 12),
                TaskImageGallery(imagePaths: task.imagePaths, height: 96),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildJournalSection({
    required String title,
    String? emptyLabel,
    required List<TaskItem> entries,
    bool isArchivedSection = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (entries.isEmpty && emptyLabel != null && emptyLabel.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              emptyLabel,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        for (final TaskItem task in entries)
          isArchivedSection
              ? Dismissible(
                  key: ValueKey<String>('project-journal-swipe-${task.id}'),
                  direction: DismissDirection.horizontal,
                  confirmDismiss: (DismissDirection direction) async {
                    if (direction == DismissDirection.startToEnd) {
                      _restoreTask(task.id);
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
                    margin: EdgeInsets.only(bottom: _layout.listBottomSpacing),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Icon(
                      Icons.unarchive_outlined,
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                    ),
                  ),
                  secondaryBackground: Container(
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
                  ),
                  child: _buildJournalEntryCard(task, isArchivedSection: true),
                )
              : Dismissible(
                  key: ValueKey<String>('project-journal-swipe-${task.id}'),
                  direction: DismissDirection.horizontal,
                  confirmDismiss: (DismissDirection direction) async {
                    if (direction == DismissDirection.startToEnd) {
                      _archiveTask(task.id);
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
                    margin: EdgeInsets.only(bottom: _layout.listBottomSpacing),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.tertiaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Icon(
                      Icons.archive_outlined,
                      color: Theme.of(context).colorScheme.onTertiaryContainer,
                    ),
                  ),
                  secondaryBackground: Container(
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
                  ),
                  child: _buildJournalEntryCard(task, isArchivedSection: false),
                ),
      ],
    );
  }

  Widget _buildTaskSection({
    required String title,
    String? emptyLabel,
    required List<TaskItem> tasks,
    required TaskItemType sectionType,
    bool showNestedPreview = false,
    bool isArchivedSection = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (tasks.isEmpty && emptyLabel != null && emptyLabel.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              emptyLabel,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        if (!isArchivedSection)
          _buildDropSlot(
            sectionType: sectionType,
            targetIndex: 0,
            inactiveHeight: tasks.isEmpty ? 4 : 0,
          ),
        for (int index = 0; index < tasks.length; index += 1) ...<Widget>[
          isArchivedSection
              ? Dismissible(
                  key: ValueKey<String>(
                    'project-task-swipe-${tasks[index].id}',
                  ),
                  direction: DismissDirection.horizontal,
                  confirmDismiss: (DismissDirection direction) async {
                    if (direction == DismissDirection.startToEnd) {
                      _restoreTask(tasks[index].id);
                      return true;
                    }
                    return true;
                  },
                  onDismissed: (DismissDirection direction) {
                    if (direction == DismissDirection.endToStart) {
                      _deleteTask(tasks[index].id);
                    }
                  },
                  background: Container(
                    margin: EdgeInsets.only(bottom: _layout.listBottomSpacing),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Icon(
                      Icons.unarchive_outlined,
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                    ),
                  ),
                  secondaryBackground: Container(
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
                  ),
                  child: _buildTaskCard(
                    task: tasks[index],
                    onTap: () => _openTaskView(tasks[index].id),
                    showNestedPreview: showNestedPreview,
                    showOptionsButton: true,
                    bottomPadding: _layout.listBottomSpacing,
                  ),
                )
              : _buildDraggableTaskCard(
                  tasks[index],
                  showNestedPreview: showNestedPreview,
                ),
          if (!isArchivedSection)
            _buildDropSlot(
              sectionType: sectionType,
              targetIndex: index + 1,
              inactiveHeight: 4,
            ),
        ],
      ],
    );
  }

  Widget _buildDropSlot({
    required TaskItemType sectionType,
    required int targetIndex,
    required double inactiveHeight,
  }) {
    return DragTarget<_TaskSectionDragPayload>(
      onWillAcceptWithDetails:
          (DragTargetDetails<_TaskSectionDragPayload> details) {
        return true;
      },
      onAcceptWithDetails:
          (DragTargetDetails<_TaskSectionDragPayload> details) {
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
          height: isActiveDropTarget
              ? 30
              : (_draggingProjectTaskId == null ? inactiveHeight : 14),
          decoration: BoxDecoration(
            color: isActiveDropTarget
                ? Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.22)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
        );
      },
    );
  }

  Widget _buildDraggableTaskCard(
    TaskItem task, {
    required bool showNestedPreview,
  }) {
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
        final Widget tile = Padding(
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
            child: _buildTaskCard(
              task: task,
              onTap: () => _openTaskView(task.id),
              showNestedPreview: showNestedPreview,
              showOptionsButton: true,
              bottomPadding: 0,
            ),
          ),
        );
        return Dismissible(
          key: ValueKey<String>('project-task-swipe-${task.id}'),
          direction: DismissDirection.horizontal,
          confirmDismiss: (DismissDirection direction) async {
            if (direction == DismissDirection.startToEnd) {
              _archiveTask(task.id);
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
            margin: EdgeInsets.only(bottom: _layout.listBottomSpacing),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.tertiaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Icon(
              Icons.archive_outlined,
              color: Theme.of(context).colorScheme.onTertiaryContainer,
            ),
          ),
          secondaryBackground: Container(
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
          ),
          child: Padding(
            padding: EdgeInsets.only(bottom: _layout.listBottomSpacing),
            child: LongPressDraggable<_TaskSectionDragPayload>(
              data: _TaskSectionDragPayload(taskId: task.id),
              onDragStarted: () {
                setState(() {
                  _draggingProjectTaskId = task.id;
                });
              },
              onDragEnd: (_) {
                if (_draggingProjectTaskId == task.id) {
                  setState(() {
                    _draggingProjectTaskId = null;
                  });
                }
              },
              feedback: Material(
                color: Colors.transparent,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: _buildTaskCard(
                    task: task,
                    onTap: null,
                    showNestedPreview: showNestedPreview,
                    bottomPadding: 0,
                  ),
                ),
              ),
              childWhenDragging: Opacity(opacity: 0.45, child: tile),
              child: tile,
            ),
          ),
        );
      },
    );
  }

  Widget _buildArchivedTaskSection(List<TaskItem> archivedTasks) {
    final List<TaskItem> archivedJournalEntries = archivedTasks
        .where((TaskItem task) => task.entryType == TaskEntryType.journal)
        .toList(growable: false);
    final List<TaskItem> archivedStandardTasks = archivedTasks
        .where((TaskItem task) => task.entryType != TaskEntryType.journal)
        .toList(growable: false);

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
              child: Column(
                children: <Widget>[
                  if (archivedJournalEntries.isNotEmpty)
                    _buildJournalSection(
                      title: 'Journal',
                      entries: archivedJournalEntries,
                      isArchivedSection: true,
                    ),
                  if (archivedJournalEntries.isNotEmpty &&
                      archivedStandardTasks.isNotEmpty)
                    const SizedBox(height: 8),
                  if (archivedStandardTasks.isNotEmpty)
                    _buildTaskSection(
                      title: 'Tasks',
                      tasks: archivedStandardTasks,
                      sectionType: TaskItemType.planning,
                      isArchivedSection: true,
                    ),
                ],
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

    final List<TaskItem> journalEntries = _journalEntries(project);
    final List<TaskItem> thinkingTasks = _thinkingTasks(project);
    final List<TaskItem> planningTasks = _planningTasks(project);
    final List<TaskItem> archivedTasks = _archivedTasks(project);
    final bool showsJournalSection = _showsJournalSection(project);
    final bool showsIdeasSection = _showsIdeasSection(project);
    final bool showsPlanningSection = _showsPlanningSection(project);
    final bool canCreateEntries = _canCreateEntries(project);
    final ProjectTypeConfig projectType = _projectTypeFor(project);
    final ProjectRules projectRules = _projectRulesFor(project);
    final bool isLlmProject = projectType.id == ProjectTypeDefaults.llmId;
    final bool isKnowledgeProject =
        projectType.id == ProjectTypeDefaults.knowledgeId;
    final bool isEntryProject = projectRules.isEntryContainer;
    final IconData? projectIconData =
        iconDataForKey(project.iconKey) ?? iconDataForKey(projectType.iconKey);
    final bool showProjectTypeLabel =
        projectType.id != ProjectTypeDefaults.blankId &&
            projectType.id != ProjectTypeDefaults.projectId;
    final TextStyle? appBarSubtitleStyle = Theme.of(context)
        .textTheme
        .labelMedium
        ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: <Widget>[
            if (projectIconData != null) ...<Widget>[
              Icon(projectIconData),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(project.name),
                  if (showProjectTypeLabel)
                    Text(projectType.name, style: appBarSubtitleStyle),
                ],
              ),
            ),
          ],
        ),
        actions: <Widget>[
          if (isLlmProject)
            IconButton(
              onPressed: _openGeneratePromptFlow,
              tooltip: 'Generate prompt',
              icon: const Icon(Icons.memory_outlined),
            ),
          if (isKnowledgeProject && !project.isArchived)
            IconButton(
              onPressed: _quickCaptureToLatestSession,
              tooltip: 'Quick capture',
              icon: const Icon(Icons.flash_on_outlined),
            ),
          if (isKnowledgeProject && !project.isArchived)
            IconButton(
              onPressed: _createSession,
              tooltip: 'New session',
              icon: const Icon(Icons.add_box_outlined),
            ),
          IconButton(
            onPressed: _openProjectSettings,
            tooltip: 'Project settings',
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: isEntryProject
          ? _buildPeopleProjectBody(project)
          : ListView(
              padding: EdgeInsets.fromLTRB(
                12,
                12,
                12,
                104 + MediaQuery.paddingOf(context).bottom,
              ),
              children: <Widget>[
                if (project.isArchived)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Chip(label: Text('Archived')),
                    ),
                  ),
                if (project.body.isNotEmpty ||
                    (isLlmProject && project.prompt.isNotEmpty))
                  Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          if (project.body.isNotEmpty) ...<Widget>[
                            Text(
                              project.body,
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ],
                          if (project.body.isNotEmpty &&
                              isLlmProject &&
                              project.prompt.isNotEmpty)
                            const SizedBox(height: 16),
                          if (isLlmProject &&
                              project.prompt.isNotEmpty) ...<Widget>[
                            Text(
                              'Prompt',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 8),
                            SelectableText(
                              project.prompt,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                if (showsJournalSection)
                  _buildJournalSection(
                    title: 'Journal',
                    entries: journalEntries,
                  ),
                if (showsJournalSection &&
                    (showsIdeasSection || showsPlanningSection))
                  const SizedBox(height: 8),
                if (showsIdeasSection)
                  _buildTaskSection(
                    title: isKnowledgeProject ? 'Knowledge notes' : 'Ideas',
                    tasks: thinkingTasks,
                    sectionType: TaskItemType.thinking,
                    showNestedPreview: true,
                  ),
                if (showsIdeasSection && showsPlanningSection)
                  const SizedBox(height: 8),
                if (showsPlanningSection)
                  _buildTaskSection(
                    title: 'Tasks',
                    tasks: planningTasks,
                    sectionType: TaskItemType.planning,
                    showNestedPreview: true,
                  ),
                if (archivedTasks.isNotEmpty)
                  _buildArchivedTaskSection(archivedTasks),
              ],
            ),
      floatingActionButton: project.isArchived
          ? null
          : isEntryProject
              ? FloatingActionButton(
                  onPressed: _addPerson,
                  tooltip: 'Add ${_peopleItemLabel(project).toLowerCase()}',
                  child: const Icon(Icons.add),
                )
              : !canCreateEntries
                  ? null
                  : FloatingActionButton(
                      onPressed: _addTaskToProject,
                      tooltip: projectRules.defaultsToJournalEntry
                          ? 'Add journal entry'
                          : isKnowledgeProject
                              ? 'Add knowledge note'
                              : 'Add project task',
                      child: const Icon(Icons.add),
                    ),
    );
  }
}
