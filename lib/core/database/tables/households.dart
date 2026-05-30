import 'package:drift/drift.dart';

@DataClassName('Household')
class Households extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get createdBy => text()(); // user email
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

@TableIndex(name: 'household_members_household_idx', columns: {#householdId})
@DataClassName('HouseholdMember')
class HouseholdMembers extends Table {
  TextColumn get id => text()();
  TextColumn get householdId => text().references(Households, #id)();
  TextColumn get email => text()();
  TextColumn get role =>
      text().withDefault(const Constant('editor'))(); // viewer, editor, admin
  BoolColumn get accepted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get invitedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get acceptedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
