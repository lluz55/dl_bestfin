import 'package:bestfin/features/transactions/data/repositories/transaction_repository.dart';
import 'package:bestfin/features/transactions/domain/models/bulk_transaction_item.dart';

/// Edita um bloco agrupado: valida as linhas (mesmas regras do lote) e delega
/// ao repositório, que substitui todos os membros do [groupId] em uma única
/// transação de banco, recalculando saldos/metas afetados.
class UpdateGroupedTransactions {
  final TransactionRepository repository;

  UpdateGroupedTransactions(this.repository);

  Future<void> call(String groupId, List<BulkTransactionItem> items) {
    if (items.isEmpty) {
      throw ArgumentError('O bloco não pode ficar vazio');
    }
    for (final item in items) {
      if (item.amount <= 0) {
        throw ArgumentError('Toda linha precisa de um valor maior que zero');
      }
      if (item.type == 'transfer') {
        if (item.toAccountId == null) {
          throw ArgumentError('Transferência exige conta de destino');
        }
        if (item.toAccountId == item.accountId) {
          throw ArgumentError('Conta de origem e destino não podem ser iguais');
        }
        if (item.categoryId != null || item.entityId != null) {
          throw ArgumentError(
            'Transferência não pode ter categoria ou entidade',
          );
        }
      } else {
        if (item.description.trim().isEmpty) {
          throw ArgumentError('Toda linha precisa de uma descrição');
        }
      }
    }
    return repository.updateGroupedTransactions(groupId, items);
  }
}
