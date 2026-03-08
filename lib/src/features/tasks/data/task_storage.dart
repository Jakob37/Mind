import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/task_models.dart';

class TaskLoadResult {
  const TaskLoadResult._({
    required this.hadPersistedData,
    this.state,
    this.error,
    this.stackTrace,
  });

  const TaskLoadResult.empty()
      : this._(
          hadPersistedData: false,
        );

  const TaskLoadResult.success(TaskBoardState loadedState)
      : this._(
          hadPersistedData: true,
          state: loadedState,
        );

  const TaskLoadResult.failure({
    required Object loadError,
    required StackTrace loadStackTrace,
  }) : this._(
          hadPersistedData: true,
          error: loadError,
          stackTrace: loadStackTrace,
        );

  final bool hadPersistedData;
  final TaskBoardState? state;
  final Object? error;
  final StackTrace? stackTrace;

  bool get isSuccess => state != null;

  bool get isFailure => hadPersistedData && error != null;
}

class TaskStorage {
  const TaskStorage();

  static const String _stateKey = 'task_board_state';
  static const String _legacyStateKey = 'task_board_state_v1';
  static const int _currentSchemaVersion = 7;
  static final Map<int, Map<String, dynamic> Function(Map<String, dynamic>)>
      _migrations = <int, Map<String, dynamic> Function(Map<String, dynamic>)>{
    1: _migrateV1ToV2,
    2: _migrateV2ToV3,
    3: _migrateV3ToV4,
    4: _migrateV4ToV5,
    5: _migrateV5ToV6,
    6: _migrateV6ToV7,
  };
  static Future<void> _saveQueue = Future<void>.value();

  String export(TaskBoardState state) {
    return const JsonEncoder.withIndent('  ').convert(
      <String, dynamic>{
        'version': _currentSchemaVersion,
        'data': state.toJson(),
      },
    );
  }

  Future<TaskLoadResult> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? rawJson =
        prefs.getString(_stateKey) ?? prefs.getString(_legacyStateKey);

    if (rawJson == null) {
      return const TaskLoadResult.empty();
    }

