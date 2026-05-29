import 'package:bestfin/core/database/app_database.dart' as db;

class Financing {
  final String id;
  final String name;
  final int totalAmount; // in cents
  final int outstandingBalance; // in cents
  final double interestRate; // % per month, e.g. 1.5
  final int totalInstallments;
  final String amortizationSystem; // sac, price
  final DateTime createdAt;
  final DateTime updatedAt;

  const Financing({
    required this.id,
    required this.name,
    required this.totalAmount,
    required this.outstandingBalance,
    required this.interestRate,
    required this.totalInstallments,
    required this.amortizationSystem,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Financing.fromDb(db.Financing dbFinancing) {
    return Financing(
      id: dbFinancing.id,
      name: dbFinancing.name,
      totalAmount: dbFinancing.totalAmount,
      outstandingBalance: dbFinancing.outstandingBalance,
      interestRate: dbFinancing.interestRate,
      totalInstallments: dbFinancing.totalInstallments,
      amortizationSystem: dbFinancing.amortizationSystem,
      createdAt: dbFinancing.createdAt,
      updatedAt: dbFinancing.updatedAt,
    );
  }

  String get systemLabel => amortizationSystem.toUpperCase();

  Financing copyWith({
    String? id,
    String? name,
    int? totalAmount,
    int? outstandingBalance,
    double? interestRate,
    int? totalInstallments,
    String? amortizationSystem,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Financing(
      id: id ?? this.id,
      name: name ?? this.name,
      totalAmount: totalAmount ?? this.totalAmount,
      outstandingBalance: outstandingBalance ?? this.outstandingBalance,
      interestRate: interestRate ?? this.interestRate,
      totalInstallments: totalInstallments ?? this.totalInstallments,
      amortizationSystem: amortizationSystem ?? this.amortizationSystem,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
