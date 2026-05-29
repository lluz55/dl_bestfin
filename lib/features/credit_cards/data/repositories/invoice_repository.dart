import 'dart:async';
import 'package:drift/drift.dart';
import 'package:bestfin/core/database/app_database.dart' as db;
import 'package:bestfin/features/categories/domain/models/category.dart';
import 'package:bestfin/features/credit_cards/domain/models/invoice.dart';
import 'package:bestfin/features/transactions/domain/models/transaction.dart';
import 'package:bestfin/features/transactions/domain/models/entry.dart';
import 'package:bestfin/features/transactions/data/repositories/transaction_repository.dart';
import 'package:uuid/uuid.dart';

abstract class InvoiceRepository {
  Stream<List<InvoiceModel>> watchInvoicesForCard(String cardId);
  Stream<InvoiceModel?> watchInvoiceById(String id);
  Stream<InvoiceModel?> watchCurrentOpenInvoice(String cardId);
  Future<void> payInvoice({
    required String invoiceId,
    required String sourceAccountId,
    required int payAmount,
  });
}

class InvoiceRepositoryImpl implements InvoiceRepository {
  final db.AppDatabase _database;

  InvoiceRepositoryImpl(this._database);

  @override
  Stream<List<InvoiceModel>> watchInvoicesForCard(String cardId) {
    // Escuta as alterações na tabela invoices
    final query = _database.select(_database.invoices)
      ..where((i) => i.creditCardId.equals(cardId))
      ..orderBy([
        (t) => OrderingTerm(expression: t.year, mode: OrderingMode.desc),
        (t) => OrderingTerm(expression: t.month, mode: OrderingMode.desc),
      ]);

    return query.watch().asyncMap((invoicesList) async {
      final List<InvoiceModel> results = [];
      final card = await (_database.select(
        _database.creditCards,
      )..where((c) => c.id.equals(cardId))).getSingleOrNull();

      if (card == null) return <InvoiceModel>[];

      final holidaysList = await _database.select(_database.holidays).get();
      final holidayDates = holidaysList.map((h) => h.date).toList();

      for (final inv in invoicesList) {
        final prevClosing = getPreviousClosing(
          inv.year,
          inv.month,
          card.closingDay,
          card.dueDay,
          holidayDates,
        );

        // Busca todas as transações (lançadas na conta de passivo do cartão) no ciclo de faturamento
        final txQuery =
            _database.select(_database.transactions).join([
                innerJoin(
                  _database.entries,
                  _database.entries.transactionId.equalsExp(
                    _database.transactions.id,
                  ),
                ),
                leftOuterJoin(
                  _database.categories,
                  _database.categories.id.equalsExp(
                    _database.transactions.categoryId,
                  ),
                ),
              ])
              ..where(
                _database.entries.accountId.equals(card.accountId) &
                    _database.transactions.date.isBiggerThanValue(prevClosing) &
                    _database.transactions.date.isSmallerOrEqualValue(
                      inv.closingDate,
                    ) &
                    _database.transactions.type.equals('expense'),
              )
              ..orderBy([
                OrderingTerm(
                  expression: _database.transactions.date,
                  mode: OrderingMode.desc,
                ),
              ]);

        final rows = await txQuery.get();
        final List<TransactionModel> transactions = [];
        int totalAmount = 0;

        for (final row in rows) {
          final tx = row.readTable(_database.transactions);
          final entry = row.readTable(_database.entries);
          final cat = row.readTableOrNull(_database.categories);

          transactions.add(
            TransactionModel.fromDb(
              tx,
              category: cat != null ? CategoryModel.fromDb(cat) : null,
              entries: [EntryModel.fromDb(entry)],
            ),
          );
          totalAmount += entry.amount;
        }

        results.add(
          InvoiceModel.fromDb(
            inv,
            transactions: transactions,
            totalAmount: totalAmount,
          ),
        );
      }
      return results;
    });
  }

