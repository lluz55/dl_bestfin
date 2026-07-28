import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bestfin/core/database/app_database.dart' as db_pkg;
import 'package:bestfin/core/database/database_provider.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/theme/breakpoints.dart';
import 'package:bestfin/core/widgets/amount_display.dart';
import 'package:bestfin/core/widgets/loading_indicator.dart';
import 'package:bestfin/features/accounts/presentation/widgets/reconciliation_entry_tile.dart';

final _reconciliationDaoProvider = Provider((ref) {
  return ref.watch(databaseProvider).reconciliationDao;
});

class _ReconcilableItem {
  final db_pkg.Entry entry;
  final db_pkg.Transaction transaction;
  const _ReconcilableItem({required this.entry, required this.transaction});
}

class ReconciliationScreen extends ConsumerStatefulWidget {
  const ReconciliationScreen({super.key, required this.accountId});

  final String accountId;

  @override
  ConsumerState<ReconciliationScreen> createState() =>
      _ReconciliationScreenState();
}

class _ReconciliationScreenState extends ConsumerState<ReconciliationScreen> {
  final Set<String> _selectedEntryIds = {};
  int _statementBalance = 0;
  final _balanceController = TextEditingController();
  List<_ReconcilableItem> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  @override
  void dispose() {
    _balanceController.dispose();
    super.dispose();
  }

  Future<void> _loadEntries() async {
    final database = ref.read(databaseProvider);
    final rawEntries =
        await (database.select(database.entries)
              ..where(
                (e) =>
                    e.accountId.equals(widget.accountId) &
                    e.reconciledAt.isNull(),
              )
              ..orderBy([
                (e) => OrderingTerm(
                  expression: e.createdAt,
                  mode: OrderingMode.asc,
                ),
              ]))
            .get();

    final items = <_ReconcilableItem>[];
    for (final entry in rawEntries) {
      final tx = await (database.select(
        database.transactions,
      )..where((t) => t.id.equals(entry.transactionId))).getSingleOrNull();
      if (tx != null) {
        items.add(_ReconcilableItem(entry: entry, transaction: tx));
      }
    }

    if (mounted) {
      setState(() {
        _items = items;
        _loading = false;
      });
    }
  }

  int get _reconciledBalance {
    int balance = 0;
    for (final item in _items) {
      if (_selectedEntryIds.contains(item.entry.id)) {
        balance += item.entry.type == 'debit'
            ? item.entry.amount
            : -item.entry.amount;
      }
    }
    return balance;
  }

  int get _difference => _reconciledBalance - _statementBalance;

  bool get _canConclude =>
      _difference == 0 &&
      _selectedEntryIds.isNotEmpty &&
      _statementBalance != 0;

  Future<void> _conclude() async {
    final dao = ref.read(_reconciliationDaoProvider);
    final database = ref.read(databaseProvider);

    await (database.update(database.entries)
          ..where((e) => e.id.isIn(_selectedEntryIds)))
        .write(db_pkg.EntriesCompanion(reconciledAt: Value(DateTime.now())));

    await dao.insertCheckpoint(
      accountId: widget.accountId,
      statementBalance: _statementBalance,
      entriesCount: _selectedEntryIds.length,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Conta reconciliada com sucesso!')),
      );
      context.pop();
    }
  }

  void _toggleEntry(String entryId) {
    setState(() {
      if (_selectedEntryIds.contains(entryId)) {
        _selectedEntryIds.remove(entryId);
      } else {
        _selectedEntryIds.add(entryId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.textTheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('Reconciliar Conta'),
        automaticallyImplyLeading: Breakpoints.isCompact(context),
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
      ),
      bottomNavigationBar: _buildFooter(cs, tt),
      body: _loading
          ? const Center(child: AppLoadingIndicator())
          : Column(
              children: [
                _buildBalanceInput(cs, tt),
                const Divider(height: 1),
                Expanded(child: _buildEntriesList(cs, tt)),
              ],
            ),
    );
  }

  Widget _buildBalanceInput(ColorScheme cs, TextTheme tt) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Saldo no extrato bancário',
            style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _balanceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Ex: 1.250,00',
              prefixText: 'R\$ ',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: cs.surfaceContainerLow,
            ),
            onChanged: (val) {
              final parsed =
                  double.tryParse(
                    val.replaceAll('.', '').replaceAll(',', '.'),
                  ) ??
                  0.0;
              setState(() {
                _statementBalance = (parsed * 100).round();
              });
            },
          ),
          const SizedBox(height: 8),
          Text(
            'Marque as transações que aparecem no extrato',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildEntriesList(ColorScheme cs, TextTheme tt) {
    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 48, color: cs.primary),
            const SizedBox(height: 16),
            Text(
              'Nenhuma movimentação pendente',
              style: tt.bodyLarge?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _items.length,
      separatorBuilder: (_, _) =>
          Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.5)),
      itemBuilder: (context, index) {
        final item = _items[index];
        return ReconciliationEntryTile(
          entry: item.entry,
          transaction: item.transaction,
          isSelected: _selectedEntryIds.contains(item.entry.id),
          onToggle: () => _toggleEntry(item.entry.id),
        );
      },
    );
  }

  Widget _buildFooter(ColorScheme cs, TextTheme tt) {
    final differenceColor = _difference == 0 ? cs.primary : cs.error;

    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        16 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        border: Border(top: BorderSide(color: cs.outlineVariant)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                'Reconciliado:',
                style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
              const Spacer(),
              AmountDisplay(amountInCents: _reconciledBalance, showSign: true),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                'Diferença:',
                style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
              const Spacer(),
              Text(
                _difference == 0 ? 'R\$ 0,00' : _formatCents(_difference),
                style: tt.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: differenceColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _canConclude ? _conclude : null,
              child: const Text('Concluir reconciliação'),
            ),
          ),
        ],
      ),
    );
  }

  String _formatCents(int cents) {
    final sign = cents < 0 ? '-' : '+';
    final abs = cents.abs();
    final reais = abs ~/ 100;
    final centavos = (abs % 100).toString().padLeft(2, '0');
    return '$sign R\$ $reais,$centavos';
  }
}
