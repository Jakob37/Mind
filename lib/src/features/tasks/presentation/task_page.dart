import 'package:flutter/material.dart';

class TaskItem {
  TaskItem({required this.title, this.isDone = false});

  final String title;
  bool isDone;
}

class TaskPage extends StatefulWidget {
  const TaskPage({super.key});

  @override
  State<TaskPage> createState() => _TaskPageState();
}

class _TaskPageState extends State<TaskPage> {
  final List<TaskItem> _tasks = <TaskItem>[];
  final TextEditingController _taskController = TextEditingController();

  @override
  void dispose() {
    _taskController.dispose();
    super.dispose();
  }

  void _addTask() {
    final String title = _taskController.text.trim();
    if (title.isEmpty) {
      return;
    }

    setState(() {
      _tasks.insert(0, TaskItem(title: title));
      _taskController.clear();
    });
  }

  void _toggleTask(int index, bool? value) {
    setState(() {
      _tasks[index].isDone = value ?? false;
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
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _taskController,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _addTask(),
                    decoration: const InputDecoration(
                      labelText: 'Add a task',
                      hintText: 'Buy groceries',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: _addTask,
                  child: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _tasks.isEmpty
                  ? const Center(
                      child: Text('No tasks yet. Add your first task.'),
                    )
                  : ListView.separated(
                      itemCount: _tasks.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final TaskItem task = _tasks[index];
                        return ListTile(
                          leading: Checkbox(
                            value: task.isDone,
                            onChanged: (value) => _toggleTask(index, value),
                          ),
                          title: Text(
                            task.title,
                            style: TextStyle(
                              decoration: task.isDone
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _deleteTask(index),
                            tooltip: 'Delete',
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
