import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bestfin/features/sync/domain/models/sync_user.dart';

/// Central Supabase wrapper.
///
/// Supabase SQL schema to create in your project dashboard:
/// ```sql
/// -- Enable RLS on all tables
///
/// CREATE TABLE households (
///   id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
///   name TEXT NOT NULL,
///   created_by TEXT NOT NULL,
///   created_at TIMESTAMPTZ DEFAULT NOW(),
///   updated_at TIMESTAMPTZ DEFAULT NOW()
/// );
///
/// CREATE TABLE household_members (
///   id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
///   household_id UUID REFERENCES households(id) ON DELETE CASCADE,
///   email TEXT NOT NULL,
///   role TEXT NOT NULL DEFAULT 'editor',
///   accepted BOOLEAN DEFAULT FALSE,
///   invited_at TIMESTAMPTZ DEFAULT NOW(),
///   accepted_at TIMESTAMPTZ
/// );
///
/// CREATE TABLE transactions_sync (
///   id TEXT PRIMARY KEY,
///   user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
///   household_id UUID REFERENCES households(id),
///   date TIMESTAMPTZ,
///   description TEXT,
///   type TEXT,
///   sentiment TEXT,
///   notes TEXT,
///   category_id TEXT,
///   amount INT,
///   is_completed BOOLEAN DEFAULT TRUE,
///   is_confirmed BOOLEAN DEFAULT TRUE,
///   source TEXT,
///   is_deleted BOOLEAN DEFAULT FALSE,
///   created_at TIMESTAMPTZ DEFAULT NOW(),
///   updated_at TIMESTAMPTZ DEFAULT NOW()
/// );
///
/// CREATE TABLE accounts_sync (
///   id TEXT PRIMARY KEY,
///   user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
///   household_id UUID REFERENCES households(id),
///   name TEXT,
///   type TEXT,
///   color TEXT,
///   icon TEXT,
///   balance_cents INT DEFAULT 0,
///   is_deleted BOOLEAN DEFAULT FALSE,
///   created_at TIMESTAMPTZ DEFAULT NOW(),
///   updated_at TIMESTAMPTZ DEFAULT NOW()
/// );
///
/// -- Row Level Security policies:
/// ALTER TABLE transactions_sync ENABLE ROW LEVEL SECURITY;
/// ALTER TABLE accounts_sync ENABLE ROW LEVEL SECURITY;
/// CREATE POLICY "user can access own data" ON transactions_sync
///   FOR ALL USING (auth.uid() = user_id);
/// CREATE POLICY "user can access own data" ON accounts_sync
///   FOR ALL USING (auth.uid() = user_id);
/// ```
class SupabaseService {
  SupabaseClient? _client;
  bool _initialized = false;

  bool get isInitialized => _initialized;
  SupabaseClient? get client => _client;

  Future<void> initialize({
    required String url,
    required String anonKey,
  }) async {
    if (url.isEmpty || anonKey.isEmpty) return;
    try {
      await Supabase.initialize(url: url, anonKey: anonKey);
      _client = Supabase.instance.client;
      _initialized = true;
    } catch (_) {
      _initialized = false;
    }
  }

  bool get isSignedIn => _client?.auth.currentUser != null;

  SyncUser? get currentUser {
    final user = _client?.auth.currentUser;
    if (user == null) return null;
    return SyncUser(
      id: user.id,
      email: user.email ?? '',
      displayName: user.userMetadata?['display_name'] as String?,
      createdAt: DateTime.tryParse(user.createdAt),
    );
  }

  Stream<SyncUser?> get authStateChanges {
    if (_client == null) return const Stream.empty();
    return _client!.auth.onAuthStateChange.map((event) {
      final user = event.session?.user;
      if (user == null) return null;
      return SyncUser(
        id: user.id,
        email: user.email ?? '',
        displayName: user.userMetadata?['display_name'] as String?,
        createdAt: DateTime.tryParse(user.createdAt),
      );
    });
  }

  Future<SyncUser?> signInWithEmail(String email, String password) async {
    if (_client == null) throw Exception('Supabase não configurado');
    final res = await _client!.auth.signInWithPassword(
      email: email,
      password: password,
    );
    final user = res.user;
    if (user == null) return null;
    return SyncUser(
      id: user.id,
      email: user.email ?? '',
      createdAt: DateTime.tryParse(user.createdAt),
    );
  }

  Future<SyncUser?> signUpWithEmail(
    String email,
    String password, {
    String? displayName,
  }) async {
    if (_client == null) throw Exception('Supabase não configurado');
    final res = await _client!.auth.signUp(
      email: email,
      password: password,
      data: displayName != null ? {'display_name': displayName} : null,
    );
    final user = res.user;
    if (user == null) return null;
    return SyncUser(
      id: user.id,
      email: user.email ?? '',
      displayName: displayName,
      createdAt: DateTime.tryParse(user.createdAt),
    );
  }

  Future<void> signOut() async {
    await _client?.auth.signOut();
  }

  Future<void> resetPassword(String email) async {
    if (_client == null) throw Exception('Supabase não configurado');
    await _client!.auth.resetPasswordForEmail(email);
  }

  // ── Data operations ───────────────────────────────────────────────────────

  Future<void> upsertRow(String table, Map<String, dynamic> data) async {
    if (_client == null || !isSignedIn) return;
    await _client!.from(table).upsert(data);
  }

  Future<void> softDelete(String table, String id) async {
    if (_client == null || !isSignedIn) return;
    await _client!
        .from(table)
        .update({
          'is_deleted': true,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', id);
  }

  Future<List<Map<String, dynamic>>> fetchSince(
    String table, {
    required DateTime since,
    String? userId,
    String? householdId,
  }) async {
    if (_client == null || !isSignedIn) return [];
    var query = _client!
        .from(table)
        .select()
        .gt('updated_at', since.toIso8601String());

    if (userId != null) query = query.eq('user_id', userId);
    if (householdId != null) query = query.eq('household_id', householdId);

    final result = await query;
    return List<Map<String, dynamic>>.from(result as List);
  }

  // ── Realtime ──────────────────────────────────────────────────────────────

  RealtimeChannel subscribeToTable(
    String table, {
    required void Function(Map<String, dynamic>) onInsert,
    required void Function(Map<String, dynamic>) onUpdate,
    required void Function(Map<String, dynamic>) onDelete,
  }) {
    final channel = _client!.channel('public:$table');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: table,
          callback: (payload) => onInsert(payload.newRecord),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: table,
          callback: (payload) => onUpdate(payload.newRecord),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: table,
          callback: (payload) => onDelete(payload.oldRecord),
        )
        .subscribe();
    return channel;
  }
}
