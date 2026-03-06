class ModelIds {
  static int _counter = 0;

  static String newTaskId() => _newId('task');

  static String newProjectId() => _newId('project');

  static String _newId(String prefix) {
    final int micros = DateTime.now().microsecondsSinceEpoch;
    _counter += 1;
    return '$prefix-${micros.toRadixString(36)}-${_counter.toRadixString(36)}';
  }
}

class TaskItem {
  TaskItem({
    String? id,
    required this.title,
    String? body,
    this.colorValue,
  })  : id = id ?? ModelIds.newTaskId(),
        body = body ?? '';

  final String id;
  final String title;
  final String body;
  final int? colorValue;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'body': body,
      'color': colorValue,
    };
  }

  factory TaskItem.fromJson(Map<String, dynamic> json) {
    final String title = json['title'] as String;
    final String? id = (json['id'] as String?)?.trim();
    final String? body = (json['body'] as String?)?.trim();
    final Object? rawColor = json['color'];
    final int? colorValue = rawColor is int ? rawColor : null;
    return TaskItem(
      id: id == null || id.isEmpty ? null : id,
      title: title,
      body: body ?? '',
      colorValue: colorValue,
    );
  }
}

class ProjectItem {
  ProjectItem({
    String? id,
    required this.name,
    String? body,
    this.colorValue,
    List<TaskItem>? tasks,
  })  : id = id ?? ModelIds.newProjectId(),
        body = body ?? '',
        tasks = tasks ?? <TaskItem>[];

  final String id;
  final String name;
  final String body;
  final int? colorValue;
  final List<TaskItem> tasks;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'body': body,
      'color': colorValue,
      'tasks': tasks.map((TaskItem task) => task.toJson()).toList(),
    };
  }

  factory ProjectItem.fromJson(Map<String, dynamic> json) {
    final String name = json['name'] as String;
    final String? id = (json['id'] as String?)?.trim();
    final String? body = (json['body'] as String?)?.trim();
    final Object? rawColor = json['color'];
    final int? colorValue = rawColor is int ? rawColor : null;
    final List<dynamic> taskJson =
        (json['tasks'] as List<dynamic>?) ?? <dynamic>[];

    return ProjectItem(
      id: id == null || id.isEmpty ? null : id,
      name: name,
      body: body ?? '',
      colorValue: colorValue,
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
