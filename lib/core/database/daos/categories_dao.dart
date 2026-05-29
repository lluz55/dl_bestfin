import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/categories.dart';

part 'categories_dao.g.dart';

@DriftAccessor(tables: [Categories])
class CategoriesDao extends DatabaseAccessor<AppDatabase>
    with _$CategoriesDaoMixin {
  CategoriesDao(AppDatabase db) : super(db);

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
}
