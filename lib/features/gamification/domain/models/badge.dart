import 'package:bestfin/core/database/app_database.dart' as db;

class BadgeModel {
  final String id;
  final String badgeKey;
  final String title;
  final String description;
  final DateTime? unlockedAt;
  final String iconAsset;

  const BadgeModel({
    required this.id,
    required this.badgeKey,
    required this.title,
    required this.description,
    this.unlockedAt,
    required this.iconAsset,
  });

  bool get isUnlocked => unlockedAt != null;

  factory BadgeModel.fromDb(db.Badge b) {
    return BadgeModel(
      id: b.id,
      badgeKey: b.badgeKey,
      title: b.title,
      description: b.description,
      unlockedAt: b.unlockedAt,
      iconAsset: b.iconAsset,
    );
  }
}
