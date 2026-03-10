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
    this.isCompleted = false,
    this.iconKey,
    List<SubTaskItem>? children,
  })  : id = id ?? ModelIds.newSubTaskId(),
        body = body ?? '',
        children = children ?? <SubTaskItem>[];

  final String id;
  final String title;
  final String body;
  final int? colorValue;
  final bool isCompleted;
  final String? iconKey;
  final List<SubTaskItem> children;

  SubTaskItem clone() {
    return SubTaskItem(
      id: id,
      title: title,
      body: body,
      colorValue: colorValue,
      isCompleted: isCompleted,
      iconKey: iconKey,
      children: children.map((SubTaskItem item) => item.clone()).toList(),
    );
  }

  SubTaskItem copyWith({
    String? id,
    String? title,
    String? body,
    int? colorValue,
    bool clearColor = false,
    bool? isCompleted,
    String? iconKey,
    bool clearIcon = false,
    List<SubTaskItem>? children,
  }) {
    return SubTaskItem(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      colorValue: clearColor ? null : (colorValue ?? this.colorValue),
      isCompleted: isCompleted ?? this.isCompleted,
      iconKey: clearIcon ? null : (iconKey ?? this.iconKey),
      children: children ??
          this.children.map((SubTaskItem item) => item.clone()).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'body': body,
      'color': colorValue,
      'completed': isCompleted,
      'icon': iconKey,
      'children': children.map((SubTaskItem item) => item.toJson()).toList(),
    };
  }

  factory SubTaskItem.fromJson(Map<String, dynamic> json) {
    final String title = _readRequiredString(json, 'title');
    final String? id = _readOptionalTrimmedString(json, 'id');
    final String? body = _readOptionalTrimmedString(json, 'body');
    final int? colorValue = _readOptionalInt(json, 'color');
    final bool isCompleted = _readOptionalBool(json, 'completed');
    final String? iconKey = _readOptionalTrimmedString(json, 'icon');
    final List<dynamic> childJson = _readOptionalList(json, 'children');

    return SubTaskItem(
      id: id == null || id.isEmpty ? null : id,
      title: title,
      body: body ?? '',
      colorValue: colorValue,
      isCompleted: isCompleted,
      iconKey: iconKey == null || iconKey.isEmpty ? null : iconKey,
      children: childJson
          .map(
            (dynamic item) => SubTaskItem.fromJson(
              _mapFromDynamic(
                item: item,
                fieldPath: 'tasks.subtasks.children[]',
              ),
            ),
          )
          .toList(),
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
    this.iconKey,
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
  final String? iconKey;
  final List<SubTaskItem> subtasks;

  TaskItem clone() {
    return TaskItem(
      id: id,
      title: title,
      body: body,
      colorValue: colorValue,
      type: type,
      iconKey: iconKey,
      subtasks: subtasks.map((SubTaskItem item) => item.clone()).toList(),
    );
  }

  TaskItem copyWith({
    String? id,
    String? title,
    String? body,
    int? colorValue,
    bool clearColor = false,
    TaskItemType? type,
    String? iconKey,
    bool clearIcon = false,
    List<SubTaskItem>? subtasks,
  }) {
    return TaskItem(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      colorValue: clearColor ? null : (colorValue ?? this.colorValue),
      type: type ?? this.type,
      iconKey: clearIcon ? null : (iconKey ?? this.iconKey),
      subtasks: subtasks ??
          this.subtasks.map((SubTaskItem item) => item.clone()).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'body': body,
      'color': colorValue,
      'type': type.name,
      'icon': iconKey,
      'subtasks': subtasks.map((SubTaskItem item) => item.toJson()).toList(),
    };
  }

  factory TaskItem.fromJson(Map<String, dynamic> json) {
    final String title = _readRequiredString(json, 'title');
    final String? id = _readOptionalTrimmedString(json, 'id');
    final String? body = _readOptionalTrimmedString(json, 'body');
    final int? colorValue = _readOptionalInt(json, 'color');
    final TaskItemType type = TaskItemType.fromJsonValue(json['type']);
    final String? iconKey = _readOptionalTrimmedString(json, 'icon');
    final List<dynamic> subtaskJson = _readOptionalList(json, 'subtasks');

    return TaskItem(
      id: id == null || id.isEmpty ? null : id,
      title: title,
      body: body ?? '',
      colorValue: colorValue,
      type: type,
      iconKey: iconKey == null || iconKey.isEmpty ? null : iconKey,
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
    this.iconKey,
    List<TaskItem>? tasks,
  })  : id = id ?? ModelIds.newProjectId(),
        body = body ?? '',
        tasks = tasks ?? <TaskItem>[];

  final String id;
  final String name;
  final String body;
  final int? colorValue;
  final String? iconKey;
  final List<TaskItem> tasks;

  ProjectItem clone() {
    return ProjectItem(
      id: id,
      name: name,
      body: body,
      colorValue: colorValue,
      iconKey: iconKey,
      tasks: tasks.map((TaskItem item) => item.clone()).toList(),
    );
  }

  ProjectItem copyWith({
    String? id,
    String? name,
    String? body,
    int? colorValue,
    bool clearColor = false,
    String? iconKey,
    bool clearIcon = false,
    List<TaskItem>? tasks,
  }) {
    return ProjectItem(
      id: id ?? this.id,
      name: name ?? this.name,
      body: body ?? this.body,
      colorValue: clearColor ? null : (colorValue ?? this.colorValue),
      iconKey: clearIcon ? null : (iconKey ?? this.iconKey),
      tasks: tasks ?? this.tasks.map((TaskItem item) => item.clone()).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'body': body,
      'color': colorValue,
      'icon': iconKey,
      'tasks': tasks.map((TaskItem item) => item.toJson()).toList(),
    };
  }

  factory ProjectItem.fromJson(Map<String, dynamic> json) {
    final String name = _readRequiredString(json, 'name');
    final String? id = _readOptionalTrimmedString(json, 'id');
    final String? body = _readOptionalTrimmedString(json, 'body');
    final int? colorValue = _readOptionalInt(json, 'color');
    final String? iconKey = _readOptionalTrimmedString(json, 'icon');
    final List<dynamic> taskJson = _readOptionalList(json, 'tasks');

    return ProjectItem(
      id: id == null || id.isEmpty ? null : id,
      name: name,
      body: body ?? '',
      colorValue: colorValue,
      iconKey: iconKey == null || iconKey.isEmpty ? null : iconKey,
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
    required this.hideCompletedProjectItems,
  });

  final List<TaskItem> incomingTasks;
  final List<TaskItem> favoriteTasks;
  final List<ProjectItem> projects;
  final Map<int, String> colorLabels;
  final bool hideCompletedProjectItems;

  TaskBoardState clone() {
    return TaskBoardState(
      incomingTasks:
          incomingTasks.map((TaskItem task) => task.clone()).toList(),
      favoriteTasks:
          favoriteTasks.map((TaskItem task) => task.clone()).toList(),
      projects: projects.map((ProjectItem project) => project.clone()).toList(),
      colorLabels: Map<int, String>.from(colorLabels),
      hideCompletedProjectItems: hideCompletedProjectItems,
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
      hideCompletedProjectItems: false,
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
      'hideCompletedProjectItems': hideCompletedProjectItems,
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
      hideCompletedProjectItems:
          _readOptionalBool(json, 'hideCompletedProjectItems'),
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

bool _readOptionalBool(Map<String, dynamic> json, String key) {
  final Object? value = json[key];
  if (value == null) {
    return false;
  }
  if (value is! bool) {
    throw FormatException('Expected "$key" to be a bool when present.');
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
