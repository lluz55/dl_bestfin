import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestfin/core/constants/transaction_types.dart';
import 'package:bestfin/features/accounts/presentation/providers/accounts_provider.dart';
import 'package:bestfin/features/transactions/presentation/providers/transactions_provider.dart';
import 'package:bestfin/features/transactions/domain/models/transaction.dart';
import 'package:bestfin/features/recurring/presentation/providers/recurring_provider.dart';
import 'package:bestfin/features/recurring/domain/models/recurring_rule.dart';
import 'package:bestfin/features/financing/presentation/providers/financing_provider.dart';
import 'package:bestfin/features/goals/presentation/providers/goals_provider.dart';
import 'package:bestfin/features/ai/domain/services/naive_bayes_classifier.dart';
import 'package:bestfin/features/ai/domain/services/insight_nlg_service.dart';

// ─── Auto-Categorização ──────────────────────────────────────────────────────

class AiCategorySuggestion {
  final String categoryId;
  final String categoryName;
  final String categoryColor;
  final String categoryIcon;
  final double confidence; // 0.0 to 1.0

  const AiCategorySuggestion({
    required this.categoryId,
    required this.categoryName,
    required this.categoryColor,
    required this.categoryIcon,
    required this.confidence,
  });
}

// Pre-seeded fallback rules when user has no transaction history
// Single-word entries use word-boundary matching; multi-word use substring.
final Map<String, List<String>> _fallbackKeywords = {
  'cat_food': [
    // Redes e apps
    'ifood', 'rappi', 'aiqfome', 'mcdonalds', 'burguer king', 'subway',
    'habib', 'outback', 'giraffas', 'bob\'s', 'frango',
    // Supermercados
    'mercado', 'supermercado', 'hipermercado', 'atacadão', 'assaí', 'carrefour',
    'pão de açúcar', 'extra', 'atacado', 'makro', 'sams club', 'costco',
    'apoio mineiro', 'bretas', 'muffato', 'condor', 'angeloni', 'nagumo',
    'sonda', 'bishopric', 'dia supermercado', 'walmart',
    // Estabelecimentos
    'restaurante', 'lanchonete', 'pizzaria', 'hamburgueria', 'churrascaria',
    'padaria', 'confeitaria', 'sorveteria', 'açougue', 'hortifruti', 'feira',
    'mercearia', 'empório', 'delicatessen',
    // Comidas/bebidas
    'almoço', 'jantar', 'café', 'lanche', 'pizza', 'burger', 'sushi',
    'comida', 'refeição', 'bebida', 'cerveja', 'vinho', 'água mineral',
    'refrigerante', 'salgado', 'marmita', 'delivery',
  ],
  'cat_transport': [
    // Apps de transporte
    'uber', '99pop', '99taxi', 'cabify', 'indrive', 'lift',
    // Táxi/ônibus/metrô
    'táxi', 'ônibus', 'metrô', 'trem', 'vlt', 'brt', 'van escolar',
    'passagem', 'bilhete único', 'cartão transporte',
    // Combustível
    'gasolina', 'etanol', 'combustível', 'diesel', 'gnv', 'abastecimento',
    // Postos
    'posto', 'shell', 'ipiranga', 'petrobras', 'ale', 'raizen',
    'br distribuidora', 'texaco',
    // Estacionamento/pedágio
    'estacionamento', 'pedágio', 'sem parar', 'veloe', 'connect car',
    'autopass', 'move mais', 'estapar',
    // Aluguel/bike
    'localiza', 'movida', 'unidas', 'hertz', 'avis', 'budget',
    'tembici', 'bike itaú', 'yellow', 'parafuzo',
    // Manutenção
    'mecânico', 'oficina', 'borracharia', 'lavagem', 'revisão',
    'licenciamento', 'ipva', 'seguro auto',
  ],
  'cat_leisure': [
    // Streaming
    'netflix', 'spotify', 'youtube premium', 'amazon prime', 'disney',
    'hbo', 'hbomax', 'globoplay', 'crunchyroll', 'paramount', 'star+',
    'apple tv', 'deezer', 'tidal', 'primevideo', 'telecine',
    // Games
    'steam', 'playstation', 'xbox', 'nintendo', 'epic games', 'nuuvem',
    'humble bundle', 'jogos',
    // Eventos
    'cinema', 'ingresso', 'teatro', 'show', 'festival', 'balada', 'festa',
    'bilheteria', 'ticketmaster', 'sympla', 'eventim',
    // Social
    'bar', 'clube', 'camarote', 'boliche', 'laser', 'escape room',
    // Viagem
    'viagem', 'hotel', 'pousada', 'hostel', 'airbnb', 'booking',
    'decolar', 'latam', 'gol', 'azul', 'trip', 'passagem aérea',
    // Outros
    'parque', 'museu', 'zoológico', 'aquário', 'circo',
  ],
  'cat_housing': [
    // Energia
    'energia', 'luz', 'enel', 'cemig', 'copel', 'celg', 'coelba',
    'elektro', 'cpfl', 'celpe', 'celesc', 'eletrobras',
    // Água/esgoto
    'água', 'sabesp', 'cedae', 'sanepar', 'embasa', 'caern', 'saneago',
    'copasa', 'casan',
    // Gás
    'gás', 'comgas', 'scgas', 'bahiagás', 'ceg', 'losango gás',
    // Internet/telefone
    'internet', 'banda larga', 'fibra', 'net virtua', 'oi fibra',
    'vivo fibra', 'claro fibra', 'tim fibra', 'sky',
    // Aluguel/condomínio
    'aluguel', 'condomínio', 'imobiliária', 'locação', 'iptu',
    'taxa condomínio', 'mensalidade condomínio',
    // Manutenção/reforma
    'reforma', 'manutenção', 'encanador', 'eletricista', 'pintura',
    'desentupidora', 'chaveiro',
    // Celular
    'celular', 'plano celular', 'claro', 'vivo', 'tim', 'oi',
    'recarregue', 'recarga',
  ],
  'cat_education': [
    // Instituições
    'faculdade', 'universidade', 'escola', 'colégio', 'creche',
    'mensalidade escolar', 'matrícula',
    // Cursos
    'curso', 'graduação', 'pós-graduação', 'mba', 'extensão',
    'capacitação', 'treinamento', 'workshop', 'palestra',
    // Plataformas online
    'udemy', 'coursera', 'alura', 'dio', 'rocketseat', 'platzi',
    'skillshare', 'linkedin learning', 'duolingo',
    // Idiomas
    'idioma', 'inglês', 'espanhol', 'francês', 'alemão', 'japonês',
    'mandarin', 'cna', 'wizard', 'cultura inglesa', 'ccaa',
    // Material
    'livro', 'apostila', 'material escolar', 'papelaria', 'caderno',
    'mochila escolar',
  ],
  'cat_health': [
    // Farmácias
    'farmácia', 'drogaria', 'drogasil', 'droga raia', 'pague menos',
    'ultrafarma', 'panvel', 'nissei', 'pacheco', 'raia', 'ultragenix',
    // Saúde
    'remédio', 'medicamento', 'vitamina', 'suplemento',
    // Profissionais
    'médico', 'consulta', 'dentista', 'psicólogo', 'terapeuta',
    'nutricionista', 'fisioterapeuta', 'ortopedista', 'cardiologista',
    'dermatologista', 'oftalmologista',
    // Estabelecimentos
    'hospital', 'clínica', 'laboratório', 'UPA', 'pronto socorro',
    'posto de saúde',
    // Exames
    'exame', 'análise', 'ressonância', 'tomografia', 'ultrassom',
    'raio-x', 'eletrocardiograma',
    // Planos
    'plano de saúde', 'unimed', 'amil', 'sulamerica', 'bradesco saúde',
    'porto seguro saúde', 'hapvida', 'notredame',
    // Fitness
    'academia', 'gym', 'smartfit', 'bodytech', 'selfit', 'bluefit',
    'crossfit', 'pilates',
  ],
  'cat_clothing': [
    // Lojas
    'zara', 'h&m', 'riachuelo', 'renner', 'marisa', 'hering', 'shein',
    'forever21', 'cea', 'proteste', 'shoulder', 'farm', 'animale',
    'arezzo', 'schutz', 'melissa', 'havaianas',
    // Esportes
    'nike', 'adidas', 'puma', 'asics', 'new balance', 'olympikus',
    'decathlon', 'netshoes', 'centauro',
    // Roupas/acessórios
    'roupa', 'camiseta', 'calça', 'vestido', 'blusa', 'jaqueta',
    'tênis', 'sapato', 'sandália', 'bolsa', 'carteira', 'mala',
    'óculos', 'relogio', 'acessório',
  ],
};

