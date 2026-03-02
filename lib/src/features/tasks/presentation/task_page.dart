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

class _TaskPageState extends State<TaskPage> {
  final List<TaskItem> _tasks = <TaskItem>[
    TaskItem(title: 'Sit for 10 minutes in silence'),
    TaskItem(title: 'Do a 3-minute breathing check-in'),
    TaskItem(title: 'Body scan before sleep'),
    TaskItem(title: 'Mindful walk without headphones'),
    TaskItem(title: 'Write down 3 emotions you notice'),
    TaskItem(title: 'Single-task one activity with full attention'),
  ];

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
      _tasks.insert(0, newTask);
    });
  }

  void _deleteTask(int index) {
    setState(() {
      _tasks.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Manager'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _tasks.length,
        itemBuilder: (context, index) {
          final TaskItem task = _tasks[index];
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
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _deleteTask(index),
                  tooltip: 'Delete',
                ),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddTaskWidget,
        tooltip: 'Add task',
        child: const Icon(Icons.add),
      ),
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
