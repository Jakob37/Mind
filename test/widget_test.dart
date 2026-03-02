import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sorted_out/src/app.dart';

void main() {
  testWidgets('add, complete, and delete a task', (WidgetTester tester) async {
    await tester.pumpWidget(const SortedOutApp());

    expect(find.text('No tasks yet. Add your first task.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Buy milk');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pump();

    expect(find.text('Buy milk'), findsOneWidget);

    await tester.tap(find.byType(Checkbox));
    await tester.pump();

    final Text taskText = tester.widget<Text>(find.text('Buy milk'));
    expect(taskText.style?.decoration, TextDecoration.lineThrough);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pump();

    expect(find.text('Buy milk'), findsNothing);
    expect(find.text('No tasks yet. Add your first task.'), findsOneWidget);
  });
}
