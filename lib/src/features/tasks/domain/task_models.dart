class ModelIds {
  static int _counter = 0;

  static String newTaskId() => _newId('task');

  static String newSubTaskId() => _newId('subtask');

  static String newProjectId() => _newId('project');

  static String _newId(String prefix) {
    final int micros = DateTime.now().microsecondsSinceEpoch;
    _counter += 1;
    return '$prefix-${micros.toRadixString(36)}-${_counter.toRadixString(36)}';
  }
}

enum TaskItemType {
  thinking,
  planning;

  static TaskItemType fromJsonValue(Object? rawValue) {
    if (rawValue is! String) {
      return TaskItemType.planning;
    }

    return switch (rawValue.trim().toLowerCase()) {
      'thinking' || 'idea' || 'ideas' => TaskItemType.thinking,
      _ => TaskItemType.planning,
    };
  }
}

class SubTaskItem {
  SubTaskItem({
    String? id,
    required this.title,
    String? body,
    this.colorValue,
  })  : id = id ?? ModelIds.newSubTaskId(),
        body = body ?? '';

  final String id;
  final String title;
  final String body;
  final int? colorValue;

  SubTaskItem clone() {
    return SubTaskItem(
      id: id,
      title: title,
      body: body,
      colorValue: colorValue,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'body': body,
      'color': colorValue,
    };
  }

  factory SubTaskItem.fromJson(Map<String, dynamic> json) {
    final String title = _readRequiredString(json, 'title');
    final String? id = _readOptionalTrimmedString(json, 'id');
    final String? body = _readOptionalTrimmedString(json, 'body');
    final int? colorValue = _readOptionalInt(json, 'color');

    return SubTaskItem(
      id: id == null || id.isEmpty ? null : id,
      title: title,
      body: body ?? '',
      colorValue: colorValue,
    );
  }
}

class TaskItem {
  TaskItem({
    String? id,
    required this.title,
    String? body,
    this.colorValue,
    TaskItemType? type,
    List<SubTaskItem>? subtasks,
  })  : id = id ?? ModelIds.newTaskId(),
        body = body ?? '',
        type = type ?? TaskItemType.planning,
        subtasks = subtasks ?? <SubTaskItem>[];

  final String id;
  final String title;
  final String body;
  final int? colorValue;
  final TaskItemType type;
  final List<SubTaskItem> subtasks;

  TaskItem clone() {
    return TaskItem(
      id: id,
      title: title,
      body: body,
      colorValue: colorValue,
      type: type,
      subtasks: subtasks.map((SubTaskItem subTask) => subTask.clone()).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'body': body,
      'color': colorValue,
      'type': type.name,
      'subtasks':
          subtasks.map((SubTaskItem subTask) => subTask.toJson()).toList(),
    };
  }

