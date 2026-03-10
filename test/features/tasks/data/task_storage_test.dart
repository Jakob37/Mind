import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sorted_out/src/features/tasks/data/task_storage.dart';
import 'package:sorted_out/src/features/tasks/domain/task_models.dart';

void main() {
  const TaskStorage storage = TaskStorage();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('load migrates v6 payload to v7 with default planning task types',
      () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'task_board_state': jsonEncode(<String, dynamic>{
        'version': 6,
        'data': <String, dynamic>{
          'incomingTasks': <Map<String, dynamic>>[
            <String, dynamic>{'id': 'incoming-1', 'title': 'Incoming task'},
          ],
          'favoriteTasks': <Map<String, dynamic>>[
            <String, dynamic>{'id': 'favorite-1', 'title': 'Favorite task'},
          ],
          'projects': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'project-1',
              'name': 'Project one',
              'tasks': <Map<String, dynamic>>[
                <String, dynamic>{'id': 'project-task-1', 'title': 'Do it'},
              ],
            },
          ],
          'colorLabels': <String, String>{
            '4294951112': 'Warm',
          },
        },
      }),
    });

    final TaskLoadResult result = await storage.load();

    expect(result.isSuccess, isTrue);
    final TaskBoardState state = result.state!;
    expect(state.incomingTasks.single.type, TaskItemType.planning);
    expect(state.favoriteTasks.single.type, TaskItemType.planning);
    expect(state.projects.single.tasks.single.type, TaskItemType.planning);
    expect(state.colorLabels[4294951112], 'Warm');
  });

  test('load preserves thinking aliases while migrating from v6', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'task_board_state': jsonEncode(<String, dynamic>{
        'version': 6,
        'data': <String, dynamic>{
          'incomingTasks': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'incoming-1',
              'title': 'Idea task',
              'type': 'IDEAS',
            },
          ],
          'favoriteTasks': <Map<String, dynamic>>[],
          'projects': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'project-1',
              'name': 'Project one',
              'tasks': <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 'project-task-1',
                  'title': 'Thinking task',
                  'type': 'thinking',
                },
              ],
            },
          ],
          'colorLabels': <String, String>{},
        },
      }),
    });

    final TaskLoadResult result = await storage.load();

    expect(result.isSuccess, isTrue);
    final TaskBoardState state = result.state!;
    expect(state.incomingTasks.single.type, TaskItemType.thinking);
    expect(state.projects.single.tasks.single.type, TaskItemType.thinking);
  });

  test('load fails for unsupported future schema versions', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'task_board_state': jsonEncode(<String, dynamic>{
        'version': 99,
        'data': <String, dynamic>{},
      }),
    });

    final TaskLoadResult result = await storage.load();

    expect(result.hadPersistedData, isTrue);
    expect(result.isFailure, isTrue);
    expect(result.error, isA<StateError>());
  });

  test('load falls back to legacy key when primary key is absent', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'task_board_state_v1': jsonEncode(<String, dynamic>{
        'incomingTasks': <String>['Legacy incoming'],
        'favoriteTasks': <String>['Legacy favorite'],
        'projects': <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'Legacy project',
            'tasks': <String>['Legacy project task'],
          },
        ],
      }),
    });

    final TaskLoadResult result = await storage.load();

    expect(result.isSuccess, isTrue);
    final TaskBoardState state = result.state!;
    expect(state.incomingTasks.first.title, 'Legacy incoming');
    expect(state.favoriteTasks.first.title, 'Legacy favorite');
    expect(state.projects.first.name, 'Legacy project');
    expect(state.projects.first.tasks.first.title, 'Legacy project task');
  });

  test('save writes versioned state and removes legacy key', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'task_board_state_v1': '{"incomingTasks":[]}',
    });

    final TaskBoardState state = TaskBoardState(
      incomingTasks: <TaskItem>[
        TaskItem(
          id: 'task-1',
          title: 'New task',
          type: TaskItemType.thinking,
        ),
      ],
      favoriteTasks: const <TaskItem>[],
      projects: const <ProjectItem>[],
      colorLabels: const <int, String>{
        4294951112: 'Warm',
      },
      hideCompletedProjectItems: false,
    );

    await storage.save(state);

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? persisted = prefs.getString('task_board_state');
    expect(persisted, isNotNull);

    final Map<String, dynamic> decoded =
        jsonDecode(persisted!) as Map<String, dynamic>;
    expect(decoded['version'], 9);

    final List<dynamic> incoming = (decoded['data']
        as Map<String, dynamic>)['incomingTasks'] as List<dynamic>;
    expect((incoming.first as Map<String, dynamic>)['type'], 'thinking');
    expect(prefs.getString('task_board_state_v1'), isNull);
  });

  test('export includes schema version and serializes task type/subtasks', () {
    final TaskBoardState state = TaskBoardState(
      incomingTasks: <TaskItem>[
        TaskItem(
          id: 'task-1',
          title: 'Planned',
          type: TaskItemType.planning,
          subtasks: <SubTaskItem>[
            SubTaskItem(
              id: 'subtask-1',
              title: 'Child card',
              body: 'Details',
            ),
          ],
        ),
      ],
      favoriteTasks: const <TaskItem>[],
      projects: const <ProjectItem>[],
      colorLabels: const <int, String>{},
      hideCompletedProjectItems: false,
    );

    final String exported = storage.export(state);
    final Map<String, dynamic> decoded =
        jsonDecode(exported) as Map<String, dynamic>;
    final Map<String, dynamic> data = decoded['data'] as Map<String, dynamic>;
    final List<dynamic> incoming = data['incomingTasks'] as List<dynamic>;
    final Map<String, dynamic> firstIncoming =
        incoming.first as Map<String, dynamic>;

    expect(exported.contains('\n  "version": 9,'), isTrue);
    expect(decoded['version'], 9);
    expect(firstIncoming['type'], 'planning');
    final List<dynamic> subtasks = firstIncoming['subtasks'] as List<dynamic>;
    expect(subtasks, hasLength(1));
    final Map<String, dynamic> firstSubtask =
        subtasks.first as Map<String, dynamic>;
    expect(firstSubtask['title'], 'Child card');
  });

  test('import restores exported board state', () {
    final TaskBoardState state = TaskBoardState(
      incomingTasks: <TaskItem>[
        TaskItem(
          id: 'task-1',
          title: 'Imported incoming',
          type: TaskItemType.thinking,
        ),
      ],
      favoriteTasks: const <TaskItem>[],
      projects: <ProjectItem>[
        ProjectItem(
          id: 'project-1',
          name: 'Imported project',
          tasks: <TaskItem>[
            TaskItem(
              id: 'task-2',
              title: 'Imported project task',
              type: TaskItemType.planning,
              subtasks: <SubTaskItem>[
                SubTaskItem(
                  id: 'subtask-1',
                  title: 'Imported child',
                ),
              ],
            ),
          ],
        ),
      ],
      colorLabels: const <int, String>{4294951112: 'Warm'},
      hideCompletedProjectItems: true,
    );

    final String exported = storage.export(state);
    final TaskBoardState imported = storage.import(exported);

    expect(imported.incomingTasks.single.title, 'Imported incoming');
    expect(imported.incomingTasks.single.type, TaskItemType.thinking);
    expect(imported.projects.single.name, 'Imported project');
    expect(
      imported.projects.single.tasks.single.subtasks.single.title,
      'Imported child',
    );
    expect(imported.colorLabels[4294951112], 'Warm');
    expect(imported.hideCompletedProjectItems, isTrue);
  });

  test('import rejects invalid payload shapes', () {
    expect(
      () => storage.import('["not-a-map"]'),
      throwsA(isA<FormatException>()),
    );
  });
}
