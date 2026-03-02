import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sorted_out/src/app.dart';

void main() {
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

    await tester.drag(find.byType(TabBarView), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.text('Sit for 10 minutes in silence'), findsOneWidget);

    await tester.drag(find.byType(TabBarView), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.text('Morning Routine'), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Breathwork');
    await tester.tap(find.widgetWithText(FilledButton, 'Create Project'));
    await tester.pumpAndSettle();
    expect(find.text('Breathwork'), findsOneWidget);

    await tester.drag(find.byType(TabBarView), const Offset(500, 0));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(TabBarView), const Offset(500, 0));
    await tester.pumpAndSettle();

    expect(find.byType(FloatingActionButton), findsOneWidget);

    await tester.tap(find.byIcon(Icons.drive_file_move_outlined).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Breathwork'));
    await tester.pumpAndSettle();

    expect(find.text('Do a 3-minute breathing check-in'), findsNothing);

    await tester.drag(find.byType(TabBarView), const Offset(-500, 0));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(TabBarView), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(find.text('Breathwork'), findsOneWidget);
    expect(find.text('1 task'), findsOneWidget);
  });
}
