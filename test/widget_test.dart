import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sorted_out/src/app.dart';

void main() {
  testWidgets('swipes between incoming and saved lists',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MindApp());

    expect(find.text('Incoming'), findsOneWidget);
    expect(find.text('Saved'), findsOneWidget);
    expect(find.text('Sit for 10 minutes in silence'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);

    await tester.tap(find.byIcon(Icons.bookmark_add_outlined).first);
    await tester.pumpAndSettle();

    expect(find.text('Sit for 10 minutes in silence'), findsNothing);

    await tester.drag(find.byType(TabBarView), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.text('Sit for 10 minutes in silence'), findsOneWidget);

    await tester.drag(find.byType(TabBarView), const Offset(500, 0));
    await tester.pumpAndSettle();

    expect(find.byType(FloatingActionButton), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Notice 5 mindful breaths');
    await tester.tap(find.widgetWithText(FilledButton, 'Save Task'));
    await tester.pumpAndSettle();

    expect(find.text('Notice 5 mindful breaths'), findsOneWidget);
  });
}
