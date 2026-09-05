import 'package:bestfin/cli/tui/screens/base.dart';
import 'package:bestfin/cli/tui/term.dart';
import 'package:bestfin/features/credit_cards/domain/models/credit_card.dart';
import 'package:bestfin/features/credit_cards/domain/models/invoice.dart';

/// Cartões de crédito: cadastro, limites, faturas por mês e pagamento
/// (total, mínimo ou parcial) debitando de uma conta.
class CreditCardsScreen extends Screen {
  CreditCardsScreen(super.ctx);

  @override
  String get title => 'Cartões de crédito';

  @override
  Future<void> run() async {
    while (true) {
      final cards = await ctx.creditCards.watchAllCreditCards().first;
      final used = cards.fold<int>(0, (s, c) => s + c.usedLimit);
      final limit = cards.fold<int>(0, (s, c) => s + c.limitAmount);

      final items = cards
          .map(
            (c) =>
                '${Term.pad(c.name, 22)} '
                '${Term.progressBar(limit == 0 ? 0 : c.usedLimit / c.limitAmount, cols: 12, color: c.availableLimit <= 0 ? Term.red : Term.cyan)} '
                '${Term.padLeft(Term.formatMoney(c.usedLimit), 15)}'
                ' / ${Term.pad(Term.formatMoney(c.limitAmount), 15)} '
                '${Term.gray}fecha dia ${c.closingDay} • vence dia ${c.dueDay}${Term.reset}',
          )
          .toList();

      final choice = listMenu(
        title,
        items: items,
        subtitle:
            'Usado ${Term.formatMoney(used)} de ${Term.formatMoney(limit)} • '
            'disponível ${Term.formatMoney(limit - used)}',
        emptyMessage: 'Nenhum cartão cadastrado. "n" cria o primeiro.',
        actions: const [
          TermAction('n', 'novo'),
          TermAction('e', 'editar'),
          TermAction('d', 'excluir'),
        ],
      );
      if (choice == null) return;

      final (key, i) = choice;
      final card = i >= 0 && i < cards.length ? cards[i] : null;
      switch (key) {
        case 'n':
          await _create();
        case 'e':
          if (card != null) await _edit(card);
        case 'd':
          if (card != null) await _delete(card);
        case '':
          if (card != null) await _invoices(card);
      }
    }
  }

  // ── Faturas ────────────────────────────────────────────────────────

  Future<void> _invoices(CreditCardModel card) async {
    while (true) {
      final invoices = await ctx.invoices.watchInvoicesForCard(card.id).first;

      final items = invoices
          .map(
            (inv) =>
                '${Term.pad('${inv.monthName}/${inv.year}', 18)} '
                '${Term.padLeft(Term.formatMoney(inv.totalAmount), 15)}  '
                '${Term.pad(_statusLabel(inv.status), 12)} '
                '${Term.gray}vence ${Term.formatDate(inv.dueDate)} • '
                '${inv.transactions.length} lançamento(s)${Term.reset}',
          )
          .toList();

      final choice = listMenu(
        'Faturas — ${card.name}',
        items: items,
        subtitle:
            'Limite ${Term.formatMoney(card.limitAmount)} • '
            'disponível ${Term.formatMoney(card.availableLimit)}',
        emptyMessage: 'Nenhuma fatura gerada para este cartão.',
        actions: const [TermAction('p', 'pagar fatura')],
      );
      if (choice == null) return;

      final (key, i) = choice;
      final invoice = i >= 0 && i < invoices.length ? invoices[i] : null;
      if (invoice == null) continue;
      switch (key) {
        case 'p':
          await _payInvoice(card, invoice);
        case '':
          _invoiceDetail(card, invoice);
      }
    }
  }

  static String _statusLabel(String status) => switch (status) {
    'open' => 'aberta',
    'closed' => 'fechada',
    'paid' => 'paga',
    _ => status,
  };

  void _invoiceDetail(CreditCardModel card, InvoiceModel inv) {
    Term.pager('Fatura ${inv.monthName}/${inv.year} — ${card.name}', [
      '',
      '  Situação:    ${_statusLabel(inv.status)}',
      '  Total:       ${Term.formatMoney(inv.totalAmount)}',
      '  Fechamento:  ${Term.formatDate(inv.closingDate)}',
      '  Vencimento:  ${Term.formatDate(inv.dueDate)}',
      '  Mínimo:      ${Term.formatMoney((inv.totalAmount * card.minPaymentPercent / 100).round())}'
          ' ${Term.gray}(${card.minPaymentPercent}%)${Term.reset}',
      '',
      '  ${Term.bold}Lançamentos${Term.reset}',
      if (inv.transactions.isEmpty) '    ${Term.gray}nenhum${Term.reset}',
      ...inv.transactions.map(
        (t) =>
            '    ${Term.formatDate(t.date)}  '
            '${Term.pad(t.description, 32)} '
            '${Term.padLeft(Term.formatMoney(t.amount.abs()), 15)}'
            '${t.installmentNumber != null ? ' ${Term.gray}#${t.installmentNumber}${Term.reset}' : ''}',
      ),
      '',
    ]);
  }

