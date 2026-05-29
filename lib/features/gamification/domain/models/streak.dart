import 'package:bestfin/core/database/app_database.dart' as db;

enum StreakType {
  recording('recording', 'Registros diários'),
  budget('budget', 'Sob orçamento');

  const StreakType(this.value, this.label);
  final String value;
  final String label;

  static StreakType fromString(String val) {
    return StreakType.values.firstWhere(
      (s) => s.value == val,
      orElse: () => StreakType.recording,
    );
  }
}

class StreakModel {
  final String id;
  final StreakType type;
  final int currentCount;
  final int longestCount;
  final DateTime? lastDate;
  final bool isActive;

  const StreakModel({
    required this.id,
    required this.type,
    required this.currentCount,
    required this.longestCount,
    this.lastDate,
    required this.isActive,
  });

  factory StreakModel.fromDb(db.Streak s) {
    return StreakModel(
      id: s.id,
      type: StreakType.fromString(s.type),
      currentCount: s.currentCount,
      longestCount: s.longestCount,
      lastDate: s.lastDate,
      isActive: s.isActive,
    );
  }
}
