import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bestfin/features/llm/domain/models/llm_state.dart';
import 'package:bestfin/features/llm/domain/services/financial_context_builder.dart';
import 'package:bestfin/features/llm/presentation/providers/llm_provider.dart';

const _cacheKey = 'llm_insights_cache';
const _cacheTimestampKey = 'llm_insights_timestamp';
const cacheTtlHours = 8;

final llmInsightsProvider = FutureProvider<List<String>>((ref) async {
  final llmState = ref.watch(llmStateProvider);
  if (llmState.status != LlmStatus.ready) return [];

  final prefs = await SharedPreferences.getInstance();
  final cachedTs = prefs.getInt(_cacheTimestampKey) ?? 0;
  final cachedAt = DateTime.fromMillisecondsSinceEpoch(cachedTs);
  final now = DateTime.now();

  if (now.difference(cachedAt).inHours < cacheTtlHours) {
    final cached = prefs.getStringList(_cacheKey);
    if (cached != null && cached.isNotEmpty) return cached;
  }

  final context = FinancialContextBuilder.build(ref);
  final service = ref.read(llmServiceProvider);

  final prompt = '''$context

Com base no contexto financeiro acima, gere exatamente 3 insights em português, um de cada tipo:
1. Sobre fluxo de caixa ou saldo atual (positivo ou alerta)
2. Sobre o gasto ou categoria mais relevante do período
3. Uma sugestão acionável e personalizada para melhorar as finanças

Cada insight deve começar com um emoji relevante e ter no máximo 2 linhas.
Separe cada insight com uma linha em branco.
Não use listas numeradas nem bullets extras.''';

  final response = await service.generateOnce(prompt, maxTokens: 250);
  final insights = response
      .split('\n\n')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .take(3)
      .toList();

  if (insights.isNotEmpty) {
    await prefs.setStringList(_cacheKey, insights);
    await prefs.setInt(_cacheTimestampKey, now.millisecondsSinceEpoch);
  }

  return insights;
});

/// Invalida o cache de insights se o TTL expirou; caso contrário, não faz nada.
/// Pode ser chamado a qualquer momento (ao carregar modelo, ao retomar o app, etc.)
final llmInsightsCacheInvalidatorProvider = Provider<void Function()>((ref) {
  return () async {
    final prefs = await SharedPreferences.getInstance();
    final cachedTs = prefs.getInt(_cacheTimestampKey) ?? 0;
    final cachedAt = DateTime.fromMillisecondsSinceEpoch(cachedTs);
    if (DateTime.now().difference(cachedAt).inHours >= cacheTtlHours) {
      await prefs.remove(_cacheKey);
      await prefs.remove(_cacheTimestampKey);
      ref.invalidate(llmInsightsProvider);
    }
  };
});
