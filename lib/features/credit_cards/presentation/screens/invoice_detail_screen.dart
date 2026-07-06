import 'package:flutter/material.dart';
import 'package:bestfin/core/widgets/app_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/utils/adaptive_modal.dart';
import 'package:bestfin/core/widgets/app_page_appbar.dart';
import 'package:bestfin/core/theme/typography.dart';
import 'package:bestfin/core/constants/transaction_types.dart';
import 'package:bestfin/core/widgets/loading_indicator.dart';
import 'package:bestfin/core/widgets/account_selector.dart';
import 'package:bestfin/core/widgets/staggered_transaction_list.dart';
import 'package:bestfin/features/accounts/domain/models/account.dart';
import 'package:bestfin/features/credit_cards/domain/models/credit_card.dart';
import 'package:bestfin/features/credit_cards/presentation/providers/credit_cards_provider.dart';
import 'package:bestfin/features/credit_cards/domain/models/invoice.dart';
import 'package:bestfin/core/providers/privacy_provider.dart';
import 'package:bestfin/features/transactions/presentation/widgets/amount_input.dart';

enum _PaymentType { full, minimum, custom }

class InvoiceDetailScreen extends ConsumerStatefulWidget {
  final String cardId;
  final String invoiceId;

  const InvoiceDetailScreen({
    super.key,
    required this.cardId,
    required this.invoiceId,
  });

