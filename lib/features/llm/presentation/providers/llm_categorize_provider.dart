import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestfin/features/ai/presentation/providers/ai_provider.dart';
import 'package:bestfin/features/categories/presentation/providers/categories_provider.dart'
    show allFlatCategoriesProvider;
import 'package:bestfin/features/llm/domain/models/llm_state.dart';
import 'package:bestfin/features/llm/presentation/providers/llm_provider.dart';

/// Wraps [autoCategorizeProvider] and falls back to the LLM when confidence < 0.5.
final llmEnhancedCategorizeProvider =
    FutureProvider.family<AiCategorySuggestion?, String>((ref, query) async {
      // Heuristic result
      final heuristic = ref.read(autoCategorizeProvider(query));
      if (heuristic != null && heuristic.confidence >= 0.5) return heuristic;

      // Only call LLM when model is ready
      final llmState = ref.read(llmStateProvider);
      if (llmState.status != LlmStatus.ready) return heuristic;

      final categories = ref.read(allFlatCategoriesProvider);
      if (categories.isEmpty) return heuristic;

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

      return heuristic;
    });
