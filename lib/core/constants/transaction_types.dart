import 'package:flutter/material.dart';

enum TransactionType {
  income,
  expense,
  transfer;

  String get label {
    switch (this) {
      case TransactionType.income:
        return 'Receita';
      case TransactionType.expense:
        return 'Despesa';
      case TransactionType.transfer:
        return 'Transferência';
    }
  }

  IconData get icon {
    switch (this) {
      case TransactionType.income:
        return Icons.arrow_downward_rounded;
      case TransactionType.expense:
        return Icons.arrow_upward_rounded;
      case TransactionType.transfer:
        return Icons.swap_horiz_rounded;
    }
  }

  static TransactionType fromString(String value) {
    return TransactionType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => TransactionType.expense,
    );
  }
}
