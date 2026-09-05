import 'dart:io';

import 'package:bestfin/cli/tui/context.dart';
import 'package:bestfin/cli/tui/screens/accounts_screen.dart';
import 'package:bestfin/cli/tui/screens/backup_screen.dart';
import 'package:bestfin/cli/tui/screens/base.dart';
import 'package:bestfin/cli/tui/screens/budgets_screen.dart';
import 'package:bestfin/cli/tui/screens/cashflow_screen.dart';
import 'package:bestfin/cli/tui/screens/categories_screen.dart';
import 'package:bestfin/cli/tui/screens/chat_screen.dart';
import 'package:bestfin/cli/tui/screens/credit_cards_screen.dart';
import 'package:bestfin/cli/tui/screens/dashboard_screen.dart';
import 'package:bestfin/cli/tui/screens/financing_screen.dart';
import 'package:bestfin/cli/tui/screens/gamification_screen.dart';
import 'package:bestfin/cli/tui/screens/goals_screen.dart';
import 'package:bestfin/cli/tui/screens/households_screen.dart';
import 'package:bestfin/cli/tui/screens/installments_screen.dart';
import 'package:bestfin/cli/tui/screens/investments_screen.dart';
import 'package:bestfin/cli/tui/screens/pdf_import_screen.dart';
import 'package:bestfin/cli/tui/screens/recurring_screen.dart';
import 'package:bestfin/cli/tui/screens/reports_screen.dart';
import 'package:bestfin/cli/tui/screens/settings_screen.dart';
import 'package:bestfin/cli/tui/screens/sync_screen.dart';
import 'package:bestfin/cli/tui/screens/transactions_screen.dart';
import 'package:bestfin/cli/tui/term.dart';

/// Uma entrada do menu principal.
class TuiEntry {
  const TuiEntry(this.label, this.hint, this.build);

  final String label;
  final String hint;
  final Screen Function(TuiContext) build;
}

/// Menu principal da TUI — dá acesso a todas as áreas do app.
class TuiApp {
  TuiApp(this.ctx);

  final TuiContext ctx;

  static const entries = <TuiEntry>[
    TuiEntry(
      'Painel',
      'saldo, receitas, despesas e o resumo do período',
      DashboardScreen.new,
    ),
    TuiEntry(
      'Transações',
      'listar, filtrar, criar (formulário ou frase), editar e excluir',
      TransactionsScreen.new,
    ),
    TuiEntry(
      'Contas',
      'saldos, criação, edição e arquivamento',
      AccountsScreen.new,
    ),
    TuiEntry(
      'Categorias',
      'árvore de categorias, subcategorias e ordenação',
      CategoriesScreen.new,
    ),
    TuiEntry(
      'Cartões de crédito',
      'limites, faturas e pagamento de fatura',
      CreditCardsScreen.new,
    ),
    TuiEntry(
      'Orçamentos',
      'planejado × gasto por período, com rollover',
      BudgetsScreen.new,
    ),
    TuiEntry('Metas', 'progresso, aportes e simulação mensal', GoalsScreen.new),
    TuiEntry(
      'Parcelamentos',
      'planos de parcelas, acompanhamento e cancelamento',
      InstallmentsScreen.new,
    ),
    TuiEntry(
      'Recorrências',
      'regras que se repetem, pausa e geração antecipada',
      RecurringScreen.new,
    ),
    TuiEntry(
      'Financiamentos',
      'SAC/Price, tabela de parcelas e baixa de pagamento',
      FinancingScreen.new,
    ),
    TuiEntry(
      'Investimentos',
      'carteira, aportes e rendimento',
      InvestmentsScreen.new,
    ),
    TuiEntry(
      'Relatórios',
      'categorias, evolução mensal, fluxo, patrimônio e Sankey',
      ReportsScreen.new,
    ),
    TuiEntry(
      'Projeção de caixa',
      'saldo projetado a partir dos lançamentos futuros',
      CashflowScreen.new,
    ),
    TuiEntry(
      'Conquistas e insights',
      'sequências, medalhas e análises automáticas',
      GamificationScreen.new,
    ),
    TuiEntry(
      'Chat (IA)',
      'converse com o LLM local e peça insights do mês',
      ChatScreen.new,
    ),
    TuiEntry(
      'Importar PDF',
      'faturas e comprovantes de banco',
      PdfImportScreen.new,
    ),
    TuiEntry(
      'Backup e dados',
      'exportar, importar e restaurar',
      BackupScreen.new,
    ),
    TuiEntry(
      'Sincronização',
      'fila, identidade Nostr e relays',
      SyncScreen.new,
    ),
    TuiEntry(
      'Grupos familiares',
      'compartilhar dados com quem divide as contas',
      HouseholdsScreen.new,
    ),
    TuiEntry(
      'Configurações',
      'preferências, diagnóstico e limpar dados',
      SettingsScreen.new,
    ),
  ];

