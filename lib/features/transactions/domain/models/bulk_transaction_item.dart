/// Uma linha de um lote de inserção em massa ("Inserir vários").
///
/// Mantém apenas os campos suportados pelo fluxo bulk — sem splits, metas,
/// cartão de crédito, sentimento ou notas. A auto-absorção de metas continua
/// acontecendo no repository a partir do [categoryId].
class BulkTransactionItem {
  final DateTime date;
  final String description;
  final String type; // 'income' | 'expense' | 'transfer'
  final int amount; // centavos
  final String? categoryId; // null para transferências
  final String? entityId; // null para transferências
  final String accountId;
  final String? toAccountId; // obrigatório para transferências
  final bool isCompleted;

  /// Quando não-nulo, todas as linhas do lote compartilham este id e são
  /// exibidas como um único lançamento agrupado. null = lançamentos avulsos.
  final String? groupId;

  const BulkTransactionItem({
    required this.date,
    required this.description,
    required this.type,
    required this.amount,
    this.categoryId,
    this.entityId,
    required this.accountId,
    this.toAccountId,
    this.isCompleted = true,
    this.groupId,
  });
}
