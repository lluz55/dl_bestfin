import 'package:drift/drift.dart';
import 'goals.dart';
import 'categories.dart';

@DataClassName('GoalCategory')
class GoalCategories extends Table {
  TextColumn get goalId =>
      text().references(Goals, #id, onDelete: KeyAction.cascade)();
  TextColumn get categoryId =>
      text().references(Categories, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column> get primaryKey => {goalId, categoryId};
}
