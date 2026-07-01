import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:bestfin/features/llm/domain/models/llm_state.dart';
import 'package:bestfin/features/llm/presentation/providers/llm_provider.dart';
import 'package:bestfin/features/ai/presentation/providers/ai_provider.dart';

const _healthNarrativeKey = 'llm_health_narrative';
const _healthNarrativeTsKey = 'llm_health_narrative_ts';
const _sentimentNarrativeKey = 'llm_sentiment_narrative';
const _sentimentNarrativeTsKey = 'llm_sentiment_narrative_ts';
const _narrativeTtlHours = 8;

// Generates a personalized health score recommendation text via LLM.
// Falls back to empty string so the dashboard uses the algorithmic text.
final llmHealthNarrativeProvider = FutureProvider<String>((ref) async {
  final llmState = ref.watch(llmStateProvider);
  if (llmState.status != LlmStatus.ready) return '';

  final prefs = await SharedPreferences.getInstance();
  final ts = prefs.getInt(_healthNarrativeTsKey) ?? 0;
  final cachedAt = DateTime.fromMillisecondsSinceEpoch(ts);
  if (DateTime.now().difference(cachedAt).inHours < _narrativeTtlHours) {
    final cached = prefs.getString(_healthNarrativeKey);
    if (cached != null && cached.isNotEmpty) return cached;
  }

  final health = ref.read(financialHealthScoreProvider);
  final anomalies = ref.read(anomalyDetectionProvider);
  final fmt = NumberFormat('#,##0.0', 'pt_BR');

  final anomalyText = anomalies.isEmpty
      ? 'sem anomalias detectadas'
      : '${anomalies.length} anomalia(s) detectada(s)';

  final prompt =
      '''Você é um consultor financeiro. Com base nos dados abaixo, escreva UMA frase curta e personalizada de recomendação em português (máximo 25 palavras). Seja direto, encorajador e específico. Não use jargão técnico.

Dados:
- Nota de saúde financeira: ${health.score}/100 (grau ${health.grade})
- Taxa de poupança: ${fmt.format(health.savingsRate * 100)}%
- Anomalias: $anomalyText

Escreva apenas a frase de recomendação, sem explicações adicionais.''';

  try {
    final service = ref.read(llmServiceProvider);
    final response = await service.generateOnce(prompt, maxTokens: 60);
    final clean = response.trim();
    if (clean.isEmpty) return '';
    await prefs.setString(_healthNarrativeKey, clean);
    await prefs.setInt(
      _healthNarrativeTsKey,
      DateTime.now().millisecondsSinceEpoch,
    );
    return clean;
  } catch (_) {
    return '';
  }
});

// Generates 2–3 psychological spending pattern insights via LLM.
// Falls back to empty list so the dashboard uses the algorithmic insights.
final llmSentimentNarrativeProvider = FutureProvider<List<String>>((ref) async {
  final llmState = ref.watch(llmStateProvider);
  if (llmState.status != LlmStatus.ready) return [];

  final prefs = await SharedPreferences.getInstance();
  final ts = prefs.getInt(_sentimentNarrativeTsKey) ?? 0;
  final cachedAt = DateTime.fromMillisecondsSinceEpoch(ts);
  if (DateTime.now().difference(cachedAt).inHours < _narrativeTtlHours) {
    final cached = prefs.getStringList(_sentimentNarrativeKey);
    if (cached != null && cached.isNotEmpty) return cached;
  }

  final sentiments = ref.read(sentimentCorrelationProvider);
  final fmt = NumberFormat('#,##0', 'pt_BR');

  final prompt =
      '''Você é um psicólogo financeiro. Com base nos dados de sentimento abaixo, escreva exatamente 2 insights curtos em português sobre o comportamento financeiro do usuário. Cada insight deve ser de no máximo 2 linhas e começar com um emoji. Separe com linha em branco. Seja empático e construtivo.

Dados:
- Gastos com bem-estar: ${fmt.format(sentiments.positivePercentage * 100)}%
- Gastos neutros: ${fmt.format(sentiments.neutralPercentage * 100)}%
- Gastos impulsivos/arrependidos: ${fmt.format(sentiments.negativePercentage * 100)}%

Escreva apenas os 2 insights, sem título ou texto adicional.''';

  try {
    final service = ref.read(llmServiceProvider);
    final response = await service.generateOnce(prompt, maxTokens: 120);
    final insights = response
        .split('\n\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .take(2)
        .toList();
    if (insights.isEmpty) return [];
    await prefs.setStringList(_sentimentNarrativeKey, insights);
    await prefs.setInt(
      _sentimentNarrativeTsKey,
      DateTime.now().millisecondsSinceEpoch,
    );
    return insights;
  } catch (_) {
    return [];
  }
});

/// Invalidate all narrative caches (call when insights TTL expires or model reloads).
final llmNarrativeCacheInvalidatorProvider = Provider<void Function()>((ref) {
  return () async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    for (final tsKey in [_healthNarrativeTsKey, _sentimentNarrativeTsKey]) {
      final ts = prefs.getInt(tsKey) ?? 0;
      final cachedAt = DateTime.fromMillisecondsSinceEpoch(ts);
      if (now.difference(cachedAt).inHours >= _narrativeTtlHours) {
        await prefs.remove(
          tsKey == _healthNarrativeTsKey
              ? _healthNarrativeKey
              : _sentimentNarrativeKey,
        );
        await prefs.remove(tsKey);
      }
    }
    ref.invalidate(llmHealthNarrativeProvider);
    ref.invalidate(llmSentimentNarrativeProvider);
  };
});
