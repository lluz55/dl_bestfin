import 'dart:typed_data';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:bestfin/core/database/app_database.dart';
import 'package:bestfin/core/database/database_provider.dart';
import 'package:bestfin/features/pdf_import/domain/models/pdf_parsed_transaction.dart';
import 'package:bestfin/features/pdf_import/domain/usecases/import_pdf_usecase.dart';
import 'package:bestfin/features/transactions/domain/usecases/create_transaction.dart';
import 'package:bestfin/features/transactions/data/repositories/transaction_repository.dart';

final importPdfUseCaseProvider = Provider<ImportPdfUseCase>((ref) {
  return ImportPdfUseCase();
});

final _createTransactionProvider = Provider<CreateTransaction>((ref) {
  final db = ref.watch(databaseProvider);
  return CreateTransaction(TransactionRepositoryImpl(db));
});

class PdfImportNotifier extends Notifier<AsyncValue<List<PdfParsedTransaction>>> {
  @override
  AsyncValue<List<PdfParsedTransaction>> build() => const AsyncValue.data([]);

  Future<void> parsePdf(Uint8List bytes) async {
    state = const AsyncValue.loading();
    final useCase = ref.read(importPdfUseCaseProvider);
    state = await AsyncValue.guard(() => useCase(bytes));
  }

  void toggleSelection(int index) {
    final list = state.value;
    if (list == null) return;
    final updated = List<PdfParsedTransaction>.from(list);
    updated[index] = updated[index].copyWith(selected: !updated[index].selected);
    state = AsyncValue.data(updated);
  }

  void updateDescription(int index, String description) {
    final list = state.value;
    if (list == null) return;
    final updated = List<PdfParsedTransaction>.from(list);
    updated[index] = updated[index].copyWith(description: description);
    state = AsyncValue.data(updated);
  }

  void setTransactions(List<PdfParsedTransaction> transactions) {
    state = AsyncValue.data(transactions);
  }

  void reset() {
    state = const AsyncValue.data([]);
  }

  /// Commits selected transactions to the database.
  /// Returns the count of imported transactions.
  Future<int> commitImport(String accountId) async {
    final list = state.value ?? [];
    final selected = list.where((t) => t.selected).toList();
    if (selected.isEmpty) return 0;

    final createTx = ref.read(_createTransactionProvider);
    for (final tx in selected) {
      await createTx(
        date: tx.date,
        description: tx.description,
        type: tx.type,
        amount: tx.amountCents,
        accountId: accountId,
        notes: null,
      );
    }
    return selected.length;
  }
}

final pdfImportProvider =
    NotifierProvider<PdfImportNotifier, AsyncValue<List<PdfParsedTransaction>>>(
  PdfImportNotifier.new,
);

/// Provides a cached list of accounts for the account picker in the review screen.
final pdfImportAccountsProvider = FutureProvider<List<Account>>((ref) async {
  final db = ref.watch(databaseProvider);
  return db.select(db.accounts).get();
});

/// Creates or returns existing account by name. Used in review screen.
Future<String> resolveOrCreateAccount(
  AppDatabase db,
  List<Account> cached,
  String name, {
  String type = 'checking',
  String color = '#6750A4',
}) async {
  final existing = cached.firstWhere(
    (a) => a.name.toLowerCase() == name.toLowerCase(),
    orElse: () => Account(
      id: '',
      name: name,
      type: type,
      color: color,
      isArchived: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
  );
  if (existing.id.isNotEmpty) return existing.id;

  final newId = 'acc_${const Uuid().v4()}';
  await db.into(db.accounts).insert(
    AccountsCompanion.insert(
      id: newId,
      name: name,
      type: type,
      color: Value(color),
    ),
  );
  return newId;
}
