import 'package:bestfin/features/transactions/domain/models/transaction.dart';

class InstallmentPlanModel {
  final String id;
  final String originTransactionId;
  final int totalInstallments;
  final int installmentValue; // in cents
  final DateTime createdAt;
  final List<TransactionModel> transactions;

  InstallmentPlanModel({
    required this.id,
    required this.originTransactionId,
    required this.totalInstallments,
    required this.installmentValue,
    required this.createdAt,
    this.transactions = const [],
  });

  int get paidInstallments => transactions.where((t) => t.isCompleted).length;

  bool get isCompleted => paidInstallments >= totalInstallments;

  int get totalAmount => transactions.fold(0, (sum, t) => sum + t.amount);
}
