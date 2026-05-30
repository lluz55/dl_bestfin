import 'package:drift/drift.dart';

@DataClassName('Entity')
class Entities extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get type => text()(); // payee, payer
  TextColumn get category =>
      text().nullable()(); // person, store, restaurant, etc.
  IntColumn get useCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
