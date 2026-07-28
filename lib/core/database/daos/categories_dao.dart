import 'package:drift/drift.dart';
import 'package:bestfin/core/database/app_database.dart';
import 'package:bestfin/core/database/tables/categories.dart';
import 'package:bestfin/core/database/tables/category_parents.dart';

part 'categories_dao.g.dart';

@DriftAccessor(tables: [Categories, CategoryParents])
class CategoriesDao extends DatabaseAccessor<AppDatabase>
    with _$CategoriesDaoMixin {
  CategoriesDao(super.db);

  Stream<List<Category>> watchAllCategories() {
    return select(categories).watch();
  }

  Stream<List<Category>> watchCategoriesByType(String type) {
    return (select(categories)..where((t) => t.type.equals(type))).watch();
  }

  Future<Category> getCategoryById(String id) {
    return (select(categories)..where((t) => t.id.equals(id))).getSingle();
  }

  Future<int> insertCategory(CategoriesCompanion category) {
    return into(categories).insert(category);
  }

  Future<bool> updateCategory(CategoriesCompanion category) {
    return update(categories).replace(category);
  }

  Future<int> deleteCategory(String id) {
    return (delete(categories)..where((t) => t.id.equals(id))).go();
  }

  Future<List<CategoryParent>> getAllRelationships() {
    return select(categoryParents).get();
  }

  Stream<List<CategoryParent>> watchAllRelationships() {
    return select(categoryParents).watch();
  }

  Future<void> deleteChildrenForParent(String parentId) {
    return (delete(
      categoryParents,
    )..where((t) => t.parentCategoryId.equals(parentId))).go();
  }

  Future<void> insertChildrenForParent(
    String parentId,
    List<String> childIds,
  ) async {
    await batch((b) {
      b.insertAll(
        categoryParents,
        childIds
            .map(
              (childId) => CategoryParentsCompanion.insert(
                parentCategoryId: parentId,
                childCategoryId: childId,
              ),
            )
            .toList(),
      );
    });
  }
}
