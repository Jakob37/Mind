import 'package:flutter/material.dart';

class TaskItem {
  TaskItem({required this.title});

  final String title;
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
  final List<TaskItem> _savedTasks = <TaskItem>[];
  late final TabController _tabController;
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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

  void _saveIncomingTask(int index) {
    setState(() {
      final TaskItem task = _incomingTasks.removeAt(index);
      _savedTasks.insert(0, task);
    });
  }

  void _moveToIncoming(int index) {
    setState(() {
      final TaskItem task = _savedTasks.removeAt(index);
      _incomingTasks.insert(0, task);
    });
  }

  void _deleteIncomingTask(int index) {
    setState(() {
      _incomingTasks.removeAt(index);
    });
  }

  void _deleteSavedTask(int index) {
    setState(() {
      _savedTasks.removeAt(index);
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
            Tab(text: 'Saved'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _TaskListView(
            tasks: _incomingTasks,
            emptyLabel: 'No incoming tasks yet.',
            primaryIcon: Icons.bookmark_add_outlined,
            primaryTooltip: 'Save task',
            onPrimaryAction: _saveIncomingTask,
            onDelete: _deleteIncomingTask,
          ),
          _TaskListView(
            tasks: _savedTasks,
            emptyLabel: 'No saved tasks yet.',
            primaryIcon: Icons.undo_outlined,
            primaryTooltip: 'Move to incoming',
            onPrimaryAction: _moveToIncoming,
            onDelete: _deleteSavedTask,
          ),
        ],
      ),
      floatingActionButton: _selectedTabIndex == 0
          ? FloatingActionButton(
              onPressed: _openAddTaskWidget,
              tooltip: 'Add task',
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
  final ValueChanged<int> onPrimaryAction;
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
                    onPressed: () => onPrimaryAction(index),
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
