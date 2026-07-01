import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestfin/features/credit_cards/presentation/providers/credit_cards_provider.dart';

enum InvoiceRiskLevel { green, yellow, red }

class InvoiceRiskScore {
  final String cardId;
  final String cardName;
  final int openInvoiceTotal;
  final int cardLimit;
  final double usagePercent;
  final InvoiceRiskLevel level;
  final DateTime? closingDate;

  const InvoiceRiskScore({
    required this.cardId,
    required this.cardName,
    required this.openInvoiceTotal,
    required this.cardLimit,
    required this.usagePercent,
    required this.level,
    this.closingDate,
  });
}

final invoiceRiskProvider = Provider<AsyncValue<List<InvoiceRiskScore>>>((ref) {
  final cardsAsync = ref.watch(creditCardsStreamProvider);

  return cardsAsync.whenData((cards) {
    final scores = <InvoiceRiskScore>[];

    for (final card in cards) {
      if (card.limitAmount <= 0) continue;

      final invoiceAsync = ref.watch(currentInvoiceStreamProvider(card.id));
      final invoice = invoiceAsync.value;

      final total = invoice?.totalAmount ?? 0;
      final usage = total / card.limitAmount;
      final level = usage < 0.5
          ? InvoiceRiskLevel.green
          : usage < 0.8
          ? InvoiceRiskLevel.yellow
          : InvoiceRiskLevel.red;

      scores.add(
        InvoiceRiskScore(
          cardId: card.id,
          cardName: card.name,
          openInvoiceTotal: total,
          cardLimit: card.limitAmount,
          usagePercent: usage,
          level: level,
          closingDate: invoice?.closingDate,
        ),
      );
    }

    return scores;
  });
});
