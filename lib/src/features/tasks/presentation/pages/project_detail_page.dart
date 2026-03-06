import 'package:flutter/material.dart';

import '../../domain/task_models.dart';
import '../widgets/edit_task_sheet.dart';
import '../widgets/item_color_picker_sheet.dart';
import '../widgets/move_project_task_sheet.dart';

enum _ProjectTaskMenuAction {
  edit,
  setColor,
  moveToProject,
  remove,
}

class ProjectDetailPage extends StatefulWidget {
  const ProjectDetailPage({
    super.key,
    required this.projectId,
    required this.projects,
    required this.onProjectsUpdated,
  });

  final String projectId;
  final List<ProjectItem> projects;
  final VoidCallback onProjectsUpdated;

  @override
  State<ProjectDetailPage> createState() => _ProjectDetailPageState();
}

class _ProjectDetailPageState extends State<ProjectDetailPage> {
  bool _isReorderMode = false;

  ProjectItem? _findProject() {
    for (final ProjectItem project in widget.projects) {
      if (project.id == widget.projectId) {
        return project;
      }
    }
    return null;
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
    widget.onProjectsUpdated();
  }

  Future<_ProjectTaskMenuAction?> _showTaskMenu(TaskItem task) {
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
                leading: const Icon(Icons.drive_file_move_outlined),
                title: const Text('Move to project'),
                onTap: () => Navigator.of(
                  context,
                ).pop(_ProjectTaskMenuAction.moveToProject),
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
      );
    });
    widget.onProjectsUpdated();
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
      builder: (_) => ItemColorPickerSheet(currentColorValue: task.colorValue),
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
      );
    });
    widget.onProjectsUpdated();
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
    widget.onProjectsUpdated();
  }

  Future<void> _moveTaskToAnotherProject(String taskId) async {
    final ProjectItem? sourceProject = _findProject();
    if (sourceProject == null) {
      return;
    }

    final String? targetProjectId = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => MoveProjectTaskSheet(
        projects: widget.projects,
        currentProjectId: widget.projectId,
      ),
    );

    if (targetProjectId == null) {
      return;
    }

    final int targetProjectIndex = widget.projects.indexWhere(
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
      widget.projects[targetProjectIndex].tasks.insert(0, task);
    });
    widget.onProjectsUpdated();
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
                    return Padding(
                      key: ValueKey<String>(task.id),
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Card(
                        color: task.colorValue == null
                            ? null
                            : Color(task.colorValue!),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          title: Text(
                            task.title,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          subtitle: task.body.isEmpty
                              ? null
                              : Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(task.body),
                                ),
                          trailing: ReorderableDragStartListener(
                            index: index,
                            child: const Icon(Icons.drag_indicator_outlined),
                          ),
                        ),
                      ),
                    );
                  },
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: project.tasks.length,
                  itemBuilder: (BuildContext context, int index) {
                    final TaskItem task = project.tasks[index];
                    return Dismissible(
                      key: ValueKey<String>('project-task-swipe-${task.id}'),
                      direction: DismissDirection.startToEnd,
                      confirmDismiss: (_) async {
                        await _moveTaskToAnotherProject(task.id);
                        return false;
                      },
                      background: Container(
                        margin: const EdgeInsets.only(bottom: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Icon(
                          Icons.drive_file_move_outlined,
                          color:
                              Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Card(
                          color: task.colorValue == null
                              ? null
                              : Color(task.colorValue!),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            title: Text(
                              task.title,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            subtitle: task.body.isEmpty
                                ? null
                                : Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(task.body),
                                  ),
                            onTap: () => _openTaskMenu(task.id),
                            onLongPress: _enterReorderMode,
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
