import 'package:bestfin/core/database/app_database.dart' as db;
import 'package:bestfin/features/categories/domain/models/category.dart';
import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

const _kOrderKey = 'category_root_order';

abstract class CategoryRepository {
  Stream<List<CategoryModel>> watchCategoriesTree();
  Stream<List<CategoryModel>> watchCategoriesTreeByType(String type);
  Future<CategoryModel?> getCategoryById(String id);
  Future<String> createCategory({
    required String name,
    required String icon,
    required String color,
    required String type,
    String? parentId,
  });
  Future<void> updateCategory({
    required String id,
    required String name,
    required String icon,
    required String color,
    required String type,
    String? parentId,
  });
  Future<void> archiveCategory(String id);
  Future<void> deleteCategory(String id);
  Future<bool> hasTransactions(String id);
  Future<void> saveRootOrder(List<String> orderedIds);
}

class CategoryRepositoryImpl implements CategoryRepository {
  final db.AppDatabase _database;

  CategoryRepositoryImpl(this._database);

  @override
  Stream<List<CategoryModel>> watchCategoriesTree() {
    return _database.categoriesDao.watchAllCategories().asyncMap(_buildTree);
  }

  @override
  Stream<List<CategoryModel>> watchCategoriesTreeByType(String type) {
    return _database.categoriesDao.watchAllCategories().asyncMap(
      (list) => _buildTree(list, typeFilter: type),
    );
  }

  Future<List<CategoryModel>> _buildTree(
    List<db.Category> flatList, {
    String? typeFilter,
  }) async {
    final active = flatList.where((c) => !c.isArchived).toList();

    final List<db.Category> filtered;
    if (typeFilter != null) {
      filtered = active.where((c) => c.type == typeFilter).toList();
    } else {
      filtered = active;
    }

    final allModels = filtered.map((c) => CategoryModel.fromDb(c)).toList();

    final roots = <CategoryModel>[];
    for (final model in allModels) {
      if (model.parentId == null) {
        final children = allModels.where((m) => m.parentId == model.id).toList()
          ..sort((a, b) => a.name.compareTo(b.name));
        roots.add(model.copyWith(children: children));
      }
    }

    final prefs = await SharedPreferences.getInstance();
    final savedOrder = prefs.getStringList(_kOrderKey);
    if (savedOrder != null && savedOrder.isNotEmpty) {
      roots.sort((a, b) {
        final ai = savedOrder.indexOf(a.id);
        final bi = savedOrder.indexOf(b.id);
        if (ai == -1 && bi == -1) return a.name.compareTo(b.name);
        if (ai == -1) return 1;
        if (bi == -1) return -1;
        return ai.compareTo(bi);
      });
    } else {
      roots.sort((a, b) => a.name.compareTo(b.name));
    }

    return roots;
  }

  @override
  Future<CategoryModel?> getCategoryById(String id) async {
    try {
      final entity = await _database.categoriesDao.getCategoryById(id);
      return CategoryModel.fromDb(entity);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String> createCategory({
    required String name,
    required String icon,
    required String color,
    required String type,
    String? parentId,
  }) async {
    final id = const Uuid().v4();
    await _database.categoriesDao.insertCategory(
      db.CategoriesCompanion.insert(
        id: id,
        name: name,
        icon: icon,
        color: color,
        type: type,
        isSystem: const Value(false),
        parentId: parentId != null ? Value(parentId) : const Value.absent(),
      ),
    );
    return id;
  }

  @override
  Future<void> updateCategory({
    required String id,
    required String name,
    required String icon,
    required String color,
    required String type,
    String? parentId,
  }) async {
    await (_database.update(
      _database.categories,
    )..where((t) => t.id.equals(id))).write(
      db.CategoriesCompanion(
        name: Value(name),
        icon: Value(icon),
        color: Value(color),
        type: Value(type),
        parentId: Value(parentId),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<void> archiveCategory(String id) async {
    await (_database.update(
      _database.categories,
    )..where((t) => t.id.equals(id))).write(
      db.CategoriesCompanion(
        isArchived: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<void> deleteCategory(String id) async {
    await _database.categoriesDao.deleteCategory(id);
  }

  @override
  Future<bool> hasTransactions(String id) async {
    final countExpr = _database.transactions.id.count();
    final query = _database.selectOnly(_database.transactions)
      ..addColumns([countExpr])
      ..where(_database.transactions.categoryId.equals(id));

    final row = await query.getSingle();
    final count = row.read(countExpr) ?? 0;
    return count > 0;
  }

  @override
  Future<void> saveRootOrder(List<String> orderedIds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kOrderKey, orderedIds);
  }
}
