import 'package:bestfin/cli/tui/screens/base.dart';
import 'package:bestfin/cli/tui/term.dart';
import 'package:bestfin/features/cashflow/domain/use_cases/calculate_cashflow_projection.dart';

/// Projeção de caixa: saldo projetado a partir dos lançamentos futuros e
/// pendentes já registrados (recorrências geradas, parcelas, agendados).
class CashflowScreen extends Screen {
  CashflowScreen(super.ctx);

  @override
  String get title => 'Projeção de caixa';

  int _days = 90;

  @override
  Future<void> run() async {
    while (true) {
      final projection = await CalculateCashFlowProjection(
        db: ctx.db,
        transactionRepository: ctx.transactions,
      ).call(days: _days);

      final points = projection.points;
      final maxValue = points.fold<int>(
        projection.currentBalance.abs().clamp(1, 1 << 62),
        (m, p) => p.cumulativeBalance.abs() > m ? p.cumulativeBalance.abs() : m,
      );
      final negativeDay = points
          .where((p) => p.cumulativeBalance < 0)
          .firstOrNull;

      final lines = <String>[
        '',
        '  Saldo atual:        ${Term.formatMoneyColored(projection.currentBalance)}',
        '  Projeção em 30d:    ${Term.formatMoneyColored(projection.projectedBalance30d)}',
        '  Projeção em 60d:    ${Term.formatMoneyColored(projection.projectedBalance60d)}',
        '  Projeção em 90d:    ${Term.formatMoneyColored(projection.projectedBalance90d)}',
        '',
        if (negativeDay != null)
          '  ${Term.c('⚠ Saldo fica negativo em ${Term.formatDate(negativeDay.date)}', Term.red)}'
        else
          '  ${Term.c('✓ Saldo permanece positivo em toda a janela', Term.green)}',
        '',
        '  ${Term.bold}Dias com movimentação prevista${Term.reset}',
        if (points.every((p) => p.dailyNet == 0))
          '    ${Term.gray}Nenhum lançamento futuro registrado.${Term.reset}',
        ...points
            .where((p) => p.dailyNet != 0)
            .map(
              (p) =>
                  '    ${Term.formatDate(p.date)}  '
                  '${Term.padLeft(Term.formatMoneyColored(p.dailyNet, sign: true), 16)}  '
                  '${Term.progressBar(p.cumulativeBalance.abs() / maxValue, cols: 18, color: p.cumulativeBalance < 0 ? Term.red : Term.cyan)} '
                  '${Term.padLeft(Term.formatMoneyColored(p.cumulativeBalance), 16)}',
            ),
        '',
      ];

      Term.pager(
        title,
        lines,
        subtitle: 'Janela de $_days dias • "p" no menu ajusta a janela',
      );

      final again = Term.confirm('Alterar a janela de projeção?');
      if (!again) return;
      final days = Term.inputInt(
        'Dias de projeção',
        initial: _days,
        min: 7,
        max: 365,
      );
      if (days == null) return;
      _days = days;
    }
  }
}
