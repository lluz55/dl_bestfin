import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestfin/core/constants/transaction_types.dart';
import 'package:bestfin/features/transactions/domain/models/transaction.dart';

class TransactionFormModalState {
  final bool isOpen;
  final TransactionType? initialType;
  final TransactionModel? transaction;
  final bool isCloning;

  const TransactionFormModalState({
    this.isOpen = false,
    this.initialType,
    this.transaction,
    this.isCloning = false,
  });

  TransactionFormModalState copyWith({
    bool? isOpen,
    TransactionType? initialType,
    TransactionModel? transaction,
    bool? isCloning,
  }) {
    return TransactionFormModalState(
      isOpen: isOpen ?? this.isOpen,
      initialType: initialType ?? this.initialType,
      transaction: transaction ?? this.transaction,
      isCloning: isCloning ?? this.isCloning,
    );
  }
}

class TransactionFormModalNotifier extends Notifier<TransactionFormModalState> {
  @override
  TransactionFormModalState build() {
    return const TransactionFormModalState();
  }

  void open({
    TransactionType? type,
    TransactionModel? transaction,
    bool isCloning = false,
  }) {
    state = state.copyWith(
      isOpen: true,
      initialType: type,
      transaction: transaction,
      isCloning: isCloning,
    );
  }

  void close() {
    state = state.copyWith(isOpen: false);
  }
}

final transactionFormModalProvider =
    NotifierProvider<TransactionFormModalNotifier, TransactionFormModalState>(
      () {
        return TransactionFormModalNotifier();
      },
    );
