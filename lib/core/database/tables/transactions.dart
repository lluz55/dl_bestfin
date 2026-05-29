import 'package:drift/drift.dart';
import 'categories.dart';
import 'entities.dart';
import 'goals.dart';

@DataClassName('Transaction')
class Transactions extends Table {
  TextColumn get id => text()();
  DateTimeColumn get date => dateTime()();
  TextColumn get description => text().withLength(min: 1, max: 255)();
  TextColumn get type => text()(); // income, expense, transfer
  TextColumn get sentiment =>
      text().nullable()(); // positive, neutral, negative
  TextColumn get notes => text().nullable()();
  TextColumn get categoryId => text().nullable().references(
    Categories,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get entityId => text().nullable().references(
    Entities,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get goalId => text().nullable().references(
    Goals,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get installmentPlanId => text().nullable()();
  IntColumn get installmentNumber => integer().nullable()();

  BoolColumn get isCompleted => boolean().withDefault(const Constant(true))();
  BoolColumn get isConfirmed => boolean().withDefault(const Constant(true))();
  TextColumn get source =>
      text().nullable()(); // 'notification', 'manual', etc.
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}