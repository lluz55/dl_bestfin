import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestfin/features/llm/domain/models/chat_message.dart';
import 'package:bestfin/features/llm/domain/models/llm_metrics.dart';
import 'package:bestfin/features/llm/domain/services/llm_router_service.dart';
import 'package:bestfin/features/llm/domain/services/skill_registry.dart';
import 'package:bestfin/features/llm/presentation/providers/llm_provider.dart';
import 'package:bestfin/features/llm/domain/services/llm_tools_service.dart';

final chatHistoryProvider =
    NotifierProvider<ChatHistoryNotifier, List<ChatMessage>>(
      ChatHistoryNotifier.new,
    );

class ChatHistoryNotifier extends Notifier<List<ChatMessage>> {
  String? _lastSkillId;
  bool _cancelled = false;

  @override
  List<ChatMessage> build() => [];

  void stopGeneration() {
    _cancelled = true;
  }

  Future<void> sendMessage(String text) async {
    final llmState = ref.read(llmStateProvider);
    if (!llmState.canChat) return;

    _cancelled = false;

    final userMsg = ChatMessage.user(text);
    debugPrint('[Chat] Usuário: $text');
    state = [...state, userMsg];

    // Start assistant message in routing state
    var assistantMsg = ChatMessage(
      role: ChatRole.assistant,
      content: '',
      createdAt: DateTime.now(),
      isRouting: true,
    );
    state = [...state, assistantMsg];

    ref.read(llmStateProvider.notifier).setGenerating(true);

    LlmMetrics? collectedMetrics;
    final enableThinking = ref.read(llmThinkingEnabledProvider);
    final thinkingBuffer = StringBuffer();

    try {
      final service = ref.read(llmServiceProvider);

      // Step 1: Route the message to a skill
      final router = ref.read(llmRouterServiceProvider);
      final skillId = await router.route(text);
      if (_cancelled) return;

      final skill = SkillRegistry.instance.get(skillId);

      // Update message: routing done, skill identified
      assistantMsg = assistantMsg.copyWith(
        isRouting: false,
        activeSkill: skillId,
      );
      _updateLast(assistantMsg);

      // Step 2: Handle out-of-scope immediately (no LLM call)
      if (skill.isStaticResponse) {
        assistantMsg = assistantMsg.copyWith(content: skill.staticResponse!);
        _updateLast(assistantMsg);
        return;
      }

      // Step 3: Reset native history only when the skill changes.
      if (_lastSkillId != skillId) {
        await service.clearHistory();
        _lastSkillId = skillId;
      }

      // Step 4: Build skill-specific context and update system prompt.
      final rawContext = await skill.buildContext(ref);
      final contextData = rawContext.length > skill.maxContextChars
          ? rawContext.substring(0, skill.maxContextChars)
          : rawContext;
      await service.updateSystemPrompt(skill.systemPrompt(contextData));

      // Step 5: Stream the skill response
      final stream = service.sendMessage(
        text,
        onMetrics: (m) => collectedMetrics = m,
        enableThinking: enableThinking,
        onThinkingToken: enableThinking
            ? (token) {
                thinkingBuffer.write(token);
                assistantMsg = assistantMsg.copyWith(
                  thinkingContent: thinkingBuffer.toString(),
                );
                _updateLast(assistantMsg);
              }
            : null,
      );
      final buffer = StringBuffer();

      await for (final token in stream) {
        if (_cancelled) break;
        buffer.write(token);
        assistantMsg = assistantMsg.copyWith(content: buffer.toString());
        _updateLast(assistantMsg);
      }

      if (_cancelled) return;

      // Step 6: Parse all tool calls (filtered to this skill's tools)
      final fullResponse = buffer.toString();
      final parsedCalls = LlmToolsService.parseAll(
        fullResponse,
        allowedTools: skill.toolNames,
      );

      if (parsedCalls.isNotEmpty) {
        // Clear generated content — tool results will produce the final answer
        assistantMsg = assistantMsg.copyWith(content: '');
        _updateLast(assistantMsg);

        final allToolResults = <String>[];

        for (final parsed in parsedCalls) {
          if (_cancelled) break;
          debugPrint('[Tool] ${parsed.toolName}(${parsed.argument})');

          final toolDetail = _toolDetail(parsed.toolName, parsed.argument);
          final record = ToolCallRecord(
            description: toolDetail,
            toolName: parsed.toolName,
            isRunning: true,
          );

          assistantMsg = assistantMsg.copyWith(
            toolCalls: [...assistantMsg.toolCalls, record],
          );
          _updateLast(assistantMsg);

          String toolResult;
          try {
            toolResult = await LlmToolsService.execute(ref, parsed);
            debugPrint('[Tool] resultado: $toolResult');
          } catch (e) {
            debugPrint('[Tool] erro ao executar ${parsed.toolName}: $e');
            toolResult =
                'Nenhum dado disponível — ${parsed.toolName} não pôde ser executado.';
          }

          allToolResults.add('Ferramenta ${parsed.toolName}:\n$toolResult');

          final updatedCalls = assistantMsg.toolCalls.toList();
          updatedCalls[updatedCalls.length - 1] = record.copyWith(
            isRunning: false,
            result: toolResult,
          );
          assistantMsg = assistantMsg.copyWith(toolCalls: updatedCalls);
          _updateLast(assistantMsg);
        }

        if (_cancelled) return;

        // Step 7: One final LLM call with all collected tool results
        assistantMsg = assistantMsg.copyWith(isPostToolStreaming: true);
        _updateLast(assistantMsg);

        final toolResultsText = allToolResults.join('\n\n');
        final toolPrompt =
            'Pergunta original do usuário:\n'
            '$text\n\n'
            '$toolResultsText\n\n'
            'Responda agora em português, de forma final, curta e útil. '
            'Não chame outra ferramenta.';

        final finalStream = service.sendMessage(
          toolPrompt,
          onMetrics: (m) => collectedMetrics = m,
        );

        final finalBuffer = StringBuffer();
        await for (final token in finalStream) {
          if (_cancelled) break;
          finalBuffer.write(token);
          assistantMsg = assistantMsg.copyWith(content: finalBuffer.toString());
          _updateLast(assistantMsg);
        }
      }

      if (state.last.content.isNotEmpty) {
        debugPrint('[Chat] IA: ${state.last.content}');
      }

      if (collectedMetrics != null) {
        final updated = state.toList();
        updated[updated.length - 1] = updated.last.copyWith(
          metrics: collectedMetrics,
        );
        state = updated;
      }
    } catch (e, st) {
      if (_cancelled) return;
      debugPrint('[LLM] Erro ao gerar resposta: $e\n$st');
      assistantMsg = assistantMsg.copyWith(
        content: 'Erro ao gerar resposta: $e',
        isRouting: false,
      );
      _updateLast(assistantMsg);
    } finally {
      ref.read(llmStateProvider.notifier).setGenerating(false);
    }
  }

  Future<void> clearHistory() async {
    state = [];
    _lastSkillId = null;
    await ref.read(llmServiceProvider).clearHistory();
  }

  void _updateLast(ChatMessage msg) {
    final updated = state.toList();
    updated[updated.length - 1] = msg;
    state = updated;
  }

  static String _toolDetail(String toolName, String argument) =>
      switch (toolName) {
        'CALCULATE' => 'Calculando "$argument"...',
        'GET_GOALS' => 'Buscando suas metas financeiras...',
        'GET_RECURRING' => 'Buscando transações recorrentes...',
        'GET_SPENDING_SUMMARY' => 'Calculando resumo de gastos por categoria...',
        _ => 'Buscando informações no banco de dados...',
      };
}
