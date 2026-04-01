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

  const TaskLoadResult.empty() : this._(hadPersistedData: false);

  const TaskLoadResult.success(TaskBoardState loadedState)
      : this._(hadPersistedData: true, state: loadedState);

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
  static const int _currentSchemaVersion = 23;
  static final Map<int, Map<String, dynamic> Function(Map<String, dynamic>)>
      _migrations = <int, Map<String, dynamic> Function(Map<String, dynamic>)>{
    1: _migrateV1ToV2,
    2: _migrateV2ToV3,
    3: _migrateV3ToV4,
    4: _migrateV4ToV5,
    5: _migrateV5ToV6,
    6: _migrateV6ToV7,
    7: _migrateV7ToV8,
    8: _migrateV8ToV9,
    9: _migrateV9ToV10,
    10: _migrateV10ToV11,
    11: _migrateV11ToV12,
    12: _migrateV12ToV13,
    13: _migrateV13ToV14,
    14: _migrateV14ToV15,
    15: _migrateV15ToV16,
    16: _migrateV16ToV17,
    17: _migrateV17ToV18,
    18: _migrateV18ToV19,
    19: _migrateV19ToV20,
    20: _migrateV20ToV21,
    21: _migrateV21ToV22,
    22: _migrateV22ToV23,
  };
  static Future<void> _saveQueue = Future<void>.value();

  String export(TaskBoardState state) {
    return const JsonEncoder.withIndent('  ').convert(<String, dynamic>{
      'version': _currentSchemaVersion,
      'data': state.toJson(),
    });
  }

  TaskBoardState import(String rawJson) {
    final Object? decoded = jsonDecode(rawJson);
    if (decoded is! Map<dynamic, dynamic>) {
      throw const FormatException('Import JSON is not a map.');
    }

    final Map<String, dynamic> decodedMap = Map<String, dynamic>.from(decoded);
    final int storedVersion = _readStoredVersion(decodedMap);
    final Object? payload = _readStoredPayload(decodedMap);
    if (payload is! Map<dynamic, dynamic>) {
      throw const FormatException('Import JSON data payload is not a map.');
    }

    final Map<String, dynamic> migratedPayload = _migrateToCurrentVersion(
      version: storedVersion,
      payload: Map<String, dynamic>.from(payload),
    );

    return TaskBoardState.fromJson(migratedPayload);
  }

  String exportPlainText(TaskBoardState state) {
    final StringBuffer buffer = StringBuffer()
      ..writeln('Mind export')
      ..writeln();

    _writeTaskSection(
      buffer: buffer,
      title: 'Incoming',
      tasks: state.incomingTasks,
    );
    _writeProjectSection(
      buffer: buffer,
      title: 'Projects',
      projects: state.projects,
      projectStacks: state.projectStacks,
    );

    return buffer.toString().trimRight();
  }

  Future<TaskLoadResult> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? rawJson =
        prefs.getString(_stateKey) ?? prefs.getString(_legacyStateKey);

    if (rawJson == null) {
      return const TaskLoadResult.empty();
    }

    try {
      return TaskLoadResult.success(import(rawJson));
    } catch (error, stackTrace) {
      return TaskLoadResult.failure(
        loadError: error,
        loadStackTrace: stackTrace,
      );
    }
  }

  Future<void> save(TaskBoardState state) {
    final String versionedPayload = jsonEncode(<String, dynamic>{
      'version': _currentSchemaVersion,
      'data': state.toJson(),
    });

    _saveQueue = _saveQueue.catchError((Object _, StackTrace __) {}).then((
      _,
    ) async {
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

  static Map<String, dynamic> _migrateV7ToV8(Map<String, dynamic> payload) {
    return <String, dynamic>{
      'incomingTasks': _addTaskSubtasks(payload['incomingTasks']),
      'favoriteTasks': _addTaskSubtasks(payload['favoriteTasks']),
      'projects': _addProjectTaskSubtasks(payload['projects']),
      'colorLabels': _normalizeColorLabels(payload['colorLabels']),
    };
  }

  static Map<String, dynamic> _migrateV8ToV9(Map<String, dynamic> payload) {
    return <String, dynamic>{
      'incomingTasks': _upgradeTaskShape(payload['incomingTasks']),
      'favoriteTasks': _upgradeTaskShape(payload['favoriteTasks']),
      'projects': _upgradeProjectShape(payload['projects']),
      'colorLabels': _normalizeColorLabels(payload['colorLabels']),
      'hideCompletedProjectItems': payload['hideCompletedProjectItems'] is bool
          ? payload['hideCompletedProjectItems']
          : false,
    };
  }

  static Map<String, dynamic> _migrateV9ToV10(Map<String, dynamic> payload) {
    final List<Map<String, dynamic>> projectStacks = _upgradeProjectStackShape(
      payload['projectStacks'],
    );
    final Set<String> stackIds = projectStacks
        .map((Map<String, dynamic> stack) => stack['id'])
        .whereType<String>()
        .toSet();

    return <String, dynamic>{
      'incomingTasks': _upgradeTaskShape(payload['incomingTasks']),
      'favoriteTasks': _upgradeTaskShape(payload['favoriteTasks']),
      'projects': _upgradeProjectShape(
        payload['projects'],
        validStackIds: stackIds,
      ),
      'projectStacks': projectStacks,
      'colorLabels': _normalizeColorLabels(payload['colorLabels']),
      'hideCompletedProjectItems': payload['hideCompletedProjectItems'] is bool
          ? payload['hideCompletedProjectItems']
          : false,
    };
  }

  static Map<String, dynamic> _migrateV10ToV11(Map<String, dynamic> payload) {
    final List<Map<String, dynamic>> projectTypes = _upgradeProjectTypeShape(
      payload['projectTypes'],
    );
    final Set<String> typeIds = projectTypes
        .map((Map<String, dynamic> type) => type['id'])
        .whereType<String>()
        .toSet();
    final Set<String> stackIds =
        _upgradeProjectStackShape(payload['projectStacks'])
            .map((Map<String, dynamic> stack) => stack['id'])
            .whereType<String>()
            .toSet();

    return <String, dynamic>{
      'incomingTasks': _upgradeTaskShape(payload['incomingTasks']),
      'favoriteTasks': _upgradeTaskShape(payload['favoriteTasks']),
      'projects': _upgradeProjectShape(
        payload['projects'],
        validStackIds: stackIds,
        validProjectTypeIds: typeIds,
        fallbackProjectTypeId: ProjectTypeDefaults.projectId,
      ),
      'projectStacks': _upgradeProjectStackShape(payload['projectStacks']),
      'projectTypes': projectTypes,
      'colorLabels': _normalizeColorLabels(payload['colorLabels']),
      'hideCompletedProjectItems': payload['hideCompletedProjectItems'] is bool
          ? payload['hideCompletedProjectItems']
          : false,
    };
  }

  static Map<String, dynamic> _migrateV11ToV12(Map<String, dynamic> payload) {
    final List<Map<String, dynamic>> projectTypes = _upgradeProjectTypeShape(
      payload['projectTypes'],
    );
    final Set<String> typeIds = projectTypes
        .map((Map<String, dynamic> type) => type['id'])
        .whereType<String>()
        .toSet();
    final List<Map<String, dynamic>> projectStacks = _upgradeProjectStackShape(
      payload['projectStacks'],
    );
    final Set<String> stackIds = projectStacks
        .map((Map<String, dynamic> stack) => stack['id'])
        .whereType<String>()
        .toSet();

    return <String, dynamic>{
      'incomingTasks': _upgradeTaskShape(payload['incomingTasks']),
      'favoriteTasks': _upgradeTaskShape(payload['favoriteTasks']),
      'projects': _upgradeProjectShape(
        payload['projects'],
        validStackIds: stackIds,
        validProjectTypeIds: typeIds,
        fallbackProjectTypeId: ProjectTypeDefaults.projectId,
      ),
      'projectStacks': projectStacks,
      'projectTypes': projectTypes,
      'colorLabels': _normalizeColorLabels(payload['colorLabels']),
      'hideCompletedProjectItems': payload['hideCompletedProjectItems'] is bool
          ? payload['hideCompletedProjectItems']
          : false,
    };
  }

  static Map<String, dynamic> _migrateV12ToV13(Map<String, dynamic> payload) {
    final List<Map<String, dynamic>> projectTypes = _upgradeProjectTypeShape(
      payload['projectTypes'],
    );
    final Set<String> typeIds = projectTypes
        .map((Map<String, dynamic> type) => type['id'])
        .whereType<String>()
        .toSet();
    final List<Map<String, dynamic>> projectStacks = _upgradeProjectStackShape(
      payload['projectStacks'],
    );
    final Set<String> stackIds = projectStacks
        .map((Map<String, dynamic> stack) => stack['id'])
        .whereType<String>()
        .toSet();

    return <String, dynamic>{
      'incomingTasks': _upgradeTaskShape(payload['incomingTasks']),
      'favoriteTasks': _upgradeTaskShape(payload['favoriteTasks']),
      'projects': _upgradeProjectShape(
        payload['projects'],
        validStackIds: stackIds,
        validProjectTypeIds: typeIds,
        fallbackProjectTypeId: ProjectTypeDefaults.projectId,
      ),
      'projectStacks': projectStacks,
      'projectTypes': projectTypes,
      'colorLabels': _normalizeColorLabels(payload['colorLabels']),
      'hideCompletedProjectItems': payload['hideCompletedProjectItems'] is bool
          ? payload['hideCompletedProjectItems']
          : false,
    };
  }

  static Map<String, dynamic> _migrateV13ToV14(Map<String, dynamic> payload) {
    final List<Map<String, dynamic>> projectTypes = _upgradeProjectTypeShape(
      payload['projectTypes'],
    );
    final Set<String> typeIds = projectTypes
        .map((Map<String, dynamic> type) => type['id'])
        .whereType<String>()
        .toSet();
    final List<Map<String, dynamic>> projectStacks = _upgradeProjectStackShape(
      payload['projectStacks'],
    );
    final Set<String> stackIds = projectStacks
        .map((Map<String, dynamic> stack) => stack['id'])
        .whereType<String>()
        .toSet();

    return <String, dynamic>{
      'incomingTasks': _upgradeTaskShape(payload['incomingTasks']),
      'favoriteTasks': _upgradeTaskShape(payload['favoriteTasks']),
      'projects': _upgradeProjectShape(
        payload['projects'],
        validStackIds: stackIds,
        validProjectTypeIds: typeIds,
        fallbackProjectTypeId: ProjectTypeDefaults.projectId,
      ),
      'projectStacks': projectStacks,
      'projectTypes': projectTypes,
      'colorLabels': _normalizeColorLabels(payload['colorLabels']),
      'hideCompletedProjectItems': payload['hideCompletedProjectItems'] is bool
          ? payload['hideCompletedProjectItems']
          : false,
    };
  }

  static Map<String, dynamic> _migrateV14ToV15(Map<String, dynamic> payload) {
    final List<Map<String, dynamic>> incomingTasks = _upgradeTaskShape(
      payload['incomingTasks'],
    );
    final List<Map<String, dynamic>> favoriteTasks = _upgradeTaskShape(
      payload['favoriteTasks'],
    );
    final List<Map<String, dynamic>> projectTypes = _upgradeProjectTypeShape(
      payload['projectTypes'],
    );
    final Set<String> typeIds = projectTypes
        .map((Map<String, dynamic> type) => type['id'])
        .whereType<String>()
        .toSet();
    final List<Map<String, dynamic>> projectStacks = _upgradeProjectStackShape(
      payload['projectStacks'],
    );
    final Set<String> stackIds = projectStacks
        .map((Map<String, dynamic> stack) => stack['id'])
        .whereType<String>()
        .toSet();

    return <String, dynamic>{
      'incomingTasks': _mergeTaskLists(
        primaryTasks: incomingTasks,
        additionalTasks: favoriteTasks,
      ),
      'projects': _upgradeProjectShape(
        payload['projects'],
        validStackIds: stackIds,
        validProjectTypeIds: typeIds,
        fallbackProjectTypeId: ProjectTypeDefaults.projectId,
      ),
      'projectStacks': projectStacks,
      'projectTypes': projectTypes,
      'colorLabels': _normalizeColorLabels(payload['colorLabels']),
      'hideCompletedProjectItems': payload['hideCompletedProjectItems'] is bool
          ? payload['hideCompletedProjectItems']
          : false,
    };
  }

  static Map<String, dynamic> _migrateV15ToV16(Map<String, dynamic> payload) {
    final List<Map<String, dynamic>> projectTypes = _upgradeProjectTypeShape(
      payload['projectTypes'],
    );
    final Set<String> typeIds = projectTypes
        .map((Map<String, dynamic> type) => type['id'])
        .whereType<String>()
        .toSet();
    final List<Map<String, dynamic>> projectStacks = _upgradeProjectStackShape(
      payload['projectStacks'],
    );
    final Set<String> stackIds = projectStacks
        .map((Map<String, dynamic> stack) => stack['id'])
        .whereType<String>()
        .toSet();

    return <String, dynamic>{
      'incomingTasks': _upgradeTaskShape(payload['incomingTasks']),
      'projects': _upgradeProjectShape(
        payload['projects'],
        validStackIds: stackIds,
        validProjectTypeIds: typeIds,
        fallbackProjectTypeId: ProjectTypeDefaults.projectId,
      ),
      'projectStacks': projectStacks,
      'projectTypes': projectTypes,
      'colorLabels': _normalizeColorLabels(payload['colorLabels']),
      'hideCompletedProjectItems': payload['hideCompletedProjectItems'] is bool
          ? payload['hideCompletedProjectItems']
          : false,
    };
  }

  static Map<String, dynamic> _migrateV16ToV17(Map<String, dynamic> payload) {
    return <String, dynamic>{
      'incomingTasks': _upgradeTaskShape(payload['incomingTasks']),
      'projects': _upgradeProjectShape(payload['projects']),
      'projectStacks': _upgradeProjectStackShape(payload['projectStacks']),
      'projectTypes': _upgradeProjectTypeShape(payload['projectTypes']),
      'colorLabels': _normalizeColorLabels(payload['colorLabels']),
      'hideCompletedProjectItems': payload['hideCompletedProjectItems'] is bool
          ? payload['hideCompletedProjectItems']
          : false,
      'cardLayoutPreset': payload['cardLayoutPreset'] is String
          ? payload['cardLayoutPreset']
          : CardLayoutPreset.standard.name,
    };
  }

  static Map<String, dynamic> _migrateV17ToV18(Map<String, dynamic> payload) {
    return <String, dynamic>{
      'incomingTasks': _upgradeTaskShape(payload['incomingTasks']),
      'projects': _upgradeProjectShape(payload['projects']),
      'projectStacks': _upgradeProjectStackShape(payload['projectStacks']),
      'projectTypes': _upgradeProjectTypeShape(payload['projectTypes']),
      'colorLabels': _normalizeColorLabels(payload['colorLabels']),
      'hideCompletedProjectItems': payload['hideCompletedProjectItems'] is bool
          ? payload['hideCompletedProjectItems']
          : false,
      'cardLayoutPreset': payload['cardLayoutPreset'] is String
          ? payload['cardLayoutPreset']
          : CardLayoutPreset.standard.name,
    };
  }

  static Map<String, dynamic> _migrateV18ToV19(Map<String, dynamic> payload) {
    return <String, dynamic>{
      'incomingTasks': _upgradeTaskShape(payload['incomingTasks']),
      'projects': _upgradeProjectShape(payload['projects']),
      'projectStacks': _upgradeProjectStackShape(payload['projectStacks']),
      'projectTypes': _upgradeProjectTypeShape(payload['projectTypes']),
      'colorLabels': _normalizeColorLabels(payload['colorLabels']),
      'hideCompletedProjectItems': payload['hideCompletedProjectItems'] is bool
          ? payload['hideCompletedProjectItems']
          : false,
      'cardLayoutPreset': payload['cardLayoutPreset'] is String
          ? payload['cardLayoutPreset']
          : CardLayoutPreset.standard.name,
    };
  }

  static Map<String, dynamic> _migrateV19ToV20(Map<String, dynamic> payload) {
    final List<Map<String, dynamic>> projectTypes = _upgradeProjectTypeShape(
      payload['projectTypes'],
    );
    final Set<String> typeIds = projectTypes
        .map((Map<String, dynamic> type) => type['id'])
        .whereType<String>()
        .toSet();
    final Map<String, ProjectLayoutKind> typeLayouts = _projectTypeLayoutsById(
      projectTypes,
    );

    return <String, dynamic>{
      'incomingTasks': _upgradeTaskShape(payload['incomingTasks']),
      'projects': _upgradeProjectShape(
        payload['projects'],
        validProjectTypeIds: typeIds,
        fallbackProjectTypeId: ProjectTypeDefaults.projectId,
        projectLayoutsByTypeId: typeLayouts,
      ),
      'projectStacks': _upgradeProjectStackShape(payload['projectStacks']),
      'projectTypes': projectTypes,
      'colorLabels': _normalizeColorLabels(payload['colorLabels']),
      'hideCompletedProjectItems': payload['hideCompletedProjectItems'] is bool
          ? payload['hideCompletedProjectItems']
          : false,
      'cardLayoutPreset': payload['cardLayoutPreset'] is String
          ? payload['cardLayoutPreset']
          : CardLayoutPreset.standard.name,
    };
  }

  static Map<String, dynamic> _migrateV20ToV21(Map<String, dynamic> payload) {
    final List<Map<String, dynamic>> projectTypes = _upgradeProjectTypeShape(
      payload['projectTypes'],
    );
    final Set<String> typeIds = projectTypes
        .map((Map<String, dynamic> type) => type['id'])
        .whereType<String>()
        .toSet();
    final Map<String, ProjectLayoutKind> typeLayouts = _projectTypeLayoutsById(
      projectTypes,
    );

    return <String, dynamic>{
      'incomingTasks': _upgradeTaskShape(payload['incomingTasks']),
      'projects': _upgradeProjectShape(
        payload['projects'],
        validProjectTypeIds: typeIds,
        fallbackProjectTypeId: ProjectTypeDefaults.projectId,
        projectLayoutsByTypeId: typeLayouts,
      ),
      'projectStacks': _upgradeProjectStackShape(payload['projectStacks']),
      'projectTypes': projectTypes,
      'colorLabels': _normalizeColorLabels(payload['colorLabels']),
      'hideCompletedProjectItems': payload['hideCompletedProjectItems'] is bool
          ? payload['hideCompletedProjectItems']
          : false,
      'cardLayoutPreset': payload['cardLayoutPreset'] is String
          ? payload['cardLayoutPreset']
          : CardLayoutPreset.standard.name,
    };
  }

  static Map<String, dynamic> _migrateV21ToV22(Map<String, dynamic> payload) {
    final List<Map<String, dynamic>> projectTypes = _upgradeProjectTypeShape(
      payload['projectTypes'],
    );
    final Set<String> typeIds = projectTypes
        .map((Map<String, dynamic> type) => type['id'])
        .whereType<String>()
        .toSet();
    final Map<String, ProjectLayoutKind> typeLayouts = _projectTypeLayoutsById(
      projectTypes,
    );

    return <String, dynamic>{
      'incomingTasks': _upgradeTaskShape(payload['incomingTasks']),
      'projects': _upgradeProjectShape(
        payload['projects'],
        validProjectTypeIds: typeIds,
        fallbackProjectTypeId: ProjectTypeDefaults.projectId,
        projectLayoutsByTypeId: typeLayouts,
      ),
      'projectStacks': _upgradeProjectStackShape(payload['projectStacks']),
      'projectTypes': projectTypes,
      'colorLabels': _normalizeColorLabels(payload['colorLabels']),
      'hideCompletedProjectItems': payload['hideCompletedProjectItems'] is bool
          ? payload['hideCompletedProjectItems']
          : false,
      'cardLayoutPreset': payload['cardLayoutPreset'] is String
          ? payload['cardLayoutPreset']
          : CardLayoutPreset.standard.name,
    };
  }

  static Map<String, dynamic> _migrateV22ToV23(Map<String, dynamic> payload) {
    final List<Map<String, dynamic>> projectTypes = _upgradeProjectTypeShape(
      payload['projectTypes'],
    );
    final Set<String> typeIds = projectTypes
        .map((Map<String, dynamic> type) => type['id'])
        .whereType<String>()
        .toSet();
    final Map<String, ProjectLayoutKind> typeLayouts = _projectTypeLayoutsById(
      projectTypes,
    );

    return <String, dynamic>{
      'incomingTasks': _upgradeTaskShape(payload['incomingTasks']),
      'projects': _upgradeProjectShape(
        payload['projects'],
        validProjectTypeIds: typeIds,
        fallbackProjectTypeId: ProjectTypeDefaults.projectId,
        projectLayoutsByTypeId: typeLayouts,
      ),
      'projectStacks': _upgradeProjectStackShape(payload['projectStacks']),
      'projectTypes': projectTypes,
      'colorLabels': _normalizeColorLabels(payload['colorLabels']),
      'hideCompletedProjectItems': payload['hideCompletedProjectItems'] is bool
          ? payload['hideCompletedProjectItems']
          : false,
      'cardLayoutPreset': payload['cardLayoutPreset'] is String
          ? payload['cardLayoutPreset']
          : CardLayoutPreset.standard.name,
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

  static List<Map<String, dynamic>> _mergeTaskLists({
    required List<Map<String, dynamic>> primaryTasks,
    required List<Map<String, dynamic>> additionalTasks,
  }) {
    return <Map<String, dynamic>>[
      ...primaryTasks.map(Map<String, dynamic>.from),
      ...additionalTasks.map(Map<String, dynamic>.from),
    ];
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
          projects.add(<String, dynamic>{
            'name': name,
            'tasks': <Map<String, dynamic>>[],
            'people': <Map<String, dynamic>>[],
          });
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

      projects.add(<String, dynamic>{
        'name': name,
        'tasks': _normalizeTaskList(rawProject['tasks']),
        'people': <Map<String, dynamic>>[],
      });
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
      final Map<String, dynamic> project = Map<String, dynamic>.from(
        rawProject,
      );
      final String? id = (project['id'] as String?)?.trim();
      if (id == null || id.isEmpty) {
        project['id'] = ModelIds.newProjectId();
      }
      project['tasks'] = _addTaskIds(project['tasks']);
      project['people'] = <Map<String, dynamic>>[];
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
      final Map<String, dynamic> project = Map<String, dynamic>.from(
        rawProject,
      );
      final Object? rawBody = project['body'];
      project['body'] = rawBody is String ? rawBody.trim() : '';
      project['tasks'] = _addTaskBodies(project['tasks']);
      project['people'] = <Map<String, dynamic>>[];
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
      final Map<String, dynamic> project = Map<String, dynamic>.from(
        rawProject,
      );
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
      final Map<String, dynamic> project = Map<String, dynamic>.from(
        rawProject,
      );
      project['tasks'] = _addTaskTypes(project['tasks']);
      projects.add(project);
    }
    return projects;
  }

  static List<Map<String, dynamic>> _addTaskSubtasks(Object? rawTasks) {
    if (rawTasks is! List<dynamic>) {
      return <Map<String, dynamic>>[];
    }

    final List<Map<String, dynamic>> tasks = <Map<String, dynamic>>[];
    for (final dynamic rawTask in rawTasks) {
      if (rawTask is! Map<dynamic, dynamic>) {
        continue;
      }
      final Map<String, dynamic> task = Map<String, dynamic>.from(rawTask);
      task['subtasks'] = _normalizeSubtaskList(task['subtasks']);
      tasks.add(task);
    }
    return tasks;
  }

  static List<Map<String, dynamic>> _addProjectTaskSubtasks(
    Object? rawProjects,
  ) {
    if (rawProjects is! List<dynamic>) {
      return <Map<String, dynamic>>[];
    }

    final List<Map<String, dynamic>> projects = <Map<String, dynamic>>[];
    for (final dynamic rawProject in rawProjects) {
      if (rawProject is! Map<dynamic, dynamic>) {
        continue;
      }
      final Map<String, dynamic> project = Map<String, dynamic>.from(
        rawProject,
      );
      project['tasks'] = _addTaskSubtasks(project['tasks']);
      projects.add(project);
    }
    return projects;
  }

  static List<Map<String, dynamic>> _normalizeSubtaskList(Object? rawSubtasks) {
    if (rawSubtasks is! List<dynamic>) {
      return <Map<String, dynamic>>[];
    }

    final List<Map<String, dynamic>> subtasks = <Map<String, dynamic>>[];
    for (final dynamic rawSubtask in rawSubtasks) {
      if (rawSubtask is String) {
        final String title = rawSubtask.trim();
        if (title.isNotEmpty) {
          subtasks.add(<String, dynamic>{'title': title, 'body': ''});
        }
        continue;
      }

      if (rawSubtask is! Map<dynamic, dynamic>) {
        continue;
      }

      final String? title = (rawSubtask['title'] as String?)?.trim();
      if (title == null || title.isEmpty) {
        continue;
      }

      final Map<String, dynamic> subtask = <String, dynamic>{
        'title': title,
        'body': (rawSubtask['body'] as String?)?.trim() ?? '',
      };

      final String? id = (rawSubtask['id'] as String?)?.trim();
      if (id != null && id.isNotEmpty) {
        subtask['id'] = id;
      } else {
        subtask['id'] = ModelIds.newSubTaskId();
      }
      subtask['color'] =
          rawSubtask['color'] is int ? rawSubtask['color'] : null;
      subtask['completed'] = false;
      subtask['icon'] = null;
      subtask['children'] = <Map<String, dynamic>>[];
      subtasks.add(subtask);
    }
    return subtasks;
  }

  static List<Map<String, dynamic>> _upgradeTaskShape(Object? rawTasks) {
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
      task['body'] =
          task['body'] is String ? (task['body'] as String).trim() : '';
      task['prompt'] =
          task['prompt'] is String ? (task['prompt'] as String).trim() : '';
      task['flashcardPrompt'] = task['flashcardPrompt'] is String
          ? (task['flashcardPrompt'] as String).trim()
          : '';
      task['imagePaths'] = task['imagePaths'] is List<dynamic>
          ? (task['imagePaths'] as List<dynamic>)
              .whereType<String>()
              .map((String path) => path.trim())
              .where((String path) => path.isNotEmpty)
              .toList()
          : <String>[];
      task['createdAtMicros'] =
          task['createdAtMicros'] is int ? task['createdAtMicros'] : null;
      task['color'] = task['color'] is int ? task['color'] : null;
      task['type'] =
          task['type'] is String && (task['type'] as String).trim().isNotEmpty
              ? (task['type'] as String).trim().toLowerCase()
              : TaskItemType.planning.name;
      task['entryType'] = task['entryType'] is String &&
              (task['entryType'] as String).trim().isNotEmpty
          ? (task['entryType'] as String).trim().toLowerCase()
          : TaskEntryType.note.name;
      task['archived'] = task['archived'] is bool ? task['archived'] : false;
      task['pinned'] = task['pinned'] is bool ? task['pinned'] : false;
      task['icon'] =
          task['icon'] is String && (task['icon'] as String).trim().isNotEmpty
              ? (task['icon'] as String).trim()
              : null;
      task['subtasks'] = _upgradeSubtaskShape(task['subtasks']);
      tasks.add(task);
    }
    return tasks;
  }

  static List<Map<String, dynamic>> _upgradeProjectShape(
    Object? rawProjects, {
    Set<String>? validStackIds,
    Set<String>? validProjectTypeIds,
    String? fallbackProjectTypeId,
    Map<String, ProjectLayoutKind>? projectLayoutsByTypeId,
  }) {
    if (rawProjects is! List<dynamic>) {
      return <Map<String, dynamic>>[];
    }

    final List<Map<String, dynamic>> projects = <Map<String, dynamic>>[];
    for (final dynamic rawProject in rawProjects) {
      if (rawProject is! Map<dynamic, dynamic>) {
        continue;
      }
      final Map<String, dynamic> project = Map<String, dynamic>.from(
        rawProject,
      );
      final String? id = (project['id'] as String?)?.trim();
      if (id == null || id.isEmpty) {
        project['id'] = ModelIds.newProjectId();
      }
      project['body'] =
          project['body'] is String ? (project['body'] as String).trim() : '';
      project['prompt'] = project['prompt'] is String
          ? (project['prompt'] as String).trim()
          : '';
      project['color'] = project['color'] is int ? project['color'] : null;
      project['icon'] = project['icon'] is String &&
              (project['icon'] as String).trim().isNotEmpty
          ? (project['icon'] as String).trim()
          : null;
      project['archived'] =
          project['archived'] is bool ? project['archived'] : false;
      project['pinned'] = project['pinned'] is bool ? project['pinned'] : false;
      final String? stackId = project['stackId'] is String &&
              (project['stackId'] as String).trim().isNotEmpty
          ? (project['stackId'] as String).trim()
          : null;
      project['stackId'] = validStackIds == null ||
              stackId == null ||
              validStackIds.contains(stackId)
          ? stackId
          : null;
      final String? projectTypeId = project['projectTypeId'] is String &&
              (project['projectTypeId'] as String).trim().isNotEmpty
          ? (project['projectTypeId'] as String).trim()
          : null;
      project['projectTypeId'] = validProjectTypeIds == null
          ? projectTypeId
          : (projectTypeId != null &&
                  validProjectTypeIds.contains(projectTypeId)
              ? projectTypeId
              : fallbackProjectTypeId);
      final ProjectLayoutKind projectLayoutKind =
          projectLayoutsByTypeId?[project['projectTypeId']] ??
              ProjectTypeConfig.defaultLayoutKindForId(
                project['projectTypeId'] as String?,
              );
      final bool isEntryContainerProject =
          projectLayoutKind == ProjectLayoutKind.entryContainer;
      project['tasks'] = isEntryContainerProject
          ? <Map<String, dynamic>>[]
          : _upgradeTaskShape(project['tasks']);
      final Object? rawEntries = project.containsKey('entries')
          ? project['entries']
          : project['people'];
      project['entries'] = _upgradeProjectEntryShape(rawEntries);
      project.remove('people');
      projects.add(project);
    }
    return projects;
  }

  static List<Map<String, dynamic>> _upgradeProjectEntryShape(
    Object? rawEntries,
  ) {
    if (rawEntries is! List<dynamic>) {
      return <Map<String, dynamic>>[];
    }

    final List<Map<String, dynamic>> entries = <Map<String, dynamic>>[];
    for (final dynamic rawEntry in rawEntries) {
      if (rawEntry is! Map<dynamic, dynamic>) {
        continue;
      }
      final Map<String, dynamic> entry = Map<String, dynamic>.from(rawEntry);
      final String? name = (entry['name'] as String?)?.trim();
      if (name == null || name.isEmpty) {
        continue;
      }
      entry['name'] = name;
      final String? id = (entry['id'] as String?)?.trim();
      entry['id'] =
          id == null || id.isEmpty ? ModelIds.newProjectEntryId() : id;
      entry['body'] =
          entry['body'] is String ? (entry['body'] as String).trim() : '';
      entry['color'] = entry['color'] is int ? entry['color'] : null;
      entry['icon'] =
          entry['icon'] is String && (entry['icon'] as String).trim().isNotEmpty
              ? (entry['icon'] as String).trim()
              : null;
      entry['archived'] = entry['archived'] is bool ? entry['archived'] : false;
      entry['tasks'] = _upgradeTaskShape(entry['tasks']);
      entries.add(entry);
    }
    return entries;
  }

  static List<Map<String, dynamic>> _upgradeProjectStackShape(
    Object? rawProjectStacks,
  ) {
    if (rawProjectStacks is! List<dynamic>) {
      return <Map<String, dynamic>>[];
    }

    final List<Map<String, dynamic>> projectStacks = <Map<String, dynamic>>[];
    for (final dynamic rawProjectStack in rawProjectStacks) {
      if (rawProjectStack is! Map<dynamic, dynamic>) {
        continue;
      }
      final Map<String, dynamic> projectStack = Map<String, dynamic>.from(
        rawProjectStack,
      );
      final String? name = (projectStack['name'] as String?)?.trim();
      if (name == null || name.isEmpty) {
        continue;
      }
      projectStack['name'] = name;
      final String? id = (projectStack['id'] as String?)?.trim();
      projectStack['id'] =
          id == null || id.isEmpty ? ModelIds.newProjectStackId() : id;
      projectStack['color'] =
          projectStack['color'] is int ? projectStack['color'] : null;
      projectStacks.add(projectStack);
    }
    return projectStacks;
  }

  static List<Map<String, dynamic>> _upgradeProjectTypeShape(
    Object? rawProjectTypes,
  ) {
    final List<ProjectTypeConfig> defaultProjectTypes =
        ProjectTypeConfig.defaults();
    final Map<String, ProjectTypeConfig> defaultsById =
        <String, ProjectTypeConfig>{
      for (final ProjectTypeConfig type in defaultProjectTypes) type.id: type,
    };

    final Map<String, Map<String, dynamic>> normalizedById =
        <String, Map<String, dynamic>>{};
    if (rawProjectTypes is List<dynamic>) {
      for (final dynamic rawProjectType in rawProjectTypes) {
        if (rawProjectType is! Map<dynamic, dynamic>) {
          continue;
        }
        final Map<String, dynamic> projectType = Map<String, dynamic>.from(
          rawProjectType,
        );
        final String? id = (projectType['id'] as String?)?.trim();
        final String? name = (projectType['name'] as String?)?.trim();
        if (id == null || id.isEmpty || name == null || name.isEmpty) {
          continue;
        }
        projectType['id'] = id;
        projectType['name'] = name;
        projectType['icon'] = projectType['icon'] is String &&
                (projectType['icon'] as String).trim().isNotEmpty
            ? (projectType['icon'] as String).trim()
            : null;
        projectType['layoutKind'] = projectType['layoutKind'] is String &&
                (projectType['layoutKind'] as String).trim().isNotEmpty
            ? ProjectLayoutKind.fromJsonValue(projectType['layoutKind']).name
            : (defaultsById[id]?.layoutKind ??
                    ProjectTypeConfig.defaultLayoutKindForId(id))
                .name;
        projectType['showsJournalEntries'] =
            projectType['showsJournalEntries'] is bool
                ? projectType['showsJournalEntries']
                : defaultsById[id]?.showsJournalEntries ?? false;
        projectType['showsPlanningTasks'] =
            projectType['showsPlanningTasks'] is bool
                ? projectType['showsPlanningTasks']
                : defaultsById[id]?.showsPlanningTasks ?? false;
        projectType['showsIdeas'] = projectType['showsIdeas'] is bool
            ? projectType['showsIdeas']
            : defaultsById[id]?.showsIdeas ?? false;
        projectType['childItemLabel'] =
            projectType['childItemLabel'] is String &&
                    (projectType['childItemLabel'] as String).trim().isNotEmpty
                ? (projectType['childItemLabel'] as String).trim()
                : defaultsById[id]?.childItemLabel ?? 'Item';
        projectType['childItemsLabel'] =
            projectType['childItemsLabel'] is String &&
                    (projectType['childItemsLabel'] as String).trim().isNotEmpty
                ? (projectType['childItemsLabel'] as String).trim()
                : defaultsById[id]?.childItemsLabel ?? 'Items';
        projectType['childItemNameHint'] = projectType['childItemNameHint']
                    is String &&
                (projectType['childItemNameHint'] as String).trim().isNotEmpty
            ? (projectType['childItemNameHint'] as String).trim()
            : defaultsById[id]?.childItemNameHint ?? 'Name this entry';
        projectType['childItemBodyLabel'] = projectType['childItemBodyLabel']
                    is String &&
                (projectType['childItemBodyLabel'] as String).trim().isNotEmpty
            ? (projectType['childItemBodyLabel'] as String).trim()
            : defaultsById[id]?.childItemBodyLabel ?? 'Notes';
        projectType['childItemBodyHint'] = projectType['childItemBodyHint']
                    is String &&
                (projectType['childItemBodyHint'] as String).trim().isNotEmpty
            ? (projectType['childItemBodyHint'] as String).trim()
            : defaultsById[id]?.childItemBodyHint ??
                'Description or anything useful to remember';
        projectType['childJournalEntryLabel'] =
            projectType['childJournalEntryLabel'] is String &&
                    (projectType['childJournalEntryLabel'] as String)
                        .trim()
                        .isNotEmpty
                ? (projectType['childJournalEntryLabel'] as String).trim()
                : defaultsById[id]?.childJournalEntryLabel ?? 'Journal entry';
        projectType['childJournalEntriesLabel'] =
            projectType['childJournalEntriesLabel'] is String &&
                    (projectType['childJournalEntriesLabel'] as String)
                        .trim()
                        .isNotEmpty
                ? (projectType['childJournalEntriesLabel'] as String).trim()
                : defaultsById[id]?.childJournalEntriesLabel ??
                    'Journal entries';
        normalizedById[id] = projectType;
      }
    }

    final List<Map<String, dynamic>> normalized = <Map<String, dynamic>>[];
    for (final ProjectTypeConfig defaultType in defaultProjectTypes) {
      final Map<String, dynamic>? existing = normalizedById.remove(
        defaultType.id,
      );
      normalized.add(existing ?? defaultType.toJson());
    }
    normalized.addAll(normalizedById.values);
    return normalized;
  }

  static Map<String, ProjectLayoutKind> _projectTypeLayoutsById(
    List<Map<String, dynamic>> projectTypes,
  ) {
    return <String, ProjectLayoutKind>{
      for (final Map<String, dynamic> projectType in projectTypes)
        if (projectType['id'] is String)
          projectType['id'] as String: ProjectLayoutKind.fromJsonValue(
            projectType['layoutKind'],
          ),
    };
  }

  static List<Map<String, dynamic>> _upgradeSubtaskShape(Object? rawSubtasks) {
    if (rawSubtasks is! List<dynamic>) {
      return <Map<String, dynamic>>[];
    }

    final List<Map<String, dynamic>> subtasks = <Map<String, dynamic>>[];
    for (final dynamic rawSubtask in rawSubtasks) {
      if (rawSubtask is String) {
        final String title = rawSubtask.trim();
        if (title.isEmpty) {
          continue;
        }
        subtasks.add(<String, dynamic>{
          'id': ModelIds.newSubTaskId(),
          'title': title,
          'body': '',
          'color': null,
          'completed': false,
          'icon': null,
          'children': <Map<String, dynamic>>[],
        });
        continue;
      }
      if (rawSubtask is! Map<dynamic, dynamic>) {
        continue;
      }

      final Map<String, dynamic> subtask = Map<String, dynamic>.from(
        rawSubtask,
      );
      final String? title = (subtask['title'] as String?)?.trim();
      if (title == null || title.isEmpty) {
        continue;
      }
      subtask['title'] = title;
      final String? id = (subtask['id'] as String?)?.trim();
      subtask['id'] = id == null || id.isEmpty ? ModelIds.newSubTaskId() : id;
      subtask['body'] =
          subtask['body'] is String ? (subtask['body'] as String).trim() : '';
      subtask['color'] = subtask['color'] is int ? subtask['color'] : null;
      subtask['completed'] =
          subtask['completed'] is bool ? subtask['completed'] : false;
      subtask['icon'] = subtask['icon'] is String &&
              (subtask['icon'] as String).trim().isNotEmpty
          ? (subtask['icon'] as String).trim()
          : null;
      subtask['children'] = _upgradeSubtaskShape(
        subtask['children'] ?? subtask['subtasks'],
      );
      subtask.remove('subtasks');
      subtasks.add(subtask);
    }
    return subtasks;
  }

  static void _writeTaskSection({
    required StringBuffer buffer,
    required String title,
    required List<TaskItem> tasks,
  }) {
    buffer.writeln(title);
    if (tasks.isEmpty) {
      buffer.writeln('- None');
      buffer.writeln();
      return;
    }

    for (final TaskItem task in tasks) {
      buffer.writeln(_taskLine(task));
      _writeSubtasks(buffer, task.subtasks, 1);
    }
    buffer.writeln();
  }

  static void _writeProjectSection({
    required StringBuffer buffer,
    required String title,
    required List<ProjectItem> projects,
    required List<ProjectStack> projectStacks,
  }) {
    buffer.writeln(title);
    if (projects.isEmpty) {
      buffer.writeln('- None');
      return;
    }

    final Set<String> handledProjectIds = <String>{};
    for (final ProjectStack stack in projectStacks) {
      final List<ProjectItem> stackProjects = projects
          .where((ProjectItem project) => project.stackId == stack.id)
          .toList(growable: false);
      if (stackProjects.isEmpty) {
        continue;
      }
      buffer.writeln('- Stack: ${stack.name}');
      for (final ProjectItem project in stackProjects) {
        handledProjectIds.add(project.id);
        _writeProject(buffer, project, 1);
      }
    }

    final List<ProjectItem> unstackedProjects = projects
        .where((ProjectItem project) => !handledProjectIds.contains(project.id))
        .toList(growable: false);
    for (final ProjectItem project in unstackedProjects) {
      _writeProject(buffer, project, 0);
    }
  }

  static void _writeProject(
    StringBuffer buffer,
    ProjectItem project,
    int depth,
  ) {
    final String indent = '  ' * depth;
    buffer.writeln('$indent- ${project.name}');
    if (project.body.isNotEmpty) {
      buffer.writeln('$indent  ${project.body}');
    }

    final List<TaskItem> thinking = project.tasks
        .where((TaskItem task) => task.type == TaskItemType.thinking)
        .toList(growable: false);
    final List<TaskItem> planning = project.tasks
        .where((TaskItem task) => task.type == TaskItemType.planning)
        .toList(growable: false);

    if (thinking.isNotEmpty) {
      buffer.writeln('$indent  Ideas');
      for (final TaskItem task in thinking) {
        buffer.writeln('$indent  ${_taskLine(task)}');
        _writeSubtasks(buffer, task.subtasks, depth + 2);
      }
    }
    if (planning.isNotEmpty) {
      buffer.writeln('$indent  Action items');
      for (final TaskItem task in planning) {
        buffer.writeln('$indent  ${_taskLine(task)}');
        _writeSubtasks(buffer, task.subtasks, depth + 2);
      }
    }
  }

  static String _taskLine(TaskItem task) {
    final String iconPrefix = task.iconKey == null ? '' : '[${task.iconKey}] ';
    return '- $iconPrefix${task.title}';
  }

  static void _writeSubtasks(
    StringBuffer buffer,
    List<SubTaskItem> subtasks,
    int depth,
  ) {
    final String indent = '  ' * depth;
    for (final SubTaskItem subtask in subtasks) {
      final String iconPrefix =
          subtask.iconKey == null ? '' : '[${subtask.iconKey}] ';
      final String checkboxPrefix = subtask.isCompleted ? '[x] ' : '[ ] ';
      buffer.writeln('$indent- $checkboxPrefix$iconPrefix${subtask.title}');
      _writeSubtasks(buffer, subtask.children, depth + 1);
    }
  }
}
