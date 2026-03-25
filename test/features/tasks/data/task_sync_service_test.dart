import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sorted_out/src/features/tasks/data/task_sync_service.dart';

void main() {
  test('parseExportJson extracts schema version and board payload', () {
    final String rawJson = jsonEncode(<String, dynamic>{
      'version': 23,
      'data': <String, dynamic>{
        'incomingTasks': <Map<String, dynamic>>[],
      },
    });

    final ({Map<String, dynamic> board, int schemaVersion}) parsed =
        TaskSyncService.parseExportJson(rawJson);

    expect(parsed.schemaVersion, 23);
    expect(parsed.board['incomingTasks'], isA<List<dynamic>>());
  });

  test('buildExportJson rebuilds versioned payload for import', () {
    final String rawJson = TaskSyncService.buildExportJson(
      schemaVersion: 23,
      board: <String, dynamic>{
        'projects': <Map<String, dynamic>>[],
      },
    );

    final Map<String, dynamic> decoded =
        jsonDecode(rawJson) as Map<String, dynamic>;

    expect(decoded['version'], 23);
    expect((decoded['data'] as Map<String, dynamic>)['projects'], isA<List>());
  });
}
