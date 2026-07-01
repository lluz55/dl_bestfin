import 'package:drift/drift.dart';
import 'categories.dart';

/// Orçamento mensal por categoria (envelope budgeting).
/// Restrição UNIQUE em (category_id, year, month) garante um budget por categoria/mês.
@DataClassName('Budget')
class Budgets extends Table {
  TextColumn get id => text()();
  TextColumn get categoryId =>
      text().references(Categories, #id, onDelete: KeyAction.cascade)();
  IntColumn get year => integer()();
  IntColumn get month => integer()(); // 1–12
  IntColumn get amount => integer()(); // centavos planejados
  IntColumn get rolloverAmount =>
      integer().withDefault(const Constant(0))(); // centavos do mês anterior
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {categoryId, year, month},
  ];
}
