import 'dart:io';

import 'package:bestfin/cli/llm_bridge.dart';
import 'package:bestfin/cli/tui/screens/base.dart';
import 'package:bestfin/cli/tui/term.dart';
import 'package:bestfin/core/constants/transaction_types.dart';
import 'package:bestfin/features/gamification/domain/services/insights_service.dart';
import 'package:bestfin/features/transactions/domain/models/transaction.dart';

/// Chat com o LLM on-device na TUI (task 60).
///
/// Regra de ouro do protocolo LLM: opcional e nunca bloqueante — se o
/// llama-server (:8087) não estiver pronto, a tela avisa e cai no fallback
/// determinístico (insights NLG por template, task 27). O prompt recebe
/// apenas **agregados** do período (totais por categoria), nunca lançamentos
/// brutos — mesma prática da GUI.
class ChatScreen extends Screen {
  ChatScreen(super.ctx);

  @override
  String get title => 'Chat — IA local';

  final _bridge = LlmBridge();
  final _history = <LlmMessage>[];

  static const _systemPrompt =
      'Você é o assistente financeiro do BestFin, um app de finanças '
      'pessoais. Responda em português do Brasil, de forma curta e '
      'direta. Use apenas os agregados fornecidos no contexto; não peça '
      'dados extras do usuário e não invente números.';

  @override
  Future<void> run() async {
    while (true) {
      final ready = await _bridge.isReady();
      final choice = Term.select(
        title,
        items: const [
          'Conversar com a IA',
          'Insights deste mês (IA, com fallback local)',
        ],
        subtitle: ready
            ? '${Term.green}●${Term.reset} llama-server pronto'
            : '${Term.yellow}●${Term.reset} LLM indisponível — fallback determinístico',
      );
      if (choice == null) return;

      switch (choice) {
        case 0:
          if (ready) {
            await _conversation();
          } else {
            Term.clear();
            Term.header(title);
            Term.writeln();
            Term.warn(
              'O LLM on-device não está pronto (llama-server em :8087). '
              'A TUI não dispara download nem carregamento de modelo — '
              'inicie o servidor (ou use o app gráfico) e volte aqui.',
            );
            Term.pause();
          }
        case 1:
          await _monthlyInsights(ready);
      }
    }
  }

  // ── Conversa ─────────────────────────────────────────────────────────

  Future<void> _conversation() async {
    while (true) {
      Term.clear();
      Term.header(
        'Chat — IA local',
        subtitle: 'histórico da sessão: ${_history.length ~/ 2} mensagem(ns)',
      );
      Term.writeln();
      for (var i = 0; i < _history.length; i += 2) {
        if (i < _history.length) {
          Term.writeln(
            '  ${Term.bold}Você:${Term.reset} ${_history[i].content}',
          );
        }
        if (i + 1 < _history.length) {
          for (final l in _wrap(_history[i + 1].content, Term.width - 8)) {
            Term.writeln('  ${Term.cyan}IA:${Term.reset} $l');
          }
        }
        Term.writeln();
      }

      final input = Term.input('Você (vazio volta):');
      if (input == null || input.trim().isEmpty) return;
      final question = input.trim();

      final aggregates = await _aggregateContext();
      final messages = [
        LlmMessage(
          'system',
          '$_systemPrompt\n\nAgregados dos últimos 31 dias (apenas isto):\n'
              '$aggregates',
        ),
        ..._history,
        LlmMessage('user', question),
      ];

      Term.write('  ${Term.cyan}IA:${Term.reset} ');
      Term.hideCursor();
      final answer = StringBuffer();
      try {
        await for (final token in _bridge.chatStream(messages)) {
          if (token.startsWith('\x00')) {
            Term.writeln();
            Term.error(_llmErrorText(token.substring(1)));
            break;
          }
          answer.write(token);
          stdout.write(token);
        }
        Term.writeln();
      } finally {
        Term.showCursor();
      }

      if (answer.isNotEmpty) {
        _history
          ..add(LlmMessage('user', question))
          ..add(LlmMessage('assistant', answer.toString()));
        // Mantém a conversa enxuta no prompt.
        while (_history.length > 12) {
          _history.removeRange(0, 2);
        }
      }
      Term.writeln();
      Term.writeln('  ${Term.gray}↵ nova mensagem • vazio volta${Term.reset}');
      final cont = Term.readKey();
      if (cont.is_('q') || cont.code == KeyCode.esc) return;
    }
  }

