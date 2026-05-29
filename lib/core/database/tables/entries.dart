import 'package:drift/drift.dart';
import 'accounts.dart';
import 'transactions.dart';

@DataClassName('Entry')
class Entries extends Table {
  TextColumn get id => text()();
  TextColumn get transactionId =>
      text().references(Transactions, #id, onDelete: KeyAction.cascade)();
  TextColumn get accountId =>
      text().references(Accounts, #id, onDelete: KeyAction.restrict)();
  IntColumn get amount => integer()(); // in cents (R$ 10.50 -> 1050)
  TextColumn get type => text()(); // debit, credit
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
