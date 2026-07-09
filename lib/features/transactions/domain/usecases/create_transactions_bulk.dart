import 'package:bestfin/features/transactions/data/repositories/transaction_repository.dart';
import 'package:bestfin/features/transactions/domain/models/bulk_transaction_item.dart';

class CreateTransactionsBulk {
  final TransactionRepository repository;

  CreateTransactionsBulk(this.repository);

  /// Valida o lote e insere tudo-ou-nada. Lança [ArgumentError] em violação
  /// de regra de domínio — nada é gravado nesse caso.
  Future<List<String>> call(List<BulkTransactionItem> items) {
    if (items.isEmpty) {
      throw ArgumentError('O lote não pode estar vazio');
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
    return repository.createTransactionsBulk(items);
  }
}
