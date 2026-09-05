import 'package:bestfin/cli/tui/screens/base.dart';
import 'package:bestfin/cli/tui/term.dart';
import 'package:bestfin/features/installments/domain/models/installment_plan.dart';

/// Parcelamentos: criação de um plano (que gera as parcelas como lançamentos),
/// acompanhamento das parcelas pagas, edição e cancelamento.
class InstallmentsScreen extends Screen {
  InstallmentsScreen(super.ctx);

  @override
  String get title => 'Parcelamentos';

  @override
  Future<void> run() async {
    while (true) {
      final plans = await ctx.installments.watchInstallmentPlans().first;
      final open = plans.where((p) => !p.isCompleted).length;

      final items = plans.map((p) {
        final description = p.transactions.isEmpty
            ? '(sem lançamentos)'
            : p.transactions.first.description;
        return '${Term.pad(description, 28)} '
            '${Term.progressBar(p.totalInstallments == 0 ? 0 : p.paidInstallments / p.totalInstallments, cols: 12, color: p.isCompleted ? Term.green : Term.cyan)} '
            '${Term.padLeft('${p.paidInstallments}/${p.totalInstallments}', 7)} '
            '${Term.padLeft(Term.formatMoney(p.installmentValue), 14)}/mês '
            '${Term.gray}total ${Term.formatMoney(p.totalAmount)}${Term.reset}';
      }).toList();

      final choice = listMenu(
        title,
        items: items,
        subtitle: '${plans.length} plano(s) • $open em aberto',
        emptyMessage: 'Nenhum parcelamento. "n" cria o primeiro.',
        actions: const [
          TermAction('n', 'novo'),
          TermAction('e', 'editar'),
          TermAction('c', 'cancelar plano'),
        ],
      );
      if (choice == null) return;

      final (key, i) = choice;
      final plan = i >= 0 && i < plans.length ? plans[i] : null;
      switch (key) {
        case 'n':
          await _create();
        case 'e':
          if (plan != null) await _edit(plan);
        case 'c':
          if (plan != null) await _cancel(plan);
        case '':
          if (plan != null) await _detail(plan);
      }
    }
  }

  Future<void> _detail(InstallmentPlanModel plan) async {
    final accounts = await ctx.rawAccounts(includeArchived: true);
    final accountNames = {for (final a in accounts) a.id: a.name};
    final description = plan.transactions.isEmpty
        ? 'Parcelamento'
        : plan.transactions.first.description;

    Term.pager('Parcelamento — $description', [
      '',
      '  Parcelas:      ${plan.paidInstallments}/${plan.totalInstallments} pagas',
      '  Valor parcela: ${Term.formatMoney(plan.installmentValue)}',
      '  Valor total:   ${Term.formatMoney(plan.totalAmount)}',
      '  Criado em:     ${Term.formatDate(plan.createdAt)}',
      '  ID:            ${Term.gray}${plan.id}${Term.reset}',
      '',
      '  ${Term.bold}Parcelas${Term.reset}',
      ...plan.transactions.map(
        (t) =>
            '    ${Term.padLeft('${t.installmentNumber ?? '?'}', 4)}  '
            '${Term.formatDate(t.date)}  '
            '${Term.padLeft(Term.formatMoney(t.amount.abs()), 15)}  '
            '${Term.pad(accountNames[t.accountId] ?? '—', 18)}'
            '${t.isCompleted ? Term.c('paga', Term.green) : Term.c('pendente', Term.yellow)}',
      ),
      '',
    ]);
  }

  Future<void> _create() async {
    Term.clear();
    Term.header('Novo parcelamento');
    Term.writeln();

    final description = Term.input('Descrição:', allowEmpty: false);
    if (description == null || description.trim().isEmpty) return;

    final total = Term.inputMoney('Valor total');
    if (total == null) return;

    final count = Term.inputInt('Número de parcelas', min: 2, max: 360);
    if (count == null) return;

    final baseDate = Term.inputDate(
      'Data da 1ª parcela',
      initial: DateTime.now(),
    );
    if (baseDate == null) return;

    final typeIndex = Term.select('Tipo', items: const ['Despesa', 'Receita']);
    if (typeIndex == null) return;
    final type = typeIndex == 0 ? 'expense' : 'income';

    final account = await pickAccount('Conta');
    if (account == null) return;

    final (chose, category) = await pickCategoryOptional(
      'Categoria',
      type: type,
    );
    if (!chose) return;

    final notes = Term.input('Observações (opcional):');
    if (notes == null) return;

    Term.writeln();
    Term.writeln(
      '  ${Term.gray}${count}x de '
      '${Term.formatMoney((total / count).round())}${Term.reset}',
    );
    if (!Term.confirm('Criar o parcelamento?', defaultYes: true)) return;

    await guard(
      () => ctx.installments.createInstallmentPlan(
        baseDate: baseDate,
        description: description.trim(),
        totalAmount: total,
        totalInstallments: count,
        accountId: account.id,
        categoryId: category?.id,
        notes: notes.trim().isEmpty ? null : notes.trim(),
        type: type,
      ),
      successMessage: '$count parcelas criadas.',
    );
  }

  Future<void> _edit(InstallmentPlanModel plan) async {
    final current = plan.transactions.isEmpty ? null : plan.transactions.first;
    Term.clear();
    Term.header('Editar parcelamento');
    Term.writeln();
    Term.writeln(
      '  ${Term.gray}Alterar o valor total redistribui as parcelas '
      'ainda não pagas.${Term.reset}',
    );
    Term.writeln();

    final description = Term.input(
      'Descrição:',
      initial: current?.description ?? '',
      allowEmpty: false,
    );
    if (description == null) return;

    final total = Term.inputMoney('Valor total', initial: plan.totalAmount);
    if (total == null) return;

    final (chose, category) = await pickCategoryOptional(
      'Categoria',
      type: current?.type.name ?? 'expense',
    );
    if (!chose) return;

    final notes = Term.input(
      'Observações (opcional):',
      initial: current?.notes ?? '',
    );
    if (notes == null) return;

    await guard(
      () => ctx.installments.updateInstallmentPlan(
        planId: plan.id,
        totalAmount: total,
        description: description.trim(),
        categoryId: category?.id,
        notes: notes.trim().isEmpty ? null : notes.trim(),
      ),
      successMessage: 'Parcelamento atualizado.',
    );
  }

  Future<void> _cancel(InstallmentPlanModel plan) async {
    Term.clear();
    Term.header('Cancelar parcelamento');
    Term.writeln();
    Term.warn(
      'As parcelas ainda não pagas são removidas; as já pagas permanecem.',
    );
    Term.writeln();
    if (!Term.confirm('Confirmar cancelamento?')) return;
    await guard(
      () => ctx.installments.cancelInstallmentPlan(plan.id),
      successMessage: 'Parcelamento cancelado.',
    );
  }
}
