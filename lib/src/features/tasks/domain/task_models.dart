class TaskItem {
  TaskItem({required this.title});

  final String title;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'title': title};
  }

  factory TaskItem.fromJson(Map<String, dynamic> json) {
    final String title = json['title'] as String;
    return TaskItem(title: title);
  }
}

class ProjectItem {
  ProjectItem({required this.name, List<TaskItem>? tasks})
      : tasks = tasks ?? <TaskItem>[];

  final String name;
  final List<TaskItem> tasks;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'name': name,
      'tasks': tasks.map((TaskItem task) => task.toJson()).toList(),
    };
  }

  factory ProjectItem.fromJson(Map<String, dynamic> json) {
    final String name = json['name'] as String;
    final List<dynamic> taskJson =
        (json['tasks'] as List<dynamic>?) ?? <dynamic>[];

    return ProjectItem(
      name: name,
      tasks: taskJson
          .map(
            (dynamic item) => TaskItem.fromJson(
              Map<String, dynamic>.from(item as Map<dynamic, dynamic>),
            ),
          )
          .toList(),
    );
  }
}

class TaskBoardState {
  const TaskBoardState({
    required this.incomingTasks,
    required this.favoriteTasks,
    required this.projects,
  });

  final List<TaskItem> incomingTasks;
  final List<TaskItem> favoriteTasks;
  final List<ProjectItem> projects;

  factory TaskBoardState.defaults() {
    return TaskBoardState(
      incomingTasks: <TaskItem>[
        TaskItem(title: 'Sit for 10 minutes in silence'),
        TaskItem(title: 'Do a 3-minute breathing check-in'),
        TaskItem(title: 'Body scan before sleep'),
        TaskItem(title: 'Mindful walk without headphones'),
        TaskItem(title: 'Write down 3 emotions you notice'),
        TaskItem(title: 'Single-task one activity with full attention'),
      ],
      favoriteTasks: <TaskItem>[],
      projects: <ProjectItem>[
        ProjectItem(name: 'Morning Routine'),
        ProjectItem(name: 'Stress Reset'),
        ProjectItem(name: 'Sleep Wind-Down'),
      ],
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'incomingTasks':
          incomingTasks.map((TaskItem task) => task.toJson()).toList(),
      'favoriteTasks':
          favoriteTasks.map((TaskItem task) => task.toJson()).toList(),
      'projects':
          projects.map((ProjectItem project) => project.toJson()).toList(),
    };
  }

  factory TaskBoardState.fromJson(Map<String, dynamic> json) {
    final List<dynamic> incomingJson =
        (json['incomingTasks'] as List<dynamic>?) ?? <dynamic>[];
    final List<dynamic> favoriteJson =
        (json['favoriteTasks'] as List<dynamic>?) ?? <dynamic>[];
    final List<dynamic> projectJson =
        (json['projects'] as List<dynamic>?) ?? <dynamic>[];

    return TaskBoardState(
      incomingTasks: incomingJson
          .map(
            (dynamic item) => TaskItem.fromJson(
              Map<String, dynamic>.from(item as Map<dynamic, dynamic>),
            ),
          )
          .toList(),
      favoriteTasks: favoriteJson
          .map(
            (dynamic item) => TaskItem.fromJson(
              Map<String, dynamic>.from(item as Map<dynamic, dynamic>),
            ),
          )
          .toList(),
      projects: projectJson
          .map(
            (dynamic item) => ProjectItem.fromJson(
              Map<String, dynamic>.from(item as Map<dynamic, dynamic>),
            ),
          )
          .toList(),
    );
  }
}