final Map<String, Map<String, String>> _categoryMeta = {
  'cat_food': {'name': 'Alimentação', 'color': '#FF9800', 'icon': 'restaurant'},
  'cat_transport': {
    'name': 'Transporte',
    'color': '#03A9F4',
    'icon': 'directions_car',
  },
  'cat_leisure': {
    'name': 'Lazer',
    'color': '#E91E63',
    'icon': 'sports_esports',
  },
  'cat_housing': {'name': 'Moradia', 'color': '#4CAF50', 'icon': 'home'},
  'cat_education': {'name': 'Educação', 'color': '#9C27B0', 'icon': 'school'},
  'cat_health': {
    'name': 'Saúde',
    'color': '#F44336',
    'icon': 'medical_services',
  },
  'cat_clothing': {
    'name': 'Vestuário',
    'color': '#795548',
    'icon': 'checkroom',
  },
};

// Tokenizes a string into lowercase words (min 2 chars), ignoring punctuation.
Set<String> _tokenize(String text) {
  return text
      .toLowerCase()
      .split(RegExp(r'[\s\-_/,\.!?@#&\(\)]+'))
      .where((w) => w.length >= 2)
      .toSet();
}

// Returns true if the keyword matches the query.
// Multi-word keywords: substring match.
// Short single-word keywords (< 4 chars): exact token match to avoid false positives.
// Long single-word keywords (>= 4 chars): substring match for compound word support.
bool _keywordMatches(
  String keyword,
  String cleanQuery,
  Set<String> queryTokens,
) {
  if (keyword.contains(' ')) {
    return cleanQuery.contains(keyword);
  }
  if (keyword.length < 4) {
    return queryTokens.contains(keyword);
  }
  return cleanQuery.contains(keyword);
}

