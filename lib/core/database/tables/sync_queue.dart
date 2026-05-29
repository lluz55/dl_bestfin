import 'package:drift/drift.dart';

@DataClassName('SyncQueueItem')
class SyncQueue extends Table {
  TextColumn get id => text()();
  TextColumn get operation => text()(); // 'insert', 'update', 'delete'
  TextColumn get entityType =>
      text()(); // 'transaction', 'account', 'category', 'goal'
  TextColumn get entityId => text()();
  TextColumn get payload => text()(); // JSON-encoded entity data
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
