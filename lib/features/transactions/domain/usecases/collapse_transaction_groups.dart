import 'package:bestfin/features/transactions/domain/models/transaction.dart';
import 'package:bestfin/features/transactions/domain/models/transaction_group.dart';

/// Colapsa lançamentos que compartilham o mesmo `groupId` em um único
/// [TransactionGroup], preservando a ordem original. O bloco assume a posição
/// do seu primeiro membro. Blocos com um único membro remanescente (ex: após
/// exclusões) voltam a ser exibidos como um lançamento avulso ([TransactionModel]).
///
/// Retorna uma lista heterogênea de [TransactionModel] e [TransactionGroup].
List<Object> collapseTransactionGroups(List<TransactionModel> transactions) {
  final Map<String, List<TransactionModel>> byGroup = {};
  for (final tx in transactions) {
    final gid = tx.groupId;
    if (gid != null) {
      byGroup.putIfAbsent(gid, () => []).add(tx);
    }
  }

  final List<Object> result = [];
  final Set<String> emitted = {};
  for (final tx in transactions) {
    final gid = tx.groupId;
    if (gid == null) {
      result.add(tx);
      continue;
    }
    if (emitted.contains(gid)) continue;
    emitted.add(gid);
    final members = byGroup[gid]!;
    if (members.length > 1) {
      result.add(TransactionGroup(groupId: gid, members: members));
    } else {
      result.add(members.first);
    }
  }
  return result;
}