  @override
  Stream<InvoiceModel?> watchInvoiceById(String id) {
    final query = _database.select(_database.invoices)
      ..where((i) => i.id.equals(id));
    return query.watchSingleOrNull().asyncMap((inv) async {
      if (inv == null) return null;

      final card = await (_database.select(
        _database.creditCards,
      )..where((c) => c.id.equals(inv.creditCardId))).getSingleOrNull();

      if (card == null) return InvoiceModel.fromDb(inv);

      final holidaysList = await _database.select(_database.holidays).get();
      final holidayDates = holidaysList.map((h) => h.date).toList();

      final prevClosing = getPreviousClosing(
        inv.year,
        inv.month,
        card.closingDay,
        card.dueDay,
        holidayDates,
      );

      final txQuery =
          _database.select(_database.transactions).join([
              innerJoin(
                _database.entries,
                _database.entries.transactionId.equalsExp(
                  _database.transactions.id,
                ),
              ),
              leftOuterJoin(
                _database.categories,
                _database.categories.id.equalsExp(
                  _database.transactions.categoryId,
                ),
              ),
            ])
            ..where(
              _database.entries.accountId.equals(card.accountId) &
                  _database.transactions.date.isBiggerThanValue(prevClosing) &
                  _database.transactions.date.isSmallerOrEqualValue(
                    inv.closingDate,
                  ) &
                  _database.transactions.type.equals('expense'),
            )
            ..orderBy([
              OrderingTerm(
                expression: _database.transactions.date,
                mode: OrderingMode.desc,
              ),
            ]);

      final rows = await txQuery.get();
      final List<TransactionModel> transactions = [];
      int totalAmount = 0;

      for (final row in rows) {
        final tx = row.readTable(_database.transactions);
        final entry = row.readTable(_database.entries);
        final cat = row.readTableOrNull(_database.categories);

        transactions.add(
          TransactionModel.fromDb(
            tx,
            category: cat != null ? CategoryModel.fromDb(cat) : null,
            entries: [EntryModel.fromDb(entry)],
          ),
        );
        totalAmount += entry.amount;
      }

      return InvoiceModel.fromDb(
        inv,
        transactions: transactions,
        totalAmount: totalAmount,
      );
    });
  }

  @override
  Stream<InvoiceModel?> watchCurrentOpenInvoice(String cardId) {
    final query = _database.select(_database.invoices)
      ..where((i) => i.creditCardId.equals(cardId) & i.status.equals('open'))
      ..limit(1);

    return query.watchSingleOrNull().asyncMap((inv) async {
      if (inv == null) return null;

      final card = await (_database.select(
        _database.creditCards,
      )..where((c) => c.id.equals(cardId))).getSingleOrNull();

      if (card == null) return InvoiceModel.fromDb(inv);

      final holidaysList = await _database.select(_database.holidays).get();
      final holidayDates = holidaysList.map((h) => h.date).toList();

      final prevClosing = getPreviousClosing(
        inv.year,
        inv.month,
        card.closingDay,
        card.dueDay,
        holidayDates,
      );

      final txQuery =
          _database.select(_database.transactions).join([
              innerJoin(
                _database.entries,
                _database.entries.transactionId.equalsExp(
                  _database.transactions.id,
                ),
              ),
              leftOuterJoin(
                _database.categories,
                _database.categories.id.equalsExp(
                  _database.transactions.categoryId,
                ),
              ),
            ])
            ..where(
              _database.entries.accountId.equals(card.accountId) &
                  _database.transactions.date.isBiggerThanValue(prevClosing) &
                  _database.transactions.date.isSmallerOrEqualValue(
                    inv.closingDate,
                  ) &
                  _database.transactions.type.equals('expense'),
            )
            ..orderBy([
              OrderingTerm(
                expression: _database.transactions.date,
                mode: OrderingMode.desc,
              ),
            ]);

      final rows = await txQuery.get();
      final List<TransactionModel> transactions = [];
      int totalAmount = 0;

      for (final row in rows) {
        final tx = row.readTable(_database.transactions);
        final entry = row.readTable(_database.entries);
        final cat = row.readTableOrNull(_database.categories);

        transactions.add(
          TransactionModel.fromDb(
            tx,
            category: cat != null ? CategoryModel.fromDb(cat) : null,
            entries: [EntryModel.fromDb(entry)],
          ),
        );
        totalAmount += entry.amount;
      }

      return InvoiceModel.fromDb(
        inv,
        transactions: transactions,
        totalAmount: totalAmount,
      );
    });
  }