final autoCategorizeProvider = Provider.family<AiCategorySuggestion?, String>((
  ref,
  query,
) {
  if (query.trim().length < 3) return null;

  final cleanQuery = query.toLowerCase().trim();
  final queryTokens = _tokenize(cleanQuery);
  final txsAsync = ref.watch(filteredTransactionsProvider);

  return txsAsync.when(
    data: (txs) {
      // 1. History-based: exact and partial description matching
      final Map<String, int> exactCounts = {};
      final Map<String, int> wordCounts = {};

      final meaningfulQuery = queryTokens.where((w) => w.length >= 3).toSet();

      for (final tx in txs) {
        if (tx.category == null) continue;
        final txDesc = tx.description.toLowerCase();
        final txTokens = _tokenize(txDesc);
        final catId = tx.categoryId!;

        if (txDesc.contains(cleanQuery) || cleanQuery.contains(txDesc)) {
          // Exact or near-exact match → high weight
          exactCounts[catId] = (exactCounts[catId] ?? 0) + 2;
        } else if (meaningfulQuery.isNotEmpty) {
          // Word overlap: count shared tokens (only meaningful words ≥ 3 chars)
          final meaningful = meaningfulQuery.intersection(
            txTokens.where((w) => w.length >= 3).toSet(),
          );
          if (meaningful.isNotEmpty) {
            wordCounts[catId] = (wordCounts[catId] ?? 0) + meaningful.length;
          }
        }
      }

      // Merge exact + word match counts (exact counts double-weighted)
      final Map<String, int> combined = {...exactCounts};
      for (final e in wordCounts.entries) {
        combined[e.key] = (combined[e.key] ?? 0) + e.value;
      }

      if (combined.isNotEmpty) {
        final sortedCats = combined.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final bestCatId = sortedCats.first.key;
        final totalCount = combined.values.fold<int>(0, (s, v) => s + v);
        final rawConf = sortedCats.first.value / totalCount;
        // Scale confidence: exact matches start higher
        final hasExact = exactCounts.containsKey(bestCatId);
        final confidence = hasExact
            ? (0.70 + rawConf * 0.30).clamp(0.0, 1.0)
            : (0.50 + rawConf * 0.30).clamp(0.0, 1.0);

        try {
          final cat = txs
              .firstWhere((t) => t.categoryId == bestCatId)
              .category!;
          return AiCategorySuggestion(
            categoryId: bestCatId,
            categoryName: cat.name,
            categoryColor: cat.color,
            categoryIcon: cat.icon,
            confidence: confidence,
          );
        } catch (_) {
          // Category not found in current txs — fall through to keyword matcher
        }
      }

      // 2. Fallback: keyword classifier with word-boundary matching
      for (final catId in _fallbackKeywords.keys) {
        final keywords = _fallbackKeywords[catId]!;
        for (final keyword in keywords) {
          if (_keywordMatches(keyword, cleanQuery, queryTokens)) {
            final meta = _categoryMeta[catId]!;
            return AiCategorySuggestion(
              categoryId: catId,
              categoryName: meta['name']!,
              categoryColor: meta['color']!,
              categoryIcon: meta['icon']!,
              confidence: 0.82,
            );
          }
        }
      }

      return null;
    },
    loading: () => null,
    error: (_, __) => null,
  );
});

// ─── Naive Bayes Categorization ─────────────────────────────────────────────

/// Builds a Naive Bayes classifier trained on the user's confirmed transaction history.
/// Rebuilds whenever the transaction list changes (Riverpod caches the result).
final naiveBayesClassifierProvider = Provider<NaiveBayesClassifier>((ref) {
  final classifier = NaiveBayesClassifier();
  final txsAsync = ref.watch(filteredTransactionsProvider);
  if (txsAsync is AsyncData<List<TransactionModel>>) {
    for (final tx in txsAsync.value) {
      if (tx.categoryId != null) {
        classifier.train(tx.description, tx.categoryId!);
      }
    }
  }
  return classifier;
});

/// Runs NB classification for a description query.
/// Returns null when the classifier lacks sufficient data or confidence < 0.45.
final naiveBayesCategorizeProvider =
    Provider.family<AiCategorySuggestion?, String>((ref, query) {
      if (query.trim().length < 3) return null;

      final classifier = ref.watch(naiveBayesClassifierProvider);
      if (!classifier.hasSufficientData) return null;

      final result = classifier.predict(query);
      if (result == null) return null;

      final (catId, confidence) = result;
      if (confidence < 0.45) return null;

      final txsAsync = ref.watch(filteredTransactionsProvider);
      return txsAsync.whenData((txs) {
        try {
          final cat = txs.firstWhere((t) => t.categoryId == catId).category!;
          return AiCategorySuggestion(
            categoryId: catId,
            categoryName: cat.name,
            categoryColor: cat.color,
            categoryIcon: cat.icon,
            confidence: confidence.clamp(0.5, 0.95),
          );
        } catch (_) {
          return null;
        }
      }).value;
    });

// ─── Cash Flow Forecasting ──────────────────────────────────────────────────

class ForecastPoint {
  final DateTime date;
  final int balance;

  const ForecastPoint(this.date, this.balance);
}

class AiForecastReport {
  final List<ForecastPoint> points;
  final int projectedBalance30Days;
  final int projectedBalance90Days;
  final String? alertMessage;
  final int? daysUntilNegative;

  const AiForecastReport({
    required this.points,
    required this.projectedBalance30Days,
    required this.projectedBalance90Days,
    this.alertMessage,
    this.daysUntilNegative,
  });
}

