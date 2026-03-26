import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sorted_out/src/features/tasks/data/task_backup_service.dart';
import 'package:sorted_out/src/features/tasks/data/task_sync_service.dart';
import 'package:sorted_out/src/features/tasks/domain/task_models.dart';
import 'package:sorted_out/src/features/tasks/presentation/pages/settings_page.dart';

void main() {
  SettingsPage buildSettingsPage({
    TaskSyncAccountState cloudAccountState = const TaskSyncAccountState(
      isConfigured: true,
      userId: 'user-1',
      email: 'you@example.com',
    ),
    Future<String?> Function()? onUploadCloudBoard,
    Future<String?> Function()? onRestoreCloudBoard,
  }) {
    return SettingsPage(
      exportData: () => '{}',
      exportPlainText: () => '',
      onImportData: (_) async => null,
      projectTypes: const <ProjectTypeConfig>[],
      onProjectTypesChanged: (_) {},
      colorLabels: const <int, String>{},
      onColorLabelsChanged: (_) {},
      hideCompletedProjectItems: false,
      onHideCompletedProjectItemsChanged: (_) {},
      automaticBackupsEnabled: false,
      onAutomaticBackupsEnabledChanged: (_) async => null,
      listAutomaticBackups: () async => <TaskBackupEntry>[],
      onRestoreAutomaticBackup: (_) async => null,
      cloudAccountState: cloudAccountState,
      onManageCloudAccount: () async => cloudAccountState,
      onSignOutCloudAccount: () async =>
          const TaskSyncAccountState(isConfigured: true),
      onUploadCloudBoard:
          onUploadCloudBoard ?? () async => 'Uploaded current board to cloud.',
      onRestoreCloudBoard: onRestoreCloudBoard ??
          () async => 'Cloud board restored. Current local data was replaced.',
      cardLayoutPreset: CardLayoutPreset.standard,
      onCardLayoutPresetChanged: (_) {},
    );
  }

  testWidgets('shows cloud sync actions when signed in', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: buildSettingsPage()));
    await tester.pumpAndSettle();

    expect(find.text('Upload board to cloud'), findsOneWidget);
    expect(find.text('Restore board from cloud'), findsOneWidget);
  });

  testWidgets('restore from cloud confirms before invoking callback', (
    WidgetTester tester,
  ) async {
    int restoreCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: buildSettingsPage(
          onRestoreCloudBoard: () async {
            restoreCalls += 1;
            return 'Cloud board restored.';
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Restore board from cloud'));
    await tester.pumpAndSettle();

    expect(find.text('Restore cloud board'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Restore'));
    await tester.pumpAndSettle();

    expect(restoreCalls, 1);
    expect(find.text('Cloud board restored.'), findsOneWidget);
  });

  test('utf8 decoding preserves Swedish characters for import payloads', () {
    final String original = '{"title":"Översikt","body":"Återställ lösenord"}';
    final String decoded = utf8.decode(utf8.encode(original));

    expect(decoded, contains('Översikt'));
    expect(decoded, contains('Återställ lösenord'));
  });
}
