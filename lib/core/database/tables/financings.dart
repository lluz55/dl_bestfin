import 'package:drift/drift.dart';

@DataClassName('Financing')
class Financings extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  IntColumn get totalAmount => integer()(); // in cents
  IntColumn get outstandingBalance => integer()(); // in cents
  RealColumn get interestRate => real()();
  IntColumn get totalInstallments => integer()();
  TextColumn get amortizationSystem => text()(); // sac, price
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
