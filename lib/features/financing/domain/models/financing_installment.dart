import 'package:bestfin/core/database/app_database.dart' as db;

class FinancingInstallment {
  final String id;
  final String financingId;
  final int number;
  final int amortizationValue; // in cents
  final int interestValue; // in cents
  final int totalValue; // in cents
  final int remainingBalance; // in cents
  final DateTime dueDate;
  final DateTime? paidDate;
  final DateTime createdAt;

  const FinancingInstallment({
    required this.id,
    required this.financingId,
    required this.number,
    required this.amortizationValue,
    required this.interestValue,
    required this.totalValue,
    required this.remainingBalance,
    required this.dueDate,
    this.paidDate,
    required this.createdAt,
  });

  factory FinancingInstallment.fromDb(db.FinancingInstallment dbInstallment) {
    return FinancingInstallment(
      id: dbInstallment.id,
      financingId: dbInstallment.financingId,
      number: dbInstallment.number,
      amortizationValue: dbInstallment.amortizationValue,
      interestValue: dbInstallment.interestValue,
      totalValue: dbInstallment.totalValue,
      remainingBalance: dbInstallment.remainingBalance,
      dueDate: dbInstallment.dueDate,
      paidDate: dbInstallment.paidDate,
      createdAt: dbInstallment.createdAt,
    );
  }

  bool get isPaid => paidDate != null;

  FinancingInstallment copyWith({
    String? id,
    String? financingId,
    int? number,
    int? amortizationValue,
    int? interestValue,
    int? totalValue,
    int? remainingBalance,
    DateTime? dueDate,
    DateTime? paidDate,
    DateTime? createdAt,
  }) {
    return FinancingInstallment(
      id: id ?? this.id,
      financingId: financingId ?? this.financingId,
      number: number ?? this.number,
      amortizationValue: amortizationValue ?? this.amortizationValue,
      interestValue: interestValue ?? this.interestValue,
      totalValue: totalValue ?? this.totalValue,
      remainingBalance: remainingBalance ?? this.remainingBalance,
      dueDate: dueDate ?? this.dueDate,
      paidDate: paidDate ?? this.paidDate,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