final cashFlowForecastingProvider = Provider<AiForecastReport>((ref) {
  final currentNetWorth = ref.watch(totalBalanceProvider);
  final txsAsync = ref.watch(filteredTransactionsProvider);
  final recurringAsync = ref.watch(activeRecurringProvider);
  final financingsAsync = ref.watch(financingsStreamProvider);

  // Initialize defaults
  final defaultReport = AiForecastReport(
    points: List.generate(
      30,
      (i) =>
          ForecastPoint(DateTime.now().add(Duration(days: i)), currentNetWorth),
    ),
    projectedBalance30Days: currentNetWorth,
    projectedBalance90Days: currentNetWorth,
  );

  return txsAsync.when(
    data: (txs) => recurringAsync.when(
      data: (recurringRules) => financingsAsync.when(
        data: (financings) {
          final now = DateTime.now();
          final List<ForecastPoint> points = [];

          // 1. EWMA daily spending baseline from past 30 days.
          //    Alpha is inversely proportional to the coefficient of variation (CV):
          //    high volatility → more smoothing (lower alpha), stable spending → less smoothing.
          final past30Days = now.subtract(const Duration(days: 30));
          final completedExpenses = txs.where(
            (t) =>
                t.isCompleted &&
                t.type == TransactionType.expense &&
                t.date.isAfter(past30Days),
          );

          // Aggregate by calendar day for the past 30 days
          final Map<int, int> dailyTotals = {};
          for (int i = 0; i < 30; i++) {
            dailyTotals[i] = 0;
          }
          for (final tx in completedExpenses) {
            final daysAgo = now.difference(tx.date).inDays.clamp(0, 29);
            dailyTotals[29 - daysAgo] =
                (dailyTotals[29 - daysAgo] ?? 0) + tx.amount;
          }
          final dailyValues = List.generate(30, (i) => dailyTotals[i] ?? 0);

          final simpleMean = dailyValues.fold<int>(0, (s, v) => s + v) / 30.0;
          final variance =
              dailyValues.fold<double>(
                0,
                (s, v) => s + (v - simpleMean) * (v - simpleMean),
              ) /
              30.0;
          final stddev = sqrt(variance);
          // CV in [0, 1]: high CV → lower alpha (more smoothing)
          final cv = simpleMean > 0
              ? (stddev / simpleMean).clamp(0.0, 1.0)
              : 1.0;
          final alpha = (0.4 - cv * 0.25).clamp(0.05, 0.4);

          // EWMA over oldest→newest days
          double ewma = simpleMean;
          for (final v in dailyValues) {
            ewma = alpha * v + (1 - alpha) * ewma;
          }
          final int dailyBaselineExpense = ewma.round();

          int currentRunningBalance = currentNetWorth;
          String? alertMessage;
          int? daysUntilNegative;

          // Compute daily forecast for the next 90 days
          for (int day = 0; day <= 90; day++) {
            final targetDate = DateTime(now.year, now.month, now.day + day);

            if (day > 0) {
              // Apply organic daily baseline expense
              currentRunningBalance -= dailyBaselineExpense;

              // Apply active recurring transactions that hit on this day
              for (final rule in recurringRules) {
                if (_doesRecurringRuleFireOn(rule, targetDate)) {
                  final amount = rule.amountInCents ?? 0;
                  if (rule.type == 'income') {
                    currentRunningBalance += amount;
                  } else {
                    currentRunningBalance -= amount;
                  }
                }
              }

              // Apply unpaid financing installments due on this day
              for (final fin in financings) {
                // If there are installments, we check their due dates. We can read them or estimate.
                // For safety in forecast, we deduct standard monthly payments or load future installments.
                // We will deduct standard monthly installments.
                // Let's assume each financing has standard monthly installments.
                // If financing start date (createdAt) matches monthly cycles, we deduct standard monthly payments.
                // To keep it simple, we deduct the calculated monthly installment value.
                final monthlyInstallment =
                    fin.totalAmount / fin.totalInstallments;
                final isInstallmentDay = targetDate.day == fin.createdAt.day;
                final installmentsPaid =
                    (fin.totalAmount - fin.outstandingBalance) ~/
                    monthlyInstallment;
                final installmentsRemaining =
                    fin.totalInstallments - installmentsPaid;

                if (isInstallmentDay && installmentsRemaining > 0) {
                  currentRunningBalance -= monthlyInstallment.round();
                }
              }
            }

            points.add(ForecastPoint(targetDate, currentRunningBalance));

            // Catch the day balance turns negative for the first time
            if (currentRunningBalance < 0 && daysUntilNegative == null) {
              daysUntilNegative = day;
              final formattedDate =
                  '${targetDate.day.toString().padLeft(2, '0')}/${targetDate.month.toString().padLeft(2, '0')}/${targetDate.year}';
              alertMessage =
                  'Seu saldo consolidado ficará negativo em $day dias ($formattedDate) se você mantiver seu ritmo de gastos atual.';
            }
          }

          final int balance30 = points[30].balance;
          final int balance90 = points[90].balance;

          return AiForecastReport(
            points: points,
            projectedBalance30Days: balance30,
            projectedBalance90Days: balance90,
            alertMessage: alertMessage,
            daysUntilNegative: daysUntilNegative,
          );
        },
        loading: () => defaultReport,
        error: (_, __) => defaultReport,
      ),
      loading: () => defaultReport,
      error: (_, __) => defaultReport,
    ),
    loading: () => defaultReport,
    error: (_, __) => defaultReport,
  );
});

// Helper to determine if a recurring transaction fires on a given day
bool _doesRecurringRuleFireOn(RecurringRuleModel rule, DateTime date) {
  final next = rule.nextDate;
  if (date.isBefore(next)) return false;

  final diffDays = date.difference(next).inDays;

  switch (rule.frequency) {
    case RecurringFrequency.daily:
      return diffDays % rule.interval == 0;
    case RecurringFrequency.weekly:
      return diffDays % (7 * rule.interval) == 0;
    case RecurringFrequency.biweekly:
      return diffDays % (14 * rule.interval) == 0;
    case RecurringFrequency.monthly:
      return date.day == next.day &&
          ((date.year - next.year) * 12 + date.month - next.month) %
                  rule.interval ==
              0;
    case RecurringFrequency.yearly:
      return date.day == next.day &&
          date.month == next.month &&
          (date.year - next.year) % rule.interval == 0;
  }
}

// ─── Detecção de Anomalias ──────────────────────────────────────────────────

class AiAnomaly {
  final TransactionModel transaction;
  final String title;
  final String description;
  final double severity; // severity indicator e.g. 3.2x above average

