import 'package:drift/drift.dart';
import 'credit_cards.dart';

@DataClassName('Invoice')
class Invoices extends Table {
  TextColumn get id => text()();
  TextColumn get creditCardId =>
      text().references(CreditCards, #id, onDelete: KeyAction.cascade)();
  IntColumn get month => integer()();
  IntColumn get year => integer()();
  TextColumn get status => text()(); // open, closed, paid
  DateTimeColumn get dueDate => dateTime()();
  DateTimeColumn get closingDate => dateTime()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
