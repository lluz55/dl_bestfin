import 'package:bestfin/features/transactions/data/repositories/transaction_repository.dart';

/// Exclui várias transações de uma vez (seleção em massa na lista). Delega ao
/// repositório, que aplica tudo em uma única transação de banco e recalcula os
/// saldos/metas afetados.
class DeleteTransactions {
  final TransactionRepository repository;

  DeleteTransactions(this.repository);

  Future<void> call(List<String> ids) {
    return repository.deleteTransactions(ids);
  }
}
