import 'package:drift/drift.dart';
import 'package:bestfin/core/database/tables/categories.dart';

/// Orçamento mensal com nome e valor planejado.
/// Categorias vinculadas via tabela pivô [BudgetCategories].
/// A coluna [categoryId] é legada (mantida para compatibilidade de migration)
/// e não deve ser usada pelo código da aplicação.
@DataClassName('Budget')
class Budgets extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()(); // nome do orçamento (ex: "Alimentação")
  TextColumn get categoryId =>
      text().nullable().references(Categories, #id)(); // legada, usar budget_categories
  IntColumn get year => integer()();
  IntColumn get month => integer()(); // 1–12
  IntColumn get amount => integer()(); // centavos planejados
  IntColumn get rolloverAmount =>
      integer().withDefault(const Constant(0))(); // centavos do mês anterior
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
