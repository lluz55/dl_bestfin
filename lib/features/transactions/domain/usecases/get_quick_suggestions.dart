import 'dart:math' as math;

import 'package:bestfin/core/constants/transaction_types.dart';
import 'package:bestfin/features/transactions/domain/models/quick_suggestion.dart';
import 'package:bestfin/features/transactions/domain/models/transaction.dart';

/// Meia-vida (em dias) do decaimento de recência: uma ocorrência de 30 dias
/// atrás vale metade de uma de hoje.
const double _recencyHalfLifeDays = 30.0;

/// Quantas transações recentes alimentam o ranqueamento.
const int _historyWindow = 180;

/// Recomendador estatístico on-device para o "Lançamento Rápido".
///
/// Agrupa o histórico por assinatura (tipo + categoria/entidade/descrição para
/// despesa/receita; tipo + par origem→destino para transferência) e ranqueia
/// cada grupo por `score = Σ 0.5^(idadeEmDias / meiaVida)` — ou seja,
/// frequência ponderada por recência. Para cada grupo, escolhe o valor e a
/// conta mais frequentes (desempate pela ocorrência mais recente).
///
/// Função pura e determinística: dado o mesmo `txs` e `now`, sempre devolve a
/// mesma lista. Não persiste nada — apenas sugere.
List<QuickSuggestion> rankQuickSuggestions(
  List<TransactionModel> txs, {
  required DateTime now,
  TransactionType? typeFilter,
  int topK = 6,
}) {
  // Considera apenas transações concluídas e confirmadas, ordenadas da mais
  // recente para a mais antiga, limitando à janela de histórico.
  final relevant =
      txs
          .where((t) => t.isCompleted && t.isConfirmed && t.amount > 0)
          .where((t) => typeFilter == null || t.type == typeFilter)
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));

  final window = relevant.take(_historyWindow);

  final Map<String, _Group> groups = {};
  for (final tx in window) {
    final key = _groupKey(tx);
    if (key == null) continue;
    final ageDays = math.max(0, now.difference(tx.date).inDays);
    final weight = math.pow(0.5, ageDays / _recencyHalfLifeDays).toDouble();
    (groups[key] ??= _Group(tx)).add(tx, weight);
  }

  final suggestions = groups.values.map((g) => g.toSuggestion()).toList()
    ..sort((a, b) => b.score.compareTo(a.score));

  return suggestions.take(topK).toList();
}

/// Assinatura de agrupamento. `null` quando a transação não tem dados mínimos
/// para virar sugestão (ex.: transferência sem conta de destino).
String? _groupKey(TransactionModel tx) {
  final account = tx.accountId;
  if (account == null) return null;

  if (tx.type == TransactionType.transfer) {
    final to = tx.toAccountId;
    final from = tx.fromAccountId;
    if (to == null || from == null) return null;
    return 'transfer|$from|$to';
  }

  final desc = tx.description.trim().toLowerCase();
  return '${tx.type.name}|$desc|${tx.categoryId ?? ''}|${tx.entityId ?? ''}';
}

/// Acumulador mutável de um grupo durante o ranqueamento.
class _Group {
  _Group(this.first);

  /// Transação mais recente do grupo (a janela já vem ordenada desc por data).
  final TransactionModel first;

  double score = 0;

  // valor -> (peso acumulado, data mais recente) — para escolher o valor típico.
  final Map<int, _Tally> _amounts = {};
  // conta -> (peso acumulado, data mais recente) — para escolher a conta típica.
  final Map<String, _Tally> _accounts = {};

  void add(TransactionModel tx, double weight) {
    score += weight;
    (_amounts[tx.amount] ??= _Tally()).bump(weight, tx.date);
    final account = tx.accountId;
    if (account != null) {
      (_accounts[account] ??= _Tally()).bump(weight, tx.date);
    }
  }

  QuickSuggestion toSuggestion() {
    return QuickSuggestion(
      type: first.type,
      description: first.description,
      amount: _mode(_amounts) ?? first.amount,
      accountId: _mode(_accounts) ?? first.accountId!,
      toAccountId: first.toAccountId,
      categoryId: first.categoryId,
      entityId: first.entityId,
      score: score,
    );
  }
}

class _Tally {
  double weight = 0;
  DateTime last = DateTime.fromMillisecondsSinceEpoch(0);

  void bump(double w, DateTime date) {
    weight += w;
    if (date.isAfter(last)) last = date;
  }
}

/// Escolhe a chave de maior peso acumulado; desempata pela ocorrência mais recente.
K? _mode<K>(Map<K, _Tally> tallies) {
  K? best;
  _Tally? bestTally;
  tallies.forEach((key, tally) {
    if (bestTally == null ||
        tally.weight > bestTally!.weight ||
        (tally.weight == bestTally!.weight &&
            tally.last.isAfter(bestTally!.last))) {
      best = key;
      bestTally = tally;
    }
  });
  return best;
}
