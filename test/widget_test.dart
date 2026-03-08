import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sorted_out/src/app.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('moves tasks to projects and creates projects',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MindApp());

    expect(find.text('Incoming'), findsOneWidget);
    expect(find.text('Projects'), findsOneWidget);
    expect(find.text('Sit for 10 minutes in silence'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);

    await tester
        .tap(find.widgetWithText(ListTile, 'Sit for 10 minutes in silence'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Task options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move to project'));
    await tester.pumpAndSettle();
    expect(find.text('Move task to project'), findsOneWidget);
    expect(find.text('Morning Routine'), findsOneWidget);
    await tester.tap(find.widgetWithText(ListTile, 'Morning Routine'));
    await tester.pumpAndSettle();
    expect(find.text('Sit for 10 minutes in silence'), findsNothing);

    await tester.tap(find.text('Projects'));
    await tester.pumpAndSettle();

    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.text('Morning Routine'), findsOneWidget);
    expect(find.text('1 task'), findsAtLeastNWidgets(1));

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Breathwork');
    await tester.tap(find.widgetWithText(FilledButton, 'Create Project'));
    await tester.pumpAndSettle();
    expect(find.text('Breathwork'), findsOneWidget);

    await tester.tap(find.text('Incoming'));
    await tester.pumpAndSettle();

    expect(find.byType(FloatingActionButton), findsOneWidget);

    await tester
        .tap(find.widgetWithText(ListTile, 'Do a 3-minute breathing check-in'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Task options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move to project'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Breathwork'));
    await tester.pumpAndSettle();

    expect(find.text('Do a 3-minute breathing check-in'), findsNothing);

    await tester.tap(find.text('Projects'));
    await tester.pumpAndSettle();

    expect(find.text('Breathwork'), findsOneWidget);
    expect(find.text('1 task'), findsAtLeastNWidgets(1));

    await tester.tap(find.widgetWithText(ListTile, 'Breathwork'));
    await tester.pumpAndSettle();

    expect(find.text('Breathwork'), findsOneWidget);
    expect(find.text('Do a 3-minute breathing check-in'), findsOneWidget);

    await tester
        .tap(find.widgetWithText(ListTile, 'Do a 3-minute breathing check-in'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Task options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move to project'));
    await tester.pumpAndSettle();
    expect(find.text('Move task to project'), findsOneWidget);
    await tester.tap(find.widgetWithText(ListTile, 'Morning Routine'));
    await tester.pumpAndSettle();
    expect(find.text('Do a 3-minute breathing check-in'), findsNothing);
    expect(find.text('No ideas in this project yet.'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ListTile, 'Morning Routine'));
    await tester.pumpAndSettle();
    expect(find.text('Do a 3-minute breathing check-in'), findsOneWidget);

    await tester.tap(
      find.widgetWithText(ListTile, 'Do a 3-minute breathing check-in'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Task options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove task'));
    await tester.pumpAndSettle();
    expect(find.text('Do a 3-minute breathing check-in'), findsNothing);
  });

  testWidgets('loads unversioned state from the previous storage key',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'task_board_state_v1': jsonEncode(<String, dynamic>{
        'incomingTasks': <Map<String, dynamic>>[
          <String, dynamic>{'title': 'Old key incoming'},
        ],
        'favoriteTasks': <Map<String, dynamic>>[
          <String, dynamic>{'title': 'Old key favorite'},
        ],
        'projects': <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'Old key project',
            'tasks': <Map<String, dynamic>>[
              <String, dynamic>{'title': 'Old key project task'},
            ],
          },
        ],
      }),
    });

    await tester.pumpWidget(const MindApp());
    await tester.pumpAndSettle();

    expect(find.text('Old key incoming'), findsOneWidget);
    expect(find.text('Old key favorite'), findsOneWidget);

    await tester.tap(find.text('Projects'));
    await tester.pumpAndSettle();
    expect(find.text('Old key project'), findsOneWidget);
  });

  testWidgets('migrates versioned v1 payload into current schema',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'task_board_state': jsonEncode(<String, dynamic>{
        'version': 1,
        'data': <String, dynamic>{
          'incomingTasks': <dynamic>[
            'String based task',
            <String, dynamic>{'title': 'Mapped incoming task'},
          ],
          'favoriteTasks': <dynamic>[
            <String, dynamic>{'title': 'Mapped favorite task'},
          ],
          'projects': <dynamic>[
            <String, dynamic>{
              'name': 'Migrated Project',
              'tasks': <dynamic>[
                'String project task',
              ],
            },
          ],
        },
      }),
    });

    await tester.pumpWidget(const MindApp());
    await tester.pumpAndSettle();

    expect(find.text('String based task'), findsOneWidget);
    expect(find.text('Mapped favorite task'), findsOneWidget);

    await tester.tap(find.text('Projects'));
    await tester.pumpAndSettle();
    expect(find.text('Migrated Project'), findsOneWidget);

    await tester.tap(find.widgetWithText(ListTile, 'Migrated Project'));
    await tester.pumpAndSettle();
    expect(find.text('String project task'), findsOneWidget);
  });

  testWidgets('opens settings and shows JSON export',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MindApp());

    await tester.tap(find.byTooltip('Open settings'));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Export data as JSON'), findsOneWidget);

    await tester.tap(find.widgetWithText(ListTile, 'Export data as JSON'));
    await tester.pumpAndSettle();

    expect(find.text('JSON Export'), findsOneWidget);
    expect(find.textContaining('"version"'), findsWidgets);
    expect(find.textContaining('8'), findsWidgets);
    expect(find.textContaining('"incomingTasks"'), findsOneWidget);
    expect(find.text('Export JSON File (Android)'), findsOneWidget);
  });

  testWidgets('uses custom color labels from settings in color picker',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MindApp());

    await tester.tap(find.byTooltip('Open settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Coral'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Urgent');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Shown as "Urgent"'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sit for 10 minutes in silence'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Task options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Set color'));
    await tester.pumpAndSettle();

    expect(find.text('Urgent'), findsOneWidget);
  });

  testWidgets('edits task and project through context menus',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MindApp());

    await tester.tap(find.text('Sit for 10 minutes in silence'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Task options'), findsOneWidget);
    await tester.tap(find.byTooltip('Task options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit task'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Edited task title');
    await tester.enterText(find.byType(TextField).last, 'Task body text');
    await tester.tap(find.widgetWithText(FilledButton, 'Save Task'));
    await tester.pumpAndSettle();

    expect(find.text('Edited task title'), findsOneWidget);
    expect(find.text('Task body text'), findsNothing);
    expect(find.byIcon(Icons.notes_outlined), findsOneWidget);

    await tester.tap(find.text('Projects'));
    await tester.pumpAndSettle();
    final Finder morningRoutineCard = find
        .ancestor(
          of: find.text('Morning Routine'),
          matching: find.byType(Card),
        )
        .first;
    await tester.tap(
      find.descendant(
        of: morningRoutineCard,
        matching: find.byTooltip('Project options'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Project options'), findsOneWidget);
    await tester.tap(find.text('Edit project'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Morning Focus');
    await tester.enterText(find.byType(TextField).last, 'Project body text');
    await tester.tap(find.widgetWithText(FilledButton, 'Save Project'));
    await tester.pumpAndSettle();

    expect(find.text('Morning Focus'), findsOneWidget);
    expect(find.textContaining('Project body text'), findsOneWidget);
  });

  testWidgets('long press enables drag mode for incoming cards',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MindApp());

    final Finder firstTaskText = find.text('Sit for 10 minutes in silence');

    await tester.longPress(firstTaskText);
    await tester.pumpAndSettle();

    expect(find.byTooltip('Done reordering'), findsOneWidget);
    expect(find.byIcon(Icons.drag_indicator_outlined), findsWidgets);
    await tester.tap(find.byTooltip('Done reordering'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Done reordering'), findsNothing);
  });

  testWidgets('swipe left removes task and project after confirmation',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MindApp());

    await tester.drag(
      find.widgetWithText(ListTile, 'Sit for 10 minutes in silence'),
      const Offset(-600, 0),
    );
    await tester.pumpAndSettle();
    expect(find.text('Remove task?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await tester.pumpAndSettle();
    expect(find.text('Sit for 10 minutes in silence'), findsNothing);

    await tester.tap(find.text('Projects'));
    await tester.pumpAndSettle();

    await tester.drag(
      find.widgetWithText(ListTile, 'Morning Routine'),
      const Offset(-600, 0),
    );
    await tester.pumpAndSettle();
    expect(find.text('Remove project?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await tester.pumpAndSettle();
    expect(find.text('Morning Routine'), findsNothing);
  });

  testWidgets('swipe right quickly moves incoming task to project',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MindApp());

    await tester.drag(
      find.widgetWithText(ListTile, 'Sit for 10 minutes in silence'),
      const Offset(600, 0),
    );
    await tester.pumpAndSettle();
    expect(find.text('Move task to project'), findsOneWidget);
    await tester.tap(find.widgetWithText(ListTile, 'Morning Routine'));
    await tester.pumpAndSettle();
    expect(find.text('Sit for 10 minutes in silence'), findsNothing);

    await tester.tap(find.text('Projects'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Morning Routine'));
    await tester.pumpAndSettle();
    expect(find.text('Sit for 10 minutes in silence'), findsOneWidget);
  });

  testWidgets('deletes projects and sets colors from context menu',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MindApp());

    await tester.tap(find.text('Projects'));
    await tester.pumpAndSettle();

    final Finder morningRoutineCard = find
        .ancestor(
          of: find.text('Morning Routine'),
          matching: find.byType(Card),
        )
        .first;
    await tester.tap(
      find.descendant(
        of: morningRoutineCard,
        matching: find.byTooltip('Project options'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove project'));
    await tester.pumpAndSettle();
    expect(find.text('Morning Routine'), findsNothing);

    final Finder stressResetCard = find
        .ancestor(
          of: find.text('Stress Reset'),
          matching: find.byType(Card),
        )
        .first;
    await tester.tap(
      find.descendant(
        of: stressResetCard,
        matching: find.byTooltip('Project options'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Set color'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Coral'));
    await tester.pumpAndSettle();

    final Card projectCard = tester.widget<Card>(
      find
          .ancestor(
            of: find.text('Stress Reset'),
            matching: find.byType(Card),
          )
          .first,
    );
    expect(projectCard.color, const Color(0xFFFFCDD2));

    await tester.tap(find.text('Incoming'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sit for 10 minutes in silence'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Task options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Set color'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Coral').last);
    await tester.pumpAndSettle();

    final Card taskCard = tester.widget<Card>(
      find
          .ancestor(
            of: find.text('Sit for 10 minutes in silence'),
            matching: find.byType(Card),
          )
          .first,
    );
    expect(taskCard.color, const Color(0xFFFFCDD2));
  });

  testWidgets('migrates versioned v2 payload and adds stable IDs',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'task_board_state': jsonEncode(<String, dynamic>{
        'version': 2,
        'data': <String, dynamic>{
          'incomingTasks': <Map<String, dynamic>>[
            <String, dynamic>{'title': 'Legacy v2 incoming'},
          ],
          'favoriteTasks': <Map<String, dynamic>>[
            <String, dynamic>{'title': 'Legacy v2 favorite'},
          ],
          'projects': <Map<String, dynamic>>[
            <String, dynamic>{
              'name': 'Legacy v2 project',
              'tasks': <Map<String, dynamic>>[
                <String, dynamic>{'title': 'Legacy v2 project task'},
              ],
            },
          ],
        },
      }),
    });

    await tester.pumpWidget(const MindApp());
    await tester.pumpAndSettle();

    expect(find.text('Legacy v2 incoming'), findsOneWidget);

    await tester.tap(find.byTooltip('Open settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Export data as JSON'));
    await tester.pumpAndSettle();

    expect(find.textContaining('"version"'), findsWidgets);
    expect(find.textContaining('8'), findsWidgets);
    expect(find.textContaining('"id"'), findsWidgets);
  });

  testWidgets('migrates versioned v3 payload and adds body/color fields',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'task_board_state': jsonEncode(<String, dynamic>{
        'version': 3,
        'data': <String, dynamic>{
          'incomingTasks': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'task-v3-incoming',
              'title': 'Legacy v3 incoming',
            },
          ],
          'favoriteTasks': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'task-v3-favorite',
              'title': 'Legacy v3 favorite',
            },
          ],
          'projects': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'project-v3',
              'name': 'Legacy v3 project',
              'tasks': <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 'task-v3-project',
                  'title': 'Legacy v3 project task',
                },
              ],
            },
          ],
        },
      }),
    });

    await tester.pumpWidget(const MindApp());
    await tester.pumpAndSettle();
    expect(find.text('Legacy v3 incoming'), findsOneWidget);

    await tester.tap(find.byTooltip('Open settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Export data as JSON'));
    await tester.pumpAndSettle();

    expect(find.textContaining('"version"'), findsWidgets);
    expect(find.textContaining('8'), findsWidgets);
    expect(find.textContaining('"body": ""'), findsWidgets);
    expect(find.textContaining('"color": null'), findsWidgets);
  });

  testWidgets('separates project tasks into thinking and planning',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'task_board_state': jsonEncode(<String, dynamic>{
        'version': 6,
        'data': <String, dynamic>{
          'incomingTasks': <Map<String, dynamic>>[],
          'favoriteTasks': <Map<String, dynamic>>[],
          'projects': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'project-v6',
              'name': 'Dual Mode Project',
              'tasks': <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 'task-v6-legacy',
                  'title': 'Legacy task',
                  'body': '',
                  'color': null,
                },
              ],
            },
          ],
          'colorLabels': <String, String>{},
        },
      }),
    });

    await tester.pumpWidget(const MindApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Projects'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Dual Mode Project'));
    await tester.pumpAndSettle();

    expect(find.text('Thinking (ideas)'), findsOneWidget);
    expect(find.text('Planning (action items)'), findsOneWidget);
    expect(find.text('Legacy task'), findsOneWidget);

    await tester.tap(find.text('Legacy task'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Task options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move to thinking'));
    await tester.pumpAndSettle();

    expect(find.text('No action items in this project yet.'), findsOneWidget);

    await tester.tap(find.text('Legacy task'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Task options'));
    await tester.pumpAndSettle();
    expect(find.text('Move to planning'), findsOneWidget);
  });

  testWidgets(
      'adds project tasks by type and drags between thinking and planning',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MindApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Projects'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Morning Routine'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Add project task'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Thinking (ideas)'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Drag idea');
    await tester.tap(find.widgetWithText(FilledButton, 'Save Task'));
    await tester.pumpAndSettle();
    expect(find.text('Drag idea'), findsOneWidget);

    await tester.longPress(find.text('Drag idea'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Done reordering'), findsOneWidget);

    final Offset dragStart = tester.getCenter(find.text('Drag idea'));
    final Offset planningHeader = tester.getCenter(
      find.text('Planning (action items)'),
    );
    final TestGesture drag = await tester.startGesture(dragStart);
    await tester.pump(const Duration(milliseconds: 700));
    await drag.moveTo(planningHeader.translate(0, 42));
    await tester.pump();
    await drag.up();
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Done reordering'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Drag idea'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Task options'));
    await tester.pumpAndSettle();
    expect(find.text('Move to thinking'), findsOneWidget);
    await tester.tapAt(const Offset(12, 12));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Add project task'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Planning (action items)'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'New action');
    await tester.tap(find.widgetWithText(FilledButton, 'Save Task'));
    await tester.pumpAndSettle();
    expect(find.text('New action'), findsOneWidget);
  });

  testWidgets(
      'pauses autosave when persisted state is corrupted to avoid overwrite',
      (WidgetTester tester) async {
    const String corruptedState = '{"version":5,"data":';

    SharedPreferences.setMockInitialValues(<String, Object>{
      'task_board_state': corruptedState,
    });

    await tester.pumpWidget(const MindApp());
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Saved data could not be loaded'),
      findsOneWidget,
    );

    await tester.tap(find.text('Projects'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Unsaved project');
    await tester.tap(find.widgetWithText(FilledButton, 'Create Project'));
    await tester.pumpAndSettle();

    expect(find.text('Unsaved project'), findsOneWidget);

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('task_board_state'), corruptedState);
  });
}
