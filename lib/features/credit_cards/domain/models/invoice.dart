import 'package:bestfin/core/database/app_database.dart' as db;
import 'package:bestfin/features/transactions/domain/models/transaction.dart';

class InvoiceModel {
  final String id;
  final String creditCardId;
  final int month;
  final int year;
  final String status; // 'open', 'closed', 'paid'
  final DateTime dueDate;
  final DateTime closingDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Loaded/Computed relations
  final List<TransactionModel> transactions;
  final int
  totalAmount; // in cents (calculated sum of all transactions in this invoice)

  const InvoiceModel({
    required this.id,
    required this.creditCardId,
    required this.month,
    required this.year,
    required this.status,
    required this.dueDate,
    required this.closingDate,
    required this.createdAt,
    required this.updatedAt,
    this.transactions = const [],
    this.totalAmount = 0,
  });

  factory InvoiceModel.fromDb(
    db.Invoice invoice, {
    List<TransactionModel> transactions = const [],
    int totalAmount = 0,
  }) {
    return InvoiceModel(
      id: invoice.id,
      creditCardId: invoice.creditCardId,
      month: invoice.month,
      year: invoice.year,
      status: invoice.status,
      dueDate: invoice.dueDate,
      closingDate: invoice.closingDate,
      createdAt: invoice.createdAt,
      updatedAt: invoice.updatedAt,
      transactions: transactions,
      totalAmount: totalAmount,
    );
  }

  String get monthName {
    const months = [
      'Janeiro',
      'Fevereiro',
      'Março',
      'Abril',
      'Maio',
      'Junho',
      'Julho',
      'Agosto',
      'Setembro',
      'Outubro',
      'Novembro',
      'Dezembro',
    ];
    if (month >= 1 && month <= 12) {
      return months[month - 1];
    }
    return '';
  }

  String get shortMonthName {
    final name = monthName;
    if (name.length >= 3) {
      return name.substring(0, 3);
    }
    return name;
  }

  String get statusLabel {
    switch (status) {
      case 'open':
        return 'Aberta';
      case 'closed':
        return 'Fechada';
      case 'paid':
        return 'Paga';
      default:
        return status;
    }
  }

  InvoiceModel copyWith({
    String? id,
    String? creditCardId,
    int? month,
    int? year,
    String? status,
    DateTime? dueDate,
    DateTime? closingDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<TransactionModel>? transactions,
    int? totalAmount,
  }) {
    return InvoiceModel(
      id: id ?? this.id,
      creditCardId: creditCardId ?? this.creditCardId,
      month: month ?? this.month,
      year: year ?? this.year,
      status: status ?? this.status,
      dueDate: dueDate ?? this.dueDate,
      closingDate: closingDate ?? this.closingDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      transactions: transactions ?? this.transactions,
      totalAmount: totalAmount ?? this.totalAmount,
    );
  }
}
