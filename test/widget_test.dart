import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sorted_out/src/app.dart';

void main() {
  testWidgets('add and delete a task from the FAB modal',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MindApp());

    expect(find.text('No tasks yet. Tap + to add one.'), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'Buy milk');
    await tester.enterText(find.byType(TextField).at(1), '2 liters');
    await tester.tap(find.widgetWithText(FilledButton, 'Save Task'));
    await tester.pumpAndSettle();

    expect(find.text('Buy milk'), findsOneWidget);
    expect(find.text('2 liters'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(find.text('Buy milk'), findsNothing);
    expect(find.text('No tasks yet. Tap + to add one.'), findsOneWidget);
  });
}
