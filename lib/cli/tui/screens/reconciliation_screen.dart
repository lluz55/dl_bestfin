import 'package:bestfin/cli/tui/screens/base.dart';
import 'package:bestfin/cli/tui/term.dart';
import 'package:bestfin/core/database/app_database.dart' as db;
import 'package:bestfin/features/accounts/domain/models/account.dart';
import 'package:drift/drift.dart' hide Column;

/// Reconciliação de contas na TUI (task 59) — paridade com a GUI da task 30:
/// marca/desmarca lançamentos contra o extrato, confere saldo e fecha
/// checkpoints. Mesmos registros da GUI (`entries.reconciledAt` +
/// `reconciliation_checkpoints`) via [db.ReconciliationDao].
///
/// Nota de sincronização: igual na GUI, a reconciliação é **local** — o
/// caminho de escrita (update direto em `entries` + checkpoint) não
/// enfileira em `sync_queue`; decisão registrada no arquivo da task 59.
class ReconciliationScreen extends Screen {
  ReconciliationScreen(this.account, super.ctx);

  final Account account;

  @override
  String get title => 'Reconciliar — ${account.name}';

  final _selected = <String>{};

  @override
  Future<void> run() async {
    while (true) {
      final items = await _loadItems();
      final checkpoints = await ctx.db.reconciliationDao.getByAccount(
        account.id,
      );

      final reconciledBalance = items
          .where((it) => it.entry.reconciledAt != null)
          .fold<int>(
            0,
            (s, it) =>
                s +
                (it.entry.type == 'debit' ? it.entry.amount : -it.entry.amount),
          );

      final options = [
        'Conferir e fechar checkpoint',
        'Ver checkpoints anteriores',
        if (checkpoints.isNotEmpty) 'Reabrir o último checkpoint',
      ];

      final choice = Term.select(
        title,
        items: options,
        subtitle:
            'Saldo do app ${Term.formatMoney(account.balance)} • '
            'saldo reconciliado ${Term.formatMoney(reconciledBalance)} • '
            '${checkpoints.length} checkpoint(s)',
      );
      if (choice == null) return;

      switch (options[choice]) {
        case 'Conferir e fechar checkpoint':
          await _reconcile(items);
        case 'Ver checkpoints anteriores':
          _showCheckpoints(checkpoints);
        default:
          await _reopenLast(checkpoints);
      }
    }
  }

  // ── Dados ────────────────────────────────────────────────────────────

  /// Entradas da conta com a transação correspondente (mesma carga da GUI).
  Future<List<_ReconcilableItem>> _loadItems() async {
    final rows =
        await (ctx.db.select(ctx.db.entries).join([
                innerJoin(
                  ctx.db.transactions,
                  ctx.db.transactions.id.equalsExp(
                    ctx.db.entries.transactionId,
                  ),
                ),
              ])
              ..where(ctx.db.entries.accountId.equals(account.id))
              ..orderBy([OrderingTerm.asc(ctx.db.entries.createdAt)]))
            .get();
    return rows
        .map(
          (row) => _ReconcilableItem(
            entry: row.readTable(ctx.db.entries),
            transaction: row.readTable(ctx.db.transactions),
          ),
        )
        .toList();
  }

  // ── Fluxo principal ──────────────────────────────────────────────────

  Future<void> _reconcile(List<_ReconcilableItem> items) async {
    final open = items.where((it) => it.entry.reconciledAt == null).toList();
    if (open.isEmpty) {
      Term.alert(
        title,
        'Nenhum lançamento aberto — tudo já está reconciliado.',
      );
      return;
    }
    _selected.clear();

    final action = _toggleList(open);
    if (action == 'done') {
      await _conclude();
    }
  }

  /// Lista com marcação por espaço; devolve 'done' no ↵, null em q/Esc.
  String? _toggleList(List<_ReconcilableItem> open) {
    var offset = 0;
    var index = 0;
    while (true) {
      Term.clear();
      Term.header(title, subtitle: 'Marque o que aparece no extrato');
      Term.writeln();

      final viewport = Term.viewportFor(Term.height - 12, open.length);
      final markedBalance = open
          .where((it) => _selected.contains(it.entry.id))
          .fold<int>(
            0,
            (s, it) =>
                s +
                (it.entry.type == 'debit' ? it.entry.amount : -it.entry.amount),
          );

      if (index < offset) offset = index;
      if (index >= offset + viewport) offset = index - viewport + 1;

      for (var i = offset; i < offset + viewport && i < open.length; i++) {
        final it = open[i];
        final mark = _selected.contains(it.entry.id)
            ? '${Term.green}[x]${Term.reset}'
            : '[ ]';
        final sign = it.entry.type == 'debit' ? '+' : '-';
        Term.writeln(
          '${i == index ? '${Term.cyan}❯ ${Term.reset}' : '  '}'
          '$mark ${Term.formatDate(it.transaction.date)}  '
          '${Term.pad(it.transaction.description, 28)} '
          '${Term.padLeft(sign, 1)}${Term.formatMoney(it.entry.amount.abs())}',
        );
      }
      if (open.length > viewport) {
        Term.writeln('  ${Term.gray}${index + 1}/${open.length}${Term.reset}');
      }
      Term.writeln();
      Term.writeln(
        '  Marcados: ${Term.formatMoneyColored(markedBalance, sign: true)} '
        '(${_selected.length} lançamento(s))',
      );
      Term.footer([
        const TermAction('↑↓', 'navegar'),
        const TermAction('espaço', 'marcar/desmarcar'),
        const TermAction('↵', 'conferir saldo'),
        const TermAction('q', 'sair'),
      ]);

      final key = Term.readKey();
      switch (key.code) {
        case KeyCode.up:
          index = index == 0 ? open.length - 1 : index - 1;
        case KeyCode.down:
          index = (index + 1) % open.length;
        case KeyCode.enter:
          return 'done';
        case KeyCode.esc:
        case KeyCode.ctrlC:
          return null;
        default:
          if (key.is_('q')) return null;
          if (key.isChar && key.char == ' ') {
            final id = open[index].entry.id;
            if (!_selected.remove(id)) _selected.add(id);
          }
      }
    }
  }

