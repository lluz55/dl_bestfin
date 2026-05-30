import 'package:drift/drift.dart';
import 'categories.dart';

@DataClassName('CategoryParent')
class CategoryParents extends Table {
  @ReferenceName('parentRelationships')
  TextColumn get parentCategoryId =>
      text().references(Categories, #id, onDelete: KeyAction.cascade)();

  @ReferenceName('childRelationships')
  TextColumn get childCategoryId =>
      text().references(Categories, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column> get primaryKey => {parentCategoryId, childCategoryId};
}
