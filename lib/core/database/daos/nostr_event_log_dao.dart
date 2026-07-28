import 'package:drift/drift.dart';
import 'package:bestfin/core/database/app_database.dart';
import 'package:bestfin/core/database/tables/nostr_event_log.dart';

part 'nostr_event_log_dao.g.dart';

@DriftAccessor(tables: [NostrEventLog])
class NostrEventLogDao extends DatabaseAccessor<AppDatabase>
    with _$NostrEventLogDaoMixin {
  NostrEventLogDao(super.db);

  Future<void> save(NostrEventLogItem item) async {
    await into(nostrEventLog).insertOnConflictUpdate(item);
  }

  Future<void> markPublished(String eventId) async {
    await (update(nostrEventLog)..where((t) => t.eventId.equals(eventId)))
        .write(const NostrEventLogCompanion(published: Value(true)));
  }

  Future<List<NostrEventLogItem>> getUnpublished() {
    return (select(nostrEventLog)
          ..where((t) => t.published.equals(false))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
  }

  Future<List<NostrEventLogItem>> getAll() {
    return (select(
      nostrEventLog,
    )..orderBy([(t) => OrderingTerm.asc(t.updatedAt)])).get();
  }

  Future<int> countUnpublished() async {
    final count = nostrEventLog.eventId.count();
    final row =
        await (selectOnly(nostrEventLog)
              ..addColumns([count])
              ..where(nostrEventLog.published.equals(false)))
            .getSingle();
    return row.read(count) ?? 0;
  }
}
