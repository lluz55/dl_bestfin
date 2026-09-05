import 'package:bestfin/cli/tui/screens/base.dart';
import 'package:bestfin/cli/tui/term.dart';
import 'package:bestfin/core/constants/transaction_types.dart';
import 'package:bestfin/features/recurring/domain/models/recurring_rule.dart';

/// Recorrências: regras que repetem um lançamento-base, com pausa/retomada,
/// geração antecipada das próximas ocorrências e exclusão.
class RecurringScreen extends Screen {
  RecurringScreen(super.ctx);

  @override
  String get title => 'Recorrências';

  @override
  Future<void> run() async {
    while (true) {
      final rules = await ctx.recurring.watchAll().first;
      final active = rules.where((r) => r.status == RecurringStatus.active);
      final monthly = active.fold<int>(0, (s, r) => s + _monthlyEquivalent(r));

      final items = rules.map(_renderRow).toList();

      final choice = listMenu(
        title,
        items: items,
        subtitle:
            '${rules.length} regra(s) • ${active.length} ativa(s) • '
            'equivalente mensal ${Term.formatMoney(monthly)}',
        emptyMessage:
            'Nenhuma recorrência. "n" transforma um lançamento existente em regra.',
        actions: const [
          TermAction('n', 'nova'),
          TermAction('p', 'pausar/retomar'),
          TermAction('g', 'gerar próximas'),
          TermAction('d', 'excluir'),
        ],
      );
      if (choice == null) return;

      final (key, i) = choice;
      final rule = i >= 0 && i < rules.length ? rules[i] : null;
      switch (key) {
        case 'n':
          await _create();
        case 'p':
          if (rule != null) await _toggle(rule);
        case 'g':
          await _generate();
        case 'd':
          if (rule != null) await _delete(rule);
        case '':
          if (rule != null) _detail(rule);
      }
    }
  }

  String _renderRow(RecurringRuleModel r) {
    final statusColor = switch (r.status) {
      RecurringStatus.active => Term.green,
      RecurringStatus.paused => Term.yellow,
      RecurringStatus.finished => Term.gray,
    };
    final every = r.interval > 1 ? 'a cada ${r.interval} ' : '';
    return '${Term.pad(r.description ?? '(sem descrição)', 26)} '
        '${Term.padLeft(Term.formatMoney(r.amountInCents ?? 0), 15)} '
        '${Term.gray}${Term.pad('$every${r.frequency.label.toLowerCase()}', 18)}${Term.reset}'
        'próx ${Term.formatDate(r.nextDate)}  '
        '${Term.c(r.status.label, statusColor)}'
        '${r.autoConfirm ? ' ${Term.gray}auto${Term.reset}' : ''}';
  }

  /// Converte a frequência da regra em um valor mensal aproximado, para dar
  /// noção do peso das recorrências no orçamento.
  int _monthlyEquivalent(RecurringRuleModel r) {
    final amount = r.amountInCents ?? 0;
    final perPeriod = r.interval <= 0 ? amount : amount ~/ r.interval;
    return switch (r.frequency) {
      RecurringFrequency.daily => perPeriod * 30,
      RecurringFrequency.weekly => (perPeriod * 30) ~/ 7,
      RecurringFrequency.biweekly => (perPeriod * 30) ~/ 15,
      RecurringFrequency.monthly => perPeriod,
      RecurringFrequency.yearly => perPeriod ~/ 12,
    };
  }

  void _detail(RecurringRuleModel r) {
    Term.pager('Recorrência — ${r.description ?? r.id}', [
      '',
      '  ${Term.bold}${r.description ?? '(sem descrição)'}${Term.reset}',
      '',
      '  Valor:            ${Term.formatMoney(r.amountInCents ?? 0)}',
      '  Tipo:             ${r.type == null ? '—' : TransactionType.fromString(r.type!).label}',
      '  Frequência:       ${r.frequency.label}'
          '${r.interval > 1 ? ' (a cada ${r.interval})' : ''}',
      '  Próxima:          ${Term.formatDate(r.nextDate)}',
      if (r.endDate != null)
        '  Termina em:       ${Term.formatDate(r.endDate!)}',
      '  Situação:         ${r.status.label}',
      '  Confirmação auto: ${r.autoConfirm ? 'sim' : 'não — vira sugestão'}',
      if (r.categoryName != null) '  Categoria:        ${r.categoryName}',
      '  Equivalente/mês:  ${Term.formatMoney(_monthlyEquivalent(r))}',
      '  Lançamento base:  ${Term.gray}${r.baseTransactionId}${Term.reset}',
      '  ID:               ${Term.gray}${r.id}${Term.reset}',
      '',
    ]);
  }