  /// Casa o nome informado em `bestfin tui <área>` com uma entrada do menu.
  /// Aceita prefixos ("orc" → Orçamentos), ignorando acentos e caixa;
  /// devolve `null` quando não há correspondência ou ela é ambígua.
  static Screen? resolveArea(TuiContext ctx, String area) {
    final needle = normalizeLabel(area);
    if (needle.isEmpty) return null;
    for (final entry in entries) {
      if (normalizeLabel(entry.label) == needle) return entry.build(ctx);
    }
    final matches = entries
        .where((e) => normalizeLabel(e.label).startsWith(needle))
        .toList();
    return matches.length == 1 ? matches.first.build(ctx) : null;
  }

  /// Minúsculas sem acento — usado para casar o nome da área.
  static String normalizeLabel(String s) {
    const accented = 'áàâãäéèêëíìîïóòôõöúùûüç';
    const plain = 'aaaaaeeeeiiiiooooouuuuc';
    final buffer = StringBuffer();
    for (final ch in s.toLowerCase().split('')) {
      final i = accented.indexOf(ch);
      buffer.write(i >= 0 ? plain[i] : ch);
    }
    return buffer.toString().trim();
  }

  /// Executa o menu até o usuário sair. Retorna o exit code do processo.
  Future<int> run() async {
    if (!Term.isInteractive) {
      stderr.writeln(const TuiNotInteractive().toString());
      return 1;
    }

    Term.enterAlt();
    Term.enterRaw();
    // Sync residente: começa junto com a TUI (sem identidade fica inativo).
    try {
      await ctx.sync.start();
    } catch (_) {}
    try {
      while (true) {
        if (ctx.exitReason != null) {
          Term.restore();
          stdout.writeln(ctx.exitReason);
          return 0;
        }

        final summary = await _summary();
        final index = Term.select(
          'BestFin',
          items: entries.map((e) => e.label).toList(),
          details: entries.map((e) => e.hint).toList(),
          subtitle: summary,
        );
        if (index == null) return 0;

        final screen = entries[index].build(ctx);
        try {
          await screen.run();
        } on TuiNotInteractive {
          rethrow;
        } catch (e) {
          Term.clear();
          Term.header('Erro em "${entries[index].label}"');
          Term.writeln();
          Term.error(Screen.describeError(e));
          Term.writeln();
          Term.pause();
        }
      }
    } finally {
      Term.restore();
    }
  }

  /// Linha de resumo do menu — saldo total, pendências de sync e o estado
  /// do engine residente (quando iniciado e com identidade).
  Future<String> _summary() async {
    try {
      final accounts = await ctx.accounts.watchAllAccounts().first;
      final total = accounts
          .where((a) => a.isActive)
          .fold<int>(0, (s, a) => s + a.balance);
      final pending = await (ctx.db.select(
        ctx.db.syncQueue,
      )..where((t) => t.synced.equals(false))).get();

      var line =
          'Saldo ${Term.formatMoney(total)} • '
          '${accounts.length} conta(s)';
      if (ctx.hasSyncEngine && ctx.sync.state.hasIdentity) {
        final st = ctx.sync.state;
        line += ' • ${st.statusLine(onlineRelays: 0, peers: 0)}';
      } else if (pending.isNotEmpty) {
        line += ' • ${pending.length} item(ns) na fila de sync';
      }
      return line;
    } catch (_) {
      return ctx.dbPath;
    }
  }
}
