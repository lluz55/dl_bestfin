import 'package:flutter/material.dart';
import 'package:bestfin/core/utils/adaptive_modal.dart';
import 'package:bestfin/core/widgets/app_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestfin/features/transactions/domain/models/transaction.dart';
import 'package:bestfin/features/transactions/domain/models/transaction_delete_context.dart';
import 'package:bestfin/features/transactions/presentation/providers/transactions_provider.dart';

/// Exibe o dialog/sheet de confirmação de exclusão adequado ao tipo da transação.
/// Retorna true se a transação foi excluída, false se o usuário cancelou.
Future<bool> showDeleteTransactionSheet(
  BuildContext context,
  WidgetRef ref,
  TransactionModel transaction,
) async {
  final deleteContext = await ref.read(
    transactionDeleteContextProvider(transaction.id).future,
  );

  if (!context.mounted) return false;

  switch (deleteContext.deleteCase) {
    case TransactionDeleteCase.regular:
      return _showRegularConfirmDialog(context, ref, transaction.id);
    case TransactionDeleteCase.installment:
      return _showInstallmentSheet(context, ref, transaction, deleteContext);
    case TransactionDeleteCase.recurringBase:
      return _showRecurringBaseSheet(context, ref, transaction, deleteContext);
    case TransactionDeleteCase.recurringClone:
      return _showRecurringCloneSheet(context, ref, transaction, deleteContext);
  }
}

Future<bool> _showRegularConfirmDialog(
  BuildContext context,
  WidgetRef ref,
  String txId,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Excluir transação?'),
      content: const Text('Esta ação não pode ser desfeita.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Excluir'),
        ),
      ],
    ),
  );

  if (confirmed == true && context.mounted) {
    await ref.read(deleteTransactionProvider).call(txId);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Transação excluída.')));
    }
    return true;
  }
  return false;
}

Future<bool> _showInstallmentSheet(
  BuildContext context,
  WidgetRef ref,
  TransactionModel transaction,
  TransactionDeleteContext deleteContext,
) async {
  final planId = deleteContext.installmentPlanId!;
  final currentNumber = deleteContext.installmentNumber ?? 1;
  final total = deleteContext.totalInstallments ?? currentNumber;
  final remaining = total - currentNumber + 1;

  final selected = await showAdaptiveModal<int>(
    context: context,
    builder: (ctx) => _DeleteOptionSheet(
      title: 'Excluir parcela?',
      subtitle: 'Parcela $currentNumber de $total',
      options: [
        const _DeleteOption(value: 0, label: 'Somente esta parcela'),
        _DeleteOption(
          value: 1,
          label: 'Esta e as $remaining parcelas restantes',
        ),
        _DeleteOption(value: 2, label: 'Todas as $total parcelas'),
      ],
    ),
  );

  if (selected == null || !context.mounted) return false;

  switch (selected) {
    case 0:
      await ref.read(deleteInstallmentSingleProvider)(transaction.id);
    case 1:
      await ref.read(deleteInstallmentFromHereProvider)(transaction.id, planId);
    case 2:
      await ref.read(deleteInstallmentAllProvider)(planId);
  }

  if (context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Parcela(s) excluída(s).')));
  }
  return true;
}

Future<bool> _showRecurringBaseSheet(
  BuildContext context,
  WidgetRef ref,
  TransactionModel transaction,
  TransactionDeleteContext deleteContext,
) async {
  final ruleId = deleteContext.recurringRuleId!;

  final selected = await showAdaptiveModal<int>(
    context: context,
    builder: (ctx) => const _DeleteOptionSheet(
      title: 'Excluir transação recorrente?',
      subtitle:
          'Esta é a transação base. A regra de recorrência também será excluída.',
      options: [
        _DeleteOption(
          value: 0,
          label: 'Somente esta',
          description: 'Ocorrências já geradas permanecem',
        ),
        _DeleteOption(value: 1, label: 'Esta e as futuras ocorrências'),
        _DeleteOption(value: 2, label: 'Todas as ocorrências geradas'),
      ],
    ),
  );

  if (selected == null || !context.mounted) return false;

  switch (selected) {
    case 0:
      await ref.read(deleteTransactionProvider).call(transaction.id);
    case 1:
      await ref.read(deleteRecurringBaseAndFutureProvider)(
        transaction.id,
        ruleId,
      );
    case 2:
      await ref.read(deleteRecurringBaseAndAllProvider)(transaction.id, ruleId);
  }

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Transação(ões) excluída(s).')),
    );
  }
  return true;
}

Future<bool> _showRecurringCloneSheet(
  BuildContext context,
  WidgetRef ref,
  TransactionModel transaction,
  TransactionDeleteContext deleteContext,
) async {
  final ruleId = deleteContext.recurringRuleId!;

  final selected = await showAdaptiveModal<int>(
    context: context,
    builder: (ctx) => const _DeleteOptionSheet(
      title: 'Excluir ocorrência?',
      options: [
        _DeleteOption(value: 0, label: 'Somente esta ocorrência'),
        _DeleteOption(
          value: 1,
          label: 'Esta e as próximas ocorrências',
          description: 'A recorrência será encerrada a partir desta data',
        ),
      ],
    ),
  );

  if (selected == null || !context.mounted) return false;

  switch (selected) {
    case 0:
      await ref.read(deleteTransactionProvider).call(transaction.id);
    case 1:
      await ref.read(deleteRecurringCloneAndFutureProvider)(
        transaction.id,
        ruleId,
        transaction.date,
      );
  }

  if (context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Ocorrência(s) excluída(s).')));
  }
  return true;
}

// ── Sheet interno ─────────────────────────────────────────────────────────────

class _DeleteOption {
  final int value;
  final String label;
  final String? description;

  const _DeleteOption({
    required this.value,
    required this.label,
    this.description,
  });
}

class _DeleteOptionSheet extends StatefulWidget {
  final String title;
  final String? subtitle;
  final List<_DeleteOption> options;

  const _DeleteOptionSheet({
    required this.title,
    this.subtitle,
    required this.options,
  });

  @override
  State<_DeleteOptionSheet> createState() => _DeleteOptionSheetState();
}

class _DeleteOptionSheetState extends State<_DeleteOptionSheet> {
  late int _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.options.first.value;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                widget.title,
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            if (widget.subtitle != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                child: Text(
                  widget.subtitle!,
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
            const SizedBox(height: 12),
            RadioGroup<int>(
              groupValue: _selected,
              onChanged: (v) => setState(() => _selected = v!),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...widget.options.map(
                    (opt) => InkWell(
                      onTap: () => setState(() => _selected = opt.value),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        child: Row(
                          children: [
                            Radio<int>(value: opt.value),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(opt.label, style: tt.bodyMedium),
                                  if (opt.description != null)
                                    Text(
                                      opt.description!,
                                      style: tt.bodySmall?.copyWith(
                                        color: cs.onSurfaceVariant,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(null),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppButton(
                    label: 'Excluir',
                    variant: AppButtonVariant.destructive,
                    onPressed: () => Navigator.of(context).pop(_selected),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