  const AiAnomaly({
    required this.transaction,
    required this.title,
    required this.description,
    required this.severity,
  });
}

final anomalyDetectionProvider = Provider<List<AiAnomaly>>((ref) {
  final txsAsync = ref.watch(filteredTransactionsProvider);

  return txsAsync.when(
    data: (txs) {
      final List<AiAnomaly> anomalies = [];

      // 1. Group completed expenses by category
      final Map<String, List<int>> categorySpentValues = {};
      final expenses = txs.where(
        (t) => t.isCompleted && t.type == TransactionType.expense,
      );

      for (final tx in expenses) {
        if (tx.categoryId != null) {
          categorySpentValues[tx.categoryId!] ??= [];
          categorySpentValues[tx.categoryId!]!.add(tx.amount);
        }
      }

      // 2. Identify anomalous high spending in each category
      categorySpentValues.forEach((catId, values) {
        if (values.length >= 3) {
          // Calculate mean
          final double mean =
              values.fold<int>(0, (sum, v) => sum + v) / values.length;

          // Scan values again to find anomalies (> 2.5x mean and > R$ 50,00 to avoid tiny noises)
          for (final tx in expenses) {
            if (tx.categoryId == catId &&
                tx.amount > 2.5 * mean &&
                tx.amount > 5000) {
              final double ratio = tx.amount / mean;
              final catName = tx.category?.name ?? 'Categoria';
              anomalies.add(
                AiAnomaly(
                  transaction: tx,
                  title: 'Gasto Incomum em $catName',
                  description:
                      'Este gasto de R\$ ${(tx.amount / 100.0).toStringAsFixed(2).replaceAll('.', ',')} está ${ratio.toStringAsFixed(1)}x superior à sua média usual de R\$ ${(mean / 100.0).toStringAsFixed(2).replaceAll('.', ',')} nesta categoria.',
                  severity: ratio,
                ),
              );
            }
          }
        }
      });

      // Sort anomalies by severity descending
      anomalies.sort((a, b) => b.severity.compareTo(a.severity));
      return anomalies;
    },
    loading: () => [],
    error: (_, __) => [],
  );
});

// ─── Análise de Sentimento Correlacionada ────────────────────────────────────

class AiSentimentCorrelation {
  final double positivePercentage;
  final double neutralPercentage;
  final double negativePercentage;
  final List<String> psychologicalInsights;

  const AiSentimentCorrelation({
    required this.positivePercentage,
    required this.neutralPercentage,
    required this.negativePercentage,
    required this.psychologicalInsights,
  });
}

final sentimentCorrelationProvider = Provider<AiSentimentCorrelation>((ref) {
  final txsAsync = ref.watch(filteredTransactionsProvider);

  final defaultCorrelation = const AiSentimentCorrelation(
    positivePercentage: 0.33,
    neutralPercentage: 0.34,
    negativePercentage: 0.33,
    psychologicalInsights: [],
  );

  return txsAsync.when(
    data: (txs) {
      final completed = txs.where((t) => t.isCompleted);
      if (completed.isEmpty) return defaultCorrelation;

      int positive = 0;
      int neutral = 0;
      int negative = 0;

      // Group by hour
      int lateNightSpending = 0;
      int lateNightNegative = 0;

      for (final tx in completed) {
        if (tx.sentiment != null) {
          switch (tx.sentiment!.name) {
            case 'positive':
              positive++;
              break;
            case 'neutral':
              neutral++;
              break;
            case 'negative':
              negative++;
              break;
          }

          // Check late night spending (between 22h and 4h)
          final hour = tx.date.hour;
          if (hour >= 22 || hour <= 4) {
            lateNightSpending++;
            if (tx.sentiment!.name == 'negative') {
              lateNightNegative++;
            }
          }
        }
      }

      final total = positive + neutral + negative;
      if (total == 0) return defaultCorrelation;

      final double posPct = positive / total;
      final double neuPct = neutral / total;
      final double negPct = negative / total;

      final List<String> insights = [];

      // 1. Late night emotional spending insight
      if (lateNightSpending >= 3) {
        final double lateNightNegRatio = lateNightNegative / lateNightSpending;
        if (lateNightNegRatio > 0.6) {
          insights.add(
            '😞 Suas compras feitas tarde da noite (22h - 04h) possuem ${(lateNightNegRatio * 100).toStringAsFixed(0)}% de sentimento negativo (arrependimento pós-compra). Considere adiar decisões de compra no fim do dia.',
          );
        }
      }

      // 2. High positive category insight
      final Map<String, List<String>> categorySentiments = {};
      for (final tx in completed) {
        if (tx.categoryId != null && tx.sentiment != null) {
          categorySentiments[tx.category?.name ?? 'Geral'] ??= [];
          categorySentiments[tx.category?.name ?? 'Geral']!.add(
            tx.sentiment!.name,
          );
        }
      }

      categorySentiments.forEach((catName, sentiments) {
        if (sentiments.length >= 3) {
          final posCount = sentiments.where((s) => s == 'positive').length;
          final posRatio = posCount / sentiments.length;
          if (posRatio > 0.7) {
            insights.add(
              '🎉 Seus gastos na categoria "$catName" geram sentimentos extremamente positivos (${(posRatio * 100).toStringAsFixed(0)}% de bem-estar). Excelente alocação de felicidade!',
            );
          }
        }
      });

      // 3. Weekday insight
      final Map<int, List<String>> weekdaySentiments = {};
      for (final tx in completed) {
        if (tx.sentiment != null) {
          final weekday = tx.date.weekday;
          weekdaySentiments[weekday] ??= [];
          weekdaySentiments[weekday]!.add(tx.sentiment!.name);
        }
      }

      // Check Sunday/Monday mood comparison
      final sundayList = weekdaySentiments[7];
      final mondayList = weekdaySentiments[1];
      if (sundayList != null &&
          mondayList != null &&
          sundayList.length >= 2 &&
          mondayList.length >= 2) {
        final sunPos =
            sundayList.where((s) => s == 'positive').length / sundayList.length;
        final monNeg =
            mondayList.where((s) => s == 'negative').length / mondayList.length;

        if (sunPos > 0.5 && monNeg > 0.5) {
          insights.add(
            '📅 Seus sentimentos financeiros variam bastante no início da semana: gastos de Domingo são em maioria positivos, enquanto os de Segunda-feira costumam ter sentimentos mais estressantes/negativos.',
          );
        }
      }

      return AiSentimentCorrelation(
        positivePercentage: posPct,
        neutralPercentage: neuPct,
        negativePercentage: negPct,
        psychologicalInsights: insights,
      );
    },
    loading: () => defaultCorrelation,
    error: (_, __) => defaultCorrelation,
  );
});

