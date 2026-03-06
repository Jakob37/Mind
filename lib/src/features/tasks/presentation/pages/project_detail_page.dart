import 'package:flutter/material.dart';

import '../../domain/task_models.dart';
import '../widgets/move_project_task_sheet.dart';

class ProjectDetailPage extends StatefulWidget {
  const ProjectDetailPage({
    super.key,
    required this.projectIndex,
    required this.projects,
    required this.onProjectsUpdated,
  });

  final int projectIndex;
  final List<ProjectItem> projects;
  final VoidCallback onProjectsUpdated;

  @override
  State<ProjectDetailPage> createState() => _ProjectDetailPageState();
}

class _ProjectDetailPageState extends State<ProjectDetailPage> {
  ProjectItem get _project => widget.projects[widget.projectIndex];

  void _deleteTask(int taskIndex) {
    setState(() {
      _project.tasks.removeAt(taskIndex);
    });
    widget.onProjectsUpdated();
  }

  Future<void> _moveTaskToAnotherProject(int taskIndex) async {
    final int? targetProjectIndex = await showModalBottomSheet<int>(
      context: context,
      builder: (_) => MoveProjectTaskSheet(
        projects: widget.projects,
        currentProjectIndex: widget.projectIndex,
      ),
    );

    if (targetProjectIndex == null) {
      return;
    }

    setState(() {
      final TaskItem task = _project.tasks.removeAt(taskIndex);
      widget.projects[targetProjectIndex].tasks.insert(0, task);
    });
    widget.onProjectsUpdated();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_project.name)),
      body: _project.tasks.isEmpty
          ? const Center(
              child: Text('No tasks in this project yet.'),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _project.tasks.length,
              itemBuilder: (BuildContext context, int index) {
                final TaskItem task = _project.tasks[index];
                return Dismissible(
                  key: ValueKey<String>(
                    'project-task-${task.title}-${_project.name}-$index',
                  ),
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
                  onDismissed: (_) => _deleteTask(index),
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
                          onPressed: () => _moveTaskToAnotherProject(index),
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
