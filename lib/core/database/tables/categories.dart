import 'package:drift/drift.dart';

@TableIndex(name: 'categories_parent_idx', columns: {#parentId})
@DataClassName('Category')
class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get icon => text()();
  TextColumn get color => text()();
  TextColumn get type => text()(); // income, expense, transfer
  BoolColumn get isSystem => boolean().withDefault(const Constant(false))();
  TextColumn get parentId => text().nullable().references(
    Categories,
    #id,
    onDelete: KeyAction.setNull,
  )();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  TextColumn get description => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
