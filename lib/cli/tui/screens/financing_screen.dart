import 'package:bestfin/cli/tui/screens/base.dart';
import 'package:bestfin/cli/tui/term.dart';
import 'package:bestfin/features/financing/domain/models/financing.dart';
import 'package:bestfin/features/financing/domain/models/financing_installment.dart';

/// Financiamentos: simulação/criação (SAC ou Price), tabela de parcelas e
/// baixa de parcelas pagas.
class FinancingScreen extends Screen {
  FinancingScreen(super.ctx);

  @override
  String get title => 'Financiamentos';

  @override
  Future<void> run() async {
    while (true) {
      final list = await ctx.financings.watchAllFinancings().first;
      final outstanding = list.fold<int>(0, (s, f) => s + f.outstandingBalance);

      final items = list
          .map(
            (f) =>
                '${Term.pad(f.name, 24)} '
                '${Term.gray}${Term.pad(f.systemLabel, 6)}${Term.reset} '
                '${Term.padLeft(Term.formatMoney(f.totalAmount), 15)} '
                '${Term.gray}saldo${Term.reset} '
                '${Term.padLeft(Term.formatMoney(f.outstandingBalance), 15)} '
                '${Term.padLeft('${f.totalInstallments}x', 6)}',
          )
          .toList();

      final choice = listMenu(
        title,
        items: items,
        subtitle: 'Saldo devedor total: ${Term.formatMoney(outstanding)}',
        emptyMessage: 'Nenhum financiamento. "n" cria o primeiro.',
        actions: const [TermAction('n', 'novo'), TermAction('d', 'excluir')],
      );
      if (choice == null) return;

      final (key, i) = choice;
      final fin = i >= 0 && i < list.length ? list[i] : null;
      switch (key) {
        case 'n':
          await _create();
        case 'd':
          if (fin != null) await _delete(fin);
        case '':
          if (fin != null) await _installments(fin);
      }
    }
  }

  /// Tabela de parcelas com baixa/estorno de pagamento.
  Future<void> _installments(Financing f) async {
    while (true) {
      final list = await ctx.financings
          .watchInstallmentsForFinancing(f.id)
          .first;
      final paid = list.where((i) => i.isPaid).length;

      final items = list
          .map(
            (i) =>
                '${Term.padLeft('${i.number}', 4)}  '
                '${Term.formatDate(i.dueDate)}  '
                '${Term.padLeft(Term.formatMoney(i.totalValue), 15)}  '
                '${Term.gray}amort ${Term.padLeft(Term.formatMoney(i.amortizationValue), 13)}'
                '  juros ${Term.padLeft(Term.formatMoney(i.interestValue), 13)}'
                '  saldo ${Term.padLeft(Term.formatMoney(i.remainingBalance), 15)}${Term.reset}'
                '${i.isPaid ? ' ${Term.c('paga', Term.green)}' : ''}',
          )
          .toList();

      final choice = listMenu(
        'Parcelas — ${f.name}',
        items: items,
        subtitle:
            '$paid/${list.length} pagas • '
            '${f.systemLabel} • juros ${f.interestRate.toStringAsFixed(2)}% a.m. • '
            'saldo ${Term.formatMoney(f.outstandingBalance)}',
        emptyMessage: 'Sem parcelas geradas.',
        actions: const [TermAction('p', 'alternar pagamento')],
      );
      if (choice == null) return;

      final (key, i) = choice;
      final inst = i >= 0 && i < list.length ? list[i] : null;
      if (inst == null) continue;
      if (key == 'p' || key == '') {
        await _togglePaid(inst);
      }
    }
  }

  Future<void> _togglePaid(FinancingInstallment inst) async {
    final target = !inst.isPaid;
    final verb = target ? 'marcar como paga' : 'estornar o pagamento da';
    if (!Term.confirm('Deseja $verb parcela ${inst.number}?')) return;
    await guard(
      () => ctx.financings.payInstallment(inst.id, target),
      successMessage: target ? 'Parcela paga.' : 'Pagamento estornado.',
    );
  }

  Future<void> _create() async {
    Term.clear();
    Term.header('Novo financiamento');
    Term.writeln();

    final name = Term.input('Nome:', allowEmpty: false);
    if (name == null || name.trim().isEmpty) return;

    final total = Term.inputMoney('Valor financiado');
    if (total == null) return;

    final rate = Term.inputDouble('Juros ao mês (%)', initial: 1.0);
    if (rate == null) return;

    final installments = Term.inputInt('Número de parcelas', min: 1, max: 600);
    if (installments == null) return;

    final systemIndex = Term.select(
      'Sistema de amortização',
      items: const ['SAC — parcelas decrescentes', 'Price — parcelas fixas'],
    );
    if (systemIndex == null) return;
    final system = systemIndex == 0 ? 'sac' : 'price';

    final firstDue = Term.inputDate('Vencimento da 1ª parcela');
    if (firstDue == null) return;

    final (chose, account) = await pickAccountOptional(
      'Conta vinculada (opcional)',
      noneLabel: '(nenhuma)',
    );
    if (!chose) return;

    await guard(
      () => ctx.financings.createFinancing(
        name: name.trim(),
        totalAmount: total,
        interestRate: rate,
        totalInstallments: installments,
        amortizationSystem: system,
        firstDueDate: firstDue,
        linkedAccountId: account?.id,
      ),
      successMessage: 'Financiamento criado com $installments parcelas.',
    );
  }

  Future<void> _delete(Financing f) async {
    Term.clear();
    Term.header('Excluir financiamento — ${f.name}');
    Term.writeln();
    Term.warn('Todas as parcelas geradas serão removidas.');
    Term.writeln();
    if (!Term.confirm('Confirmar exclusão?')) return;
    await guard(
      () => ctx.financings.deleteFinancing(f.id),
      successMessage: 'Financiamento excluído.',
    );
  }
}
