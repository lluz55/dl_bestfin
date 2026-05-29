import 'package:drift/drift.dart';

@DataClassName('Investment')
class Investments extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get type => text()(); // fixed_income, stocks, crypto, etc.
  IntColumn get investedAmount => integer()(); // in cents
  IntColumn get currentYield =>
      integer().withDefault(const Constant(0))(); // in cents
  DateTimeColumn get maturityDate => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
