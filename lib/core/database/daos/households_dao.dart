import 'package:drift/drift.dart';
import 'package:bestfin/core/database/app_database.dart';
import 'package:bestfin/core/database/tables/households.dart';

part 'households_dao.g.dart';

@DriftAccessor(tables: [Households, HouseholdMembers])
class HouseholdsDao extends DatabaseAccessor<AppDatabase>
    with _$HouseholdsDaoMixin {
  HouseholdsDao(super.db);

  Stream<List<Household>> watchAllHouseholds() {
    return select(households).watch();
  }

  Future<Household?> getHouseholdById(String id) {
    return (select(
      households,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<void> upsertHousehold(HouseholdsCompanion companion) async {
    await into(households).insertOnConflictUpdate(companion);
  }

  Future<void> deleteHousehold(String id) async {
    await (delete(
      householdMembers,
    )..where((m) => m.householdId.equals(id))).go();
    await (delete(households)..where((t) => t.id.equals(id))).go();
  }

  Stream<List<HouseholdMember>> watchMembersOf(String householdId) {
    return (select(
      householdMembers,
    )..where((m) => m.householdId.equals(householdId))).watch();
  }

  Future<void> upsertMember(HouseholdMembersCompanion companion) async {
    await into(householdMembers).insertOnConflictUpdate(companion);
  }

  Future<void> removeMember(String memberId) async {
    await (delete(householdMembers)..where((m) => m.id.equals(memberId))).go();
  }

  Future<void> acceptInvite(String memberId) async {
    await (update(householdMembers)..where((m) => m.id.equals(memberId))).write(
      HouseholdMembersCompanion(
        accepted: const Value(true),
        acceptedAt: Value(DateTime.now()),
      ),
    );
  }
}
