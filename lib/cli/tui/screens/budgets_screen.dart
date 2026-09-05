import 'package:bestfin/cli/tui/screens/base.dart';
import 'package:bestfin/cli/tui/term.dart';
import 'package:bestfin/core/database/app_database.dart' as db;
import 'package:bestfin/features/budgets/domain/models/budget_model.dart';

/// Orçamentos: acompanhamento por período, criação/edição por categorias e
/// aplicação do rollover (saldo que sobra ou falta migra para o mês seguinte).
class BudgetsScreen extends Screen {
  BudgetsScreen(super.ctx);

  @override
  String get title => 'Orçamentos';

  late int _year = DateTime.now().year;
  late int _month = DateTime.now().month;

  @override
  Future<void> run() async {
    while (true) {
      final budgets = await ctx.budgets.getBudgetsForPeriod(_year, _month);
      final planned = budgets.fold<int>(0, (s, b) => s + b.totalBudget);
      final spent = budgets.fold<int>(0, (s, b) => s + b.spent);

      final items = budgets.map(_renderRow).toList();

      final choice = listMenu(
        title,
        items: items,
        subtitle:
            '${Term.monthLabel(_year, _month)} • '
            'planejado ${Term.formatMoney(planned)} • '
            'gasto ${Term.formatMoney(spent)} • '
            'disponível ${Term.formatMoneyColored(planned - spent)}',
        emptyMessage:
            'Nenhum orçamento em ${Term.monthLabel(_year, _month)}. "n" cria um.',
        actions: const [
          TermAction('n', 'novo'),
          TermAction('e', 'editar'),
          TermAction('<', 'mês anterior'),
          TermAction('>', 'próximo mês'),
          TermAction('r', 'rollover'),
          TermAction('d', 'excluir'),
        ],
      );
      if (choice == null) return;

      final (key, i) = choice;
      final budget = i >= 0 && i < budgets.length ? budgets[i] : null;
      switch (key) {
        case 'n':
          await _create();
        case 'e':
          if (budget != null) await _edit(budget);
        case '<':
          _shiftMonth(-1);
        case '>':
          _shiftMonth(1);
        case 'r':
          await _rollover();
        case 'd':
          if (budget != null) await _delete(budget);
        case '':
          if (budget != null) _detail(budget);
      }
    }
  }

  void _shiftMonth(int delta) {
    final d = DateTime(_year, _month + delta, 1);
    _year = d.year;
    _month = d.month;
  }

  String _renderRow(BudgetModel b) {
    final color = b.isOverBudget
        ? Term.red
        : (b.progress > 0.8 ? Term.yellow : Term.green);
    return '${Term.pad(b.displayName, 22)} '
        '${Term.progressBar(b.progress, cols: 14, color: color)} '
        '${Term.padLeft('${(b.progress * 100).round()}%', 5)} '
        '${Term.padLeft(Term.formatMoney(b.spent), 15)}'
        ' / ${Term.pad(Term.formatMoney(b.totalBudget), 15)}';
  }

  void _detail(BudgetModel b) {
    Term.pager('Orçamento — ${b.displayName}', [
      '',
      '  ${Term.bold}${b.name}${Term.reset}  ${Term.gray}${Term.monthLabel(b.year, b.month)}${Term.reset}',
      '',
      '  Valor planejado:   ${Term.formatMoney(b.amount)}',
      '  Rollover:          ${Term.formatMoneyColored(b.rolloverAmount, sign: true)}',
      '  Total disponível:  ${Term.formatMoney(b.totalBudget)}',
      '  Gasto:             ${Term.formatMoney(b.spent)}',
      '  Pendente:          ${Term.formatMoney(b.pending)}',
      '  Projetado:         ${Term.formatMoney(b.projectedSpent)}',
      '  Saldo:             ${Term.formatMoneyColored(b.available)}',
      '',
      '  ${Term.progressBar(b.progress, cols: 30)} ${(b.progress * 100).toStringAsFixed(1)}%',
      '',
      '  Categorias:        ${b.categories.isEmpty ? '—' : b.categories.map((c) => c.name).join(', ')}',
      '  ID:                ${Term.gray}${b.id}${Term.reset}',
      '',
    ]);
  }

  Future<void> _create() async {
    Term.clear();
    Term.header('Novo orçamento — ${Term.monthLabel(_year, _month)}');
    Term.writeln();

    final name = Term.input('Nome:', allowEmpty: false);
    if (name == null || name.trim().isEmpty) return;

    final amount = Term.inputMoney('Valor planejado');
    if (amount == null) return;

    final categoryIds = await _pickCategories();
    if (categoryIds == null) return;

    await guard(
      () => ctx.budgets.createBudget(
        name: name.trim(),
        year: _year,
        month: _month,
        amount: amount,
        categoryIds: categoryIds,
      ),
      successMessage: 'Orçamento criado.',
    );
  }

  Future<void> _edit(BudgetModel b) async {
    Term.clear();
    Term.header('Editar orçamento — ${b.name}');
    Term.writeln();

    final name = Term.input('Nome:', initial: b.name, allowEmpty: false);
    if (name == null) return;

    final amount = Term.inputMoney('Valor planejado', initial: b.amount);
    if (amount == null) return;

    final categoryIds = await _pickCategories(selected: b.categoryIds.toSet());
    if (categoryIds == null) return;

    await guard(
      () => ctx.budgets.updateBudget(
        b.id,
        name: name.trim(),
        amount: amount,
        categoryIds: categoryIds,
      ),
      successMessage: 'Orçamento atualizado.',
    );
  }

  Future<List<String>?> _pickCategories({Set<String>? selected}) async {
    final categories = await ctx.rawCategories(type: 'expense');
    if (categories.isEmpty) {
      Term.alert('Categorias', 'Crie ao menos uma categoria de despesa antes.');
      return null;
    }
    final initial = <int>{
      for (var i = 0; i < categories.length; i++)
        if (selected?.contains(categories[i].id) ?? false) i,
    };
    final picked = pickMulti<db.Category>(
      'Categorias do orçamento',
      categories,
      (c) => c.name,
      initial: initial,
    );
    if (picked == null) return null;
    return picked.map((i) => categories[i].id).toList();
  }

  Future<void> _rollover() async {
    Term.clear();
    Term.header('Aplicar rollover');
    Term.writeln();
    Term.writeln(
      '  ${Term.gray}Leva o saldo (positivo ou negativo) de '
      '${Term.monthLabel(_year, _month)} para o mês seguinte.${Term.reset}',
    );
    Term.writeln();
    if (!Term.confirm(
      'Aplicar rollover de ${Term.monthLabel(_year, _month)}?',
    )) {
      return;
    }
    await guard(
      () => ctx.budgets.applyRollover(_year, _month),
      successMessage: 'Rollover aplicado.',
    );
  }

  Future<void> _delete(BudgetModel b) async {
    if (!Term.confirm('Excluir orçamento "${b.name}"?')) return;
    await guard(
      () => ctx.budgets.deleteBudget(b.id),
      successMessage: 'Orçamento excluído.',
    );
  }
}