// ─── Tendências de Gastos ────────────────────────────────────────────────────

class AiSpendingTrend {
  final String categoryId;
  final String categoryName;
  final String categoryColor;
  final String categoryIcon;
  final double percentChange;
  final String trend; // 'increasing' | 'decreasing' | 'stable'
  final int currentMonthTotal;
  final int previousMonthTotal;

  const AiSpendingTrend({
    required this.categoryId,
    required this.categoryName,
    required this.categoryColor,
    required this.categoryIcon,
    required this.percentChange,
    required this.trend,
    required this.currentMonthTotal,
    required this.previousMonthTotal,
  });
}

final spendingTrendsProvider = Provider<List<AiSpendingTrend>>((ref) {
  final txsAsync = ref.watch(filteredTransactionsProvider);

  return txsAsync.when(
    data: (txs) {
      final now = DateTime.now();
      final currentMonthStart = DateTime(now.year, now.month, 1);
      final previousMonthStart = DateTime(now.year, now.month - 1, 1);

      final Map<String, int> currentTotals = {};
      final Map<String, int> previousTotals = {};
      final Map<String, int> currentCounts = {};
      final Map<String, int> previousCounts = {};
      final Map<String, TransactionModel> categoryMeta = {};

      for (final tx in txs) {
        if (tx.categoryId == null || tx.category == null) continue;
        if (!tx.isCompleted || tx.type != TransactionType.expense) continue;
        final catId = tx.categoryId!;
        categoryMeta[catId] = tx;

        if (!tx.date.isBefore(currentMonthStart)) {
          currentTotals[catId] = (currentTotals[catId] ?? 0) + tx.amount;
          currentCounts[catId] = (currentCounts[catId] ?? 0) + 1;
        } else if (!tx.date.isBefore(previousMonthStart)) {
          previousTotals[catId] = (previousTotals[catId] ?? 0) + tx.amount;
          previousCounts[catId] = (previousCounts[catId] ?? 0) + 1;
        }
      }

      final List<AiSpendingTrend> trends = [];

      for (final catId in categoryMeta.keys) {
        final current = currentTotals[catId] ?? 0;
        final previous = previousTotals[catId] ?? 0;
        final currCount = currentCounts[catId] ?? 0;
        final prevCount = previousCounts[catId] ?? 0;

        if (currCount + prevCount < 2 || previous == 0) continue;

        final double percentChange = (current - previous) / previous * 100;
        final String trend;
        if (percentChange.abs() < 10) {
          trend = 'stable';
        } else if (percentChange > 0) {
          trend = 'increasing';
        } else {
          trend = 'decreasing';
        }

        final cat = categoryMeta[catId]!.category!;
        trends.add(
          AiSpendingTrend(
            categoryId: catId,
            categoryName: cat.name,
            categoryColor: cat.color,
            categoryIcon: cat.icon,
            percentChange: percentChange,
            trend: trend,
            currentMonthTotal: current,
            previousMonthTotal: previous,
          ),
        );
      }

      trends.sort(
        (a, b) => b.percentChange.abs().compareTo(a.percentChange.abs()),
      );
      return trends.take(7).toList();
    },
    loading: () => [],
    error: (_, __) => [],
  );
});

// ─── Score de Saúde Financeira ───────────────────────────────────────────────

class AiHealthScore {
  final int score;
  final String grade;
  final double savingsRate;
  final String primaryRecommendation;
  final List<String> tips;

  const AiHealthScore({
    required this.score,
    required this.grade,
    required this.savingsRate,
    required this.primaryRecommendation,
    required this.tips,
  });
}

