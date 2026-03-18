import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sorted_out/src/features/tasks/data/task_backup_preferences.dart';
import 'package:sorted_out/src/features/tasks/data/task_backup_service.dart';

void main() {
  late Directory backupDirectory;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    backupDirectory = await Directory.systemTemp.createTemp(
      'mind-task-backups-test-',
    );
  });

  tearDown(() async {
    if (await backupDirectory.exists()) {
      await backupDirectory.delete(recursive: true);
    }
  });

  TaskBackupService buildService({
    int retentionCount = 20,
    Duration minimumBackupInterval = const Duration(minutes: 15),
  }) {
    return TaskBackupService(
      directoryProvider: () async => backupDirectory,
      retentionCount: retentionCount,
      minimumBackupInterval: minimumBackupInterval,
    );
  }

  test('automatic backup preference defaults to disabled and can be enabled',
      () async {
    const TaskBackupPreferences preferences = TaskBackupPreferences();

    expect(await preferences.loadAutomaticBackupsEnabled(), isFalse);

    await preferences.saveAutomaticBackupsEnabled(true);

    expect(await preferences.loadAutomaticBackupsEnabled(), isTrue);
  });

  test('saveAutomaticBackup creates a readable backup entry', () async {
    final TaskBackupService service = buildService();

    await service.saveAutomaticBackup('{"version":22}');

    final List<TaskBackupEntry> backups = await service.listBackups();
    expect(backups, hasLength(1));
    expect(backups.single.fileName, startsWith('mind-auto-backup-'));
    expect(await service.readBackup(backups.single.id), '{"version":22}');
  });

  test('saveAutomaticBackup updates the latest backup within the interval',
      () async {
    final TaskBackupService service = buildService(
      minimumBackupInterval: const Duration(hours: 1),
    );

    await service.saveAutomaticBackup('{"version":22,"value":1}');
    await service.saveAutomaticBackup('{"version":22,"value":2}');

    final List<TaskBackupEntry> backups = await service.listBackups();
    expect(backups, hasLength(1));
    expect(
      await service.readBackup(backups.single.id),
      '{"version":22,"value":2}',
    );
  });

  test('saveAutomaticBackup prunes older backups past the retention limit',
      () async {
    final TaskBackupService service = buildService(
      retentionCount: 2,
      minimumBackupInterval: Duration.zero,
    );

    await service.saveAutomaticBackup('{"backup":1}');
    await Future<void>.delayed(const Duration(milliseconds: 2));
    await service.saveAutomaticBackup('{"backup":2}');
    await Future<void>.delayed(const Duration(milliseconds: 2));
    await service.saveAutomaticBackup('{"backup":3}');

    final List<TaskBackupEntry> backups = await service.listBackups();
    expect(backups, hasLength(2));
    expect(
      backups.map((TaskBackupEntry backup) => backup.fileName),
      everyElement(startsWith('mind-auto-backup-')),
    );
    expect(await service.readBackup(backups.first.id), '{"backup":3}');
    expect(await service.readBackup(backups.last.id), '{"backup":2}');
  });

  test('readBackup rejects invalid backup identifiers', () async {
    final TaskBackupService service = buildService();

    expect(
      () => service.readBackup('../outside.json'),
      throwsA(isA<FormatException>()),
    );
  });
}
