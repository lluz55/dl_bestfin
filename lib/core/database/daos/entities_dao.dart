import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'package:bestfin/core/database/app_database.dart';
import 'package:bestfin/core/database/tables/entities.dart';

part 'entities_dao.g.dart';

@DriftAccessor(tables: [Entities])
class EntitiesDao extends DatabaseAccessor<AppDatabase>
    with _$EntitiesDaoMixin {
  EntitiesDao(super.db);

  Stream<List<Entity>> watchAllEntities() {
    return (select(entities)..orderBy([
          (t) => OrderingTerm(expression: t.useCount, mode: OrderingMode.desc),
        ]))
        .watch();
  }

  Future<Entity> getEntityById(String id) {
    return (select(entities)..where((t) => t.id.equals(id))).getSingle();
  }

  Future<Entity?> getEntityByIdOrNull(String id) {
    return (select(entities)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<int> insertEntity(EntitiesCompanion entity) async {
    final res = await into(entities).insert(entity);
    final id = entity.id.value;
    await _enqueueEntitySync(id, 'insert');
    return res;
  }

  Future<bool> updateEntity(EntitiesCompanion entity) async {
    final res = await update(entities).replace(entity);
    final id = entity.id.value;
    await _enqueueEntitySync(id, 'update');
    return res;
  }

  Future<int> deleteEntity(String id) async {
    await _enqueueEntitySync(id, 'delete');
    return (delete(entities)..where((t) => t.id.equals(id))).go();
  }

  Future<void> _enqueueEntitySync(String id, String operation) async {
    final entity = await getEntityByIdOrNull(id);

    final payload = entity == null
        ? <String, dynamic>{'id': id}
        : <String, dynamic>{
            'id': entity.id,
            'name': entity.name,
            'type': entity.type,
            'category': entity.category,
            'use_count': entity.useCount,
            'created_at': entity.createdAt.toIso8601String(),
            'updated_at': entity.updatedAt.toIso8601String(),
          };

    await db.syncQueueDao.enqueue(
      id: const Uuid().v4(),
      operation: operation,
      entityType: 'entity',
      entityId: id,
      payload: jsonEncode(payload),
    );
  }
}
