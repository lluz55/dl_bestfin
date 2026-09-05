import 'package:bestfin/cli/tui/screens/base.dart';
import 'package:bestfin/cli/tui/term.dart';
import 'package:bestfin/features/reports/domain/usecases/generate_cash_flow.dart';
import 'package:bestfin/features/reports/domain/usecases/generate_category_report.dart';
import 'package:bestfin/features/reports/domain/usecases/generate_monthly_report.dart';
import 'package:bestfin/features/reports/domain/usecases/generate_net_worth.dart';
import 'package:bestfin/features/reports/domain/usecases/generate_sankey_report.dart';

/// Relatórios: os mesmos cinco da GUI, renderizados como gráficos de texto.
class ReportsScreen extends Screen {
  ReportsScreen(super.ctx);

  @override
  String get title => 'Relatórios';

  DateTime _start = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _end = DateTime(
    DateTime.now().year,
    DateTime.now().month + 1,
    0,
    23,
    59,
    59,
  );

  @override
  Future<void> run() async {
    while (true) {
      final options = [
        'Despesas por categoria',
        'Evolução mensal (receitas × despesas)',
        'Fluxo de caixa do período',
        'Patrimônio líquido',
        'Fluxo receitas → despesas (Sankey)',
        'Alterar período — ${Term.formatDate(_start)} a ${Term.formatDate(_end)}',
      ];
      final choice = Term.select(
        title,
        items: options,
        subtitle:
            'Período: ${Term.formatDate(_start)} → ${Term.formatDate(_end)}',
      );
      if (choice == null) return;

      switch (choice) {
        case 0:
          await _categoryReport();
        case 1:
          await _monthlyReport();
        case 2:
          await _cashFlowReport();
        case 3:
          await _netWorthReport();
        case 4:
          await _sankeyReport();
        case 5:
          await _pickPeriod();
      }
    }
  }

  Future<void> _pickPeriod() async {
    final now = DateTime.now();
    final i = Term.select(
      'Período dos relatórios',
      items: const [
        'Mês atual',
        'Mês anterior',
        'Últimos 3 meses',
        'Ano atual',
        'Personalizado',
      ],
    );
    if (i == null) return;
    switch (i) {
      case 0:
        _start = DateTime(now.year, now.month, 1);
        _end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
      case 1:
        _start = DateTime(now.year, now.month - 1, 1);
        _end = DateTime(now.year, now.month, 0, 23, 59, 59);
      case 2:
        _start = DateTime(now.year, now.month - 2, 1);
        _end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
      case 3:
        _start = DateTime(now.year, 1, 1);
        _end = DateTime(now.year, 12, 31, 23, 59, 59);
      case 4:
        final s = Term.inputDate('Início', initial: _start);
        if (s == null) return;
        final e = Term.inputDate('Fim', initial: _end);
        if (e == null) return;
        _start = s;
        _end = DateTime(e.year, e.month, e.day, 23, 59, 59);
    }
  }

  Future<void> _categoryReport() async {
    final report = await GenerateCategoryReport(
      ctx.transactions,
    ).call(startDate: _start, endDate: _end).first;

    Term.pager(
      'Despesas por categoria',
      [
        '',
        '  Total de despesas: ${Term.formatMoney(report.totalExpense)}',
        '',
        if (report.items.isEmpty)
          '  ${Term.gray}Sem despesas no período.${Term.reset}',
        ...report.items.map(
          (item) =>
              '  ${Term.pad(item.category?.displayName ?? 'Sem categoria', 24)} '
              '${Term.progressBar(item.percentage / 100, cols: 20)} '
              '${Term.padLeft('${item.percentage.toStringAsFixed(1)}%', 7)} '
              '${Term.padLeft(Term.formatMoney(item.amountInCents), 15)}'
              '${item.pendingAmountInCents > 0 ? ' ${Term.gray}(+${Term.formatMoney(item.pendingAmountInCents)} pendente)${Term.reset}' : ''}',
        ),
        '',
      ],
      subtitle: '${Term.formatDate(_start)} → ${Term.formatDate(_end)}',
    );
  }

  Future<void> _monthlyReport() async {
    final months = Term.inputInt('Quantos meses', initial: 6, min: 1, max: 36);
    if (months == null) return;

    final report = await GenerateMonthlyReport(
      ctx.transactions,
    ).call(months: months).first;

    final maxValue = report.bars.fold<int>(
      1,
      (m, b) => [m, b.income, b.expense].reduce((a, c) => a > c ? a : c),
    );

    Term.pager('Evolução mensal', [
      '',
      '  ${Term.c('█ receitas', Term.green)}   ${Term.c('█ despesas', Term.red)}',
      '',
      ...report.bars.map((b) {
        final income = (b.income / maxValue * 20).round();
        final expense = (b.expense / maxValue * 20).round();
        return '  ${Term.pad(Term.monthLabel(b.year, b.month), 9)}'
            '${Term.c('█' * income, Term.green)}${' ' * (20 - income)} '
            '${Term.c('█' * expense, Term.red)}${' ' * (20 - expense)} '
            '${Term.padLeft(Term.formatMoneyColored(b.income - b.expense, sign: true), 16)}';
      }),
      '',
      '  ${Term.bold}Totais${Term.reset}',
      '    Receitas: '
          '${Term.formatMoney(report.bars.fold<int>(0, (s, b) => s + b.income))}',
      '    Despesas: '
          '${Term.formatMoney(report.bars.fold<int>(0, (s, b) => s + b.expense))}',
      '',
    ]);
  }

