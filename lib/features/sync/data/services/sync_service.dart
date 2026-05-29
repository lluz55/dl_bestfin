import 'dart:async';
import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:bestfin/core/database/app_database.dart';
import 'package:bestfin/features/sync/data/services/supabase_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Offline-first sync service.
///
/// Flow:
/// 1. Local changes are enqueued in sync_queue (insert/update/delete)
/// 2. processSyncQueue() pushes pending items to Supabase
/// 3. pullRemoteChanges() fetches rows updated since lastSyncAt from Supabase
///    and upserts them into the local Drift DB
/// 4. Conflict resolution: last-write-wins based on updated_at
class SyncService {
  final AppDatabase _db;
  final SupabaseService _supabase;
  Timer? _timer;
  bool _syncing = false;

  static const _lastSyncKey = 'sync_last_synced_at';
  static const _syncIntervalSeconds = 30;

  SyncService(this._db, this._supabase);

  // ── Queue management ──────────────────────────────────────────────────────

  Future<void> enqueue({
    required String operation,
    required String entityType,
    required String entityId,
    required Map<String, dynamic> payload,
  }) async {
    await _db.syncQueueDao.enqueue(
      id: const Uuid().v4(),
      operation: operation,
      entityType: entityType,
      entityId: entityId,
      payload: jsonEncode(payload),
    );
  }

  // ── Push (local → remote) ─────────────────────────────────────────────────

  Future<SyncResult> processSyncQueue() async {
    if (!_supabase.isInitialized || !_supabase.isSignedIn) {
      return SyncResult.notConfigured;
    }
    if (_syncing) return SyncResult.alreadyRunning;
    _syncing = true;

    int pushed = 0;
    int failed = 0;

    try {
      final items = await _db.syncQueueDao.getPendingItems();

      for (final item in items) {
        try {
          final payload = jsonDecode(item.payload) as Map<String, dynamic>;
          final table = _tableForEntity(item.entityType);
          if (table == null) {
            await _db.syncQueueDao.markSynced(item.id);
            continue;
          }

          if (item.operation == 'delete') {
            await _supabase.softDelete(table, item.entityId);
          } else {
            final userId = _supabase.currentUser?.id;
            if (userId != null) payload['user_id'] = userId;
            await _supabase.upsertRow(table, payload);
          }

          await _db.syncQueueDao.markSynced(item.id);
          pushed++;
        } catch (_) {
          await _db.syncQueueDao.incrementAttempts(item.id);
          failed++;
        }
      }

      await _db.syncQueueDao.clearSynced();
      await _updateLastSyncAt();
    } finally {
      _syncing = false;
    }

    return SyncResult.completed(pushed: pushed, failed: failed);
  }

  // ── Pull (remote → local) ─────────────────────────────────────────────────

  Future<SyncResult> pullRemoteChanges() async {
    if (!_supabase.isInitialized || !_supabase.isSignedIn) {
      return SyncResult.notConfigured;
    }

    final since = await _getLastSyncAt();
    int pulled = 0;

    try {
      final userId = _supabase.currentUser?.id;

      // Pull transactions
      final txRows = await _supabase.fetchSince(
        'transactions_sync',
        since: since,
        userId: userId,
      );
      for (final row in txRows) {
        await _mergeTransactionFromRemote(row);
        pulled++;
      }

      // Pull accounts
      final accRows = await _supabase.fetchSince(
        'accounts_sync',
        since: since,
        userId: userId,
      );
      for (final row in accRows) {
        await _mergeAccountFromRemote(row);
        pulled++;
      }

      await _updateLastSyncAt();
    } catch (_) {
      return SyncResult.error;
    }

    return SyncResult.completed(pushed: 0, failed: 0, pulled: pulled);
  }

  // ── Bidirectional sync ────────────────────────────────────────────────────

  Future<SyncResult> syncNow() async {
    final pushResult = await processSyncQueue();
    if (pushResult == SyncResult.notConfigured) return pushResult;
    final pullResult = await pullRemoteChanges();
    return pullResult;
  }

  // ── Auto-sync ─────────────────────────────────────────────────────────────

  void startAutoSync() {
    _timer?.cancel();
    _timer = Timer.periodic(
      const Duration(seconds: _syncIntervalSeconds),
      (_) => syncNow(),
    );
  }

