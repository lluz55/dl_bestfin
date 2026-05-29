import 'package:bestfin/core/database/app_database.dart' as db;

class Investment {
  final String id;
  final String name;
  final String
  type; // fixed_income, stocks, fiis, crypto, savings, cdb, tesouro
  final int investedAmount; // in cents
  final int currentYield; // in cents (can be negative for loss)
  final DateTime? maturityDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Investment({
    required this.id,
    required this.name,
    required this.type,
    required this.investedAmount,
    required this.currentYield,
    this.maturityDate,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Investment.fromDb(db.Investment dbInvestment) {
    return Investment(
      id: dbInvestment.id,
      name: dbInvestment.name,
      type: dbInvestment.type,
      investedAmount: dbInvestment.investedAmount,
      currentYield: dbInvestment.currentYield,
      maturityDate: dbInvestment.maturityDate,
      createdAt: dbInvestment.createdAt,
      updatedAt: dbInvestment.updatedAt,
    );
  }

  int get totalValue => investedAmount + currentYield;

  double get yieldPercentage {
    if (investedAmount == 0) return 0.0;
    return (currentYield / investedAmount) * 100.0;
  }

  String get typeLabel {
    switch (type) {
      case 'fixed_income':
        return 'Renda Fixa';
      case 'stocks':
        return 'Ações';
      case 'fiis':
        return 'FIIs';
      case 'crypto':
        return 'Criptomoedas';
      case 'savings':
        return 'Poupança';
      case 'cdb':
        return 'CDB';
      case 'tesouro':
        return 'Tesouro Direto';
      default:
        return 'Outros';
    }
  }

  Investment copyWith({
    String? id,
    String? name,
    String? type,
    int? investedAmount,
    int? currentYield,
    DateTime? maturityDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Investment(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      investedAmount: investedAmount ?? this.investedAmount,
      currentYield: currentYield ?? this.currentYield,
      maturityDate: maturityDate ?? this.maturityDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
