import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import 'package:bestfin/core/database/app_database.dart';
import 'package:bestfin/core/database/database_provider.dart';
import 'package:intl/intl.dart';

final exportCsvUseCaseProvider = Provider<ExportCsvUseCase>((ref) {
  // watch (não read): após um invalidate do databaseProvider (clear-all,
  // restore), o use case precisa ser reconstruído com a instância nova —
  // com read ele ficava preso a um banco já fechado.
  return ExportCsvUseCase(ref.watch(databaseProvider));
});

class ExportCsvUseCase {
  final AppDatabase _db;

  ExportCsvUseCase(this._db);

  Future<String> execute({
    DateTime? startDate,
    DateTime? endDate,
    String separator = ';',
  }) async {
    // 1. Fetch transactions with date filters
    final query = _db.select(_db.transactions);
    if (startDate != null) {
      query.where((t) => t.date.isBiggerOrEqualValue(startDate));
    }
    if (endDate != null) {
      query.where((t) => t.date.isSmallerOrEqualValue(endDate));
    }
    query.orderBy([
      (t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc),
    ]);
    final txList = await query.get();

    // 2. Fetch categories and accounts for in-memory mapping
    final allCategories = await _db.select(_db.categories).get();
    final categoryMap = {for (var c in allCategories) c.id: c.name};

    final allAccounts = await _db.select(_db.accounts).get();
    final accountMap = {for (var a in allAccounts) a.id: a.name};

    final allEntries = await _db.select(_db.entries).get();
    final entriesByTx = <String, List<Entry>>{};
    for (final entry in allEntries) {
      entriesByTx.putIfAbsent(entry.transactionId, () => []).add(entry);
    }

    // 3. Assemble CSV Headers
    final headers = [
      'ID',
      'Data',
      'Descrição',
      'Tipo',
      'Valor',
      'Categoria',
      'Conta Origem',
      'Conta Destino',
      'Sentimento',
      'Observações',
    ];

    final csvRows = <List<String>>[headers];

    // 4. Map transactions to rows
    for (final tx in txList) {
      final txEntries = entriesByTx[tx.id] ?? [];
      int amountCents = 0;
      String sourceAccount = '';
      String destAccount = '';

      if (tx.type == 'expense') {
        final creditEntry = txEntries.firstWhere(
          (e) => e.type == 'credit',
          orElse: () => txEntries.isNotEmpty
              ? txEntries.first
              : Entry(
                  id: '',
                  transactionId: '',
                  accountId: '',
                  amount: 0,
                  type: '',
                  createdAt: DateTime.now(),
                ),
        );
        amountCents = creditEntry.amount;
        sourceAccount = accountMap[creditEntry.accountId] ?? '';
      } else if (tx.type == 'income') {
        final debitEntry = txEntries.firstWhere(
          (e) => e.type == 'debit',
          orElse: () => txEntries.isNotEmpty
              ? txEntries.first
              : Entry(
                  id: '',
                  transactionId: '',
                  accountId: '',
                  amount: 0,
                  type: '',
                  createdAt: DateTime.now(),
                ),
        );
        amountCents = debitEntry.amount;
        sourceAccount = accountMap[debitEntry.accountId] ?? '';
      } else if (tx.type == 'transfer') {
        final creditEntry = txEntries.firstWhere(
          (e) => e.type == 'credit',
          orElse: () => Entry(
            id: '',
            transactionId: '',
            accountId: '',
            amount: 0,
            type: '',
            createdAt: DateTime.now(),
          ),
        );
        final debitEntry = txEntries.firstWhere(
          (e) => e.type == 'debit',
          orElse: () => Entry(
            id: '',
            transactionId: '',
            accountId: '',
            amount: 0,
            type: '',
            createdAt: DateTime.now(),
          ),
        );
        amountCents = creditEntry.amount > 0
            ? creditEntry.amount
            : debitEntry.amount;
        sourceAccount = accountMap[creditEntry.accountId] ?? '';
        destAccount = accountMap[debitEntry.accountId] ?? '';
      }

      // Format currency
      double amountDouble = amountCents / 100.0;
      if (tx.type == 'expense') {
        amountDouble = -amountDouble;
      }
      final amountStr = amountDouble
          .toStringAsFixed(2)
          .replaceAll('.', separator == ';' ? ',' : '.');

      final dateStr = DateFormat('dd/MM/yyyy').format(tx.date);

      csvRows.add([
        tx.id,
        dateStr,
        tx.description,
        tx.type,
        amountStr,
        categoryMap[tx.categoryId] ?? 'Sem Categoria',
        sourceAccount,
        destAccount,
        tx.sentiment ?? '',
        tx.notes ?? '',
      ]);
    }

    // 5. Stringify CSV Rows with escaping
    final buffer = StringBuffer();
    // Excel needs UTF-8 BOM to read accents correctly
    buffer.write('\uFEFF');

    for (final row in csvRows) {
      final escapedLine = row
          .map((val) => _escapeCsvValue(val, separator))
          .join(separator);
      buffer.write(escapedLine);
      buffer.write('\r\n');
    }

    return buffer.toString();
  }

  String _escapeCsvValue(String val, String separator) {
    if (val.contains(separator) ||
        val.contains('\n') ||
        val.contains('\r') ||
        val.contains('"')) {
      return '"${val.replaceAll('"', '""')}"';
    }
    return val;
  }
}
