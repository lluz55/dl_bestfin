import 'package:bestfin/core/database/app_database.dart' as db;

class NotificationPatternModel {
  final String id;
  final String bankName;
  final String regexPattern;
  final bool isEnabled;
  final String? defaultCategoryId;
  final String? defaultAccountId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const NotificationPatternModel({
    required this.id,
    required this.bankName,
    required this.regexPattern,
    required this.isEnabled,
    this.defaultCategoryId,
    this.defaultAccountId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory NotificationPatternModel.fromDb(db.NotificationPattern p) {
    return NotificationPatternModel(
      id: p.id,
      bankName: p.bankName,
      regexPattern: p.regexPattern,
      isEnabled: p.isEnabled,
      defaultCategoryId: p.defaultCategoryId,
      defaultAccountId: p.defaultAccountId,
      createdAt: p.createdAt,
      updatedAt: p.updatedAt,
    );
  }

  NotificationPatternModel copyWith({
    String? bankName,
    String? regexPattern,
    bool? isEnabled,
    String? defaultCategoryId,
    String? defaultAccountId,
  }) {
    return NotificationPatternModel(
      id: id,
      bankName: bankName ?? this.bankName,
      regexPattern: regexPattern ?? this.regexPattern,
      isEnabled: isEnabled ?? this.isEnabled,
      defaultCategoryId: defaultCategoryId ?? this.defaultCategoryId,
      defaultAccountId: defaultAccountId ?? this.defaultAccountId,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
