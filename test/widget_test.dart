import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sorted_out/src/app.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('moves tasks to favorites or projects and creates projects',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MindApp());

    expect(find.text('Incoming'), findsOneWidget);
    expect(find.text('Favorites'), findsOneWidget);
    expect(find.text('Projects'), findsOneWidget);
    expect(find.text('Sit for 10 minutes in silence'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);

    await tester.tap(find.byIcon(Icons.drive_file_move_outlined).first);
    await tester.pumpAndSettle();
    expect(find.text('Move task to'), findsOneWidget);
    expect(find.text('Favorites'), findsAtLeastNWidgets(1));
    expect(find.text('Morning Routine'), findsOneWidget);

    await tester.tap(find.widgetWithText(ListTile, 'Favorites'));
    await tester.pumpAndSettle();

    expect(find.text('Sit for 10 minutes in silence'), findsNothing);

    await tester.tap(find.text('Favorites'));
    await tester.pumpAndSettle();

    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.text('Sit for 10 minutes in silence'), findsOneWidget);

    await tester.tap(find.text('Projects'));
    await tester.pumpAndSettle();

    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.text('Morning Routine'), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Breathwork');
    await tester.tap(find.widgetWithText(FilledButton, 'Create Project'));
    await tester.pumpAndSettle();
    expect(find.text('Breathwork'), findsOneWidget);

    await tester.tap(find.text('Incoming'));
    await tester.pumpAndSettle();

    expect(find.byType(FloatingActionButton), findsOneWidget);

    await tester.tap(find.byIcon(Icons.drive_file_move_outlined).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Breathwork'));
    await tester.pumpAndSettle();

    expect(find.text('Do a 3-minute breathing check-in'), findsNothing);

    await tester.tap(find.text('Projects'));
    await tester.pumpAndSettle();

    expect(find.text('Breathwork'), findsOneWidget);
    expect(find.text('1 task'), findsOneWidget);

    await tester.tap(find.widgetWithText(ListTile, 'Breathwork'));
    await tester.pumpAndSettle();

    expect(find.text('Breathwork'), findsOneWidget);
    expect(find.text('Do a 3-minute breathing check-in'), findsOneWidget);

    await tester.tap(find.byTooltip('Move to another project'));
    await tester.pumpAndSettle();
    expect(find.text('Move task to project'), findsOneWidget);
    await tester.tap(find.widgetWithText(ListTile, 'Morning Routine'));
    await tester.pumpAndSettle();
    expect(find.text('Do a 3-minute breathing check-in'), findsNothing);
    expect(find.text('No tasks in this project yet.'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ListTile, 'Morning Routine'));
    await tester.pumpAndSettle();
    expect(find.text('Do a 3-minute breathing check-in'), findsOneWidget);

    await tester.drag(
      find.widgetWithText(ListTile, 'Do a 3-minute breathing check-in'),
      const Offset(-600, 0),
    );
    await tester.pumpAndSettle();
    expect(find.text('Do a 3-minute breathing check-in'), findsNothing);
    expect(find.text('No tasks in this project yet.'), findsOneWidget);
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

    await tester.tap(find.text('Favorites'));
    await tester.pumpAndSettle();
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

    await tester.tap(find.text('Favorites'));
    await tester.pumpAndSettle();
    expect(find.text('Mapped favorite task'), findsOneWidget);

    await tester.tap(find.text('Projects'));
    await tester.pumpAndSettle();
    expect(find.text('Migrated Project'), findsOneWidget);

    await tester.tap(find.widgetWithText(ListTile, 'Migrated Project'));
    await tester.pumpAndSettle();
    expect(find.text('String project task'), findsOneWidget);
  });
}
