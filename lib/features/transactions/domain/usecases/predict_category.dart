import 'dart:math' as math;

import 'package:bestfin/core/constants/transaction_types.dart';
import 'package:bestfin/features/transactions/domain/models/transaction.dart';

/// Meia-vida (em dias) do decaimento de recência — mesma constante usada pelo
/// recomendador de sugestões ([rankQuickSuggestions]): uma ocorrência de 30 dias
/// atrás pesa metade de uma de hoje.
const double _recencyHalfLifeDays = 30.0;

/// Prevê a categoria mais provável para uma nova transação, com base no
/// histórico recente, usando o mesmo score de frequência ponderada por recência
/// das sugestões. Serve de _smart default_ no "Lançamento Rápido".
///
/// Combina três sinais, em ordem de prioridade:
///  1. **Entidade** — se o pagador/recebedor já foi usado antes, a categoria
///     típica dele é o palpite mais forte.
///  2. **Descrição** — descrição idêntica (normalizada) a um lançamento passado.
///  3. **Frequência geral** — a categoria mais recorrente do tipo, como fallback.
///
/// Função pura e determinística. Retorna `null` quando não há histórico
/// suficiente (ex.: primeira transação do tipo).
String? predictCategory(
  List<TransactionModel> txs, {
  required TransactionType type,
  String? entityId,
  String? description,
  required DateTime now,
}) {
  if (type == TransactionType.transfer) return null;

  final desc = description?.trim().toLowerCase() ?? '';

  final Map<String, double> byEntity = {};
  final Map<String, double> byDescription = {};
  final Map<String, double> general = {};

  for (final tx in txs) {
    if (!tx.isCompleted || !tx.isConfirmed) continue;
    if (tx.type != type) continue;
    final cat = tx.categoryId;
    if (cat == null) continue;

    final ageDays = math.max(0, now.difference(tx.date).inDays);
    final weight = math.pow(0.5, ageDays / _recencyHalfLifeDays).toDouble();

    general[cat] = (general[cat] ?? 0) + weight;
    if (entityId != null && tx.entityId == entityId) {
      byEntity[cat] = (byEntity[cat] ?? 0) + weight;
    }
    if (desc.isNotEmpty && tx.description.trim().toLowerCase() == desc) {
      byDescription[cat] = (byDescription[cat] ?? 0) + weight;
    }
  }

  return _topKey(byEntity) ?? _topKey(byDescription) ?? _topKey(general);
}

/// Chave de maior peso acumulado, ou `null` se o mapa estiver vazio.
String? _topKey(Map<String, double> weights) {
  String? best;
  double bestWeight = 0;
  weights.forEach((key, weight) {
    if (best == null || weight > bestWeight) {
      best = key;
      bestWeight = weight;
    }
  });
  return best;
}
