import 'package:flutter/material.dart';

class TaskItem {
  TaskItem({required this.title});

  final String title;
}

class ProjectItem {
  ProjectItem({required this.name, List<TaskItem>? tasks})
      : tasks = tasks ?? <TaskItem>[];

  final String name;
  final List<TaskItem> tasks;
}

class _MoveTarget {
  const _MoveTarget.favorites() : projectIndex = null;
  const _MoveTarget.project(this.projectIndex);

  final int? projectIndex;
}

class TaskPage extends StatefulWidget {
  const TaskPage({super.key});

  @override
  State<TaskPage> createState() => _TaskPageState();
}

class _TaskPageState extends State<TaskPage>
    with SingleTickerProviderStateMixin {
  final List<TaskItem> _incomingTasks = <TaskItem>[
    TaskItem(title: 'Sit for 10 minutes in silence'),
    TaskItem(title: 'Do a 3-minute breathing check-in'),
    TaskItem(title: 'Body scan before sleep'),
    TaskItem(title: 'Mindful walk without headphones'),
    TaskItem(title: 'Write down 3 emotions you notice'),
    TaskItem(title: 'Single-task one activity with full attention'),
  ];
  final List<TaskItem> _favoriteTasks = <TaskItem>[];
  final List<ProjectItem> _projects = <ProjectItem>[
    ProjectItem(name: 'Morning Routine'),
    ProjectItem(name: 'Stress Reset'),
    ProjectItem(name: 'Sleep Wind-Down'),
  ];
  late final TabController _tabController;
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_selectedTabIndex == _tabController.index) {
        return;
      }
      setState(() {
        _selectedTabIndex = _tabController.index;
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _openAddTaskWidget() async {
    final TaskItem? newTask = await showModalBottomSheet<TaskItem>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _AddTaskWidget(),
    );

    if (newTask == null) {
      return;
    }

    setState(() {
      _incomingTasks.insert(0, newTask);
    });
  }

  Future<void> _openAddProjectWidget() async {
    final String? newProjectName = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _AddProjectWidget(),
    );

    if (newProjectName == null) {
      return;
    }

    setState(() {
      _projects.insert(0, ProjectItem(name: newProjectName));
    });
  }

  Future<void> _moveIncomingTask(int index) async {
    final _MoveTarget? target = await showModalBottomSheet<_MoveTarget>(
      context: context,
      builder: (context) => _MoveTaskWidget(projects: _projects),
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
  }

  Future<void> _moveFavoriteToIncoming(int index) async {
    setState(() {
      final TaskItem task = _favoriteTasks.removeAt(index);
      _incomingTasks.insert(0, task);
    });
  }

  void _deleteIncomingTask(int index) {
    setState(() {
      _incomingTasks.removeAt(index);
    });
  }

  void _deleteFavoriteTask(int index) {
    setState(() {
      _favoriteTasks.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Manager'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Incoming'),
            Tab(text: 'Favorites'),
            Tab(text: 'Projects'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _TaskListView(
            tasks: _incomingTasks,
            emptyLabel: 'No incoming tasks yet.',
            primaryIcon: Icons.drive_file_move_outlined,
            primaryTooltip: 'Move task',
            onPrimaryAction: _moveIncomingTask,
            onDelete: _deleteIncomingTask,
          ),
          _TaskListView(
            tasks: _favoriteTasks,
            emptyLabel: 'No favorite tasks yet.',
            primaryIcon: Icons.undo_outlined,
            primaryTooltip: 'Move to incoming',
            onPrimaryAction: _moveFavoriteToIncoming,
            onDelete: _deleteFavoriteTask,
          ),
          _ProjectListView(projects: _projects),
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

class _TaskListView extends StatelessWidget {
  const _TaskListView({
    required this.tasks,
    required this.emptyLabel,
    required this.primaryIcon,
    required this.primaryTooltip,
    required this.onPrimaryAction,
    required this.onDelete,
  });

  final List<TaskItem> tasks;
  final String emptyLabel;
  final IconData primaryIcon;
  final String primaryTooltip;
  final Future<void> Function(int) onPrimaryAction;
  final ValueChanged<int> onDelete;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return Center(child: Text(emptyLabel));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final TaskItem task = tasks[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              title: Text(
                task.title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(primaryIcon),
                    onPressed: () async => onPrimaryAction(index),
                    tooltip: primaryTooltip,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => onDelete(index),
                    tooltip: 'Delete',
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AddTaskWidget extends StatefulWidget {
  const _AddTaskWidget();

  @override
  State<_AddTaskWidget> createState() => _AddTaskWidgetState();
}

class _AddTaskWidgetState extends State<_AddTaskWidget> {
  final TextEditingController _titleController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _saveTask() {
    final String title = _titleController.text.trim();
    if (title.isEmpty) {
      return;
    }

    Navigator.of(context).pop(TaskItem(title: title));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'New Task',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _titleController,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _saveTask(),
            decoration: const InputDecoration(
              labelText: 'Title',
              hintText: 'Buy groceries',
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saveTask,
            child: const Text('Save Task'),
          ),
        ],
      ),
    );
  }
}

class _ProjectListView extends StatelessWidget {
  const _ProjectListView({required this.projects});

  final List<ProjectItem> projects;

  @override
  Widget build(BuildContext context) {
    if (projects.isEmpty) {
      return const Center(child: Text('No projects yet.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: projects.length,
      itemBuilder: (context, index) {
        final ProjectItem project = projects[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              leading: const Icon(Icons.folder_outlined),
              title: Text(
                project.name,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${project.tasks.length} task${project.tasks.length == 1 ? '' : 's'}',
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MoveTaskWidget extends StatelessWidget {
  const _MoveTaskWidget({required this.projects});

  final List<ProjectItem> projects;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          const ListTile(
            title: Text(
              'Move task to',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.star_outline),
            title: const Text('Favorites'),
            onTap: () =>
                Navigator.of(context).pop(const _MoveTarget.favorites()),
          ),
          const Divider(height: 1),
          for (int i = 0; i < projects.length; i++)
            ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: Text(projects[i].name),
              subtitle: Text(
                '${projects[i].tasks.length} task${projects[i].tasks.length == 1 ? '' : 's'}',
              ),
              onTap: () => Navigator.of(context).pop(_MoveTarget.project(i)),
            ),
        ],
      ),
    );
  }
}

class _AddProjectWidget extends StatefulWidget {
  const _AddProjectWidget();

  @override
  State<_AddProjectWidget> createState() => _AddProjectWidgetState();
}

class _AddProjectWidgetState extends State<_AddProjectWidget> {
  final TextEditingController _projectNameController = TextEditingController();

  @override
  void dispose() {
    _projectNameController.dispose();
    super.dispose();
  }

  void _createProject() {
    final String name = _projectNameController.text.trim();
    if (name.isEmpty) {
      return;
    }
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'New Project',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _projectNameController,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _createProject(),
            decoration: const InputDecoration(
              labelText: 'Project name',
              hintText: 'Deep Focus',
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _createProject,
            child: const Text('Create Project'),
          ),
        ],
      ),
    );
  }
}
