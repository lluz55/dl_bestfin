import 'dart:async';

import 'package:bestfin/core/database/app_database.dart' as db;
import 'package:bestfin/features/categories/domain/models/category.dart';

/// Read-side cache of the enriched (parent/child) category tree.
///
/// Extracted from [TransactionRepositoryImpl] (task 58 — refatoração de "god
/// files"). O mapa enriquecido é consultado a cada emissão dos streams de
/// transação, mas categorias e seus relacionamentos mudam com pouca frequência,
/// então cacheamos o Future e o invalidamos apenas quando essas tabelas
/// realmente mudam — evitando refazer a árvore inteira a cada gravação de
/// transação. Guardar o Future (e não o Map) também dedupa reconstruções
/// concorrentes disparadas por emissões simultâneas.
class EnrichedCategoryCache {
  EnrichedCategoryCache(this._database) {
    _categoriesInvalidationSub = _database.categoriesDao
        .watchAllCategories()
        .listen((_) => _cached = null);
    _relationshipsInvalidationSub = _database.categoriesDao
        .watchAllRelationships()
        .listen((_) => _cached = null);
  }

  final db.AppDatabase _database;

  Future<Map<String, CategoryModel>>? _cached;
  StreamSubscription<void>? _categoriesInvalidationSub;
  StreamSubscription<void>? _relationshipsInvalidationSub;

  /// Retorna o mapa enriquecido, construindo-o (e cacheando) na primeira chamada
  /// e reaproveitando o cache até que categorias/relacionamentos mudem.
  Future<Map<String, CategoryModel>> load() {
    return _cached ??= _build();
  }

  void dispose() {
    unawaited(_categoriesInvalidationSub?.cancel());
    unawaited(_relationshipsInvalidationSub?.cancel());
  }

  Future<Map<String, CategoryModel>> _build() async {
    final flatList = await _database.categoriesDao.watchAllCategories().first;
    final active = flatList.where((c) => !c.isArchived).toList();
    final filteredIds = active.map((c) => c.id).toSet();
    final relationships = await _database.categoriesDao.getAllRelationships();

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

    final allModels = <String, CategoryModel>{
      for (final c in active)
        c.id: CategoryModel.fromDb(c, parentIds: childToParentIds[c.id] ?? []),
    };

    final Map<String, CategoryModel> enrichedMap = {};
    CategoryModel nest(
      String id, {
      String? parentName,
      String? parentIcon,
      String? parentColor,
    }) {
      final base = allModels[id]!;
      final children = (parentToChildIds[id] ?? [])
          .where(filteredIds.contains)
          .map(
            (cid) => nest(
              cid,
              parentName: base.name,
              parentIcon: base.icon,
              parentColor: base.color,
            ),
          )
          .toList();
      final enriched = base.copyWith(
        children: children,
        parentName: parentName,
        parentIcon: parentIcon,
        parentColor: parentColor,
      );
      enrichedMap[id] = enriched;
      return enriched;
    }

    for (final model in allModels.values) {
      if (model.isRoot) {
        nest(model.id);
      }
    }

    return enrichedMap;
  }
}