  Future<void> _cashFlowReport() async {
    final report = await GenerateCashFlow(
      ctx.transactions,
    ).call(startDate: _start, endDate: _end).first;

    Term.pager(
      'Fluxo de caixa',
      [
        '',
        '  Receitas:  ${Term.c(Term.formatMoney(report.totalIncome), Term.green)}',
        '  Despesas:  ${Term.c(Term.formatMoney(report.totalExpense), Term.red)}',
        '  Resultado: '
            '${Term.formatMoneyColored(report.totalIncome - report.totalExpense, sign: true)}',
        '',
        '  ${Term.bold}Dia a dia${Term.reset}',
        if (report.points.isEmpty)
          '    ${Term.gray}Sem movimentação no período.${Term.reset}',
        ...report.points.map(
          (p) =>
              '    ${Term.formatDate(p.date)}  '
              '${Term.padLeft(Term.c('+${Term.formatMoney(p.income)}', Term.green), 18)}  '
              '${Term.padLeft(Term.c('-${Term.formatMoney(p.expense)}', Term.red), 18)}  '
              '${Term.gray}acumulado${Term.reset} '
              '${Term.padLeft(Term.formatMoneyColored(p.cumulativeBalance), 16)}',
        ),
        '',
      ],
      subtitle: '${Term.formatDate(_start)} → ${Term.formatDate(_end)}',
    );
  }

  Future<void> _netWorthReport() async {
    final months = Term.inputInt('Quantos meses', initial: 6, min: 1, max: 36);
    if (months == null) return;

    final report = await GenerateNetWorth(
      transactionRepository: ctx.transactions,
      accountRepository: ctx.accounts,
      database: ctx.db,
    ).call(months: months).first;

    final delta = report.currentNetWorth - report.previousNetWorth;
    final maxValue = report.points.fold<int>(
      1,
      (m, p) => p.netWorth.abs() > m ? p.netWorth.abs() : m,
    );

    Term.pager('Patrimônio líquido', [
      '',
      '  Atual:     ${Term.formatMoneyColored(report.currentNetWorth)}',
      '  Anterior:  ${Term.formatMoney(report.previousNetWorth)}',
      '  Variação:  ${Term.formatMoneyColored(delta, sign: true)}',
      '',
      ...report.points.map(
        (p) =>
            '  ${Term.pad(Term.monthLabel(p.date.year, p.date.month), 9)}'
            '${Term.progressBar(p.netWorth.abs() / maxValue, cols: 24, color: p.netWorth < 0 ? Term.red : Term.cyan)} '
            '${Term.padLeft(Term.formatMoneyColored(p.netWorth), 16)}',
      ),
      '',
    ]);
  }

  Future<void> _sankeyReport() async {
    final data = await GenerateSankeyReport(
      ctx.transactions,
    ).call(startDate: _start, endDate: _end).first;

    final byColumn = <int, List<dynamic>>{};
    for (final node in data.nodes) {
      byColumn.putIfAbsent(node.column, () => []).add(node);
    }
    final columns = byColumn.keys.toList()..sort();

    final lines = <String>[
      '',
      '  ${Term.bold}Fluxo do dinheiro${Term.reset}',
      '',
    ];
    for (final col in columns) {
      final label = col < data.columnLabels.length
          ? data.columnLabels[col]
          : 'Coluna $col';
      final nodes = byColumn[col]!
        ..sort((a, b) => (b.value as int).compareTo(a.value as int));
      final maxValue = nodes.fold<int>(
        1,
        (m, n) => (n.value as int) > m ? n.value as int : m,
      );
      lines.add('  ${Term.bold}$label${Term.reset}');
      for (final n in nodes) {
        lines.add(
          '    ${Term.pad(n.label as String, 24)} '
          '${Term.progressBar((n.value as int) / maxValue, cols: 20)} '
          '${Term.padLeft(Term.formatMoney(n.value as int), 15)}',
        );
      }
      lines.add('');
    }
    if (data.nodes.isEmpty) {
      lines.add('  ${Term.gray}Sem dados no período.${Term.reset}');
    }

    Term.pager(
      'Fluxo receitas → despesas',
      lines,
      subtitle: '${Term.formatDate(_start)} → ${Term.formatDate(_end)}',
    );
  }
}
