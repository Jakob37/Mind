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
}
