import 'package:bestfin/cli/tui/screens/base.dart';
import 'package:bestfin/cli/tui/term.dart';
import 'package:bestfin/core/constants/transaction_types.dart';
import 'package:bestfin/features/dashboard/domain/usecases/get_dashboard_data.dart';

/// Painel: o mesmo resumo da tela inicial da GUI, em texto.
class DashboardScreen extends Screen {
  DashboardScreen(super.ctx);

  @override
  String get title => 'Painel';

  static const _periods = [
    'Este mês',
    'Esta semana',
    '3 meses',
    '6 meses',
    'Ano',
  ];

  int _periodIndex = 0;

  @override
  Future<void> run() async {
    while (true) {
      final data = await GetDashboardData(
        transactionRepository: ctx.transactions,
        accountRepository: ctx.accounts,
        goalRepository: ctx.goals,
      ).call(periodIndex: _periodIndex).first;

      final lines = <String>[
        '',
        '  ${Term.bold}Saldo total${Term.reset}          '
            '${Term.formatMoneyColored(data.totalBalance)}',
        '  Receitas do período   '
            '${Term.c(Term.formatMoney(data.monthlyIncome), Term.green)}',
        '  Despesas do período   '
            '${Term.c(Term.formatMoney(data.monthlyExpense), Term.red)}',
        '  Resultado             '
            '${Term.formatMoneyColored(data.monthlyIncome - data.monthlyExpense, sign: true)}',
        '  Livre para gastar     '
            '${Term.formatMoneyColored(data.freeToSpendAmount)} '
            '${Term.gray}(${data.freeToSpendPercentage.toStringAsFixed(0)}%)${Term.reset}',
        '',
        '  ${Term.bold}Gastos por categoria${Term.reset}',
        if (data.categoryExpenses.isEmpty)
          '    ${Term.gray}sem gastos no período${Term.reset}',
        ...data.categoryExpenses
            .take(8)
            .map(
              (c) =>
                  '    ${Term.pad(c.categoryName, 22)} '
                  '${Term.progressBar(c.percentage / 100, cols: 16)} '
                  '${Term.padLeft('${c.percentage.round()}%', 5)} '
                  '${Term.padLeft(Term.formatMoney(c.amountInCents), 15)}',
            ),
        '',
        '  ${Term.bold}Histórico mensal${Term.reset}',
        ..._monthlyBars(data.monthlyHistory),
        '',
        '  ${Term.bold}Metas ativas${Term.reset}',
        if (data.activeGoals.isEmpty)
          '    ${Term.gray}nenhuma meta ativa${Term.reset}',
        ...data.activeGoals
            .take(5)
            .map(
              (g) =>
                  '    ${Term.pad(g.name, 22)} '
                  '${Term.progressBar(g.progressFraction, cols: 16)} '
                  '${Term.padLeft('${g.progressPercent.round()}%', 5)} '
                  '${Term.padLeft(Term.formatMoney(g.currentAmountInCents), 15)}',
            ),
        '',
        '  ${Term.bold}Próximos lançamentos${Term.reset}',
        if (data.upcomingTransactions.isEmpty)
          '    ${Term.gray}nada agendado${Term.reset}',
        ...data.upcomingTransactions
            .take(6)
            .map(
              (t) =>
                  '    ${Term.formatDate(t.date)}  '
                  '${Term.pad(t.description, 28)} '
                  '${Term.padLeft(_signed(t.type, t.amount), 16)}',
            ),
        '',
        '  ${Term.bold}Últimos lançamentos${Term.reset}',
        if (data.recentTransactions.isEmpty)
          '    ${Term.gray}nenhum lançamento${Term.reset}',
        ...data.recentTransactions
            .take(8)
            .map(
              (t) =>
                  '    ${Term.formatDate(t.date)}  '
                  '${Term.pad(t.description, 28)} '
                  '${Term.padLeft(_signed(t.type, t.amount), 16)}',
            ),
        '',
      ];

      final action = _pagerWithPeriod(lines);
      if (action == null) return;
    }
  }

  String _signed(TransactionType type, int amount) => switch (type) {
    TransactionType.income => Term.c(
      '+${Term.formatMoney(amount.abs())}',
      Term.green,
    ),
    TransactionType.expense => Term.c(
      '-${Term.formatMoney(amount.abs())}',
      Term.red,
    ),
    TransactionType.transfer => '↔ ${Term.formatMoney(amount.abs())}',
  };

  List<String> _monthlyBars(List<dynamic> bars) {
    if (bars.isEmpty) return ['    ${Term.gray}sem histórico${Term.reset}'];
    final maxValue = bars.fold<int>(
      1,
      (m, b) => [
        m,
        b.income as int,
        b.expense as int,
      ].reduce((a, c) => a > c ? a : c),
    );
    return bars.map((b) {
      final label = Term.monthLabel(b.year as int, b.month as int);
      final income = ((b.income as int) / maxValue * 18).round();
      final expense = ((b.expense as int) / maxValue * 18).round();
      return '    ${Term.pad(label, 9)}'
          '${Term.c('█' * income, Term.green)}${' ' * (18 - income)} '
          '${Term.c('█' * expense, Term.red)}${' ' * (18 - expense)} '
          '${Term.padLeft(Term.formatMoneyColored((b.income as int) - (b.expense as int), sign: true), 16)}';
    }).toList();
  }

  /// Pager com troca de período — devolve `null` quando o usuário sai.
  bool? _pagerWithPeriod(List<String> lines) {
    var offset = 0;
    while (true) {
      final viewport = (Term.height - 6).clamp(3, 1000);
      final maxOffset = (lines.length - viewport).clamp(0, lines.length);
      if (offset > maxOffset) offset = maxOffset;

      Term.clear();
      Term.header(title, subtitle: 'Período: ${_periods[_periodIndex]}');
      for (var i = offset; i < offset + viewport && i < lines.length; i++) {
        Term.writeln(Term.truncate(lines[i], Term.width));
      }
      Term.footer(const [
        TermAction('↑↓', 'rolar'),
        TermAction('p', 'período'),
        TermAction('q', 'voltar'),
      ]);

      final key = Term.readKey();
      if (key.code == KeyCode.esc ||
          key.code == KeyCode.ctrlC ||
          key.is_('q')) {
        return null;
      }
      if (key.is_('p')) {
        final i = Term.select(
          'Período',
          items: _periods,
          initialIndex: _periodIndex,
        );
        if (i != null) _periodIndex = i;
        return true;
      }
      switch (key.code) {
        case KeyCode.up:
          offset = (offset - 1).clamp(0, maxOffset);
        case KeyCode.down:
          offset = (offset + 1).clamp(0, maxOffset);
        case KeyCode.pageUp:
          offset = (offset - viewport).clamp(0, maxOffset);
        case KeyCode.pageDown:
          offset = (offset + viewport).clamp(0, maxOffset);
        case KeyCode.home:
          offset = 0;
        case KeyCode.end:
          offset = maxOffset;
        default:
          if (key.is_('j')) offset = (offset + 1).clamp(0, maxOffset);
          if (key.is_('k')) offset = (offset - 1).clamp(0, maxOffset);
      }
    }
  }
}
