import 'package:bestfin/cli/tui/screens/base.dart';
import 'package:bestfin/cli/tui/term.dart';
import 'package:bestfin/features/investments/domain/models/investment.dart';

/// Investimentos: carteira, aporte, atualização de rendimento e exclusão.
class InvestmentsScreen extends Screen {
  InvestmentsScreen(super.ctx);

  @override
  String get title => 'Investimentos';

  static const _types = <String, String>{
    'fixed_income': 'Renda Fixa',
    'stocks': 'Ações',
    'fiis': 'FIIs',
    'crypto': 'Criptomoedas',
    'savings': 'Poupança',
    'cdb': 'CDB',
    'tesouro': 'Tesouro Direto',
    'other': 'Outros',
  };

  @override
  Future<void> run() async {
    while (true) {
      final list = await ctx.investments.watchAllInvestments().first;
      final invested = list.fold<int>(0, (s, i) => s + i.investedAmount);
      final yield_ = list.fold<int>(0, (s, i) => s + i.currentYield);

      final items = list
          .map(
            (i) =>
                '${Term.pad(i.name, 24)} '
                '${Term.gray}${Term.pad(i.typeLabel, 14)}${Term.reset} '
                '${Term.padLeft(Term.formatMoney(i.investedAmount), 15)} '
                '${Term.padLeft(Term.formatMoneyColored(i.currentYield, sign: true), 16)} '
                '${Term.padLeft('${i.yieldPercentage.toStringAsFixed(1)}%', 8)}',
          )
          .toList();

      final choice = listMenu(
        title,
        items: items,
        subtitle:
            'Aplicado ${Term.formatMoney(invested)} • '
            'Rendimento ${Term.formatMoneyColored(yield_, sign: true)} • '
            'Total ${Term.formatMoney(invested + yield_)}',
        emptyMessage: 'Nenhum investimento cadastrado. "n" cria o primeiro.',
        actions: const [
          TermAction('n', 'novo'),
          TermAction('e', 'editar'),
          TermAction('r', 'atualizar rendimento'),
          TermAction('d', 'excluir'),
        ],
      );
      if (choice == null) return;

      final (key, i) = choice;
      final inv = i >= 0 && i < list.length ? list[i] : null;
      switch (key) {
        case 'n':
          await _create();
        case 'e':
          if (inv != null) await _edit(inv);
        case 'r':
          if (inv != null) await _updateYield(inv);
        case 'd':
          if (inv != null) await _delete(inv);
        case '':
          if (inv != null) _detail(inv);
      }
    }
  }

  void _detail(Investment i) {
    Term.pager('Investimento — ${i.name}', [
      '',
      '  ${Term.bold}${i.name}${Term.reset}',
      '',
      '  Tipo:            ${i.typeLabel}',
      '  Valor aplicado:  ${Term.formatMoney(i.investedAmount)}',
      '  Rendimento:      ${Term.formatMoneyColored(i.currentYield, sign: true)}',
      '  Valor total:     ${Term.formatMoney(i.totalValue)}',
      '  Rentabilidade:   ${i.yieldPercentage.toStringAsFixed(2)}%',
      if (i.maturityDate != null)
        '  Vencimento:      ${Term.formatDate(i.maturityDate!)}',
      '  Criado em:       ${Term.formatDate(i.createdAt)}',
      '  ID:              ${Term.gray}${i.id}${Term.reset}',
      '',
    ]);
  }

  String? _pickType({String? current}) {
    final keys = _types.keys.toList();
    final initial = current == null ? 0 : keys.indexOf(current);
    final index = Term.select(
      'Tipo de investimento',
      items: keys.map((k) => _types[k]!).toList(),
      initialIndex: initial < 0 ? 0 : initial,
    );
    return index == null ? null : keys[index];
  }

  Future<void> _create() async {
    Term.clear();
    Term.header('Novo investimento');
    Term.writeln();

    final name = Term.input('Nome:', allowEmpty: false);
    if (name == null || name.trim().isEmpty) return;

    final type = _pickType();
    if (type == null) return;

    final invested = Term.inputMoney('Valor aplicado');
    if (invested == null) return;

    final currentYield = Term.inputMoney('Rendimento atual', initial: 0);
    if (currentYield == null) return;

    final hasMaturity = Term.confirm('Tem data de vencimento?');
    DateTime? maturity;
    if (hasMaturity) {
      maturity = Term.inputDate('Vencimento');
      if (maturity == null) return;
    }

    await guard(
      () => ctx.investments.createInvestment(
        name: name.trim(),
        type: type,
        investedAmount: invested,
        currentYield: currentYield,
        maturityDate: maturity,
      ),
      successMessage: 'Investimento criado.',
    );
  }

  Future<void> _edit(Investment i) async {
    Term.clear();
    Term.header('Editar investimento — ${i.name}');
    Term.writeln();

    final name = Term.input('Nome:', initial: i.name, allowEmpty: false);
    if (name == null) return;

    final type = _pickType(current: i.type);
    if (type == null) return;

    final invested = Term.inputMoney(
      'Valor aplicado',
      initial: i.investedAmount,
    );
    if (invested == null) return;

    final currentYield = Term.inputMoney(
      'Rendimento atual',
      initial: i.currentYield,
    );
    if (currentYield == null) return;

    DateTime? maturity = i.maturityDate;
    if (Term.confirm(
      'Alterar vencimento (${maturity == null ? 'sem data' : Term.formatDate(maturity)})?',
    )) {
      maturity = Term.inputDate('Vencimento', initial: maturity);
      if (maturity == null) return;
    }

    await guard(
      () => ctx.investments.updateInvestment(
        id: i.id,
        name: name.trim(),
        type: type,
        investedAmount: invested,
        currentYield: currentYield,
        maturityDate: maturity,
      ),
      successMessage: 'Investimento atualizado.',
    );
  }

  Future<void> _updateYield(Investment i) async {
    Term.clear();
    Term.header('Atualizar rendimento — ${i.name}');
    Term.writeln();
    Term.writeln(
      '  ${Term.gray}Rendimento atual: '
      '${Term.formatMoney(i.currentYield)}${Term.reset}',
    );
    Term.writeln();
    final value = Term.inputMoney('Novo rendimento', initial: i.currentYield);
    if (value == null) return;
    await guard(
      () => ctx.investments.updateYield(i.id, value),
      successMessage: 'Rendimento atualizado.',
    );
  }

  Future<void> _delete(Investment i) async {
    if (!Term.confirm('Excluir investimento "${i.name}"?')) return;
    await guard(
      () => ctx.investments.deleteInvestment(i.id),
      successMessage: 'Investimento excluído.',
    );
  }
}