  @override
  ConsumerState<InvoiceDetailScreen> createState() =>
      _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends ConsumerState<InvoiceDetailScreen> {
  String? _selectedSourceAccountId;
  bool _isProcessingPayment = false;

  Future<void> _showPaymentDialog(
    InvoiceModel invoice,
    CreditCardModel card,
  ) async {
    final cs = context.colorScheme;
    final tt = context.textTheme;

    // Pre-fill with card's linked account if not yet selected
    _selectedSourceAccountId ??= card.accountId;

    _PaymentType paymentType = _PaymentType.full;
    int paymentAmountCents = invoice.totalAmount;

    int _calcAmount(_PaymentType type) => switch (type) {
      _PaymentType.full => invoice.totalAmount,
      _PaymentType.minimum =>
        (invoice.totalAmount * card.minPaymentPercent / 100).round(),
      _PaymentType.custom => paymentAmountCents,
    };

    await showAdaptiveModal<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 32,
                      height: 4,
                      decoration: BoxDecoration(
                        color: cs.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Pagar Fatura',
                    style: tt.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Conta de Origem',
                    style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 8),
                  AccountSelector(
                    selectedAccountId: _selectedSourceAccountId,
                    onAccountSelected: (Account? acc) {
                      setModalState(() {
                        _selectedSourceAccountId = acc?.id;
                      });
                    },
                    hint: 'Selecione a conta para pagar',
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Tipo de Pagamento',
                    style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<_PaymentType>(
                    segments: [
                      ButtonSegment(
                        value: _PaymentType.minimum,
                        label: Text(
                          'Mínima\n${card.minPaymentPercent}%',
                          textAlign: TextAlign.center,
                          style: tt.labelSmall,
                        ),
                      ),
                      const ButtonSegment(
                        value: _PaymentType.custom,
                        label: Text('Específico'),
                      ),
                      const ButtonSegment(
                        value: _PaymentType.full,
                        label: Text('Completa'),
                      ),
                    ],
                    selected: {paymentType},
                    onSelectionChanged: (Set<_PaymentType> selection) {
                      setModalState(() {
                        paymentType = selection.first;
                        paymentAmountCents = _calcAmount(paymentType);
                      });
                    },
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Valor do Pagamento',
                    style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 8),
                  IgnorePointer(
                    ignoring: paymentType != _PaymentType.custom,
                    child: Opacity(
                      opacity: paymentType == _PaymentType.custom ? 1.0 : 0.6,
                      child: AmountInput(
                        amountInCents: _calcAmount(paymentType),
                        color: cs.primary,
                        onChanged: (val) {
                          if (paymentType == _PaymentType.custom) {
                            setModalState(() {
                              paymentAmountCents = val;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  AppButton(
                    label: 'CONFIRMAR PAGAMENTO',
                    expanded: true,
                    onPressed: _selectedSourceAccountId == null
                        ? null
                        : () {
                            final amount = _calcAmount(paymentType);
                            if (amount <= 0) return;
                            Navigator.pop(context);
                            _executePayment(amount);
                          },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _executePayment(int cents) async {
    setState(() => _isProcessingPayment = true);
    try {
      await ref
          .read(invoiceRepositoryProvider)
          .payInvoice(
            invoiceId: widget.invoiceId,
            sourceAccountId: _selectedSourceAccountId!,
            payAmount: cents,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pagamento registrado com sucesso.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao pagar fatura: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessingPayment = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.textTheme;
    final colors = context.customColors;
    ref.watch(valuesHiddenProvider);

    final invoiceAsync = ref.watch(invoiceByIdStreamProvider(widget.invoiceId));
    final cardAsync = ref.watch(creditCardByIdStreamProvider(widget.cardId));

    return invoiceAsync.when(
      data: (invoice) {
        if (invoice == null) {
          return Scaffold(
            appBar: const AppPageAppBar(title: ''),
            body: const Center(child: Text('Fatura não encontrada')),
          );
        }

        Color statusColor;
        switch (invoice.status) {
          case 'paid':
            statusColor = colors.income;
            break;
          case 'closed':
            statusColor = Colors.orange;
            break;
          case 'open':
          default:
            statusColor = cs.primary;
            break;
        }

        final double amount = invoice.totalAmount / 100.0;
        final formattedAmount =
            'R\$ ${amount.toStringAsFixed(2).replaceAll('.', ',')}';

        final dueDay = invoice.dueDate.day.toString().padLeft(2, '0');
        final dueMonth = invoice.dueDate.month.toString().padLeft(2, '0');
        final formattedDue = '$dueDay/$dueMonth';

        final closingDay = invoice.closingDate.day.toString().padLeft(2, '0');
        final closingMonth = invoice.closingDate.month.toString().padLeft(
          2,
          '0',
        );
        final formattedClosing = '$closingDay/$closingMonth';

        // Mapeia transações
        final transactionItems = invoice.transactions.map((tx) {
          final isExpense = tx.type == TransactionType.expense;
          final amountInCents = isExpense ? -tx.amount : tx.amount;

          final day = tx.date.day.toString().padLeft(2, '0');
          final month = tx.date.month.toString().padLeft(2, '0');
          final dateStr = '$day/$month';

          return TransactionItem(
            title: tx.description,
            category: tx.category?.name ?? 'Sem Categoria',
            amountInCents: amountInCents,
            date: dateStr,
            icon: tx.category?.iconData ?? Icons.receipt_long_outlined,
            isCreditCard: tx.creditCardId != null,
            isRecurring: tx.recurringRuleId != null,
            rawTransaction: tx,
          );
        }).toList();

        return Scaffold(
          backgroundColor: cs.surface,
          appBar: AppPageAppBar(
            title: '${invoice.monthName} de ${invoice.year}',
          ),
          body: _isProcessingPayment
              ? const Center(child: AppLoadingIndicator())
              : Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(20),
                        children: [
                          // Status Header Card
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'FECHAMENTO: $formattedClosing',
                                      style: tt.labelSmall?.copyWith(
                                        color: cs.onSurfaceVariant.withValues(
                                          alpha: 0.7,
                                        ),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'VENCIMENTO: $formattedDue',
                                      style: tt.labelSmall?.copyWith(
                                        color: cs.onSurfaceVariant.withValues(
                                          alpha: 0.7,
                                        ),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    invoice.statusLabel.toUpperCase(),
                                    style: tt.labelSmall?.copyWith(
                                      color: statusColor,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 28),
                          Center(
                            child: Column(
                              children: [
                                Text(
                                  'Valor Total da Fatura',
                                  style: tt.bodyMedium?.copyWith(
                                    color: cs.onSurfaceVariant,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  formattedAmount,
                                  style: tt.displayMedium
                                      ?.copyWith(
                                        color: cs.onSurface,
                                        fontWeight: FontWeight.w800,
                                      )
                                      .merge(AppTypography.monospace),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),
                          Text(
                            'COMPRAS NA FATURA',
                            style: tt.labelSmall?.copyWith(
                              color: cs.onSurfaceVariant.withValues(alpha: 0.8),
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (transactionItems.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 32),
                              child: Center(
                                child: Text(
                                  'Nenhuma compra registrada nesta fatura.',
                                  style: tt.bodyMedium?.copyWith(
                                    color: cs.onSurfaceVariant.withValues(
                                      alpha: 0.6,
                                    ),
                                  ),
                                ),
                              ),
                            )
                          else
                            StaggeredTransactionList(items: transactionItems),
                        ],
                      ),
                    ),
                    if (invoice.status == 'closed')
                      Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: AppButton(
                          label: 'PAGAR FATURA',
                          expanded: true,
                          onPressed: cardAsync.value == null
                              ? null
                              : () => _showPaymentDialog(
                                  invoice,
                                  cardAsync.value!,
                                ),
                        ),
                      ),
                  ],
                ),
        );
      },
      loading: () => Scaffold(
        appBar: const AppPageAppBar(title: ''),
        body: const Center(child: AppLoadingIndicator()),
      ),
      error: (err, __) => Scaffold(
        appBar: const AppPageAppBar(title: ''),
        body: Center(child: Text('Erro ao carregar fatura: $err')),
      ),
    );
  }
}
