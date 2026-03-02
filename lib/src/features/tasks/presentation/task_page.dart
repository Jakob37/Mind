import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  static const MethodChannel _widgetChannel = MethodChannel(
    'mind/widget_actions',
  );

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
  bool _isAddTaskSheetOpen = false;

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
    _setupWidgetActionHandling();
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
      builder: (context) => const _AddTaskWidget(),
    );
    _isAddTaskSheetOpen = false;

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

  void _openProjectDetail(int projectIndex) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _ProjectDetailPage(
          projectIndex: projectIndex,
          projects: _projects,
          onProjectsUpdated: () {
            setState(() {});
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 0,
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
          _ProjectListView(
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
      padding: const EdgeInsets.all(12),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final TaskItem task = tasks[index];
        return Dismissible(
          key: ValueKey<String>('task-${task.title}-$index'),
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
          onDismissed: (_) => onDelete(index),
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
                  icon: Icon(primaryIcon),
                  onPressed: () async => onPrimaryAction(index),
                  tooltip: primaryTooltip,
                ),
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
        12,
        12,
        12,
        12 + MediaQuery.of(context).viewInsets.bottom,
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
          const SizedBox(height: 12),
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
  const _ProjectListView({
    required this.projects,
    required this.onProjectTap,
  });

  final List<ProjectItem> projects;
  final ValueChanged<int> onProjectTap;

  @override
  Widget build(BuildContext context) {
    if (projects.isEmpty) {
      return const Center(child: Text('No projects yet.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: projects.length,
      itemBuilder: (context, index) {
        final ProjectItem project = projects[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
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
              onTap: () => onProjectTap(index),
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
        12,
        12,
        12,
        12 + MediaQuery.of(context).viewInsets.bottom,
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
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _createProject,
            child: const Text('Create Project'),
          ),
        ],
      ),
    );
  }
}

class _MoveProjectTaskWidget extends StatelessWidget {
  const _MoveProjectTaskWidget({
    required this.projects,
    required this.currentProjectIndex,
  });

  final List<ProjectItem> projects;
  final int currentProjectIndex;

  @override
  Widget build(BuildContext context) {
    final List<int> targetIndexes = <int>[
      for (int i = 0; i < projects.length; i++)
        if (i != currentProjectIndex) i,
    ];

    if (targetIndexes.isEmpty) {
      return const SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No other projects available.'),
        ),
      );
    }

    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          const ListTile(
            title: Text(
              'Move task to project',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const Divider(height: 1),
          for (final int targetIndex in targetIndexes)
            ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: Text(projects[targetIndex].name),
              subtitle: Text(
                '${projects[targetIndex].tasks.length} task${projects[targetIndex].tasks.length == 1 ? '' : 's'}',
              ),
              onTap: () => Navigator.of(context).pop(targetIndex),
            ),
        ],
      ),
    );
  }
}

class _ProjectDetailPage extends StatefulWidget {
  const _ProjectDetailPage({
    required this.projectIndex,
    required this.projects,
    required this.onProjectsUpdated,
  });

  final int projectIndex;
  final List<ProjectItem> projects;
  final VoidCallback onProjectsUpdated;

  @override
  State<_ProjectDetailPage> createState() => _ProjectDetailPageState();
}

class _ProjectDetailPageState extends State<_ProjectDetailPage> {
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
      builder: (_) => _MoveProjectTaskWidget(
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
              itemBuilder: (context, index) {
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
