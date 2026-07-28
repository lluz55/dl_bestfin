import 'package:drift/drift.dart';
import 'package:bestfin/core/database/tables/budgets.dart';
import 'package:bestfin/core/database/tables/categories.dart';

/// Tabela pivô: relaciona orçamentos a múltiplas categorias (1:N).
@DataClassName('BudgetCategory')
class BudgetCategories extends Table {
  TextColumn get budgetId =>
      text().references(Budgets, #id, onDelete: KeyAction.cascade)();
  TextColumn get categoryId =>
      text().references(Categories, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column> get primaryKey => {budgetId, categoryId};
}
