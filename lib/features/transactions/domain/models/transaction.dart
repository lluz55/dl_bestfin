import 'package:bestfin/core/constants/transaction_types.dart';
import 'package:bestfin/core/constants/sentiment_types.dart';
import 'package:bestfin/features/categories/domain/models/category.dart';
import 'package:bestfin/core/database/app_database.dart' as db;
import 'entry.dart';

class TransactionModel {
  final String id;
  final DateTime date;
  final String description;
  final TransactionType type;
  final SentimentType? sentiment;
  final String? notes;
  final String? categoryId;
  final String? entityId;
  final String? goalId;
  final String? installmentPlanId;
  final int? installmentNumber;
  final String? recurringRuleId;
  final String? creditCardId;
  final int? rawAmount;
  final String? invoiceId;
  final bool isCompleted;
  final bool isConfirmed;
  final String? source;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Relações carregadas/agregadas
  final CategoryModel? category;
  final db.Entity? entity;
  final List<EntryModel> entries;

  const TransactionModel({
    required this.id,
    required this.date,
    required this.description,
    required this.type,
    this.sentiment,
    this.notes,
    this.categoryId,
    this.entityId,
    this.goalId,
    this.installmentPlanId,
    this.installmentNumber,
    this.recurringRuleId,
    this.creditCardId,
    this.rawAmount,
    this.invoiceId,
    required this.isCompleted,
    this.isConfirmed = true,
    this.source,
    required this.createdAt,
    required this.updatedAt,
    this.category,
    this.entity,
    this.entries = const [],
  });

  factory TransactionModel.fromDb(
    db.Transaction tx, {
    CategoryModel? category,
    db.Entity? entity,
    List<EntryModel> entries = const [],
    String? recurringRuleId,
  }) {
    return TransactionModel(
      id: tx.id,
      date: tx.date,
      description: tx.description,
      type: TransactionType.fromString(tx.type),
      sentiment: SentimentType.fromString(tx.sentiment),
      notes: tx.notes,
      categoryId: tx.categoryId,
      entityId: tx.entityId,
      goalId: tx.goalId,
      installmentPlanId: tx.installmentPlanId,
      installmentNumber: tx.installmentNumber,
      recurringRuleId: recurringRuleId ?? tx.recurringRuleId,
      creditCardId: tx.creditCardId,
      rawAmount: tx.rawAmount,
      invoiceId: tx.invoiceId,
      isCompleted: tx.isCompleted,
      isConfirmed: tx.isConfirmed,
      source: tx.source,
      createdAt: tx.createdAt,
      updatedAt: tx.updatedAt,
      category: category,
      entity: entity,
      entries: entries,
    );
  }

  /// Retorna o valor monetário da transação
  int get amount {
    if (entries.isNotEmpty) return entries.first.amount;
    return rawAmount ?? 0;
  }

  /// Retorna o ID da conta principal envolvida
  String? get accountId {
    if (entries.isEmpty) return null;
    return entries.first.accountId;
  }

  /// Retorna o ID da conta destino (em caso de transferência)
  String? get toAccountId {
    if (type != TransactionType.transfer || entries.length < 2) return null;
    // Em transferência, um entry é credit (origem) e o outro é debit (destino)
    final debitEntry = entries.firstWhere(
      (e) => e.type == 'debit',
      orElse: () => entries.first,
    );
    return debitEntry.accountId;
  }

  /// Retorna o ID da conta origem (em caso de transferência)
  String? get fromAccountId {
    if (type != TransactionType.transfer || entries.length < 2) return null;
    final creditEntry = entries.firstWhere(
      (e) => e.type == 'credit',
      orElse: () => entries.first,
    );
    return creditEntry.accountId;
  }
}