  /// Cria a regra a partir de um lançamento existente — é assim que a GUI
  /// funciona: a transação-base define valor, conta e categoria.
  Future<void> _create() async {
    final candidates = await ctx.transactions
        .watchTransactionsWithFilters(isCompleted: true)
        .first;
    final withoutRule = candidates
        .where((t) => t.recurringRuleId == null)
        .take(200)
        .toList();

    if (withoutRule.isEmpty) {
      Term.alert(
        'Nova recorrência',
        'Crie primeiro o lançamento que servirá de base para a regra.',
      );
      return;
    }

    final base = Term.pick(
      'Lançamento base',
      withoutRule,
      (t) =>
          '${Term.formatDate(t.date)}  ${Term.pad(t.description, 30)} '
          '${Term.padLeft(Term.formatMoney(t.amount.abs()), 15)}',
      subtitle: 'a regra repetirá este lançamento',
    );
    if (base == null) return;

    final frequency = Term.pick<RecurringFrequency>(
      'Frequência',
      RecurringFrequency.values,
      (f) => f.label,
      initialIndex: RecurringFrequency.values.indexOf(
        RecurringFrequency.monthly,
      ),
    );
    if (frequency == null) return;

    final interval = Term.inputInt(
      'Repetir a cada quantos períodos',
      initial: 1,
      min: 1,
      max: 99,
    );
    if (interval == null) return;

    final startDate = Term.inputDate('Início', initial: base.date);
    if (startDate == null) return;

    DateTime? endDate;
    if (Term.confirm('Definir data de término?')) {
      endDate = Term.inputDate('Término');
      if (endDate == null) return;
    }

    final autoConfirm = Term.confirm(
      'Lançar automaticamente (sem virar sugestão)?',
      defaultYes: true,
    );

    await guard(
      () => ctx.recurring.createRule(
        baseTransactionId: base.id,
        frequency: frequency,
        interval: interval,
        startDate: startDate,
        endDate: endDate,
        autoConfirm: autoConfirm,
      ),
      successMessage: 'Recorrência criada.',
    );
  }

  Future<void> _toggle(RecurringRuleModel r) async {
    if (r.status == RecurringStatus.finished) {
      Term.alert('Recorrência', 'Esta regra já foi finalizada.');
      return;
    }
    final pause = r.status == RecurringStatus.active;
    if (!Term.confirm(
      '${pause ? 'Pausar' : 'Retomar'} "${r.description ?? r.id}"?',
    )) {
      return;
    }
    await guard(
      () => pause
          ? ctx.recurring.pauseRule(r.id)
          : ctx.recurring.resumeRule(r.id),
      successMessage: pause ? 'Recorrência pausada.' : 'Recorrência retomada.',
    );
  }

  Future<void> _generate() async {
    Term.clear();
    Term.header('Gerar próximos lançamentos');
    Term.writeln();
    Term.writeln(
      '  ${Term.gray}Cria as ocorrências das regras ativas até a data limite. '
      'Regras sem confirmação automática viram sugestões.${Term.reset}',
    );
    Term.writeln();
    final days = Term.inputInt(
      'Antecedência em dias',
      initial: 30,
      min: 1,
      max: 365,
    );
    if (days == null) return;
    await guard(
      () => ctx.recurring.generatePendingTransactions(daysAhead: days),
      successMessage: 'Lançamentos gerados para os próximos $days dias.',
    );
  }

  Future<void> _delete(RecurringRuleModel r) async {
    Term.clear();
    Term.header('Excluir recorrência');
    Term.writeln();
    Term.writeln(
      '  ${Term.gray}A regra é removida; os lançamentos já gerados '
      'permanecem no histórico.${Term.reset}',
    );
    Term.writeln();
    if (!Term.confirm('Excluir "${r.description ?? r.id}"?')) return;
    await guard(
      () => ctx.recurring.deleteRule(r.id),
      successMessage: 'Recorrência excluída.',
    );
  }
}
