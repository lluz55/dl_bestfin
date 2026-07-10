import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestfin/core/constants/transaction_types.dart';
import 'package:bestfin/core/constants/sentiment_types.dart';
import 'package:bestfin/features/transactions/domain/models/transaction.dart';

/// Rascunho de uma nova transação começada no "Lançamento Rápido" e levada para
/// o formulário completo pelo botão "Mais opções", para que nada digitado se
/// perca no caminho. Carrega só o essencial já preenchido no sheet.
class TransactionDraft {
  final TransactionType type;
  final int amountInCents;
  final String description;
  final String? accountId;
  final String? toAccountId;
  final String? categoryId;
  final String? entityId;
  final bool isPending;
  final SentimentType? sentiment;

  const TransactionDraft({
    required this.type,
    this.amountInCents = 0,
    this.description = '',
    this.accountId,
    this.toAccountId,
    this.categoryId,
    this.entityId,
    this.isPending = false,
    this.sentiment,
  });
}

class TransactionFormModalState {
  final bool isOpen;
  final TransactionType? initialType;
  final TransactionModel? transaction;
  final bool isCloning;
  final TransactionDraft? draft;

  /// Abre o formulário já com o assistente de recorrência ("Repetir") em
  /// primeiro plano — ponto de entrada único para qualquer "nova transação
  /// recorrente" (hub de assinaturas, lista de recorrentes, etc.), em vez de
  /// cada tela reimplementar seu próprio formulário de transação.
  final bool openRecurringWizard;

  const TransactionFormModalState({
    this.isOpen = false,
    this.initialType,
    this.transaction,
    this.isCloning = false,
    this.draft,
    this.openRecurringWizard = false,
  });

  TransactionFormModalState copyWith({
    bool? isOpen,
    TransactionType? initialType,
    TransactionModel? transaction,
    bool? isCloning,
    TransactionDraft? draft,
    bool? openRecurringWizard,
  }) {
    return TransactionFormModalState(
      isOpen: isOpen ?? this.isOpen,
      initialType: initialType ?? this.initialType,
      transaction: transaction ?? this.transaction,
      isCloning: isCloning ?? this.isCloning,
      draft: draft ?? this.draft,
      openRecurringWizard: openRecurringWizard ?? this.openRecurringWizard,
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
    TransactionDraft? draft,
    bool openRecurringWizard = false,
  }) {
    // Estado novo a cada abertura para não arrastar um rascunho antigo.
    state = TransactionFormModalState(
      isOpen: true,
      initialType: type,
      transaction: transaction,
      isCloning: isCloning,
      draft: draft,
      openRecurringWizard: openRecurringWizard,
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