  factory TaskItem.fromJson(Map<String, dynamic> json) {
    final String title = _readRequiredString(json, 'title');
    final String? id = _readOptionalTrimmedString(json, 'id');
    final String? body = _readOptionalTrimmedString(json, 'body');
    final int? colorValue = _readOptionalInt(json, 'color');
    final TaskItemType type = TaskItemType.fromJsonValue(json['type']);
    final List<dynamic> subtaskJson = _readOptionalList(json, 'subtasks');

    return TaskItem(
      id: id == null || id.isEmpty ? null : id,
      title: title,
      body: body ?? '',
      colorValue: colorValue,
      type: type,
      subtasks: subtaskJson
          .map(
            (dynamic item) => SubTaskItem.fromJson(
              _mapFromDynamic(
                item: item,
                fieldPath: 'tasks.subtasks[]',
              ),
            ),
          )
          .toList(),
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

  ProjectItem clone() {
    return ProjectItem(
      id: id,
      name: name,
      body: body,
      colorValue: colorValue,
      tasks: tasks.map((TaskItem task) => task.clone()).toList(),
    );
  }

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
    final String name = _readRequiredString(json, 'name');
    final String? id = _readOptionalTrimmedString(json, 'id');
    final String? body = _readOptionalTrimmedString(json, 'body');
    final int? colorValue = _readOptionalInt(json, 'color');
    final List<dynamic> taskJson = _readOptionalList(json, 'tasks');

    return ProjectItem(
      id: id == null || id.isEmpty ? null : id,
      name: name,
      body: body ?? '',
      colorValue: colorValue,
      tasks: taskJson
          .map(
            (dynamic item) => TaskItem.fromJson(
              _mapFromDynamic(
                item: item,
                fieldPath: 'projects.tasks[]',
              ),
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
    required this.colorLabels,
  });

  final List<TaskItem> incomingTasks;
  final List<TaskItem> favoriteTasks;
  final List<ProjectItem> projects;
  final Map<int, String> colorLabels;

  TaskBoardState clone() {
    return TaskBoardState(
      incomingTasks:
          incomingTasks.map((TaskItem task) => task.clone()).toList(),
      favoriteTasks:
          favoriteTasks.map((TaskItem task) => task.clone()).toList(),
      projects: projects.map((ProjectItem project) => project.clone()).toList(),
      colorLabels: Map<int, String>.from(colorLabels),
    );
  }

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
      colorLabels: <int, String>{},
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
      'colorLabels': colorLabels.map(
        (int colorValue, String label) =>
            MapEntry<String, String>(colorValue.toString(), label),
      ),
    };
  }

  factory TaskBoardState.fromJson(Map<String, dynamic> json) {
    final List<dynamic> incomingJson = _readOptionalList(json, 'incomingTasks');
    final List<dynamic> favoriteJson = _readOptionalList(json, 'favoriteTasks');
    final List<dynamic> projectJson = _readOptionalList(json, 'projects');
    final Map<int, String> colorLabels = _readColorLabelMap(
      json,
      'colorLabels',
    );

    return TaskBoardState(
      incomingTasks: incomingJson
          .map(
            (dynamic item) => TaskItem.fromJson(
              _mapFromDynamic(
                item: item,
                fieldPath: 'incomingTasks[]',
              ),
            ),
          )
          .toList(),
      favoriteTasks: favoriteJson
          .map(
            (dynamic item) => TaskItem.fromJson(
              _mapFromDynamic(
                item: item,
                fieldPath: 'favoriteTasks[]',
              ),
            ),
          )
          .toList(),
      projects: projectJson
          .map(
            (dynamic item) => ProjectItem.fromJson(
              _mapFromDynamic(
                item: item,
                fieldPath: 'projects[]',
              ),
            ),
          )
          .toList(),
      colorLabels: colorLabels,
    );
  }
}

String _readRequiredString(Map<String, dynamic> json, String key) {
  final Object? value = json[key];
  if (value is! String) {
    throw FormatException('Expected "$key" to be a string.');
  }
  final String trimmed = value.trim();
  if (trimmed.isEmpty) {
    throw FormatException('Expected "$key" to be a non-empty string.');
  }
  return trimmed;
}

String? _readOptionalTrimmedString(Map<String, dynamic> json, String key) {
  final Object? value = json[key];
  if (value == null) {
    return null;
  }
  if (value is! String) {
    throw FormatException('Expected "$key" to be a string when present.');
  }
  return value.trim();
}

int? _readOptionalInt(Map<String, dynamic> json, String key) {
  final Object? value = json[key];
  if (value == null) {
    return null;
  }
  if (value is! int) {
    throw FormatException('Expected "$key" to be an int when present.');
  }
  return value;
}

List<dynamic> _readOptionalList(Map<String, dynamic> json, String key) {
  final Object? value = json[key];
  if (value == null) {
    return <dynamic>[];
  }
  if (value is! List<dynamic>) {
    throw FormatException('Expected "$key" to be a JSON array.');
  }
  return value;
}

Map<int, String> _readColorLabelMap(Map<String, dynamic> json, String key) {
  final Object? value = json[key];
  if (value == null) {
    return <int, String>{};
  }
  if (value is! Map<dynamic, dynamic>) {
    throw FormatException('Expected "$key" to be a JSON map.');
  }

  final Map<int, String> result = <int, String>{};
  for (final MapEntry<dynamic, dynamic> entry in value.entries) {
    final int? colorValue = switch (entry.key) {
      int numericKey => numericKey,
      String stringKey => int.tryParse(stringKey),
      _ => int.tryParse(entry.key.toString()),
    };
    if (colorValue == null) {
      continue;
    }

    if (entry.value is! String) {
      throw FormatException(
        'Expected "$key.${entry.key}" to be a string label.',
      );
    }
    final String label = (entry.value as String).trim();
    if (label.isEmpty) {
      continue;
    }

    result[colorValue] = label;
  }

  return result;
}

Map<String, dynamic> _mapFromDynamic({
  required dynamic item,
  required String fieldPath,
}) {
  if (item is! Map<dynamic, dynamic>) {
    throw FormatException('Expected "$fieldPath" item to be a JSON map.');
  }
  return Map<String, dynamic>.from(item);
}
