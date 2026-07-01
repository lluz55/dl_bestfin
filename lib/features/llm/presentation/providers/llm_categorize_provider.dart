import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestfin/features/ai/presentation/providers/ai_provider.dart';
import 'package:bestfin/features/categories/presentation/providers/categories_provider.dart'
    show allFlatCategoriesProvider;
import 'package:bestfin/features/llm/domain/models/llm_state.dart';
import 'package:bestfin/features/llm/presentation/providers/llm_provider.dart';

/// Categorization pipeline: heuristic → Naive Bayes → LLM.
/// Each stage runs only when the previous returns confidence < 0.5.
final llmEnhancedCategorizeProvider =
    FutureProvider.family<AiCategorySuggestion?, String>((ref, query) async {
      // 1. Keyword + history heuristic
      final heuristic = ref.read(autoCategorizeProvider(query));
      if (heuristic != null && heuristic.confidence >= 0.5) return heuristic;

      // 2. Naive Bayes (trained on user history, no LLM cost)
      final nb = ref.read(naiveBayesCategorizeProvider(query));
      if (nb != null && nb.confidence >= 0.55) return nb;

      // 3. LLM fallback — only when model is ready
      final llmState = ref.read(llmStateProvider);
      if (llmState.status != LlmStatus.ready) return heuristic ?? nb;

      final categories = ref.read(allFlatCategoriesProvider);
      if (categories.isEmpty) return heuristic ?? nb;

      final categoryList = categories
          .map((c) => '${c.name} (${c.type})')
          .take(20)
          .join(', ');

      final service = ref.read(llmServiceProvider);
      final prompt =
          '''Categorize a seguinte transação financeira escolhendo UMA categoria da lista.
Transação: "$query"
Categorias disponíveis: $categoryList
Responda apenas com o nome exato da categoria, nada mais.''';

      try {
        final response = await service.generateOnce(prompt, maxTokens: 20);
        final normalized = response.trim().toLowerCase();

        // Find the best matching category by name
        for (final cat in categories) {
          if (cat.name.toLowerCase() == normalized ||
              normalized.contains(cat.name.toLowerCase())) {
            return AiCategorySuggestion(
              categoryId: cat.id,
              categoryName: cat.name,
              categoryColor: cat.color,
              categoryIcon: cat.icon,
              confidence: 0.75,
            );
          }
        }
      } catch (e, st) {
        debugPrint('[LLM] Falha na categorização: $e\n$st');
      }

      return heuristic ?? nb;
    });
