import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/entities.dart';

part 'entities_dao.g.dart';

@DriftAccessor(tables: [Entities])
class EntitiesDao extends DatabaseAccessor<AppDatabase>
    with _$EntitiesDaoMixin {
  EntitiesDao(AppDatabase db) : super(db);

  Stream<List<Entity>> watchAllEntities() {
    return (select(entities)..orderBy([
          (t) => OrderingTerm(expression: t.useCount, mode: OrderingMode.desc),
        ]))
        .watch();
  }

  Future<Entity> getEntityById(String id) {
    return (select(entities)..where((t) => t.id.equals(id))).getSingle();
  }

  Future<int> insertEntity(EntitiesCompanion entity) {
    return into(entities).insert(entity);
  }

  Future<bool> updateEntity(EntitiesCompanion entity) {
    return update(entities).replace(entity);
  }

  Future<int> deleteEntity(String id) {
    return (delete(entities)..where((t) => t.id.equals(id))).go();
  }
}