  Future<void> _payInvoice(CreditCardModel card, InvoiceModel inv) async {
    if (inv.status == 'paid') {
      Term.alert('Fatura paga', 'Esta fatura já está quitada.');
      return;
    }
    if (inv.totalAmount <= 0) {
      Term.alert('Fatura vazia', 'Não há valor a pagar nesta fatura.');
      return;
    }

    final minimum = (inv.totalAmount * card.minPaymentPercent / 100).round();
    final choice = Term.select(
      'Pagar fatura ${inv.monthName}/${inv.year}',
      items: [
        'Valor total — ${Term.formatMoney(inv.totalAmount)}',
        'Pagamento mínimo — ${Term.formatMoney(minimum)}',
        'Outro valor',
      ],
      subtitle: 'Vence em ${Term.formatDate(inv.dueDate)}',
    );
    if (choice == null) return;

    int? amount;
    switch (choice) {
      case 0:
        amount = inv.totalAmount;
      case 1:
        amount = minimum;
      case 2:
        amount = Term.inputMoney('Valor a pagar', initial: inv.totalAmount);
    }
    if (amount == null || amount <= 0) return;

    final account = await pickAccount('Conta de origem do pagamento');
    if (account == null) return;

    await guard(
      () => ctx.invoices.payInvoice(
        invoiceId: inv.id,
        sourceAccountId: account.id,
        payAmount: amount!,
      ),
      successMessage: 'Pagamento de ${Term.formatMoney(amount)} registrado.',
    );
  }

  // ── Cartão ─────────────────────────────────────────────────────────

  Future<void> _create() async {
    Term.clear();
    Term.header('Novo cartão de crédito');
    Term.writeln();

    final name = Term.input('Nome:', allowEmpty: false);
    if (name == null || name.trim().isEmpty) return;

    final limit = Term.inputMoney('Limite');
    if (limit == null) return;

    final closingDay = Term.inputInt('Dia de fechamento', min: 1, max: 31);
    if (closingDay == null) return;

    final dueDay = Term.inputInt('Dia de vencimento', min: 1, max: 31);
    if (dueDay == null) return;

    final account = await pickAccount('Conta de pagamento padrão');
    if (account == null) return;

    final minPercent = Term.inputInt(
      'Percentual do pagamento mínimo',
      initial: 15,
      min: 1,
      max: 100,
    );
    if (minPercent == null) return;

    await guard(
      () => ctx.creditCards.createCreditCard(
        name: name.trim(),
        limitAmount: limit,
        closingDay: closingDay,
        dueDay: dueDay,
        accountId: account.id,
        minPaymentPercent: minPercent,
      ),
      successMessage: 'Cartão "${name.trim()}" criado.',
    );
  }

  Future<void> _edit(CreditCardModel card) async {
    Term.clear();
    Term.header('Editar cartão — ${card.name}');
    Term.writeln();

    final name = Term.input('Nome:', initial: card.name, allowEmpty: false);
    if (name == null) return;

    final limit = Term.inputMoney('Limite', initial: card.limitAmount);
    if (limit == null) return;

    final closingDay = Term.inputInt(
      'Dia de fechamento',
      initial: card.closingDay,
      min: 1,
      max: 31,
    );
    if (closingDay == null) return;

    final dueDay = Term.inputInt(
      'Dia de vencimento',
      initial: card.dueDay,
      min: 1,
      max: 31,
    );
    if (dueDay == null) return;

    final minPercent = Term.inputInt(
      'Percentual do pagamento mínimo',
      initial: card.minPaymentPercent,
      min: 1,
      max: 100,
    );
    if (minPercent == null) return;

    var accountId = card.accountId;
    if (Term.confirm('Alterar a conta de pagamento padrão?')) {
      final account = await pickAccount('Conta de pagamento padrão');
      if (account == null) return;
      accountId = account.id;
    }

    await guard(
      () => ctx.creditCards.updateCreditCard(
        id: card.id,
        name: name.trim(),
        limitAmount: limit,
        closingDay: closingDay,
        dueDay: dueDay,
        accountId: accountId,
        color: card.color,
        minPaymentPercent: minPercent,
      ),
      successMessage: 'Cartão atualizado.',
    );
  }

  Future<void> _delete(CreditCardModel card) async {
    Term.clear();
    Term.header('Excluir cartão — ${card.name}');
    Term.writeln();
    Term.warn('As faturas e os lançamentos vinculados também são removidos.');
    Term.writeln();
    if (!Term.confirm('Confirmar exclusão?')) return;
    await guard(
      () => ctx.creditCards.deleteCreditCard(card.id),
      successMessage: 'Cartão excluído.',
    );
  }
}
