import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/widgets/app_page_appbar.dart';
import 'package:bestfin/core/widgets/empty_state.dart';
import 'package:bestfin/core/widgets/loading_indicator.dart';
import 'package:bestfin/core/database/app_database.dart';
import 'package:bestfin/core/database/database_provider.dart';
import 'package:bestfin/features/pdf_import/domain/models/pdf_parsed_transaction.dart';
import 'package:bestfin/features/pdf_import/presentation/providers/pdf_import_provider.dart';
import 'package:bestfin/features/pdf_import/presentation/widgets/parsed_transaction_tile.dart';

class PdfReviewScreen extends ConsumerStatefulWidget {
  final List<PdfParsedTransaction> transactions;

  const PdfReviewScreen({super.key, required this.transactions});

  @override
  ConsumerState<PdfReviewScreen> createState() => _PdfReviewScreenState();
}

class _PdfReviewScreenState extends ConsumerState<PdfReviewScreen> {
  String? _selectedAccountId;
  bool _isImporting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(pdfImportProvider.notifier).setTransactions(widget.transactions);
    });
  }

  Future<void> _handleConfirm(
    List<PdfParsedTransaction> list,
    List<Account> accounts,
  ) async {
    final selected = list.where((t) => t.selected).toList();
    if (selected.isEmpty) {
      _showSnack('Selecione ao menos uma transação.', error: true);
      return;
    }

    String accountId = _selectedAccountId ?? '';
    if (accountId.isEmpty) {
      // Auto-resolve by institution name
      final institutionName = selected.first.accountName;
      final db = ref.read(databaseProvider);
      accountId = await resolveOrCreateAccount(db, accounts, institutionName);
    }

    setState(() => _isImporting = true);
    try {
      final count = await ref
          .read(pdfImportProvider.notifier)
          .commitImport(accountId);
      if (!mounted) return;
      ref.read(pdfImportProvider.notifier).reset();
      _showSnack('$count transações importadas com sucesso!');
      context.pop();
    } catch (e) {
      if (!mounted) return;
      _showSnack('Erro ao importar: $e', error: true);
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  void _showSnack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error
            ? context.colorScheme.error
            : context.customColors.income,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.textTheme;
    final importState = ref.watch(pdfImportProvider);
    final accountsAsync = ref.watch(pdfImportAccountsProvider);

    final list = importState.value ?? widget.transactions;
    final selectedCount = list.where((t) => t.selected).length;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppPageAppBar(
        title: 'Revisar Transações',
        infoDescription: 'Revise e confirme os dados extraídos do PDF antes de importar as transações para o aplicativo. Selecione quais transações deseja importar.',
        infoFeatures: const [
          'Revisão de dados extraídos',
          'Seleção individual ou em lote',
          'Confirmação antes de importar',
        ],
        actions: [
          TextButton(
            onPressed: () {
              for (int i = 0; i < list.length; i++) {
                ref.read(pdfImportProvider.notifier).toggleSelection(i);
              }
            },
            child: Text(
              selectedCount == list.length ? 'Desmarcar tudo' : 'Marcar tudo',
              style: TextStyle(color: cs.primary),
            ),
          ),
        ],
      ),
      body: accountsAsync.when(
        loading: () => const Center(child: AppLoadingIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (accounts) {
          return Column(
            children: [
              // Account selector
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.account_balance_wallet_rounded,
                      color: cs.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Conta destino',
                      style: tt.labelLarge?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedAccountId,
                          hint: Text(
                            'Auto (${list.isNotEmpty ? list.first.accountName : "Detectar"})',
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          isExpanded: true,
                          borderRadius: BorderRadius.circular(12),
                          items: accounts.map((a) {
                            return DropdownMenuItem<String>(
                              value: a.id,
                              child: Text(
                                a.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (v) =>
                              setState(() => _selectedAccountId = v),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Summary chip
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Row(
                  children: [
                    Chip(
                      avatar: Icon(
                        Icons.check_circle_outline_rounded,
                        size: 16,
                        color: cs.primary,
                      ),
                      label: Text(
                        '$selectedCount de ${list.length} selecionadas',
                        style: tt.labelMedium,
                      ),
                      backgroundColor: cs.primaryContainer.withValues(
                        alpha: 0.4,
                      ),
                      side: BorderSide.none,
                    ),
                  ],
                ),
              ),

              // Transaction list
              Expanded(
                child: list.isEmpty
                    ? const EmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: 'Nenhuma transação encontrada',
                        description:
                            'Nenhuma transação corresponde ao filtro selecionado.',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                        itemCount: list.length,
                        itemBuilder: (_, i) {
                          return ParsedTransactionTile(
                            transaction: list[i],
                            index: i,
                            onToggle: (_) => ref
                                .read(pdfImportProvider.notifier)
                                .toggleSelection(i),
                            onDescriptionChanged: (desc) => ref
                                .read(pdfImportProvider.notifier)
                                .updateDescription(i, desc),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: FilledButton.icon(
            onPressed: _isImporting
                ? null
                : () async {
                    final list =
                        ref.read(pdfImportProvider).value ??
                        widget.transactions;
                    final accounts =
                        ref.read(pdfImportAccountsProvider).value ?? [];
                    await _handleConfirm(list, accounts);
                  },
            icon: _isImporting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.download_done_rounded),
            label: Text(
              _isImporting
                  ? 'Importando...'
                  : 'Importar $selectedCount transações',
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
            ),
          ),
        ),
      ),
    );
  }
}