  void stopAutoSync() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    stopAutoSync();
  }

  // ── Merge helpers ─────────────────────────────────────────────────────────

  Future<void> _mergeTransactionFromRemote(Map<String, dynamic> row) async {
    final id = row['id'] as String?;
    if (id == null) return;

    // Skip if local record is newer
    final local = await (_db.select(
      _db.transactions,
    )..where((t) => t.id.equals(id))).getSingleOrNull();

    final remoteUpdatedAt = DateTime.tryParse(
      row['updated_at'] as String? ?? '',
    );
    if (local != null && remoteUpdatedAt != null) {
      if (local.updatedAt.isAfter(remoteUpdatedAt)) return;
    }

    final isDeleted = row['is_deleted'] as bool? ?? false;
    if (isDeleted) {
      await (_db.delete(_db.transactions)..where((t) => t.id.equals(id))).go();
      return;
    }

    await _db
        .into(_db.transactions)
        .insertOnConflictUpdate(
          TransactionsCompanion(
            id: Value(id),
            date: Value(
              DateTime.tryParse(row['date'] as String? ?? '') ?? DateTime.now(),
            ),
            description: Value(row['description'] as String? ?? ''),
            type: Value(row['type'] as String? ?? 'expense'),
            sentiment: Value(row['sentiment'] as String?),
            notes: Value(row['notes'] as String?),
            categoryId: Value(row['category_id'] as String?),
            isCompleted: Value(row['is_completed'] as bool? ?? true),
            isConfirmed: Value(row['is_confirmed'] as bool? ?? true),
            source: Value(row['source'] as String?),
            updatedAt: Value(remoteUpdatedAt ?? DateTime.now()),
            createdAt: Value(
              DateTime.tryParse(row['created_at'] as String? ?? '') ??
                  DateTime.now(),
            ),
          ),
        );
  }

  Future<void> _mergeAccountFromRemote(Map<String, dynamic> row) async {
    final id = row['id'] as String?;
    if (id == null) return;

    final local = await (_db.select(
      _db.accounts,
    )..where((a) => a.id.equals(id))).getSingleOrNull();

    final remoteUpdatedAt = DateTime.tryParse(
      row['updated_at'] as String? ?? '',
    );
    if (local != null && remoteUpdatedAt != null) {
      if (local.updatedAt.isAfter(remoteUpdatedAt)) return;
    }

    final isDeleted = row['is_deleted'] as bool? ?? false;
    if (isDeleted) {
      await (_db.delete(_db.accounts)..where((a) => a.id.equals(id))).go();
      return;
    }

    await _db
        .into(_db.accounts)
        .insertOnConflictUpdate(
          AccountsCompanion(
            id: Value(id),
            name: Value(row['name'] as String? ?? ''),
            type: Value(row['type'] as String? ?? 'checking'),
            color: Value(row['color'] as String? ?? '#6750A4'),
            icon: Value(row['icon'] as String? ?? '984168'),
            updatedAt: Value(remoteUpdatedAt ?? DateTime.now()),
            createdAt: Value(
              DateTime.tryParse(row['created_at'] as String? ?? '') ??
                  DateTime.now(),
            ),
          ),
        );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String? _tableForEntity(String entityType) {
    switch (entityType) {
      case 'transaction':
        return 'transactions_sync';
      case 'account':
        return 'accounts_sync';
      default:
        return null;
    }
  }

  Future<DateTime> _getLastSyncAt() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_lastSyncKey);
    if (stored == null) return DateTime.fromMillisecondsSinceEpoch(0);
    return DateTime.tryParse(stored) ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  Future<void> _updateLastSyncAt() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());
  }

  Future<DateTime?> getLastSyncAt() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_lastSyncKey);
    if (stored == null) return null;
    return DateTime.tryParse(stored);
  }
}

class SyncResult {
  final bool success;
  final int pushed;
  final int pulled;
  final int failed;
  final String? errorMessage;

  const SyncResult._({
    required this.success,
    this.pushed = 0,
    this.pulled = 0,
    this.failed = 0,
    this.errorMessage,
  });

  static const notConfigured = SyncResult._(
    success: false,
    errorMessage: 'Supabase não configurado ou usuário não autenticado',
  );

  static const alreadyRunning = SyncResult._(
    success: false,
    errorMessage: 'Sincronização já em progresso',
  );

  static const error = SyncResult._(
    success: false,
    errorMessage: 'Erro ao sincronizar',
  );

  static SyncResult completed({
    required int pushed,
    required int failed,
    int pulled = 0,
  }) => SyncResult._(
    success: true,
    pushed: pushed,
    pulled: pulled,
    failed: failed,
  );
}
