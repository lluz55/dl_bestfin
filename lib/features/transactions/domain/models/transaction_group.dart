import 'package:bestfin/core/constants/transaction_types.dart';
import 'package:bestfin/features/transactions/domain/models/transaction.dart';

/// Agregação de um bloco de lançamentos criados juntos e que compartilham o
/// mesmo `groupId`. É exibido nas listas como um único item, revelando apenas
/// o valor total; a edição continua permitindo alterar cada membro.
class TransactionGroup {
  final String groupId;
  final List<TransactionModel> members;

  const TransactionGroup({required this.groupId, required this.members});

  TransactionModel get first => members.first;

  int get count => members.length;

  /// Título de exibição do bloco: o nome da entidade (pago a / recebido de),
  /// compartilhado por todos os membros do lote. Cai para um rótulo genérico
  /// quando não há entidade (ex.: transferências).
  String get title => first.entity?.name ?? 'Lançamento agrupado';

  /// Data do bloco (todos os membros compartilham a data do cabeçalho do lote).
  DateTime get date => first.date;

  /// Todos os membros de um lote compartilham o mesmo tipo (definido no
  /// cabeçalho da inserção em massa).
  TransactionType get type => first.type;

  /// Soma dos valores de todos os membros.
  int get total => members.fold(0, (sum, tx) => sum + tx.amount);

  /// Algum membro ainda está pendente (não concluído)?
  bool get hasPending => members.any((tx) => tx.isPending);
}