final financialHealthScoreProvider = Provider<AiHealthScore>((ref) {
  final txsAsync = ref.watch(filteredTransactionsProvider);
  final goalsAsync = ref.watch(activeGoalsProvider);
  final anomalies = ref.watch(anomalyDetectionProvider);
  final sentiments = ref.watch(sentimentCorrelationProvider);

  const defaultScore = AiHealthScore(
    score: 50,
    grade: 'C',
    savingsRate: 0.0,
    primaryRecommendation:
        'Cadastre suas transações para receber seu Score de Saúde Financeira personalizado.',
    tips: [],
  );

  return txsAsync.when(
    data: (txs) {
      final now = DateTime.now();
      final past90Days = now.subtract(const Duration(days: 90));
      final completed = txs.where(
        (t) => t.isCompleted && t.date.isAfter(past90Days),
      );

      final totalIncome = completed
          .where((t) => t.type == TransactionType.income)
          .fold<int>(0, (sum, t) => sum + t.amount);
      final totalExpense = completed
          .where((t) => t.type == TransactionType.expense)
          .fold<int>(0, (sum, t) => sum + t.amount);

      final double savingsRate = totalIncome > 0
          ? (totalIncome - totalExpense) / totalIncome
          : 0.0;

      final int savingsScore;
      if (savingsRate >= 0.20) {
        savingsScore = 25;
      } else if (savingsRate >= 0.10) {
        savingsScore = 15;
      } else if (savingsRate >= 0.0) {
        savingsScore = 8;
      } else {
        savingsScore = 0;
      }

      final int anomalyScore;
      if (anomalies.isEmpty) {
        anomalyScore = 25;
      } else if (anomalies.length <= 2) {
        anomalyScore = 15;
      } else {
        anomalyScore = 5;
      }

      final int goalScore = goalsAsync.when(
        data: (goals) {
          if (goals.isEmpty) return 12;
          final avgProgress =
              goals.fold<double>(
                0,
                (sum, g) => sum + g.progressFraction.clamp(0.0, 1.0),
              ) /
              goals.length;
          return (avgProgress * 25).round();
        },
        loading: () => 12,
        error: (_, __) => 12,
      );

      final int sentimentScore = (sentiments.positivePercentage * 25).round();

      final int totalScore =
          savingsScore + anomalyScore + goalScore + sentimentScore;

      final String grade;
      if (totalScore >= 90) {
        grade = 'A';
      } else if (totalScore >= 70) {
        grade = 'B';
      } else if (totalScore >= 50) {
        grade = 'C';
      } else if (totalScore >= 30) {
        grade = 'D';
      } else {
        grade = 'F';
      }

      final Map<String, int> subScoreMap = {
        'savings': savingsScore,
        'anomaly': anomalyScore,
        'goals': goalScore,
        'sentiment': sentimentScore,
      };
      final weakestArea = subScoreMap.entries
          .reduce((a, b) => a.value < b.value ? a : b)
          .key;

      String primaryRecommendation = '';
      final List<String> tips = [];

      if (weakestArea == 'savings') {
        primaryRecommendation =
            'Sua taxa de poupança precisa de atenção. Tente poupar pelo menos 10% da sua renda mensal.';
        tips.add(
          'Identifique as 3 maiores categorias de gasto e tente reduzir cada uma em 10%.',
        );
        if (savingsRate < 0) {
          tips.add(
            'Suas despesas estão superando sua renda. Revise gastos não essenciais com urgência.',
          );
        }
      } else if (weakestArea == 'anomaly') {
        primaryRecommendation =
            'Você teve gastos fora do padrão recentemente. Revise as anomalias detectadas.';
        tips.add(
          'Gastos anômalos costumam ser compras por impulso. Considere um período de reflexão antes de compras grandes.',
        );
      } else if (weakestArea == 'goals') {
        primaryRecommendation =
            'Suas metas financeiras precisam de mais atenção. Contribua regularmente para cada objetivo.';
        tips.add(
          'Automatize aportes mensais para suas metas para garantir consistência.',
        );
      } else {
        primaryRecommendation =
            'Muitas compras com sentimento negativo. Reflita sobre quais gastos trazem satisfação real.';
        tips.add(
          'Antes de comprar, pergunte-se: isso vai me trazer satisfação durável?',
        );
      }

      tips.add(
        'Manter um orçamento mensal por categoria aumenta em 40% a chance de atingir metas financeiras.',
      );

      return AiHealthScore(
        score: totalScore,
        grade: grade,
        savingsRate: savingsRate,
        primaryRecommendation: primaryRecommendation,
        tips: tips,
      );
    },
    loading: () => defaultScore,
    error: (_, __) => defaultScore,
  );
});

// ─── Previsão de Atingimento de Metas ────────────────────────────────────────

class AiGoalForecast {
  final String goalId;
  final String goalName;
  final String? goalColor;
  final bool isOnTrack;
  final double progressFraction;
  final int? monthlyContributionNeeded;
  final int estimatedMonthlySurplus;
  final DateTime? projectedCompletionDate;
  final String statusMessage;

  const AiGoalForecast({
    required this.goalId,
    required this.goalName,
    this.goalColor,
    required this.isOnTrack,
    required this.progressFraction,
    this.monthlyContributionNeeded,
    required this.estimatedMonthlySurplus,
    this.projectedCompletionDate,
    required this.statusMessage,
  });
}

