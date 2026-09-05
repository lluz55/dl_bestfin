import 'package:bestfin/cli/tui/screens/base.dart';
import 'package:bestfin/cli/tui/term.dart';
import 'package:bestfin/core/database/app_database.dart' as db;
import 'package:bestfin/features/goals/domain/models/goal.dart';
import 'package:bestfin/features/goals/domain/usecases/calculate_monthly_target.dart';

/// Metas: acompanhamento, aportes, simulação mensal, recorrência e arquivo.
class GoalsScreen extends Screen {
  GoalsScreen(super.ctx);

  @override
  String get title => 'Metas';

  bool _showArchived = false;

  @override
  Future<void> run() async {
    while (true) {
      final all = await ctx.goals.watchAllGoals().first;
      final list = _showArchived
          ? all
          : all.where((g) => g.status != GoalStatus.archived).toList();

      final saved = list.fold<int>(0, (s, g) => s + g.currentAmountInCents);
      final target = list.fold<int>(0, (s, g) => s + g.targetAmountInCents);

      final items = list
          .map(
            (g) =>
                '${Term.pad(g.name, 22)} '
                '${Term.progressBar(g.progressFraction, cols: 14, color: g.isCompleted ? Term.green : Term.cyan)} '
                '${Term.padLeft('${g.progressPercent.round()}%', 5)} '
                '${Term.padLeft(Term.formatMoney(g.currentAmountInCents), 15)}'
                ' / ${Term.pad(Term.formatMoney(g.targetAmountInCents), 15)}'
                '${g.status == GoalStatus.archived ? ' ${Term.gray}(arquivada)${Term.reset}' : ''}',
          )
          .toList();

      final choice = listMenu(
        title,
        items: items,
        subtitle:
            '${list.length} meta(s) • guardado ${Term.formatMoney(saved)} '
            'de ${Term.formatMoney(target)}'
            '${_showArchived ? ' • incluindo arquivadas' : ''}',
        emptyMessage: 'Nenhuma meta ainda. "n" cria a primeira.',
        actions: const [
          TermAction('n', 'nova'),
          TermAction('c', 'aporte'),
          TermAction('e', 'editar'),
          TermAction('a', 'arquivar'),
          TermAction('v', 'ver arquivadas'),
          TermAction('d', 'excluir'),
        ],
      );
      if (choice == null) return;

      final (key, i) = choice;
      final goal = i >= 0 && i < list.length ? list[i] : null;
      switch (key) {
        case 'n':
          await _create();
        case 'c':
          if (goal != null) await _contribute(goal);
        case 'e':
          if (goal != null) await _edit(goal);
        case 'a':
          if (goal != null) await _archive(goal);
        case 'v':
          _showArchived = !_showArchived;
        case 'd':
          if (goal != null) await _delete(goal);
        case '':
          if (goal != null) _detail(goal);
      }
    }
  }

  void _detail(GoalModel g) {
    final months = g.monthsRemaining;
    final simulation = months == null
        ? null
        : CalculateMonthlyTarget().call(
            remainingInCents: g.remainingInCents,
            months: months,
          );

    Term.pager('Meta — ${g.name}', [
      '',
      '  ${Term.bold}${g.name}${Term.reset}',
      if (g.description != null && g.description!.isNotEmpty)
        '  ${Term.gray}${g.description}${Term.reset}',
      '',
      '  Tipo:            ${g.type.label}',
      '  Situação:        ${g.status.label}',
      '  Alvo:            ${Term.formatMoney(g.targetAmountInCents)}',
      '  Guardado:        ${Term.formatMoney(g.currentAmountInCents)}',
      '  Falta:           ${Term.formatMoney(g.remainingInCents)}',
      '  Progresso:       ${Term.progressBar(g.progressFraction, cols: 24)} '
          '${g.progressPercent.toStringAsFixed(1)}%',
      if (g.targetDate != null)
        '  Data alvo:       ${Term.formatDate(g.targetDate!)}',
      if (months != null) '  Meses restantes: $months',
      if (g.isRecurring)
        '  Recorrência:     ${g.recurrenceFrequency?.label ?? '—'}',
      '',
      if (simulation != null) ...[
        '  ${Term.bold}Simulação de aporte mensal${Term.reset}',
        '    Otimista:      ${Term.formatMoney(simulation.optimisticInCents)}',
        '    Ideal:         ${Term.formatMoney(simulation.idealInCents)}',
        '    Pessimista:    ${Term.formatMoney(simulation.pessimisticInCents)}',
        '',
      ],
      '  ID:              ${Term.gray}${g.id}${Term.reset}',
      '',
    ]);
  }

