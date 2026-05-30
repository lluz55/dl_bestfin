import 'package:bestfin/core/database/app_database.dart' as db;

class CreditCardModel {
  final String id;
  final String name;
  final int limitAmount; // in cents (e.g. 500000 = R$ 5.000,00)
  final int closingDay;
  final int dueDay;
  final String accountId;
  final String? color;
  final int minPaymentPercent;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Loaded/Computed relations
  final int usedLimit; // in cents
  final int availableLimit; // in cents

  const CreditCardModel({
    required this.id,
    required this.name,
    required this.limitAmount,
    required this.closingDay,
    required this.dueDay,
    required this.accountId,
    this.color,
    this.minPaymentPercent = 15,
    required this.isArchived,
    required this.createdAt,
    required this.updatedAt,
    this.usedLimit = 0,
    this.availableLimit = 0,
  });

  factory CreditCardModel.fromDb(db.CreditCard card, {int usedLimit = 0}) {
    return CreditCardModel(
      id: card.id,
      name: card.name,
      limitAmount: card.limitAmount,
      closingDay: card.closingDay,
      dueDay: card.dueDay,
      accountId: card.accountId,
      color: card.color,
      minPaymentPercent: card.minPaymentPercent,
      isArchived: card.isArchived,
      createdAt: card.createdAt,
      updatedAt: card.updatedAt,
      usedLimit: usedLimit,
      availableLimit: card.limitAmount - usedLimit,
    );
  }

  CreditCardModel copyWith({
    String? id,
    String? name,
    int? limitAmount,
    int? closingDay,
    int? dueDay,
    String? accountId,
    String? color,
    int? minPaymentPercent,
    bool? isArchived,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? usedLimit,
    int? availableLimit,
  }) {
    return CreditCardModel(
      id: id ?? this.id,
      name: name ?? this.name,
      limitAmount: limitAmount ?? this.limitAmount,
      closingDay: closingDay ?? this.closingDay,
      dueDay: dueDay ?? this.dueDay,
      accountId: accountId ?? this.accountId,
      color: color ?? this.color,
      minPaymentPercent: minPaymentPercent ?? this.minPaymentPercent,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      usedLimit: usedLimit ?? this.usedLimit,
      availableLimit: availableLimit ?? this.availableLimit,
    );
  }
}
