import 'package:bestfin/core/database/app_database.dart' as db;
import 'package:bestfin/features/sync/domain/models/household.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

abstract class HouseholdRepository {
  Stream<List<HouseholdModel>> watchAll();
  Future<HouseholdModel> createHousehold(String name, String createdBy);
  Future<void> deleteHousehold(String id);
  Future<HouseholdMemberModel> inviteMember({
    required String householdId,
    required String email,
    required MemberRole role,
  });
  Future<void> removeMember(String memberId);
  Future<void> updateMemberRole(String memberId, MemberRole role);
}

class HouseholdRepositoryImpl implements HouseholdRepository {
  final db.AppDatabase _database;

  HouseholdRepositoryImpl(this._database);

  @override
  Stream<List<HouseholdModel>> watchAll() {
    return _database.householdsDao.watchAllHouseholds().asyncMap((rows) async {
      final models = <HouseholdModel>[];
      for (final h in rows) {
        final memberRows = await (_database.select(
          _database.householdMembers,
        )..where((m) => m.householdId.equals(h.id))).get();
        models.add(
          HouseholdModel.fromDb(
            h,
            members: memberRows.map(HouseholdMemberModel.fromDb).toList(),
          ),
        );
      }
      return models;
    });
  }

  @override
  Future<HouseholdModel> createHousehold(String name, String createdBy) async {
    final id = const Uuid().v4();
    await _database.householdsDao.upsertHousehold(
      db.HouseholdsCompanion.insert(id: id, name: name, createdBy: createdBy),
    );
    // Auto-add creator as admin
    await _database.householdsDao.upsertMember(
      db.HouseholdMembersCompanion.insert(
        id: const Uuid().v4(),
        householdId: id,
        email: createdBy,
        role: const Value('admin'),
        accepted: const Value(true),
      ),
    );
    return HouseholdModel(
      id: id,
      name: name,
      createdBy: createdBy,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<void> deleteHousehold(String id) async {
    await _database.householdsDao.deleteHousehold(id);
  }

  @override
  Future<HouseholdMemberModel> inviteMember({
    required String householdId,
    required String email,
    required MemberRole role,
  }) async {
    final id = const Uuid().v4();
    await _database.householdsDao.upsertMember(
      db.HouseholdMembersCompanion.insert(
        id: id,
        householdId: householdId,
        email: email,
        role: Value(role.value),
      ),
    );
    return HouseholdMemberModel(
      id: id,
      householdId: householdId,
      email: email,
      role: role,
      accepted: false,
      invitedAt: DateTime.now(),
    );
  }

  @override
  Future<void> removeMember(String memberId) async {
    await _database.householdsDao.removeMember(memberId);
  }

  @override
  Future<void> updateMemberRole(String memberId, MemberRole role) async {
    await (_database.update(_database.householdMembers)
          ..where((m) => m.id.equals(memberId)))
        .write(db.HouseholdMembersCompanion(role: Value(role.value)));
  }
}
