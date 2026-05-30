import 'package:drift/drift.dart';
import 'package:bestfin/core/database/tables/accounts.dart';

/// Tabela de Objetivos Financeiros.
/// [status]: 'active' | 'completed' | 'archived'
@TableIndex(name: 'goals_account_idx', columns: {#accountId})
@DataClassName('Goal')
class Goals extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get description => text().nullable()();
  IntColumn get targetAmount => integer()(); // in cents
  IntColumn get currentAmount =>
      integer().withDefault(const Constant(0))(); // in cents
  DateTimeColumn get targetDate => dateTime().nullable()();
  TextColumn get accountId => text().nullable().references(
    Accounts,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get color => text().nullable()();
  TextColumn get icon => text().nullable()();
  TextColumn get type =>
      text().withDefault(const Constant('saving'))(); // saving | spending
  TextColumn get status => text().withDefault(
    const Constant('active'),
  )(); // active | completed | archived
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
