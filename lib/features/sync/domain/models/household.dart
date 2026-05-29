import 'package:bestfin/core/database/app_database.dart' as db;

enum MemberRole { viewer, editor, admin }

extension MemberRoleExt on MemberRole {
  String get value => name;
  static MemberRole fromString(String s) => MemberRole.values.firstWhere(
    (e) => e.name == s,
    orElse: () => MemberRole.editor,
  );
}

class HouseholdModel {
  final String id;
  final String name;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<HouseholdMemberModel> members;

  const HouseholdModel({
    required this.id,
    required this.name,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.members = const [],
  });

  factory HouseholdModel.fromDb(
    db.Household h, {
    List<HouseholdMemberModel> members = const [],
  }) {
    return HouseholdModel(
      id: h.id,
      name: h.name,
      createdBy: h.createdBy,
      createdAt: h.createdAt,
      updatedAt: h.updatedAt,
      members: members,
    );
  }
}

class HouseholdMemberModel {
  final String id;
  final String householdId;
  final String email;
  final MemberRole role;
  final bool accepted;
  final DateTime invitedAt;
  final DateTime? acceptedAt;

  const HouseholdMemberModel({
    required this.id,
    required this.householdId,
    required this.email,
    required this.role,
    required this.accepted,
    required this.invitedAt,
    this.acceptedAt,
  });

  factory HouseholdMemberModel.fromDb(db.HouseholdMember m) {
    return HouseholdMemberModel(
      id: m.id,
      householdId: m.householdId,
      email: m.email,
      role: MemberRoleExt.fromString(m.role),
      accepted: m.accepted,
      invitedAt: m.invitedAt,
      acceptedAt: m.acceptedAt,
    );
  }
}
