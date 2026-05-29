import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestfin/core/database/database_provider.dart';
import 'package:bestfin/features/credit_cards/data/repositories/credit_card_repository.dart';
import 'package:bestfin/features/credit_cards/data/repositories/invoice_repository.dart';
import 'package:bestfin/features/credit_cards/domain/models/credit_card.dart';
import 'package:bestfin/features/credit_cards/domain/models/invoice.dart';

final creditCardRepositoryProvider = Provider<CreditCardRepository>((ref) {
  final database = ref.watch(databaseProvider);
  return CreditCardRepositoryImpl(database);
});

final invoiceRepositoryProvider = Provider<InvoiceRepository>((ref) {
  final database = ref.watch(databaseProvider);
  return InvoiceRepositoryImpl(database);
});

final creditCardsStreamProvider = StreamProvider<List<CreditCardModel>>((ref) {
  final repository = ref.watch(creditCardRepositoryProvider);
  return repository.watchAllCreditCards();
});

final creditCardByIdStreamProvider =
    StreamProvider.family<CreditCardModel, String>((ref, id) {
      final repository = ref.watch(creditCardRepositoryProvider);
      return repository.watchCreditCardById(id);
    });

final invoicesStreamProvider =
    StreamProvider.family<List<InvoiceModel>, String>((ref, cardId) {
      final repository = ref.watch(invoiceRepositoryProvider);
      return repository.watchInvoicesForCard(cardId);
    });

final invoiceByIdStreamProvider = StreamProvider.family<InvoiceModel?, String>((
  ref,
  id,
) {
  final repository = ref.watch(invoiceRepositoryProvider);
  return repository.watchInvoiceById(id);
});

final currentInvoiceStreamProvider =
    StreamProvider.family<InvoiceModel?, String>((ref, cardId) {
      final repository = ref.watch(invoiceRepositoryProvider);
      return repository.watchCurrentOpenInvoice(cardId);
    });