  /// Painel de conferência: saldo informado do extrato × saldo reconstruído
  /// dos lançamentos reconciliados — mesma matemática da GUI (débito soma,
  /// crédito subtrai). Só fecha com diferença zero.
  Future<void> _conclude() async {
    if (_selected.isEmpty) {
      Term.error('Nenhum lançamento marcado.');
      Term.pause();
      return;
    }
    final statement = Term.inputMoney('Saldo final do extrato');
    if (statement == null) return;

    // Saldo conferido = lançamentos reconciliados até agora (os já
    // reconciliados antes + os marcados nesta sessão).
    final allItems = await _loadItems();
    final reconciledBalance = allItems
        .where(
          (it) =>
              it.entry.reconciledAt != null || _selected.contains(it.entry.id),
        )
        .fold<int>(
          0,
          (s, it) =>
              s +
              (it.entry.type == 'debit' ? it.entry.amount : -it.entry.amount),
        );
    final appBalance = allItems.fold<int>(
      0,
      (s, it) =>
          s + (it.entry.type == 'debit' ? it.entry.amount : -it.entry.amount),
    );

    Term.writeln();
    Term.writeln(
      '  Saldo reconstruído dos reconciliados: '
      '${Term.formatMoney(reconciledBalance)}',
    );
    Term.writeln(
      '  Saldo informado do extrato:    ${Term.formatMoney(statement)}',
    );
    final diff = reconciledBalance - statement;
    final color = diff == 0 ? Term.green : Term.red;
    Term.writeln(
      '  Diferença: ${Term.c(Term.formatMoney(diff, sign: true), color)}',
    );
    Term.writeln(
      '  ${Term.gray}(saldo do app pelos lançamentos: ${Term.formatMoney(appBalance)})${Term.reset}',
    );
    Term.writeln();

    if (diff != 0) {
      Term.error(
        'A diferença precisa zerar para fechar o checkpoint. '
        'Verifique se esqueceu de marcar algum lançamento.',
      );
      Term.pause();
      return;
    }
    if (!Term.confirm(
      'Fechar checkpoint com ${_selected.length} lançamento(s)?',
    )) {
      return;
    }

    await guard(() async {
      await (ctx.db.update(ctx.db.entries)..where((e) => e.id.isIn(_selected)))
          .write(db.EntriesCompanion(reconciledAt: Value(DateTime.now())));
      await ctx.db.reconciliationDao.insertCheckpoint(
        accountId: account.id,
        statementBalance: statement,
        entriesCount: _selected.length,
      );
      _selected.clear();
    }, successMessage: 'Checkpoint fechado.');
    Term.pause();
  }

  void _showCheckpoints(List<db.ReconciliationCheckpoint> checkpoints) {
    Term.pager('Checkpoints — ${account.name}', [
      '',
      if (checkpoints.isEmpty)
        '  ${Term.gray}Nenhum checkpoint ainda.${Term.reset}',
      ...checkpoints.map(
        (c) =>
            '  ${Term.formatDate(c.date)}  '
            'extrato ${Term.padLeft(Term.formatMoney(c.statementBalance), 14)}  '
            '${c.entriesCount} lançamento(s)',
      ),
      '',
    ]);
  }

  /// Reabrir o último checkpoint: apaga o registro (as entradas permanecem
  /// reconciliadas — desmarque individualmente numa nova conferência).
  Future<void> _reopenLast(
    List<db.ReconciliationCheckpoint> checkpoints,
  ) async {
    if (checkpoints.isEmpty) {
      Term.alert(title, 'Nenhum checkpoint para reabrir.');
      return;
    }
    final last = checkpoints.first;
    if (!Term.confirm(
      'Reabrir checkpoint de ${Term.formatDate(last.date)} '
      '(extrato ${Term.formatMoney(last.statementBalance)})?',
    )) {
      return;
    }
    await guard(
      () => ctx.db.reconciliationDao.deleteCheckpoint(last.id),
      successMessage: 'Checkpoint reaberto.',
    );
  }
}

class _ReconcilableItem {
  const _ReconcilableItem({required this.entry, required this.transaction});

  final db.Entry entry;
  final db.Transaction transaction;
}
