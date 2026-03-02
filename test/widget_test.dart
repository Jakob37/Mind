import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sorted_out/src/app.dart';

void main() {
  testWidgets('shows default tasks and adds/deletes a title-only task',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MindApp());

    expect(find.text('Sit for 10 minutes in silence'), findsOneWidget);
    expect(find.text('Do a 3-minute breathing check-in'), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Notice 5 mindful breaths');
    await tester.tap(find.widgetWithText(FilledButton, 'Save Task'));
    await tester.pumpAndSettle();

    expect(find.text('Notice 5 mindful breaths'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();

    expect(find.text('Notice 5 mindful breaths'), findsNothing);
  });
}