  // ── Insights on-demand ───────────────────────────────────────────────

  Future<void> _monthlyInsights(bool llmReady) async {
    Term.clear();
    Term.header('Insights deste mês');
    Term.writeln();
    Term.writeln('  ${Term.gray}Analisando agregados do período…${Term.reset}');
    Term.writeln();

    if (llmReady) {
      final aggregates = await _aggregateContext();
      final answer = await _bridge.chatOnce([
        LlmMessage(
          'system',
          '$_systemPrompt\n\nAgregados dos últimos 31 dias (apenas isto):\n'
              '$aggregates',
        ),
        const LlmMessage('user', 'Meus insights deste mês'),
      ]);
      if (answer != null && answer.trim().isNotEmpty) {
        Term.pager('Insights (IA local)', [
          '',
          ..._wrap(answer.trim(), Term.width - 4),
          '',
        ]);
        return;
      }
      Term.warn('IA não respondeu — usando o fallback determinístico.');
      Term.writeln();
    }

    // Fallback: insights NLG por template (task 27) — os mesmos da tela
    // de Conquistas.
    try {
      final service = InsightsService(
        transactionRepository: ctx.transactions,
        db: ctx.db,
        accountRepository: ctx.accounts,
        goalRepository: ctx.goals,
        investmentRepository: ctx.investments,
      );
      final insights = await service.generateInsights();
      Term.pager('Insights (local)', [
        '',
        if (insights.isEmpty)
          '  ${Term.gray}Sem insights no momento.${Term.reset}',
        for (final i in insights) ...[
          '  ${i.icon} ${Term.bold}${i.category?.name ?? 'geral'}${Term.reset}',
          ..._wrap(i.text, Term.width - 6).map((l) => '     $l'),
          '',
        ],
      ]);
    } catch (e) {
      Term.error(Screen.describeError(e));
      Term.pause();
    }
  }

  // ── Agregados (única coisa que vai ao prompt) ────────────────────────

  /// Totais do período por categoria — agregados apenas, sem lançamentos
  /// individuais (mesma prática da GUI).
  Future<String> _aggregateContext() async {
    final history = await ctx.recentHistory(days: 31);
    final expenses = history
        .where((t) => t.type == TransactionType.expense && t.isCompleted)
        .toList();
    final income = history
        .where((t) => t.type == TransactionType.income && t.isCompleted)
        .fold<int>(0, (s, t) => s + t.amount.abs());
    final totalExpense = expenses.fold<int>(0, (s, t) => s + t.amount.abs());

    final byCategory = <String, int>{};
    final categories = await ctx.rawCategories();
    final names = {for (final c in categories) c.id: c.name};
    for (final TransactionModel t in expenses) {
      final name = t.categoryId == null
          ? '(sem categoria)'
          : (names[t.categoryId] ?? t.categoryId!);
      byCategory[name] = (byCategory[name] ?? 0) + t.amount.abs();
    }
    final ranked = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final buf = StringBuffer();
    buf.writeln('- receitas: R\$ ${(income / 100).toStringAsFixed(2)}');
    buf.writeln('- despesas: R\$ ${(totalExpense / 100).toStringAsFixed(2)}');
    buf.writeln('- despesas por categoria (R\$):');
    for (final e in ranked.take(10)) {
      buf.writeln('  ${e.key}: ${(e.value / 100).toStringAsFixed(2)}');
    }
    return buf.toString();
  }

  String _llmErrorText(String raw) {
    return 'Falou com o llama-server mas a resposta falhou: $raw\n'
        '  ${Term.gray}Dica: verifique se o servidor on-device está de pé; '
        'a TUI nunca baixa modelo por conta própria.${Term.reset}';
  }

  List<String> _wrap(String text, int cols) {
    final words = text.split(RegExp(r'\s+'));
    final lines = <String>[];
    var current = StringBuffer();
    for (final w in words) {
      if (current.isEmpty) {
        current.write(w);
      } else if (current.length + 1 + w.length <= cols) {
        current.write(' $w');
      } else {
        lines.add(current.toString());
        current = StringBuffer(w);
      }
    }
    if (current.isNotEmpty) lines.add(current.toString());
    return lines;
  }
}
