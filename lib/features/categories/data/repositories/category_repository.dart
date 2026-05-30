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
    String? description,
  });
  Future<void> updateCategory({
    required String id,
    required String name,
    required String icon,
    required String color,
    required String type,
    String? description,
  });
  Future<void> setCategoryChildren(String parentId, List<String> childIds);
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

    final filteredIds = filtered.map((c) => c.id).toSet();

    // Load all parent-child relationships from junction table
    final relationships = await _database.categoriesDao.getAllRelationships();

    // Build maps: childId → parentIds, parentId → childIds
    final childToParentIds = <String, List<String>>{};
    final parentToChildIds = <String, List<String>>{};
    for (final rel in relationships) {
      if (filteredIds.contains(rel.parentCategoryId) &&
          filteredIds.contains(rel.childCategoryId)) {
        childToParentIds
            .putIfAbsent(rel.childCategoryId, () => [])
            .add(rel.parentCategoryId);
        parentToChildIds
            .putIfAbsent(rel.parentCategoryId, () => [])
            .add(rel.childCategoryId);
      }
    }

    // Build base models with parentIds populated
    final allModels = <String, CategoryModel>{
      for (final c in filtered)
        c.id: CategoryModel.fromDb(
          c,
          parentIds: childToParentIds[c.id] ?? [],
        ),
    };

    // Identify roots (no parents within filtered set)
    final roots = <CategoryModel>[];
    for (final model in allModels.values) {
      if (model.isRoot) {
        final childIds = parentToChildIds[model.id] ?? [];
        final children = childIds
            .where(filteredIds.contains)
            .map(
              (id) => allModels[id]!.copyWith(
                parentName: model.name,
                parentIcon: model.icon,
                parentColor: model.color,
              ),
            )
            .toList()
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
    String? description,
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
        description: description != null
            ? Value(description)
            : const Value.absent(),
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
    String? description,
  }) async {
    await (_database.update(
      _database.categories,
    )..where((t) => t.id.equals(id))).write(
      db.CategoriesCompanion(
        name: Value(name),
        icon: Value(icon),
        color: Value(color),
        type: Value(type),
        description: Value(description),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<void> setCategoryChildren(
    String parentId,
    List<String> childIds,
  ) async {
    await _database.categoriesDao.deleteChildrenForParent(parentId);
    if (childIds.isNotEmpty) {
      await _database.categoriesDao.insertChildrenForParent(parentId, childIds);
    }
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