final goalAchievabilityProvider = Provider<List<AiGoalForecast>>((ref) {
  final goalsAsync = ref.watch(activeGoalsProvider);
  final txsAsync = ref.watch(filteredTransactionsProvider);

  return goalsAsync.when(
    data: (goals) => txsAsync.when(
      data: (txs) {
        if (goals.isEmpty) return [];

        final now = DateTime.now();
        final past90Days = now.subtract(const Duration(days: 90));
        final completed = txs.where(
          (t) => t.isCompleted && t.date.isAfter(past90Days),
        );

        final totalIncome = completed
            .where((t) => t.type == TransactionType.income)
            .fold<int>(0, (sum, t) => sum + t.amount);
        final totalExpense = completed
            .where((t) => t.type == TransactionType.expense)
            .fold<int>(0, (sum, t) => sum + t.amount);
        final int monthlySurplus = ((totalIncome - totalExpense) / 3.0).round();

        final List<AiGoalForecast> forecasts = [];

        for (final goal in goals) {
          if (goal.remainingInCents <= 0) continue;

          final monthlyNeeded = goal.monthlyTargetInCents;
          final bool isOnTrack = monthlyNeeded == null
              ? monthlySurplus > 0
              : monthlySurplus >= monthlyNeeded;

          DateTime? projectedCompletion;
          if (monthlySurplus > 0) {
            final monthsToCompletion = (goal.remainingInCents / monthlySurplus)
                .ceil();
            projectedCompletion = DateTime(
              now.year,
              now.month + monthsToCompletion,
              now.day,
            );
          }

          String statusMessage = '';
          if (monthlyNeeded == null) {
            if (monthlySurplus > 0 && projectedCompletion != null) {
              final months = (projectedCompletion.difference(now).inDays / 30)
                  .round();
              statusMessage =
                  'No ritmo atual, concluída em ~$months ${months == 1 ? 'mês' : 'meses'}';
            } else {
              statusMessage = 'Defina um prazo ou aumente sua poupança mensal';
            }
          } else if (isOnTrack) {
            statusMessage = 'No prazo — continue assim!';
          } else {
            final shortfall = monthlyNeeded - monthlySurplus;
            statusMessage =
                'Falta R\$ ${(shortfall / 100).toStringAsFixed(0)} a mais por mês para atingir o prazo';
          }

          forecasts.add(
            AiGoalForecast(
              goalId: goal.id,
              goalName: goal.name,
              goalColor: goal.color,
              isOnTrack: isOnTrack,
              progressFraction: goal.progressFraction,
              monthlyContributionNeeded: monthlyNeeded,
              estimatedMonthlySurplus: monthlySurplus,
              projectedCompletionDate: goal.targetDate ?? projectedCompletion,
              statusMessage: statusMessage,
            ),
          );
        }

        return forecasts;
      },
      loading: () => [],
      error: (_, __) => [],
    ),
    loading: () => [],
    error: (_, __) => [],
  );
});

// ─── Recomendações de Orçamento ──────────────────────────────────────────────

class AiBudgetRecommendation {
  final String categoryId;
  final String categoryName;
  final String categoryColor;
  final String categoryIcon;
  final int avgMonthlySpend;
  final int suggestedBudget;
  final String reasoning;

  const AiBudgetRecommendation({
    required this.categoryId,
    required this.categoryName,
    required this.categoryColor,
    required this.categoryIcon,
    required this.avgMonthlySpend,
    required this.suggestedBudget,
    required this.reasoning,
  });
}

final budgetRecommendationsProvider = Provider<List<AiBudgetRecommendation>>((
  ref,
) {
  final txsAsync = ref.watch(filteredTransactionsProvider);

  return txsAsync.when(
    data: (txs) {
      final now = DateTime.now();
      final past90Days = now.subtract(const Duration(days: 90));

      final Map<String, int> categoryTotals = {};
      final Map<String, int> categoryCounts = {};
      final Map<String, TransactionModel> categoryMeta = {};

      for (final tx in txs) {
        if (tx.categoryId == null || tx.category == null) continue;
        if (!tx.isCompleted || tx.type != TransactionType.expense) continue;
        if (!tx.date.isAfter(past90Days)) continue;

        final catId = tx.categoryId!;
        categoryTotals[catId] = (categoryTotals[catId] ?? 0) + tx.amount;
        categoryCounts[catId] = (categoryCounts[catId] ?? 0) + 1;
        categoryMeta[catId] = tx;
      }

      final List<AiBudgetRecommendation> recommendations = [];

      for (final catId in categoryTotals.keys) {
        if ((categoryCounts[catId] ?? 0) < 3) continue;

        final total = categoryTotals[catId]!;
        final avgMonthly = (total / 3).round();
        final suggestedBudget = (avgMonthly * 0.90).round();
        final savings = avgMonthly - suggestedBudget;

        final cat = categoryMeta[catId]!.category!;
        recommendations.add(
          AiBudgetRecommendation(
            categoryId: catId,
            categoryName: cat.name,
            categoryColor: cat.color,
            categoryIcon: cat.icon,
            avgMonthlySpend: avgMonthly,
            suggestedBudget: suggestedBudget,
            reasoning:
                'Média mensal de R\$ ${(avgMonthly / 100).toStringAsFixed(2).replaceAll('.', ',')}. Com esse limite, você economizaria R\$ ${(savings / 100).toStringAsFixed(2).replaceAll('.', ',')} por mês.',
          ),
        );
      }

      recommendations.sort(
        (a, b) => b.avgMonthlySpend.compareTo(a.avgMonthlySpend),
      );
      return recommendations.take(6).toList();
    },
    loading: () => [],
    error: (_, __) => [],
  );
});

// ─── Insights via Template NLG (sem LLM) ─────────────────────────────────────

/// Gera os 3 insights do período usando NLG baseada em templates sobre os
/// dados algorítmicos já existentes — substituto determinístico do
/// `llmInsightsProvider`, sempre disponível mesmo sem modelo carregado.
final templateInsightsProvider = Provider<List<String>>((ref) {
  final balance = ref.watch(totalBalanceProvider);
  final forecast = ref.watch(cashFlowForecastingProvider);
  final health = ref.watch(financialHealthScoreProvider);
  final trends = ref.watch(spendingTrendsProvider);

  // Categoria com maior gasto no mês corrente (insight #2).
  String topName = '';
  int topCents = 0;
  double topPct = 0;
  for (final t in trends) {
    if (t.currentMonthTotal > topCents) {
      topCents = t.currentMonthTotal;
      topName = t.categoryName;
      topPct = t.percentChange;
    }
  }

  return InsightNlgService.periodInsights(
    balanceCents: balance,
    savingsRate: health.savingsRate,
    cashFlowAlert: forecast.alertMessage,
    topCategoryName: topName,
    topCategoryCents: topCents,
    topCategoryPctChange: topPct,
    primaryRecommendation: health.primaryRecommendation,
  );
});
