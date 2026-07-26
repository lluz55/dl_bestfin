import 'package:drift/drift.dart';
import 'package:bestfin/core/database/tables/accounts.dart';

@TableIndex(name: 'credit_cards_account_idx', columns: {#accountId})
@DataClassName('CreditCard')
class CreditCards extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  IntColumn get limitAmount => integer()(); // in cents
  IntColumn get closingDay => integer()();
  IntColumn get dueDay => integer()();
  TextColumn get accountId =>
      text().references(Accounts, #id, onDelete: KeyAction.restrict)();
  TextColumn get color => text().nullable()();
  IntColumn get minPaymentPercent =>
      integer().withDefault(const Constant(15))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
