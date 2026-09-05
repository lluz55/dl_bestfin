import 'package:bestfin/cli/tui/screens/base.dart';
import 'package:bestfin/cli/tui/screens/reconciliation_screen.dart';
import 'package:bestfin/cli/tui/term.dart';
import 'package:bestfin/core/constants/account_types.dart';
import 'package:bestfin/features/accounts/domain/models/account.dart';

/// Contas: listagem com saldo, criação, edição, arquivamento e exclusão.
class AccountsScreen extends Screen {
  AccountsScreen(super.ctx);

  @override
  String get title => 'Contas';

  @override
  Future<void> run() async {
    while (true) {
      final accounts = await ctx.accounts.watchAllAccounts().first;
      final total = accounts
          .where((a) => a.isActive)
          .fold<int>(0, (s, a) => s + a.balance);

      final items = accounts
          .map(
            (a) =>
                '${Term.pad(a.name, 26)} ${Term.gray}${Term.pad(a.type.label, 16)}${Term.reset}'
                ' ${Term.padLeft(Term.formatMoneyColored(a.balance), 16)}'
                '${a.isActive ? '' : ' ${Term.gray}(arquivada)${Term.reset}'}',
          )
          .toList();

      final choice = listMenu(
        title,
        items: items,
        subtitle: 'Saldo total (ativas): ${Term.formatMoney(total)}',
        emptyMessage: 'Nenhuma conta ainda. Aperte "n" para criar a primeira.',
        actions: const [
          TermAction('n', 'nova'),
          TermAction('e', 'editar'),
          TermAction('r', 'reconciliar'),
          TermAction('a', 'arquivar/reativar'),
          TermAction('d', 'excluir'),
        ],
      );
      if (choice == null) return;

      final (key, i) = choice;
      final account = i >= 0 && i < accounts.length ? accounts[i] : null;
      switch (key) {
        case 'n':
          await _create();
        case 'e':
          if (account != null) await _edit(account);
        case 'r':
          if (account != null) {
            await ReconciliationScreen(account, ctx).run();
          }
        case 'a':
          if (account != null) await _toggleArchive(account);
        case 'd':
          if (account != null) await _delete(account);
        case '':
          if (account != null) await _detail(account);
      }
    }
  }

  Future<void> _detail(Account account) async {
    final initial = await ctx.accounts.getInitialBalance(account.id);
    Term.pager('Conta — ${account.name}', [
      '',
      '  ${Term.bold}${account.name}${Term.reset}',
      '',
      '  Tipo:            ${account.type.label}',
      '  Saldo atual:     ${Term.formatMoneyColored(account.balance)}',
      '  Saldo inicial:   ${Term.formatMoney(initial)}',
      '  Movimentação:    '
          '${Term.formatMoneyColored(account.balance - initial, sign: true)}',
      '  Situação:        ${account.isActive ? 'ativa' : 'arquivada'}',
      '  ID:              ${Term.gray}${account.id}${Term.reset}',
      '',
    ]);
  }

  Future<void> _create() async {
    Term.clear();
    Term.header('Nova conta');
    Term.writeln();

    final name = Term.input('Nome:', allowEmpty: false);
    if (name == null || name.trim().isEmpty) return;

    final type = Term.pick<AccountType>(
      'Tipo da conta',
      AccountType.values,
      (t) => t.label,
    );
    if (type == null) return;

    final initial = Term.inputMoney('Saldo inicial', initial: 0);
    if (initial == null) return;

    await guard(
      () => ctx.accounts.createWithInitialBalance(
        name: name.trim(),
        type: type.name,
        icon: null,
        color: null,
        initialBalance: initial,
      ),
      successMessage: 'Conta "${name.trim()}" criada.',
    );
  }

  Future<void> _edit(Account account) async {
    Term.clear();
    Term.header('Editar conta — ${account.name}');
    Term.writeln();

    final name = Term.input('Nome:', initial: account.name, allowEmpty: false);
    if (name == null) return;

    final typeIndex = AccountType.values.indexOf(account.type);
    final type = Term.pick<AccountType>(
      'Tipo da conta',
      AccountType.values,
      (t) => t.label,
      initialIndex: typeIndex < 0 ? 0 : typeIndex,
    );
    if (type == null) return;

    final currentInitial = await ctx.accounts.getInitialBalance(account.id);
    final initial = Term.inputMoney('Saldo inicial', initial: currentInitial);
    if (initial == null) return;

    await guard(
      () => ctx.accounts.updateAccount(
        id: account.id,
        name: name.trim(),
        type: type.name,
        icon: account.icon,
        color: account.color,
        initialBalance: initial,
      ),
      successMessage: 'Conta atualizada.',
    );
  }

  Future<void> _toggleArchive(Account account) async {
    final toActive = !account.isActive;
    final verb = toActive ? 'reativar' : 'arquivar';
    if (!Term.confirm('Deseja $verb "${account.name}"?')) return;
    await guard(
      () => ctx.accounts.updateAccount(
        id: account.id,
        name: account.name,
        type: account.type.name,
        icon: account.icon,
        color: account.color,
        isActive: toActive,
      ),
      successMessage: 'Conta ${toActive ? 'reativada' : 'arquivada'}.',
    );
  }

  Future<void> _delete(Account account) async {
    Term.clear();
    Term.header('Excluir conta — ${account.name}');
    Term.writeln();
    Term.warn(
      'Excluir a conta remove também seus lançamentos e recalcula os saldos.',
    );
    Term.writeln();
    if (!Term.confirm('Confirmar exclusão de "${account.name}"?')) return;
    await guard(
      () => ctx.accounts.deleteAccount(account.id),
      successMessage: 'Conta excluída.',
    );
  }
}
