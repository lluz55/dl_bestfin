import 'package:drift/drift.dart';
import 'package:bestfin/core/database/app_database.dart';
import 'package:bestfin/core/database/tables/sync_queue.dart';

part 'sync_queue_dao.g.dart';

@DriftAccessor(tables: [SyncQueue])
class SyncQueueDao extends DatabaseAccessor<AppDatabase>
    with _$SyncQueueDaoMixin {
  SyncQueueDao(super.db);

  Future<List<SyncQueueItem>> getPendingItems({int limit = 50}) {
    return (select(syncQueue)
          ..where((t) => t.synced.equals(false))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)])
          ..limit(limit))
        .get();
  }

  Future<void> enqueue({
    required String id,
    required String operation,
    required String entityType,
    required String entityId,
    required String payload,
  }) async {
    await into(syncQueue).insertOnConflictUpdate(
      SyncQueueCompanion.insert(
        id: id,
        operation: operation,
        entityType: entityType,
        entityId: entityId,
        payload: payload,
      ),
    );
  }

  Future<void> markSynced(String id) async {
    await (update(syncQueue)..where((t) => t.id.equals(id))).write(
      const SyncQueueCompanion(synced: Value(true)),
    );
  }

  Future<void> incrementAttempts(String id) async {
    await customStatement(
      'UPDATE sync_queue SET attempts = attempts + 1 WHERE id = ?',
      [id],
    );
  }

  Future<void> clearSynced() async {
    await (delete(syncQueue)..where((t) => t.synced.equals(true))).go();
  }

  Stream<int> watchPendingCount() {
    final count = syncQueue.id.count();
    return (selectOnly(syncQueue)
          ..addColumns([count])
          ..where(syncQueue.synced.equals(false)))
        .watch()
        .map((rows) => rows.first.read(count) ?? 0);
  }
}
