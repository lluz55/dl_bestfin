import 'dart:math' as math;

import 'package:bestfin/core/constants/transaction_types.dart';
import 'package:bestfin/features/transactions/domain/models/transaction.dart';

/// Meia-vida (em dias) do decaimento de recência — mesma constante usada pelo
/// recomendador de sugestões ([rankQuickSuggestions]): uma ocorrência de 30 dias
/// atrás pesa metade de uma de hoje.
const double _recencyHalfLifeDays = 30.0;

/// Bônus máximo aplicado quando o valor da nova transação é próximo do valor de
/// um lançamento histórico que já casou por descrição. Conservador de propósito:
/// o valor é um sinal fraco de categoria (o mesmo R$ 50 serve a várias), então
/// ele só _refina_ a ordenação entre casamentos de descrição — nunca cria
/// sinal sozinho.
const double _amountBonusMax = 0.25;

/// Prevê a categoria mais provável para uma nova transação, com base no
/// histórico recente. Combina quatro sinais, em ordem de prioridade:
///
///  1. **Entidade** — se o pagador/recebedor já foi usado antes, a categoria
///     típica dele é o palpite mais forte.
///  2. **Descrição (n-gramas)** — sobreposição de tokens (unigramas + bigramas,
///     sem acento, sem stopwords) entre a descrição nova e as do histórico,
///     ponderada por similaridade de Jaccard × recência. Generaliza o antigo
///     casamento por string exata: "Extra Supermercado" casa com
///     "Supermercado Extra 123" mesmo sem serem idênticas.
///  3. **Valor** (opcional) — refino: entre casamentos de descrição, um valor
///     próximo dá um pequeno empurrão. Nunca decide sozinho.
///  4. **Frequência geral** — a categoria mais recorrente do tipo, como fallback.
///
/// **Feedback loop:** como o decaimento de recência (meia-vida de 30 dias) pesa
/// muito mais os lançamentos recentes, uma correção manual do usuário — que vira
/// uma transação nova com a categoria certa — rapidamente domina o histórico
/// antigo. O recomendador aprende com as correções sem precisar de estado extra.
///
/// Função pura e determinística. Retorna `null` quando não há histórico
/// suficiente (ex.: primeira transação do tipo).
String? predictCategory(
  List<TransactionModel> txs, {
  required TransactionType type,
  String? entityId,
  String? description,
  int? amountInCents,
  required DateTime now,
}) {
  if (type == TransactionType.transfer) return null;

  final queryTokens = _tokenSet(description);

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

    if (queryTokens.isNotEmpty) {
      final sim = _jaccard(queryTokens, _tokenSet(tx.description));
      if (sim > 0) {
        final amountFactor = _amountFactor(amountInCents, tx.amount);
        byDescription[cat] =
            (byDescription[cat] ?? 0) + weight * sim * amountFactor;
      }
    }
  }

  return _topKey(byEntity) ?? _topKey(byDescription) ?? _topKey(general);
}

/// Fator multiplicativo em `[1.0, 1.0 + _amountBonusMax]` pela proximidade
/// relativa entre dois valores. Retorna `1.0` (neutro) se algum valor faltar.
double _amountFactor(int? queryAmount, int histAmount) {
  if (queryAmount == null || queryAmount <= 0 || histAmount <= 0) return 1.0;
  final ratio = queryAmount < histAmount
      ? queryAmount / histAmount
      : histAmount / queryAmount;
  return 1.0 + _amountBonusMax * ratio;
}

/// Índice de Jaccard entre dois conjuntos de tokens: |A∩B| / |A∪B|.
/// Descrições idênticas → 1.0; sem tokens em comum → 0.0.
double _jaccard(Set<String> a, Set<String> b) {
  if (a.isEmpty || b.isEmpty) return 0;
  var intersection = 0;
  for (final t in a) {
    if (b.contains(t)) intersection++;
  }
  final union = a.length + b.length - intersection;
  return union == 0 ? 0 : intersection / union;
}

/// Stopwords do português + ruído de meio de pagamento que não carregam sinal
/// de categoria (aparecem em todas: alimentação, transporte, etc.).
const Set<String> _stopwords = {
  'de', 'da', 'do', 'das', 'dos', 'e', 'a', 'o', 'as', 'os', 'um', 'uma',
  'para', 'pra', 'por', 'com', 'sem', 'em', 'no', 'na', 'nos', 'nas', 'ao',
  'pix', 'ted', 'doc', 'pag', 'pagamento', 'compra', 'debito', 'credito',
};

/// Normaliza a descrição em um conjunto de tokens: minúsculas, sem acento,
/// separado por não-alfanuméricos, sem stopwords/dígitos puros, e enriquecido
/// com bigramas dos tokens adjacentes (capturam frases curtas como
/// "conta luz" ou "mercado extra").
Set<String> _tokenSet(String? description) {
  final raw = (description ?? '').trim();
  if (raw.isEmpty) return const {};

  final folded = _foldAccents(raw.toLowerCase());
  final words = folded
      .split(RegExp(r'[^a-z0-9]+'))
      .where(
        (w) => w.length >= 2 && !_stopwords.contains(w) && !_isAllDigits(w),
      )
      .toList();

  if (words.isEmpty) return const {};

  final tokens = <String>{...words};
  for (var i = 0; i < words.length - 1; i++) {
    tokens.add('${words[i]}_${words[i + 1]}');
  }
  return tokens;
}

bool _isAllDigits(String s) {
  for (final unit in s.codeUnits) {
    if (unit < 0x30 || unit > 0x39) return false;
  }
  return true;
}

/// Remove acentos comuns do português (mapeamento direto — sem dependências).
String _foldAccents(String s) {
  const map = {
    'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a',
    'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
    'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
    'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
    'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
    'ç': 'c', 'ñ': 'n',
  };
  final buffer = StringBuffer();
  for (final ch in s.split('')) {
    buffer.write(map[ch] ?? ch);
  }
  return buffer.toString();
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
