import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../app_database.dart';
import '../tables/reconciliation_checkpoints.dart';
import '../tables/entries.dart';

part 'reconciliation_dao.g.dart';

@DriftAccessor(tables: [ReconciliationCheckpoints, Entries])
class ReconciliationDao extends DatabaseAccessor<AppDatabase>
    with _$ReconciliationDaoMixin {
  ReconciliationDao(super.db);

  Stream<List<ReconciliationCheckpoint>> watchByAccount(String accountId) {
    return (select(reconciliationCheckpoints)
          ..where((r) => r.accountId.equals(accountId))
          ..orderBy([
            (r) => OrderingTerm(expression: r.date, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  Future<List<ReconciliationCheckpoint>> getByAccount(String accountId) {
    return (select(reconciliationCheckpoints)
          ..where((r) => r.accountId.equals(accountId))
          ..orderBy([
            (r) => OrderingTerm(expression: r.date, mode: OrderingMode.desc),
          ]))
        .get();
  }

  Future<ReconciliationCheckpoint?> getLatest(String accountId) {
    return (select(reconciliationCheckpoints)
          ..where((r) => r.accountId.equals(accountId))
          ..orderBy([
            (r) => OrderingTerm(expression: r.date, mode: OrderingMode.desc),
          ])
          ..limit(1))
        .getSingleOrNull();
  }

  Future<ReconciliationCheckpoint> insertCheckpoint({
    required String accountId,
    required int statementBalance,
    required int entriesCount,
  }) async {
    final id = const Uuid().v4();
    await into(reconciliationCheckpoints).insert(
      ReconciliationCheckpointsCompanion.insert(
        id: id,
        accountId: accountId,
        statementBalance: statementBalance,
        date: DateTime.now(),
        entriesCount: entriesCount,
      ),
    );
    return (select(
      reconciliationCheckpoints,
    )..where((r) => r.id.equals(id))).getSingle();
  }

  Future<int> deleteCheckpoint(String id) {
    return (delete(
      reconciliationCheckpoints,
    )..where((r) => r.id.equals(id))).go();
  }
}