    try {
      final Object? decoded = jsonDecode(rawJson);
      if (decoded is! Map<dynamic, dynamic>) {
        return TaskLoadResult.failure(
          loadError:
              const FormatException('Persisted state is not a JSON map.'),
          loadStackTrace: StackTrace.current,
        );
      }

      final Map<String, dynamic> decodedMap =
          Map<String, dynamic>.from(decoded);
      final int storedVersion = _readStoredVersion(decodedMap);
      final Object? payload = _readStoredPayload(decodedMap);
      if (payload is! Map<dynamic, dynamic>) {
        return TaskLoadResult.failure(
          loadError: const FormatException(
            'Persisted state payload is not a JSON map.',
          ),
          loadStackTrace: StackTrace.current,
        );
      }

      final Map<String, dynamic> migratedPayload = _migrateToCurrentVersion(
        version: storedVersion,
        payload: Map<String, dynamic>.from(payload),
      );

      return TaskLoadResult.success(TaskBoardState.fromJson(migratedPayload));
    } catch (error, stackTrace) {
      return TaskLoadResult.failure(
        loadError: error,
        loadStackTrace: stackTrace,
      );
    }
  }

  Future<void> save(TaskBoardState state) {
    final String versionedPayload = jsonEncode(
      <String, dynamic>{
        'version': _currentSchemaVersion,
        'data': state.toJson(),
      },
    );

    _saveQueue =
        _saveQueue.catchError((Object _, StackTrace __) {}).then((_) async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(_stateKey, versionedPayload);
      await prefs.remove(_legacyStateKey);
    });

    return _saveQueue;
  }

  static int _readStoredVersion(Map<String, dynamic> rawState) {
    if (!rawState.containsKey('version')) {
      return 1;
    }

    final Object? version = rawState['version'];
    if (version is! int) {
      throw const FormatException('Expected "version" to be an int.');
    }
    return version;
  }

  static Object? _readStoredPayload(Map<String, dynamic> rawState) {
    if (!rawState.containsKey('version')) {
      return rawState;
    }

    return rawState['data'];
  }

  static Map<String, dynamic> _migrateToCurrentVersion({
    required int version,
    required Map<String, dynamic> payload,
  }) {
    if (version > _currentSchemaVersion) {
      throw StateError(
        'State version $version is newer than supported '
        '$_currentSchemaVersion.',
      );
    }

    int currentVersion = version;
    Map<String, dynamic> workingPayload = Map<String, dynamic>.from(payload);

    while (currentVersion < _currentSchemaVersion) {
      final Map<String, dynamic> Function(Map<String, dynamic>)? migrateStep =
          _migrations[currentVersion];
      if (migrateStep == null) {
        throw StateError('Missing migration for version $currentVersion.');
      }
      workingPayload = migrateStep(workingPayload);
      currentVersion += 1;
    }

    return workingPayload;
  }

  static Map<String, dynamic> _migrateV1ToV2(Map<String, dynamic> payload) {
    return <String, dynamic>{
      'incomingTasks': _normalizeTaskList(payload['incomingTasks']),
      'favoriteTasks': _normalizeTaskList(payload['favoriteTasks']),
      'projects': _normalizeProjectList(payload['projects']),
    };
  }

  static Map<String, dynamic> _migrateV2ToV3(Map<String, dynamic> payload) {
    return <String, dynamic>{
      'incomingTasks': _addTaskIds(payload['incomingTasks']),
      'favoriteTasks': _addTaskIds(payload['favoriteTasks']),
      'projects': _addProjectAndTaskIds(payload['projects']),
    };
  }

  static Map<String, dynamic> _migrateV3ToV4(Map<String, dynamic> payload) {
    return <String, dynamic>{
      'incomingTasks': _addTaskBodies(payload['incomingTasks']),
      'favoriteTasks': _addTaskBodies(payload['favoriteTasks']),
      'projects': _addProjectBodies(payload['projects']),
    };
  }

  static Map<String, dynamic> _migrateV4ToV5(Map<String, dynamic> payload) {
    return <String, dynamic>{
      'incomingTasks': _addTaskColors(payload['incomingTasks']),
      'favoriteTasks': _addTaskColors(payload['favoriteTasks']),
      'projects': _addProjectColors(payload['projects']),
    };
  }

  static Map<String, dynamic> _migrateV5ToV6(Map<String, dynamic> payload) {
    return <String, dynamic>{
      'incomingTasks': _addTaskColors(payload['incomingTasks']),
      'favoriteTasks': _addTaskColors(payload['favoriteTasks']),
      'projects': _addProjectColors(payload['projects']),
      'colorLabels': _normalizeColorLabels(payload['colorLabels']),
    };
  }

  static Map<String, dynamic> _migrateV6ToV7(Map<String, dynamic> payload) {
    return <String, dynamic>{
      'incomingTasks': _addTaskTypes(payload['incomingTasks']),
      'favoriteTasks': _addTaskTypes(payload['favoriteTasks']),
      'projects': _addProjectTaskTypes(payload['projects']),
      'colorLabels': _normalizeColorLabels(payload['colorLabels']),
    };
  }

  static List<Map<String, dynamic>> _normalizeTaskList(Object? rawTasks) {
    if (rawTasks is! List<dynamic>) {
      return <Map<String, dynamic>>[];
    }

    final List<Map<String, dynamic>> tasks = <Map<String, dynamic>>[];

    for (final dynamic rawTask in rawTasks) {
      if (rawTask is String) {
        final String title = rawTask.trim();
        if (title.isNotEmpty) {
          tasks.add(<String, dynamic>{'title': title});
        }
        continue;
      }

      if (rawTask is! Map<dynamic, dynamic>) {
        continue;
      }

      final String? title = (rawTask['title'] as String?)?.trim();
      if (title == null || title.isEmpty) {
        continue;
      }

      tasks.add(<String, dynamic>{'title': title});
    }

    return tasks;
  }

  static List<Map<String, dynamic>> _normalizeProjectList(Object? rawProjects) {
    if (rawProjects is! List<dynamic>) {
      return <Map<String, dynamic>>[];
    }

    final List<Map<String, dynamic>> projects = <Map<String, dynamic>>[];

    for (final dynamic rawProject in rawProjects) {
      if (rawProject is String) {
        final String name = rawProject.trim();
        if (name.isNotEmpty) {
          projects.add(
            <String, dynamic>{
              'name': name,
              'tasks': <Map<String, dynamic>>[],
            },
          );
        }
        continue;
      }

      if (rawProject is! Map<dynamic, dynamic>) {
        continue;
      }

      final String? name = (rawProject['name'] as String?)?.trim();
      if (name == null || name.isEmpty) {
        continue;
      }

      projects.add(
        <String, dynamic>{
          'name': name,
          'tasks': _normalizeTaskList(rawProject['tasks']),
        },
      );
    }

    return projects;
  }

  static List<Map<String, dynamic>> _addTaskIds(Object? rawTasks) {
    if (rawTasks is! List<dynamic>) {
      return <Map<String, dynamic>>[];
    }

    final List<Map<String, dynamic>> tasks = <Map<String, dynamic>>[];
    for (final dynamic rawTask in rawTasks) {
      if (rawTask is! Map<dynamic, dynamic>) {
        continue;
      }
      final Map<String, dynamic> task = Map<String, dynamic>.from(rawTask);
      final String? id = (task['id'] as String?)?.trim();
      if (id == null || id.isEmpty) {
        task['id'] = ModelIds.newTaskId();
      }
      tasks.add(task);
    }
    return tasks;
  }

  static List<Map<String, dynamic>> _addProjectAndTaskIds(Object? rawProjects) {
    if (rawProjects is! List<dynamic>) {
      return <Map<String, dynamic>>[];
    }

    final List<Map<String, dynamic>> projects = <Map<String, dynamic>>[];
    for (final dynamic rawProject in rawProjects) {
      if (rawProject is! Map<dynamic, dynamic>) {
        continue;
      }
      final Map<String, dynamic> project =
          Map<String, dynamic>.from(rawProject);
      final String? id = (project['id'] as String?)?.trim();
      if (id == null || id.isEmpty) {
        project['id'] = ModelIds.newProjectId();
      }
      project['tasks'] = _addTaskIds(project['tasks']);
      projects.add(project);
    }
    return projects;
  }

  static List<Map<String, dynamic>> _addTaskBodies(Object? rawTasks) {
    if (rawTasks is! List<dynamic>) {
      return <Map<String, dynamic>>[];
    }

    final List<Map<String, dynamic>> tasks = <Map<String, dynamic>>[];
    for (final dynamic rawTask in rawTasks) {
      if (rawTask is! Map<dynamic, dynamic>) {
        continue;
      }
      final Map<String, dynamic> task = Map<String, dynamic>.from(rawTask);
      final Object? rawBody = task['body'];
      task['body'] = rawBody is String ? rawBody.trim() : '';
      tasks.add(task);
    }
    return tasks;
  }

  static List<Map<String, dynamic>> _addProjectBodies(Object? rawProjects) {
    if (rawProjects is! List<dynamic>) {
      return <Map<String, dynamic>>[];
    }

    final List<Map<String, dynamic>> projects = <Map<String, dynamic>>[];
    for (final dynamic rawProject in rawProjects) {
      if (rawProject is! Map<dynamic, dynamic>) {
        continue;
      }
      final Map<String, dynamic> project =
          Map<String, dynamic>.from(rawProject);
      final Object? rawBody = project['body'];
      project['body'] = rawBody is String ? rawBody.trim() : '';
      project['tasks'] = _addTaskBodies(project['tasks']);
      projects.add(project);
    }
    return projects;
  }

  static List<Map<String, dynamic>> _addTaskColors(Object? rawTasks) {
    if (rawTasks is! List<dynamic>) {
      return <Map<String, dynamic>>[];
    }

    final List<Map<String, dynamic>> tasks = <Map<String, dynamic>>[];
    for (final dynamic rawTask in rawTasks) {
      if (rawTask is! Map<dynamic, dynamic>) {
        continue;
      }
      final Map<String, dynamic> task = Map<String, dynamic>.from(rawTask);
      final Object? rawColor = task['color'];
      task['color'] = rawColor is int ? rawColor : null;
      tasks.add(task);
    }
    return tasks;
  }

  static List<Map<String, dynamic>> _addProjectColors(Object? rawProjects) {
    if (rawProjects is! List<dynamic>) {
      return <Map<String, dynamic>>[];
    }

    final List<Map<String, dynamic>> projects = <Map<String, dynamic>>[];
    for (final dynamic rawProject in rawProjects) {
      if (rawProject is! Map<dynamic, dynamic>) {
        continue;
      }
      final Map<String, dynamic> project =
          Map<String, dynamic>.from(rawProject);
      final Object? rawColor = project['color'];
      project['color'] = rawColor is int ? rawColor : null;
      project['tasks'] = _addTaskColors(project['tasks']);
      projects.add(project);
    }
    return projects;
  }

  static Map<String, String> _normalizeColorLabels(Object? rawColorLabels) {
    if (rawColorLabels is! Map<dynamic, dynamic>) {
      return <String, String>{};
    }

    final Map<String, String> labels = <String, String>{};
    for (final MapEntry<dynamic, dynamic> entry in rawColorLabels.entries) {
      final int? colorValue = switch (entry.key) {
        int numericKey => numericKey,
        String stringKey => int.tryParse(stringKey),
        _ => int.tryParse(entry.key.toString()),
      };
      if (colorValue == null || entry.value is! String) {
        continue;
      }

      final String label = (entry.value as String).trim();
      if (label.isEmpty) {
        continue;
      }
      labels[colorValue.toString()] = label;
    }

    return labels;
  }

  static List<Map<String, dynamic>> _addTaskTypes(Object? rawTasks) {
    if (rawTasks is! List<dynamic>) {
      return <Map<String, dynamic>>[];
    }

    final List<Map<String, dynamic>> tasks = <Map<String, dynamic>>[];
    for (final dynamic rawTask in rawTasks) {
      if (rawTask is! Map<dynamic, dynamic>) {
        continue;
      }
      final Map<String, dynamic> task = Map<String, dynamic>.from(rawTask);
      final Object? rawType = task['type'];
      task['type'] = rawType is String && rawType.trim().isNotEmpty
          ? rawType.trim().toLowerCase()
          : TaskItemType.planning.name;
      tasks.add(task);
    }
    return tasks;
  }

  static List<Map<String, dynamic>> _addProjectTaskTypes(Object? rawProjects) {
    if (rawProjects is! List<dynamic>) {
      return <Map<String, dynamic>>[];
    }

    final List<Map<String, dynamic>> projects = <Map<String, dynamic>>[];
    for (final dynamic rawProject in rawProjects) {
      if (rawProject is! Map<dynamic, dynamic>) {
        continue;
      }
      final Map<String, dynamic> project =
          Map<String, dynamic>.from(rawProject);
      project['tasks'] = _addTaskTypes(project['tasks']);
      projects.add(project);
    }
    return projects;
  }
}