  Future<void> _create() async {
    Term.clear();
    Term.header('Nova meta');
    Term.writeln();

    final name = Term.input('Nome:', allowEmpty: false);
    if (name == null || name.trim().isEmpty) return;

    final description = Term.input('Descrição (opcional):');
    if (description == null) return;

    final type = Term.pick<GoalType>('Tipo', GoalType.values, (t) => t.label);
    if (type == null) return;

    final target = Term.inputMoney('Valor alvo');
    if (target == null) return;

    DateTime? targetDate;
    if (Term.confirm('Definir data alvo?', defaultYes: true)) {
      targetDate = Term.inputDate('Data alvo');
      if (targetDate == null) return;
    }

    final (choseAccount, account) = await pickAccountOptional(
      'Conta vinculada (opcional)',
    );
    if (!choseAccount) return;

    final isRecurring = Term.confirm('Meta recorrente?');
    GoalRecurrenceFrequency? frequency;
    if (isRecurring) {
      frequency = Term.pick<GoalRecurrenceFrequency>(
        'Frequência',
        GoalRecurrenceFrequency.values,
        (f) => f.label,
      );
      if (frequency == null) return;
    }

    final categoryIds = await _pickCategories(type);
    if (categoryIds == null) return;

    await guard(
      () => ctx.goals.createGoal(
        name: name.trim(),
        description: description.trim().isEmpty ? null : description.trim(),
        targetAmountInCents: target,
        targetDate: targetDate,
        accountId: account?.id,
        type: type,
        isRecurring: isRecurring,
        recurrenceFrequency: frequency,
        categoryIds: categoryIds,
      ),
      successMessage: 'Meta "${name.trim()}" criada.',
    );
  }

  Future<void> _edit(GoalModel g) async {
    Term.clear();
    Term.header('Editar meta — ${g.name}');
    Term.writeln();

    final name = Term.input('Nome:', initial: g.name, allowEmpty: false);
    if (name == null) return;

    final description = Term.input(
      'Descrição (opcional):',
      initial: g.description ?? '',
    );
    if (description == null) return;

    final target = Term.inputMoney(
      'Valor alvo',
      initial: g.targetAmountInCents,
    );
    if (target == null) return;

    var targetDate = g.targetDate;
    if (Term.confirm(
      'Alterar data alvo (${targetDate == null ? 'sem data' : Term.formatDate(targetDate)})?',
    )) {
      targetDate = Term.inputDate('Data alvo', initial: targetDate);
      if (targetDate == null) return;
    }

    await guard(
      () => ctx.goals.updateGoal(
        id: g.id,
        name: name.trim(),
        description: description.trim().isEmpty ? null : description.trim(),
        targetAmountInCents: target,
        targetDate: targetDate,
        accountId: g.accountId,
        color: g.color,
        icon: g.icon,
        type: g.type,
        isRecurring: g.isRecurring,
        recurrenceFrequency: g.recurrenceFrequency,
        categoryIds: g.categoryIds,
      ),
      successMessage: 'Meta atualizada.',
    );
  }

  /// Categorias acompanhadas pela meta — relevante sobretudo para metas de
  /// gasto, que somam os lançamentos dessas categorias.
  Future<List<String>?> _pickCategories(GoalType type) async {
    if (type != GoalType.spending) return const [];
    final categories = await ctx.rawCategories(type: 'expense');
    if (categories.isEmpty) return const [];
    final picked = pickMulti<db.Category>(
      'Categorias acompanhadas',
      categories,
      (c) => c.name,
    );
    if (picked == null) return null;
    return picked.map((i) => categories[i].id).toList();
  }

  Future<void> _contribute(GoalModel g) async {
    Term.clear();
    Term.header('Aporte — ${g.name}');
    Term.writeln();
    Term.writeln(
      '  ${Term.gray}Guardado ${Term.formatMoney(g.currentAmountInCents)} '
      'de ${Term.formatMoney(g.targetAmountInCents)} • '
      'falta ${Term.formatMoney(g.remainingInCents)}${Term.reset}',
    );
    Term.writeln();

    final amount = Term.inputMoney('Valor do aporte');
    if (amount == null || amount <= 0) return;

    final account = await pickAccount('Conta de origem');
    if (account == null) return;

    final notes = Term.input('Observações (opcional):');
    if (notes == null) return;

    await guard(
      () => ctx.goals.addContribution(
        goalId: g.id,
        amountInCents: amount,
        fromAccountId: account.id,
        notes: notes.trim().isEmpty ? null : notes.trim(),
      ),
      successMessage: 'Aporte de ${Term.formatMoney(amount)} registrado.',
    );
  }

  Future<void> _archive(GoalModel g) async {
    if (!Term.confirm('Arquivar a meta "${g.name}"?')) return;
    await guard(
      () => ctx.goals.archiveGoal(g.id),
      successMessage: 'Meta arquivada.',
    );
  }

  Future<void> _delete(GoalModel g) async {
    Term.clear();
    Term.header('Excluir meta — ${g.name}');
    Term.writeln();
    Term.warn('Os aportes registrados voltam para a conta de origem.');
    Term.writeln();
    if (!Term.confirm('Confirmar exclusão?')) return;
    await guard(
      () => ctx.goals.deleteGoal(g.id),
      successMessage: 'Meta excluída.',
    );
  }
}
