import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/widgets/app_page_appbar.dart';
import 'package:bestfin/core/providers/privacy_provider.dart';
import 'package:bestfin/core/widgets/loading_indicator.dart';
import 'package:bestfin/features/ai/presentation/providers/invoice_risk_provider.dart';
import 'package:bestfin/features/credit_cards/presentation/providers/credit_cards_provider.dart';
import 'package:bestfin/features/credit_cards/presentation/providers/credit_card_form_modal_provider.dart';
import 'package:bestfin/features/credit_cards/presentation/widgets/credit_card_visual_widget.dart';
import 'package:bestfin/features/credit_cards/presentation/widgets/limit_bar_widget.dart';
import 'package:bestfin/features/credit_cards/presentation/widgets/invoice_timeline_widget.dart';
import 'package:go_router/go_router.dart';

class CreditCardDetailScreen extends ConsumerWidget {
  final String cardId;

  const CreditCardDetailScreen({super.key, required this.cardId});

  Future<void> _deleteCard(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Cartão'),
        content: const Text(
          'Tem certeza que deseja excluir este cartão? Todas as faturas associadas serão apagadas, e a conta vinculada será arquivada.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCELAR'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: context.colorScheme.error,
            ),
            child: const Text('EXCLUIR'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(creditCardRepositoryProvider).deleteCreditCard(cardId);
        if (context.mounted) {
          context.pop();
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Erro ao excluir cartão: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = context.colorScheme;
    final tt = context.textTheme;
    ref.watch(valuesHiddenProvider);
    final cardAsync = ref.watch(creditCardByIdStreamProvider(cardId));
    final invoicesAsync = ref.watch(invoicesStreamProvider(cardId));
    final riskAsync = ref.watch(invoiceRiskProvider);

    return cardAsync.when(
      data: (card) => Scaffold(
        backgroundColor: cs.surface,
        appBar: AppPageAppBar(
          title: card.name,
          showVisibilityToggle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => ref
                  .read(creditCardFormModalProvider.notifier)
                  .open(card: card),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () => _deleteCard(context, ref),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CreditCardVisualWidget(card: card),
              const SizedBox(height: 16),
              _DetailRiskChip(cardId: cardId, riskAsync: riskAsync),
              const SizedBox(height: 16),
              LimitBarWidget(card: card),
              const SizedBox(height: 32),
              Text(
                'HISTÓRICO DE FATURAS',
                style: tt.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.8),
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              invoicesAsync.when(
                data: (invoices) =>
                    InvoiceTimelineWidget(invoices: invoices, cardId: cardId),
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: AppLoadingIndicator(),
                  ),
                ),
                error: (err, __) => Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text('Erro ao carregar faturas: $err'),
                  ),
                ),
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
      loading: () => Scaffold(
        backgroundColor: cs.surface,
        appBar: const AppPageAppBar(title: ''),
        body: const Center(child: AppLoadingIndicator()),
      ),
      error: (err, stack) => Scaffold(
        backgroundColor: cs.surface,
        appBar: const AppPageAppBar(title: ''),
        body: Center(child: Text('Erro ao carregar detalhes do cartão: $err')),
      ),
    );
  }
}

class _DetailRiskChip extends StatelessWidget {
  final String cardId;
  final AsyncValue<List<InvoiceRiskScore>> riskAsync;

  const _DetailRiskChip({required this.cardId, required this.riskAsync});

  @override
  Widget build(BuildContext context) {
    final score = riskAsync.value?.where((s) => s.cardId == cardId).firstOrNull;

    if (score == null || score.openInvoiceTotal == 0)
      return const SizedBox.shrink();

    final (color, icon, label) = switch (score.level) {
      InvoiceRiskLevel.green => (
        Colors.green,
        Icons.check_circle_outline,
        'Fatura saudável',
      ),
      InvoiceRiskLevel.yellow => (
        Colors.orange,
        Icons.warning_amber_rounded,
        'Uso elevado',
      ),
      InvoiceRiskLevel.red => (
        Colors.red,
        Icons.error_outline_rounded,
        'Limite crítico',
      ),
    };

    final usagePct = (score.usagePercent * 100).toStringAsFixed(0);
    final totalFormatted =
        'R\$ ${(score.openInvoiceTotal / 100).toStringAsFixed(2).replaceAll('.', ',')}';
    final daysLabel = score.closingDate != null
        ? 'Fecha em ${score.closingDate!.difference(DateTime.now()).inDays} dias'
        : '';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$totalFormatted ($usagePct% do limite)${daysLabel.isNotEmpty ? ' · $daysLabel' : ''}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: color.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
