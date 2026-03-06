import 'package:flutter/material.dart';

import '../../domain/task_models.dart';
import '../widgets/move_project_task_sheet.dart';

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
  ProjectItem? _findProject() {
    for (final ProjectItem project in widget.projects) {
      if (project.id == widget.projectId) {
        return project;
      }
    }
    return null;
  }

  void _deleteTask(String taskId) {
    final ProjectItem? project = _findProject();
    if (project == null) {
      return;
    }

    final int taskIndex = project.tasks.indexWhere(
      (TaskItem task) => task.id == taskId,
    );
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

    final int sourceTaskIndex = sourceProject.tasks.indexWhere(
      (TaskItem task) => task.id == taskId,
    );
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
      appBar: AppBar(title: Text(project.name)),
      body: project.tasks.isEmpty
          ? const Center(
              child: Text('No tasks in this project yet.'),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: project.tasks.length,
              itemBuilder: (BuildContext context, int index) {
                final TaskItem task = project.tasks[index];
                return Dismissible(
                  key: ValueKey<String>(task.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
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
                  onDismissed: (_) => _deleteTask(task.id),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        title: Text(
                          task.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.drive_file_move_outlined),
                          onPressed: () => _moveTaskToAnotherProject(task.id),
                          tooltip: 'Move to another project',
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
