import 'package:drift/drift.dart';
import 'transactions.dart';

@TableIndex(
  name: 'recurring_rules_base_transaction_idx',
  columns: {#baseTransactionId},
)
@DataClassName('RecurringRule')
class RecurringRules extends Table {
  TextColumn get id => text()();
  TextColumn get baseTransactionId =>
      text().references(Transactions, #id, onDelete: KeyAction.cascade)();

  /// Frequência: daily, weekly, biweekly, monthly, yearly
  TextColumn get frequency => text()();
  IntColumn get interval => integer().withDefault(const Constant(1))();
  DateTimeColumn get nextDate => dateTime()();
  DateTimeColumn get endDate => dateTime().nullable()();

  /// Status: active, paused, finished
  TextColumn get status => text().withDefault(const Constant('active'))();

  /// Se true, transações geradas já vêm como confirmadas (isCompleted = true)
  BoolColumn get autoConfirm => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