  @override
  Future<void> payInvoice({
    required String invoiceId,
    required String sourceAccountId,
    required int payAmount,
  }) async {
    final now = DateTime.now();

    await _database.transaction(() async {
      final inv = await (_database.select(
        _database.invoices,
      )..where((i) => i.id.equals(invoiceId))).getSingleOrNull();

      if (inv == null) throw Exception('Invoice not found');

      final card = await (_database.select(
        _database.creditCards,
      )..where((c) => c.id.equals(inv.creditCardId))).getSingleOrNull();

      if (card == null) throw Exception('Credit Card not found');

      final monthStr = inv.month.toString().padLeft(2, '0');
      final desc = 'Pgmto Fatura $monthStr/${inv.year}';

      // Criar a transferência (Double-entry)
      // Crédito na conta de origem (debitando da carteira/corrente) e Débito no cartão (liquidando passivo)
      final transactionId = const Uuid().v4();

      await _database
          .into(_database.transactions)
          .insert(
            db.TransactionsCompanion.insert(
              id: transactionId,
              date: now,
              description: desc,
              type: 'transfer',
              isCompleted: const Value(true),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );

      // Entrada 1: crédito da conta de origem (saída)
      await _database
          .into(_database.entries)
          .insert(
            db.EntriesCompanion.insert(
              id: const Uuid().v4(),
              transactionId: transactionId,
              accountId: sourceAccountId,
              amount: payAmount,
              type: 'credit',
            ),
          );

      // Entrada 2: débito da conta do cartão (entrada/redução passivo)
      await _database
          .into(_database.entries)
          .insert(
            db.EntriesCompanion.insert(
              id: const Uuid().v4(),
              transactionId: transactionId,
              accountId: card.accountId,
              amount: payAmount,
              type: 'debit',
            ),
          );

      // Atualiza o status da fatura para 'paid' se o pagamento for total
      // Para saber se o pagamento foi total, somamos as transações da fatura e comparamos com o saldo
      final holidaysList = await _database.select(_database.holidays).get();
      final holidayDates = holidaysList.map((h) => h.date).toList();
      final prevClosing = getPreviousClosing(
        inv.year,
        inv.month,
        card.closingDay,
        card.dueDay,
        holidayDates,
      );

      final txQuery =
          _database.select(_database.transactions).join([
            innerJoin(
              _database.entries,
              _database.entries.transactionId.equalsExp(
                _database.transactions.id,
              ),
            ),
          ])..where(
            _database.entries.accountId.equals(card.accountId) &
                _database.transactions.date.isBiggerThanValue(prevClosing) &
                _database.transactions.date.isSmallerOrEqualValue(
                  inv.closingDate,
                ) &
                _database.transactions.type.equals('expense'),
          );

      final rows = await txQuery.get();
      int invoiceTotal = 0;
      for (final row in rows) {
        invoiceTotal += row.readTable(_database.entries).amount;
      }

      // Se o valor pago é maior ou igual ao total acumulado da fatura, marca como paga
      if (payAmount >= invoiceTotal) {
        await (_database.update(
          _database.invoices,
        )..where((i) => i.id.equals(invoiceId))).write(
          db.InvoicesCompanion(
            status: const Value('paid'),
            updatedAt: Value(now),
          ),
        );
      }
    });
  }

  // Lógica de fechamento inteligente
  static DateTime calculateClosingDateStatic({
    required int year,
    required int month,
    required int closingDay,
    int? dueDay,
    required List<DateTime> holidays,
    bool anticipatesWeekend = true,
    bool anticipatesHoliday = true,
  }) {
    DateTime closing;
    if (closingDay <= 0 && dueDay != null) {
      final offset = -closingDay;
      final dueDate = DateTime(year, month, dueDay);
      closing = dueDate.subtract(Duration(days: offset));
    } else {
      final actualClosingDay = closingDay <= 0 ? 5 : closingDay;
      closing = DateTime(year, month, actualClosingDay);
    }

    bool isWeekend(DateTime dt) =>
        dt.weekday == DateTime.saturday || dt.weekday == DateTime.sunday;
    bool isHoliday(DateTime dt) => holidays.any(
      (h) => h.year == dt.year && h.month == dt.month && h.day == dt.day,
    );

    while (true) {
      bool adjusted = false;
      if (anticipatesWeekend && isWeekend(closing)) {
        if (closing.weekday == DateTime.sunday) {
          closing = closing.subtract(const Duration(days: 2));
        } else if (closing.weekday == DateTime.saturday) {
          closing = closing.subtract(const Duration(days: 1));
        }
        adjusted = true;
      }
      if (anticipatesHoliday && isHoliday(closing)) {
        closing = closing.subtract(const Duration(days: 1));
        adjusted = true;
      }
      if (!adjusted) break;
    }
    return closing;
  }

  DateTime getPreviousClosing(
    int year,
    int month,
    int closingDay,
    int dueDay,
    List<DateTime> holidays,
  ) {
    final prevMonth = month == 1 ? 12 : month - 1;
    final prevYear = month == 1 ? year - 1 : year;
    return calculateClosingDateStatic(
      year: prevYear,
      month: prevMonth,
      closingDay: closingDay,
      dueDay: dueDay,
      holidays: holidays,
    );
  }
}
