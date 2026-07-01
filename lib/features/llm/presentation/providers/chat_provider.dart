import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestfin/features/llm/domain/models/chat_message.dart';
import 'package:bestfin/features/llm/domain/models/llm_metrics.dart';
import 'package:bestfin/features/llm/presentation/providers/llm_provider.dart';
import 'package:bestfin/features/llm/domain/services/llm_tools_service.dart';
import 'package:bestfin/features/llm/domain/services/financial_context_builder.dart';

final chatHistoryProvider =
    NotifierProvider<ChatHistoryNotifier, List<ChatMessage>>(
      ChatHistoryNotifier.new,
    );

class ChatHistoryNotifier extends Notifier<List<ChatMessage>> {
  @override
  List<ChatMessage> build() => [];

  Future<void> sendMessage(String text) async {
    final llmState = ref.read(llmStateProvider);
    if (!llmState.canChat) return;

    final userMsg = ChatMessage.user(text);
    debugPrint('[Chat] Usuário: $text');
    state = [...state, userMsg];

    var assistantMsg = ChatMessage.assistant('');
    state = [...state, assistantMsg];

    ref.read(llmStateProvider.notifier).setGenerating(true);

    LlmMetrics? collectedMetrics;
    final enableThinking = ref.read(llmThinkingEnabledProvider);
    final thinkingBuffer = StringBuffer();

    try {
      final service = ref.read(llmServiceProvider);

      // Dynamically update the system prompt with the latest live financial context and date/time
      final latestContext = FinancialContextBuilder.build(ref);
      service.updateSystemPrompt(latestContext);

      // Step 1: Send user query to LLM and stream the response
      var stream = service.sendMessage(
        text,
        onMetrics: (m) => collectedMetrics = m,
        enableThinking: enableThinking,
        onThinkingToken: enableThinking
            ? (token) {
                thinkingBuffer.write(token);
                final updated = state.toList();
                updated[updated.length - 1] = assistantMsg.copyWith(
                  thinkingContent: thinkingBuffer.toString(),
                );
                state = updated;
                assistantMsg = state.last;
              }
            : null,
      );
      var buffer = StringBuffer();

      await for (final token in stream) {
        buffer.write(token);
        final updated = state.toList();
        updated[updated.length - 1] = assistantMsg.copyWith(
          content: buffer.toString(),
        );
        state = updated;
      }

      // Check if the response contains a tool call
      final fullResponse = buffer.toString();
      final parsed = LlmToolsService.parseFirst(fullResponse);

      if (parsed != null) {
        debugPrint('[Tool] ${parsed.toolName}(${parsed.argument})');

        // Step 2: Update UI message to show that a tool is running
        final toolDetail = switch (parsed.toolName) {
          'CALCULATE' => 'Calculando "${parsed.argument}"...',
          'GET_GOALS' => 'Buscando suas metas financeiras...',
          'GET_RECURRING' => 'Buscando transações recorrentes...',
          'GET_SPENDING_SUMMARY' =>
            'Calculando resumo de gastos por categoria...',
          _ => 'Buscando informações no banco de dados...',
        };

        assistantMsg = assistantMsg.copyWith(
          content: '', // Clear the raw [CALCULATE: ...] tag from UI content
          toolCall: toolDetail,
          isToolRunning: true,
        );

        final updatedList = state.toList();
        updatedList[updatedList.length - 1] = assistantMsg;
        state = updatedList;

        // Step 3: Execute the tool
        final toolResult = await LlmToolsService.execute(ref, parsed);
        debugPrint('[Tool] resultado: $toolResult');

        // Step 4: Update UI message to show the tool has finished and has results
        assistantMsg = assistantMsg.copyWith(
          isToolRunning: false,
          toolResult: toolResult,
          isPostToolStreaming: true,
        );

        final updatedList2 = state.toList();
        updatedList2[updatedList2.length - 1] = assistantMsg;
        state = updatedList2;

        // Step 5: Send tool result back to LLM to get the final human-readable response
        final toolPrompt =
            'Resultado da ferramenta ${parsed.toolName}:\n$toolResult\n\nAgora responda ao usuário de forma final, concisa, clara, profissional e amigável no mesmo idioma/linguagem que ele usou na pergunta com base nesse resultado.';

        final finalStream = service.sendMessage(
          toolPrompt,
          onMetrics: (m) =>
              collectedMetrics = m, // update with final generation metrics
        );

        final finalBuffer = StringBuffer();
        await for (final token in finalStream) {
          finalBuffer.write(token);
          final updated = state.toList();
          updated[updated.length - 1] = assistantMsg.copyWith(
            content: finalBuffer.toString(),
          );
          state = updated;
        }
      }

      final finalContent = state.last.content;
      if (finalContent.isNotEmpty) {
        debugPrint('[Chat] IA: $finalContent');
      }

      // Attach final metrics to the completed message
      if (collectedMetrics != null) {
        final updated = state.toList();
        updated[updated.length - 1] = updated.last.copyWith(
          metrics: collectedMetrics,
        );
        state = updated;
      }
    } catch (e, st) {
      debugPrint('[LLM] Erro ao gerar resposta: $e\n$st');
      final updated = state.toList();
      updated[updated.length - 1] = assistantMsg.copyWith(
        content: 'Erro ao gerar resposta: $e',
      );
      state = updated;
    } finally {
      ref.read(llmStateProvider.notifier).setGenerating(false);
    }
  }

  void clearHistory() {
    state = [];
    ref.read(llmServiceProvider).clearHistory();
  }
}
