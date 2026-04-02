import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sorted_out/src/app.dart';
import 'package:sorted_out/src/features/tasks/domain/task_models.dart';
import 'package:sorted_out/src/features/tasks/presentation/widgets/add_task_sheet.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('moves tasks to projects and creates projects', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MindApp());
    await tester.pumpAndSettle();

    expect(find.byTooltip('Open settings'), findsOneWidget);
    expect(find.text('Incoming'), findsOneWidget);
    expect(find.text('Projects'), findsOneWidget);
    expect(find.text('Sit for 10 minutes in silence'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);

    await tester.tap(
      find.widgetWithText(ListTile, 'Sit for 10 minutes in silence'),
    );
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

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Breathwork');
    await tester.tap(find.text('Type: Project'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Project'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Create Project'));
    await tester.pumpAndSettle();
    expect(find.text('Breathwork'), findsOneWidget);

    await tester.tap(find.text('Incoming'));
    await tester.pumpAndSettle();

    expect(find.byType(FloatingActionButton), findsOneWidget);

    await tester.tap(
      find.widgetWithText(ListTile, 'Do a 3-minute breathing check-in'),
    );
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

    await tester.tap(find.widgetWithText(ListTile, 'Breathwork'));
    await tester.pumpAndSettle();

    expect(find.text('Breathwork'), findsOneWidget);
    expect(find.text('Do a 3-minute breathing check-in'), findsOneWidget);

    await tester.tap(
      find.widgetWithText(ListTile, 'Do a 3-minute breathing check-in'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Task options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move to project'));
    await tester.pumpAndSettle();
    expect(find.text('Move task to project'), findsOneWidget);
    await tester.tap(find.widgetWithText(ListTile, 'Morning Routine'));
    await tester.pumpAndSettle();
    expect(find.text('Do a 3-minute breathing check-in'), findsNothing);
    expect(find.text('Ideas'), findsOneWidget);

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
    expect(find.text('Revert?'), findsOneWidget);
  });

  testWidgets(
    'add task sheet supports direct project capture with body and prompt',
    (WidgetTester tester) async {
      await tester.pumpWidget(const MindApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      final SegmentedButton<bool> insertionControl = tester
          .widget<SegmentedButton<bool>>(find.byType(SegmentedButton<bool>));
      expect(insertionControl.selected, <bool>{false});

      await tester.enterText(
        find.byType(TextField).first,
        'Plan weekend reset',
      );
      await tester.tap(find.text('Project: Incoming'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Morning Routine'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Icon: No icon'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Brain'));
      await tester.pumpAndSettle();
      expect(find.text('Icon: Brain'), findsOneWidget);

      await tester.tap(find.text('Show body'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField).at(1),
        'Block the afternoon and prep tea ahead of time.',
      );

      await tester.tap(find.text('Show prompt'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField).at(2),
        'Turn this into a simple two-step routine.',
      );

      await tester.ensureVisible(
        find.widgetWithText(FilledButton, 'Save to Project'),
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Save to Project'));
      await tester.pumpAndSettle();

      expect(find.text('Plan weekend reset'), findsNothing);

      await tester.tap(find.text('Projects'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Morning Routine'));
      await tester.pumpAndSettle();

      expect(find.text('Plan weekend reset'), findsOneWidget);

      await tester.tap(find.widgetWithText(ListTile, 'Plan weekend reset'));
      await tester.pumpAndSettle();

      expect(
        find.text('Block the afternoon and prep tea ahead of time.'),
        findsOneWidget,
      );
      expect(
        find.text('Turn this into a simple two-step routine.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('project picker supports free-text substring filtering', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AddTaskSheet(
            projects: <ProjectItem>[
              ProjectItem(name: 'Summer project'),
              ProjectItem(name: 'Big project'),
              ProjectItem(name: 'Reading list'),
            ],
            projectTypes: ProjectTypeConfig.defaults(),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Project: Incoming'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, 'jec');
    await tester.pumpAndSettle();

    expect(find.text('Summer project'), findsOneWidget);
    expect(find.text('Big project'), findsOneWidget);
    expect(find.text('Reading list'), findsNothing);
    expect(find.text('Morning Routine'), findsNothing);
  });

  testWidgets('new default projects can receive incoming tasks', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MindApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Projects'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Default Project');
    expect(find.text('Type: Project'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Create Project'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Incoming'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(ListTile, 'Do a 3-minute breathing check-in'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Task options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move to project'));
    await tester.pumpAndSettle();

    expect(find.text('Default Project'), findsOneWidget);
  });

  testWidgets('flashcards tab shows active idea flashcards', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'task_board_state': jsonEncode(<String, dynamic>{
        'version': 24,
        'data': <String, dynamic>{
          'incomingTasks': <Map<String, dynamic>>[],
          'projects': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'project-1',
              'name': 'Morning Routine',
              'projectTypeId': ProjectTypeDefaults.projectId,
              'tasks': <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 'task-1',
                  'title': 'Name the breathing pattern',
                  'body': 'Box breathing uses equal counts.',
                  'flashcardPrompt': 'What is box breathing?',
                  'type': 'thinking',
                  'entryType': 'note',
                  'archived': false,
                  'pinned': false,
                  'subtasks': <Map<String, dynamic>>[],
                },
              ],
              'people': <Map<String, dynamic>>[],
            },
          ],
          'projectStacks': <Map<String, dynamic>>[],
          'projectTypes': ProjectTypeConfig.defaults()
              .map((ProjectTypeConfig type) => type.toJson())
              .toList(),
          'colorLabels': <String, String>{},
          'hideCompletedProjectItems': false,
          'cardLayoutPreset': 'standard',
        },
      }),
    });

    await tester.pumpWidget(const MindApp());
    await tester.pumpAndSettle();

    expect(find.widgetWithText(Tab, 'Flashcards'), findsOneWidget);

    await tester.tap(find.widgetWithText(Tab, 'Flashcards'));
    await tester.pumpAndSettle();

    expect(find.text('What is box breathing?'), findsOneWidget);
    expect(find.text('Reveal answer'), findsOneWidget);
    expect(find.text('1 cards due'), findsOneWidget);

    await tester.tap(find.text('Reveal answer'));
    await tester.pumpAndSettle();

    expect(find.text('Name the breathing pattern'), findsOneWidget);
    expect(find.text('Box breathing uses equal counts.'), findsOneWidget);
    expect(find.text('Source: Morning Routine'), findsOneWidget);
    expect(find.text('Failed'), findsOneWidget);
    expect(find.text('Hard'), findsOneWidget);
    expect(find.text('Correct'), findsOneWidget);

    await tester.tap(find.text('Correct'));
    await tester.pumpAndSettle();

    expect(find.text('Reveal answer'), findsOneWidget);
    expect(find.text('No cards due right now'), findsOneWidget);
  });

  testWidgets('loads unversioned state from the previous storage key', (
    WidgetTester tester,
  ) async {
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
    await tester.pumpAndSettle();

    expect(find.text('Old key incoming'), findsOneWidget);
    expect(find.text('Old key favorite'), findsOneWidget);

    await tester.tap(find.text('Projects'));
    await tester.pumpAndSettle();
    expect(find.text('Old key project'), findsOneWidget);
  });

  testWidgets('migrates versioned v1 payload into current schema', (
    WidgetTester tester,
  ) async {
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
              'tasks': <dynamic>['String project task'],
            },
          ],
        },
      }),
    });

    await tester.pumpWidget(const MindApp());
    await tester.pumpAndSettle();
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

  testWidgets('opens settings and shows JSON export', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MindApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Open settings'));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Export data as JSON'), findsOneWidget);

    await tester.tap(find.widgetWithText(ListTile, 'Export data as JSON'));
    await tester.pumpAndSettle();

    expect(find.text('JSON Export'), findsOneWidget);
    expect(find.textContaining('"version"'), findsWidgets);
    expect(find.textContaining('"incomingTasks"'), findsOneWidget);
    expect(find.text('Save JSON File'), findsNothing);
    expect(find.text('Save JSON File (Android)'), findsOneWidget);
  });

  testWidgets('pinning shows a pinned section on Projects', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MindApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Projects'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Project options').first);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Pin project'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Pin project'));
    await tester.pumpAndSettle();

    expect(find.text('Pinned projects'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Morning Routine'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Stress Reset'), findsOneWidget);
  });

  testWidgets(
      'stacked projects expose project options and appear in pinned section', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MindApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Projects'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Studio');
    await tester.tap(find.text('Stack: No stack'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create stack'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Focus Stack');
    await tester.tap(find.widgetWithText(FilledButton, 'Save Stack'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Create Project'));
    await tester.pumpAndSettle();

    if (find.text('Studio').evaluate().isEmpty) {
      await tester.tap(find.text('Focus Stack'));
      await tester.pumpAndSettle();
    }

    expect(find.text('Studio'), findsOneWidget);

    final Offset studioCenter = tester.getCenter(find.text('Studio'));
    final Finder projectOptions = find.byTooltip('Project options');
    int studioOptionsIndex = 0;
    double bestVerticalDistance = double.infinity;
    final int optionCount = projectOptions.evaluate().length;
    for (int index = 0; index < optionCount; index += 1) {
      final Offset optionCenter = tester.getCenter(projectOptions.at(index));
      final double verticalDistance = (optionCenter.dy - studioCenter.dy).abs();
      if (verticalDistance < bestVerticalDistance) {
        bestVerticalDistance = verticalDistance;
        studioOptionsIndex = index;
      }
    }
    await tester.tap(projectOptions.at(studioOptionsIndex));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Pin project'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Pin project'));
    await tester.pumpAndSettle();

    expect(find.text('Pinned projects'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Studio'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Morning Routine'), findsOneWidget);
  });

  testWidgets('creates stacks and groups projects by dragging', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MindApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Projects'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Studio');
    await tester.tap(find.text('Stack: No stack'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create stack'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Focus Stack');
    await tester.tap(find.widgetWithText(FilledButton, 'Save Stack'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Create Project'));
    await tester.pumpAndSettle();

    expect(find.text('Focus Stack'), findsOneWidget);
    expect(find.text('Studio'), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Research');
    await tester.tap(find.widgetWithText(FilledButton, 'Create Project'));
    await tester.pumpAndSettle();

    expect(find.text('Unstacked'), findsNothing);
    expect(find.text('Research'), findsOneWidget);

    final Finder researchTile = find.widgetWithText(ListTile, 'Research');
    final Finder studioTile = find.widgetWithText(ListTile, 'Studio');
    final TestGesture gesture = await tester.startGesture(
      tester.getCenter(researchTile),
    );
    await tester.pump(kLongPressTimeout);
    await gesture.moveTo(tester.getCenter(studioTile));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.text('Create or Select Stack'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Group Projects'));
    await tester.pumpAndSettle();

    expect(find.text('Focus Stack'), findsOneWidget);
    expect(find.text('Studio'), findsOneWidget);
    expect(find.text('Research'), findsOneWidget);

    await tester.tap(find.text('Focus Stack'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, 'Studio'), findsNothing);
    expect(find.widgetWithText(ListTile, 'Research'), findsNothing);
    expect(find.widgetWithText(ListTile, 'Focus Stack'), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Archive');
    await tester.tap(find.widgetWithText(FilledButton, 'Create Project'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, 'Archive'), findsOneWidget);

    final Finder collapsedStackTile = find.widgetWithText(
      ListTile,
      'Focus Stack',
    );
    final Finder archiveTile = find.widgetWithText(ListTile, 'Archive');
    final TestGesture stackGesture = await tester.startGesture(
      tester.getCenter(collapsedStackTile),
    );
    await tester.pump(kLongPressTimeout);
    await stackGesture.moveTo(tester.getCenter(archiveTile));
    await tester.pump();
    await stackGesture.up();
    await tester.pumpAndSettle();

    expect(find.text('Create or Select Stack'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Group Projects'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Focus Stack'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, 'Studio'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Research'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Archive'), findsOneWidget);
  });

  testWidgets(
    'projects can be reordered inside an expanded stack by dragging',
    (WidgetTester tester) async {
      await tester.pumpWidget(const MindApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Projects'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Studio');
      await tester.tap(find.text('Stack: No stack'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create stack'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Focus Stack');
      await tester.tap(find.widgetWithText(FilledButton, 'Save Stack'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Create Project'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Research');
      await tester.tap(find.widgetWithText(FilledButton, 'Create Project'));
      await tester.pumpAndSettle();

      final Finder researchTile = find.widgetWithText(ListTile, 'Research');
      final Finder studioTile = find.widgetWithText(ListTile, 'Studio');
      final TestGesture groupingGesture = await tester.startGesture(
        tester.getCenter(researchTile),
      );
      await tester.pump(kLongPressTimeout);
      await groupingGesture.moveTo(tester.getCenter(studioTile));
      await tester.pump();
      await groupingGesture.up();
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Group Projects'));
      await tester.pumpAndSettle();

      final Finder reorderedResearchTile = find.widgetWithText(
        ListTile,
        'Research',
      );
      final Finder reorderedStudioTile = find.widgetWithText(
        ListTile,
        'Studio',
      );
      final bool researchStartsAboveStudio =
          tester.getTopLeft(reorderedResearchTile).dy <
              tester.getTopLeft(reorderedStudioTile).dy;
      final Offset targetOffset = researchStartsAboveStudio
          ? Offset(
              tester.getCenter(reorderedStudioTile).dx,
              tester.getBottomLeft(reorderedStudioTile).dy + 6,
            )
          : Offset(
              tester.getCenter(reorderedStudioTile).dx,
              tester.getTopLeft(reorderedStudioTile).dy - 6,
            );
      final TestGesture reorderGesture = await tester.startGesture(
        tester.getCenter(reorderedResearchTile),
      );
      await tester.pump(kLongPressTimeout);
      await reorderGesture.moveTo(targetOffset);
      await tester.pump();
      await reorderGesture.up();
      await tester.pumpAndSettle();

      final double researchY =
          tester.getTopLeft(find.widgetWithText(ListTile, 'Research')).dy;
      final double studioY =
          tester.getTopLeft(find.widgetWithText(ListTile, 'Studio')).dy;
      if (researchStartsAboveStudio) {
        expect(researchY, greaterThan(studioY));
      } else {
        expect(researchY, lessThan(studioY));
      }
    },
  );

  testWidgets('uses custom color labels from settings in color picker', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MindApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Open settings'));
    await tester.pumpAndSettle();
    final Finder coralTile = find.widgetWithText(ListTile, 'Coral');
    await tester.scrollUntilVisible(
      coralTile,
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(coralTile);
    await tester.pumpAndSettle();
    await tester.tap(coralTile);
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

  testWidgets('edits task and project through context menus', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MindApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sit for 10 minutes in silence'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Task options'), findsOneWidget);
    await tester.tap(find.byTooltip('Task options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit task'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Edited task title');
    await tester.enterText(find.byType(TextField).at(1), 'Task body text');
    await tester.tap(find.widgetWithText(FilledButton, 'Save Task'));
    await tester.pumpAndSettle();

    expect(find.text('Edited task title'), findsOneWidget);
    expect(find.text('Task body text'), findsNothing);
    expect(find.byIcon(Icons.notes_outlined), findsOneWidget);

    await tester.tap(find.text('Projects'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Morning Routine'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Project settings'));
    await tester.pumpAndSettle();
    expect(find.text('Project settings'), findsOneWidget);
    await tester.tap(find.text('Edit project'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Morning Focus');
    await tester.enterText(find.byType(TextField).last, 'Project body text');
    await tester.tap(find.widgetWithText(FilledButton, 'Save Project'));
    await tester.pumpAndSettle();

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Morning Focus'), findsOneWidget);
    expect(find.textContaining('Project body text'), findsOneWidget);
  });

  testWidgets('shows subtask count and supports subtask swipe/reorder', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MindApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sit for 10 minutes in silence'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Add checklist item'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'First subtask');
    await tester.tap(find.widgetWithText(FilledButton, 'Save Item'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Add checklist item'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Second subtask');
    await tester.tap(find.widgetWithText(FilledButton, 'Save Item'));
    await tester.pumpAndSettle();

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.byTooltip('2 subtasks'), findsOneWidget);

    await tester.tap(find.text('Sit for 10 minutes in silence'));
    await tester.pumpAndSettle();

    final double initialFirstY =
        tester.getTopLeft(find.text('First subtask')).dy;
    final double initialSecondY =
        tester.getTopLeft(find.text('Second subtask')).dy;
    final bool isFirstOnTop = initialFirstY < initialSecondY;

    final String topSubtask = isFirstOnTop ? 'First subtask' : 'Second subtask';
    final String bottomSubtask =
        isFirstOnTop ? 'Second subtask' : 'First subtask';

    final Offset topSubtaskCenter = tester.getCenter(find.text(topSubtask));
    final Offset bottomSubtaskCenter = tester.getCenter(
      find.text(bottomSubtask),
    );
    final TestGesture reorderGesture = await tester.startGesture(
      topSubtaskCenter,
    );
    await tester.pump(kLongPressTimeout);
    await reorderGesture.moveTo(bottomSubtaskCenter.translate(0, 28));
    await tester.pump();
    await reorderGesture.up();
    await tester.pumpAndSettle();

    expect(find.text(topSubtask), findsOneWidget);
    expect(find.text(bottomSubtask), findsOneWidget);

    await tester.drag(
      find.ancestor(
        of: find.text('Second subtask'),
        matching: find.byType(Dismissible),
      ),
      const Offset(-600, 0),
    );
    await tester.pumpAndSettle();
    expect(find.text('Second subtask'), findsNothing);
  });

  testWidgets('opens subtask menu to edit and set color', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MindApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sit for 10 minutes in silence'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Add checklist item'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Menu subtask');
    await tester.tap(find.widgetWithText(FilledButton, 'Save Item'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Menu subtask'));
    await tester.pumpAndSettle();
    expect(find.text('Nested item options'), findsOneWidget);
    await tester.tap(find.text('Edit item'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Edited subtask');
    await tester.enterText(find.byType(TextField).last, 'Subtask body text');
    await tester.tap(find.widgetWithText(FilledButton, 'Save Task'));
    await tester.pumpAndSettle();

    expect(find.text('Edited subtask'), findsOneWidget);
    expect(find.text('Subtask body text'), findsOneWidget);
    expect(find.byIcon(Icons.notes_outlined), findsWidgets);

    await tester.tap(find.text('Edited subtask'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Set color'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Coral').first);
    await tester.pumpAndSettle();

    final Card subTaskCard = tester.widget<Card>(
      find
          .ancestor(
            of: find.text('Edited subtask'),
            matching: find.byType(Card),
          )
          .first,
    );
    expect(subTaskCard.color, const Color(0xFFFFCDD2));
  });

  testWidgets('incoming cards expose direct controls without drag mode', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MindApp());
    await tester.pumpAndSettle();

    expect(find.byTooltip('Enter drag mode'), findsNothing);
    expect(find.byTooltip('Done reordering'), findsNothing);
    expect(find.byTooltip('Task options'), findsWidgets);

    await tester.tap(find.byTooltip('Task options').first);
    await tester.pumpAndSettle();

    expect(find.text('Task options'), findsOneWidget);
    expect(find.text('Edit task'), findsOneWidget);
  });

  testWidgets('task menu can copy task text to the clipboard', (
    WidgetTester tester,
  ) async {
    String? copiedText;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (
      MethodCall methodCall,
    ) async {
      if (methodCall.method == 'Clipboard.setData') {
        copiedText = (methodCall.arguments as Map<Object?, Object?>?)?['text']
            as String?;
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    await tester.pumpWidget(const MindApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Task options').first);
    await tester.pumpAndSettle();

    expect(find.byTooltip('Copy task text'), findsOneWidget);

    await tester.tap(find.byTooltip('Copy task text'));
    await tester.pumpAndSettle();

    expect(copiedText, 'Sit for 10 minutes in silence');
    expect(find.text('Task text copied.'), findsOneWidget);
  });

  testWidgets(
    'swipe left removes task with undo and project with confirmation',
    (WidgetTester tester) async {
      await tester.pumpWidget(const MindApp());
      await tester.pumpAndSettle();

      await tester.drag(
        find.widgetWithText(ListTile, 'Sit for 10 minutes in silence'),
        const Offset(-600, 0),
      );
      await tester.pumpAndSettle();
      expect(find.text('Sit for 10 minutes in silence'), findsNothing);
      expect(find.text('Revert?'), findsOneWidget);

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
    },
  );

  testWidgets('swipe right quickly moves incoming task to project', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MindApp());
    await tester.pumpAndSettle();

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

  testWidgets('swipe right archives and restores project tasks and projects', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MindApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Projects'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Morning Routine'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.widgetWithText(ListTile, 'Shape a calm start sequence'),
    );
    await tester.pumpAndSettle();
    await tester.drag(
      find.widgetWithText(ListTile, 'Shape a calm start sequence'),
      const Offset(600, 0),
    );
    await tester.pumpAndSettle();
    expect(find.text('Shape a calm start sequence'), findsNothing);
    expect(find.text('Archived'), findsOneWidget);
    await tester.tap(find.byTooltip('Dismiss').first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Archived'));
    await tester.pumpAndSettle();
    expect(find.text('Shape a calm start sequence'), findsOneWidget);

    await tester.ensureVisible(
      find.widgetWithText(ListTile, 'Shape a calm start sequence'),
    );
    await tester.pumpAndSettle();
    await tester.drag(
      find.widgetWithText(ListTile, 'Shape a calm start sequence'),
      const Offset(600, 0),
    );
    await tester.pumpAndSettle();
    expect(find.text('Shape a calm start sequence'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.drag(
      find.widgetWithText(ListTile, 'Morning Routine'),
      const Offset(600, 0),
    );
    await tester.pumpAndSettle();
    expect(find.text('Archived projects'), findsOneWidget);
    expect(find.text('Morning Routine'), findsNothing);

    await tester.tap(find.text('Archived projects'));
    await tester.pumpAndSettle();
    expect(find.text('Morning Routine'), findsOneWidget);

    await tester.ensureVisible(
      find.widgetWithText(ListTile, 'Morning Routine'),
    );
    await tester.pumpAndSettle();
    await tester.drag(
      find.widgetWithText(ListTile, 'Morning Routine'),
      const Offset(600, 0),
    );
    await tester.pumpAndSettle();
    expect(find.text('Morning Routine'), findsOneWidget);
  });

  testWidgets('deletes projects and sets colors from context menu', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MindApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Projects'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ListTile, 'Morning Routine'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Project settings'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).last, const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove project'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await tester.pumpAndSettle();
    expect(find.text('Morning Routine'), findsNothing);

    await tester.tap(find.widgetWithText(ListTile, 'Stress Reset'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Project settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Set color'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Coral'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    final Card projectCard = tester.widget<Card>(
      find
          .ancestor(of: find.text('Stress Reset'), matching: find.byType(Card))
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

  testWidgets(
    'project types can be configured and change new project behavior',
    (WidgetTester tester) async {
      await tester.pumpWidget(const MindApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Open settings'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.widgetWithText(ListTile, 'Blank'),
        300,
      );
      await tester.tap(find.widgetWithText(ListTile, 'Blank'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show tasks section'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save Project Type'));
      await tester.pumpAndSettle();

      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Projects'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Reference');
      await tester.tap(find.text('Type: Project'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Blank'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Create Project'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ListTile, 'Reference'));
      await tester.pumpAndSettle();

      expect(find.text('Tasks'), findsOneWidget);
      expect(find.text('Ideas'), findsNothing);
      expect(find.byTooltip('Add project task'), findsOneWidget);
    },
  );

  testWidgets('knowledge projects support sessions and quick capture', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MindApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Projects'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Knowledge Hub');
    await tester.tap(find.text('Type: Project'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Knowledge'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Create Project'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ListTile, 'Knowledge Hub'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Quick capture'), findsOneWidget);
    expect(find.byTooltip('New session'), findsOneWidget);

    await tester.tap(find.byTooltip('Quick capture'));
    await tester.pumpAndSettle();
    expect(
      find.text('Create a session first to use quick capture.'),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('New session'));
    await tester.pumpAndSettle();
    expect(find.text('New Session'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Podcast: Deep Dive');
    await tester.enterText(find.byType(TextField).last, 'Episode on learning');
    await tester.tap(find.widgetWithText(FilledButton, 'Create Session'));
    await tester.pumpAndSettle();

    expect(find.text('Podcast: Deep Dive'), findsOneWidget);
    expect(find.text('Session'), findsOneWidget);

    await tester.tap(find.byTooltip('Quick capture'));
    await tester.pumpAndSettle();
    expect(find.text('Quick Capture'), findsOneWidget);
    await tester.enterText(
      find.byType(TextField).first,
      'Analogies improve recall',
    );
    await tester.enterText(
      find.byType(TextField).last,
      'Speaker used concrete examples.',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save Capture'));
    await tester.pumpAndSettle();

    expect(find.text('Analogies improve recall'), findsOneWidget);
  });

  testWidgets('diary projects create timestamped journal entries', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MindApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Projects'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Daily Notes');
    await tester.tap(find.text('Type: Project'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Diary'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Diary'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Create Project'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ListTile, 'Daily Notes'));
    await tester.pumpAndSettle();

    expect(find.text('Diary'), findsOneWidget);
    expect(find.text('Journal'), findsOneWidget);
    expect(find.byTooltip('Add journal entry'), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('New Diary Entry'), findsOneWidget);
    await tester.enterText(
      find.byType(TextField),
      'Walked for 20 minutes and felt more clear afterwards.',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save Entry'));
    await tester.pumpAndSettle();

    expect(
      find.text('Walked for 20 minutes and felt more clear afterwards.'),
      findsOneWidget,
    );
    expect(find.textContaining('at '), findsWidgets);
  });

  testWidgets('people projects contain people with interactions and ideas', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MindApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Projects'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Contacts');
    await tester.tap(find.text('Type: Project'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.widgetWithText(ListTile, 'People'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -120));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'People'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Create Project'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ListTile, 'Contacts'));
    await tester.pumpAndSettle();

    expect(find.text('No people in this project yet.'), findsOneWidget);
    expect(find.byTooltip('Add person'), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('New Person'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Alice');
    await tester.enterText(
      find.byType(TextField).at(1),
      'Friend from climbing group',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Create Person'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ListTile, 'Alice'), findsOneWidget);
    expect(find.textContaining('interaction'), findsNothing);
    expect(find.textContaining('idea'), findsNothing);

    await tester.tap(find.widgetWithText(ListTile, 'Alice'));
    await tester.pumpAndSettle();

    expect(find.text('Interactions'), findsOneWidget);
    expect(find.text('Ideas'), findsWidgets);
    expect(find.byTooltip('Add interaction or idea'), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('Interaction'), findsOneWidget);
    expect(find.text('Ideas'), findsWidgets);
    await tester.tap(find.text('Interaction'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField),
      'Had coffee together and discussed summer plans.',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save Interaction'));
    await tester.pumpAndSettle();

    expect(
      find.text('Had coffee together and discussed summer plans.'),
      findsOneWidget,
    );

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Ideas'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField),
      'Invite Alice to hiking day',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save Task'));
    await tester.pumpAndSettle();

    expect(find.text('Invite Alice to hiking day'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ListTile, 'Alice'), findsOneWidget);
    expect(find.textContaining('interaction'), findsNothing);
    expect(find.textContaining('idea'), findsNothing);
  });

  testWidgets('exercise projects contain exercise types with workout logs', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MindApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Projects'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Training');
    await tester.tap(find.text('Type: Project'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.widgetWithText(ListTile, 'Exercise'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.widgetWithText(ListTile, 'Exercise'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Create Project'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ListTile, 'Training'));
    await tester.pumpAndSettle();

    expect(find.text('No exercise types in this project yet.'), findsOneWidget);
    expect(find.byTooltip('Add exercise type'), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('New Exercise type'), findsOneWidget);
    expect(find.text('Description'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Squat');
    await tester.enterText(
      find.byType(TextField).at(1),
      'Main lower-body strength movement.',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Create Exercise type'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ListTile, 'Squat'), findsOneWidget);

    await tester.tap(find.widgetWithText(ListTile, 'Squat'));
    await tester.pumpAndSettle();

    expect(find.text('Workout log'), findsOneWidget);
    expect(find.text('Ideas'), findsWidgets);
    expect(find.byTooltip('Add workout entry or idea'), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('Workout entry'), findsOneWidget);
    await tester.tap(find.text('Workout entry'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField),
      '5x5 at a steady weight with solid depth.',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save Workout entry'));
    await tester.pumpAndSettle();

    expect(
        find.text('5x5 at a steady weight with solid depth.'), findsOneWidget);
  });

  testWidgets('migrates versioned v2 payload and adds stable IDs', (
    WidgetTester tester,
  ) async {
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
    await tester.pumpAndSettle();

    expect(find.text('Legacy v2 incoming'), findsOneWidget);

    await tester.tap(find.byTooltip('Open settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Export data as JSON'));
    await tester.pumpAndSettle();

    expect(find.textContaining('"version"'), findsWidgets);
    expect(find.textContaining('24'), findsWidgets);
    expect(find.textContaining('"id"'), findsWidgets);
  });

  testWidgets('migrates versioned v3 payload and adds body/color fields', (
    WidgetTester tester,
  ) async {
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
    await tester.pumpAndSettle();
    expect(find.text('Legacy v3 incoming'), findsOneWidget);

    await tester.tap(find.byTooltip('Open settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Export data as JSON'));
    await tester.pumpAndSettle();

    expect(find.textContaining('"version"'), findsWidgets);
    expect(find.textContaining('24'), findsWidgets);
    expect(find.textContaining('"body": ""'), findsWidgets);
    expect(find.textContaining('"color": null'), findsWidgets);
  });

  testWidgets('separates project tasks into thinking and planning', (
    WidgetTester tester,
  ) async {
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
    await tester.pumpAndSettle();

    await tester.tap(find.text('Projects'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Dual Mode Project'));
    await tester.pumpAndSettle();

    expect(find.text('Ideas'), findsOneWidget);
    expect(find.text('Tasks'), findsOneWidget);
    expect(find.text('Legacy task'), findsOneWidget);

    await tester.tap(find.text('Legacy task'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Task options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move to thinking'));
    await tester.pumpAndSettle();

    expect(find.text('Tasks'), findsOneWidget);

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
      await tester.pumpAndSettle();

      await tester.tap(find.text('Projects'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Morning Routine'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Add project task'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Ideas'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Drag idea');
      await tester.tap(find.widgetWithText(FilledButton, 'Save Task'));
      await tester.pumpAndSettle();
      expect(find.text('Drag idea'), findsOneWidget);

      final Offset dragStart = tester.getCenter(find.text('Drag idea'));
      final Offset planningHeader = tester.getCenter(find.text('Tasks'));
      final TestGesture drag = await tester.startGesture(dragStart);
      await tester.pump(kLongPressTimeout);
      await drag.moveTo(planningHeader.translate(0, 42));
      await tester.pump();
      await drag.up();
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Add project task'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Tasks'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'New action');
      await tester.tap(find.widgetWithText(FilledButton, 'Save Task'));
      await tester.pumpAndSettle();
      expect(find.text('New action'), findsOneWidget);
    },
  );

  testWidgets(
    'pauses autosave when persisted state is corrupted to avoid overwrite',
    (WidgetTester tester) async {
      const String corruptedState = '{"version":5,"data":';

      SharedPreferences.setMockInitialValues(<String, Object>{
        'task_board_state': corruptedState,
      });

      await tester.pumpWidget(const MindApp());
      await tester.pumpAndSettle();
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
    },
  );
}
