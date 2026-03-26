import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../supabase_bootstrap.dart';

class TaskSyncAccountState {
  const TaskSyncAccountState({
    required this.isConfigured,
    this.userId,
    this.email,
  });

  final bool isConfigured;
  final String? userId;
  final String? email;

  bool get isSignedIn => userId != null && userId!.isNotEmpty;
}

class TaskAuthResult {
  const TaskAuthResult({
    required this.isSignedIn,
    required this.message,
  });

  final bool isSignedIn;
  final String message;
}

class TaskCloudBoardSnapshot {
  const TaskCloudBoardSnapshot({
    required this.rawJson,
    this.updatedAt,
  });

  final String rawJson;
  final DateTime? updatedAt;
}

class TaskCloudSyncResult {
  const TaskCloudSyncResult({
    required this.message,
    this.updatedAt,
  });

  final String message;
  final DateTime? updatedAt;
}

class TaskSyncService {
  TaskSyncService({
    SupabaseClient? client,
  }) : _client = client ?? SupabaseBootstrap.client;

  final SupabaseClient? _client;

  bool get isConfigured => _client != null;

  TaskSyncAccountState get accountState {
    final User? user = _client?.auth.currentUser;
    return TaskSyncAccountState(
      isConfigured: isConfigured,
      userId: user?.id,
      email: user?.email,
    );
  }

  Future<TaskAuthResult> signIn({
    required String email,
    required String password,
  }) async {
    final SupabaseClient client = _requireClient();
    final AuthResponse response = await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    final User? user = response.user ?? client.auth.currentUser;
    final String resolvedEmail = user?.email ?? email;

    return TaskAuthResult(
      isSignedIn: true,
      message: 'Signed in as $resolvedEmail.',
    );
  }

  Future<TaskAuthResult> signUp({
    required String email,
    required String password,
  }) async {
    final SupabaseClient client = _requireClient();
    final AuthResponse response = await client.auth.signUp(
      email: email,
      password: password,
    );
    final User? user = response.user ?? client.auth.currentUser;
    final bool isSignedIn = response.session != null;
    final String resolvedEmail = user?.email ?? email;

    return TaskAuthResult(
      isSignedIn: isSignedIn,
      message: isSignedIn
          ? 'Account created and signed in as $resolvedEmail.'
          : 'Account created for $resolvedEmail. Check email confirmation '
              'settings in Supabase if sign-in is not immediate.',
    );
  }

  Future<void> signOut() async {
    final SupabaseClient client = _requireClient();
    await client.auth.signOut();
  }

  Future<TaskCloudSyncResult> saveBoardJson(String rawJson) async {
    final SupabaseClient client = _requireClient();
    final User user = _requireSignedInUser(client);
    final ({Map<String, dynamic> board, int schemaVersion}) payload =
        parseExportJson(rawJson);

    final Map<String, dynamic> response = Map<String, dynamic>.from(
      await client
          .from('boards')
          .upsert(<String, dynamic>{
            'user_id': user.id,
            'board': payload.board,
            'schema_version': payload.schemaVersion,
          })
          .select('updated_at')
          .single(),
    );

    return TaskCloudSyncResult(
      message: 'Uploaded current board to cloud.',
      updatedAt: _readUpdatedAt(response['updated_at']),
    );
  }

  Future<TaskCloudBoardSnapshot?> loadBoardJson() async {
    final SupabaseClient client = _requireClient();
    final User user = _requireSignedInUser(client);

    final dynamic response = await client
        .from('boards')
        .select('board, schema_version, updated_at')
        .eq('user_id', user.id)
        .maybeSingle();

    if (response == null) {
      return null;
    }

    final Map<String, dynamic> record = Map<String, dynamic>.from(
      response as Map,
    );
    final Object? rawBoard = record['board'];
    if (rawBoard is! Map) {
      throw const FormatException('Cloud board payload is not a map.');
    }
    final Object? rawSchemaVersion = record['schema_version'];
    if (rawSchemaVersion is! int) {
      throw const FormatException('Cloud board schema version is not an int.');
    }

    return TaskCloudBoardSnapshot(
      rawJson: buildExportJson(
        board: Map<String, dynamic>.from(rawBoard),
        schemaVersion: rawSchemaVersion,
      ),
      updatedAt: _readUpdatedAt(record['updated_at']),
    );
  }

  static ({Map<String, dynamic> board, int schemaVersion}) parseExportJson(
    String rawJson,
  ) {
    final Object? decoded = jsonDecode(rawJson);
    if (decoded is! Map) {
      throw const FormatException('Export JSON is not a map.');
    }

    final Map<String, dynamic> payload = Map<String, dynamic>.from(decoded);
    final Object? rawSchemaVersion = payload['version'];
    if (rawSchemaVersion is! int) {
      throw const FormatException('Export JSON version is not an int.');
    }

    final Object? rawBoard = payload['data'];
    if (rawBoard is! Map) {
      throw const FormatException('Export JSON data payload is not a map.');
    }

    return (
      board: Map<String, dynamic>.from(rawBoard),
      schemaVersion: rawSchemaVersion,
    );
  }

  static String buildExportJson({
    required Map<String, dynamic> board,
    required int schemaVersion,
  }) {
    return jsonEncode(<String, dynamic>{
      'version': schemaVersion,
      'data': board,
    });
  }

  SupabaseClient _requireClient() {
    final SupabaseClient? client = _client;
    if (client == null) {
      throw StateError(
        'Supabase is not configured. Launch with SUPABASE_URL and '
        'SUPABASE_ANON_KEY.',
      );
    }
    return client;
  }

  User _requireSignedInUser(SupabaseClient client) {
    final User? user = client.auth.currentUser;
    if (user == null) {
      throw StateError('Sign in to use cloud sync.');
    }
    return user;
  }

  static DateTime? _readUpdatedAt(Object? rawUpdatedAt) {
    if (rawUpdatedAt is! String || rawUpdatedAt.trim().isEmpty) {
      return null;
    }
    return DateTime.tryParse(rawUpdatedAt)?.toLocal();
  }
}
