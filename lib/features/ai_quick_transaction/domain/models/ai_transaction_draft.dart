import 'package:bestfin/core/constants/transaction_types.dart';
import 'package:bestfin/features/recurring/domain/models/recurring_rule.dart';

typedef CategorySuggestion = ({String id, String name});

class AiTransactionDraft {
  final double amount;
  final String description;
  final TransactionType? type;
  final String? categoryId;
  final String? categoryName;
  final List<CategorySuggestion> categorySuggestions;
  final String? accountId;
  final String? accountName;
  // Transfer destination; null for non-transfers
  final String? toAccountId;
  final String? toAccountName;
  // Counterpart entity: payee for expense, payer for income; null for transfer
  final String? entityName;
  final DateTime date;
  final String rawInput;
  final bool isRecurring;
  final RecurringFrequency? recurringFrequency;

  const AiTransactionDraft({
    required this.amount,
    required this.description,
    this.type,
    this.categoryId,
    this.categoryName,
    this.categorySuggestions = const [],
    this.accountId,
    this.accountName,
    this.toAccountId,
    this.toAccountName,
    this.entityName,
    required this.date,
    required this.rawInput,
    this.isRecurring = false,
    this.recurringFrequency,
  });

  /// All required fields are filled; the transaction can be saved.
  bool get isComplete {
    if (amount <= 0) return false;
    if (categoryId == null) return false;
    if (accountId == null) return false;
    if (type == TransactionType.transfer) {
      return toAccountId != null && toAccountId != accountId;
    }
    return entityName != null && entityName!.trim().isNotEmpty;
  }

  AiTransactionDraft copyWith({
    double? amount,
    String? description,
    Object? type = _sentinel,
    Object? categoryId = _sentinel,
    Object? categoryName = _sentinel,
    List<CategorySuggestion>? categorySuggestions,
    Object? accountId = _sentinel,
    Object? accountName = _sentinel,
    Object? toAccountId = _sentinel,
    Object? toAccountName = _sentinel,
    Object? entityName = _sentinel,
    DateTime? date,
    String? rawInput,
    bool? isRecurring,
    Object? recurringFrequency = _sentinel,
  }) {
    return AiTransactionDraft(
      amount: amount ?? this.amount,
      description: description ?? this.description,
      type: type == _sentinel ? this.type : type as TransactionType?,
      categoryId: categoryId == _sentinel
          ? this.categoryId
          : categoryId as String?,
      categoryName: categoryName == _sentinel
          ? this.categoryName
          : categoryName as String?,
      categorySuggestions: categorySuggestions ?? this.categorySuggestions,
      accountId: accountId == _sentinel ? this.accountId : accountId as String?,
      accountName: accountName == _sentinel
          ? this.accountName
          : accountName as String?,
      toAccountId: toAccountId == _sentinel
          ? this.toAccountId
          : toAccountId as String?,
      toAccountName: toAccountName == _sentinel
          ? this.toAccountName
          : toAccountName as String?,
      entityName: entityName == _sentinel
          ? this.entityName
          : entityName as String?,
      date: date ?? this.date,
      rawInput: rawInput ?? this.rawInput,
      isRecurring: isRecurring ?? this.isRecurring,
      recurringFrequency: recurringFrequency == _sentinel
          ? this.recurringFrequency
          : recurringFrequency as RecurringFrequency?,
    );
  }
}

const _sentinel = Object();
