import 'dart:async';
import 'dart:convert';

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

  // Emits whenever categories OR category_parents changes so that parent-child
  // relationship updates (setCategoryChildren) are immediately reflected.
  Stream<void> _changesStream() {
    StreamSubscription? s1, s2;
    late StreamController<void> ctrl;
    ctrl = StreamController<void>(
      onListen: () {
        s1 = _database.categoriesDao.watchAllCategories().listen(
          (_) => ctrl.add(null),
          onError: ctrl.addError,
        );
        s2 = _database.categoriesDao.watchAllRelationships().listen(
          (_) => ctrl.add(null),
          onError: ctrl.addError,
        );
      },
      onCancel: () {
        s1?.cancel();
        s2?.cancel();
      },
    );
    return ctrl.stream;
  }

  @override
  Stream<List<CategoryModel>> watchCategoriesTree() {
    return _changesStream().asyncMap((_) async {
      final cats = await _database.categoriesDao.watchAllCategories().first;
      return _buildTree(cats);
    });
  }

  @override
  Stream<List<CategoryModel>> watchCategoriesTreeByType(String type) {
    return _changesStream().asyncMap((_) async {
      final cats = await _database.categoriesDao.watchAllCategories().first;
      return _buildTree(cats, typeFilter: type);
    });
  }

  CategoryModel _nestCategory(
    String id,
    Map<String, CategoryModel> allModels,
    Map<String, List<String>> parentToChildIds,
    Set<String> filteredIds, {
    String? parentName,
    String? parentIcon,
    String? parentColor,
  }) {
    final base = allModels[id]!;
    final childIds = (parentToChildIds[id] ?? [])
        .where(filteredIds.contains)
        .toList();
    final children =
        childIds
            .map(
              (cid) => _nestCategory(
                cid,
                allModels,
                parentToChildIds,
                filteredIds,
                parentName: base.name,
                parentIcon: base.icon,
                parentColor: base.color,
              ),
            )
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    return base.copyWith(
      children: children,
      parentName: parentName,
      parentIcon: parentIcon,
      parentColor: parentColor,
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
        c.id: CategoryModel.fromDb(c, parentIds: childToParentIds[c.id] ?? []),
    };

    // Identify roots (no parents within filtered set)
    final roots = <CategoryModel>[];
    for (final model in allModels.values) {
      if (model.isRoot) {
        roots.add(
          _nestCategory(model.id, allModels, parentToChildIds, filteredIds),
        );
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
    await _enqueueCategorySync(id, 'insert');
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
    await _enqueueCategorySync(id, 'update');
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
    await _enqueueCategorySync(parentId, 'update');
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
    await _enqueueCategorySync(id, 'update');
  }

  @override
  Future<void> deleteCategory(String id) async {
    await _enqueueCategorySync(id, 'delete');
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

  Future<void> _enqueueCategorySync(String id, String operation) async {
    final category = await (_database.select(
      _database.categories,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    final relationships = await (_database.select(
      _database.categoryParents,
    )..where((r) => r.parentCategoryId.equals(id))).get();

    final payload = category == null
        ? <String, dynamic>{'id': id}
        : <String, dynamic>{
            'id': category.id,
            'name': category.name,
            'icon': category.icon,
            'color': category.color,
            'type': category.type,
            'is_system': category.isSystem,
            'parent_id': category.parentId,
            'is_archived': category.isArchived,
            'description': category.description,
            'created_at': category.createdAt.toIso8601String(),
            'updated_at': category.updatedAt.toIso8601String(),
            'child_ids': relationships.map((r) => r.childCategoryId).toList(),
          };

    await _database.syncQueueDao.enqueue(
      id: const Uuid().v4(),
      operation: operation,
      entityType: 'category',
      entityId: id,
      payload: jsonEncode(payload),
    );
  }
}
