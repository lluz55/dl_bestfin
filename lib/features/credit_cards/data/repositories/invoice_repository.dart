import 'dart:async';
import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:bestfin/core/database/app_database.dart' as db;
import 'package:bestfin/features/categories/domain/models/category.dart';
import 'package:bestfin/features/credit_cards/domain/models/invoice.dart';
import 'package:bestfin/features/transactions/domain/models/transaction.dart';
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

  /// Busca as transações CC do período de uma fatura usando creditCardId diretamente.
  Future<List<TransactionModel>> _fetchInvoiceTransactions({
    required String cardId,
    required DateTime prevClosing,
    required DateTime closingDate,
  }) async {
    final txQuery =
        _database.select(_database.transactions).join([
            leftOuterJoin(
              _database.categories,
              _database.categories.id.equalsExp(
                _database.transactions.categoryId,
              ),
            ),
          ])
          ..where(
            _database.transactions.creditCardId.equals(cardId) &
                _database.transactions.date.isBiggerThanValue(prevClosing) &
                _database.transactions.date.isSmallerOrEqualValue(closingDate) &
                _database.transactions.type.equals('expense'),
          )
          ..orderBy([
            OrderingTerm(
              expression: _database.transactions.date,
              mode: OrderingMode.desc,
            ),
          ]);

    final rows = await txQuery.get();
    return rows.map((row) {
      final tx = row.readTable(_database.transactions);
      final cat = row.readTableOrNull(_database.categories);
      return TransactionModel.fromDb(
        tx,
        category: cat != null ? CategoryModel.fromDb(cat) : null,
      );
    }).toList();
  }

  @override
  Stream<List<InvoiceModel>> watchInvoicesForCard(String cardId) {
    final query = _database.select(_database.invoices)
      ..where((i) => i.creditCardId.equals(cardId))
      ..orderBy([
        (t) => OrderingTerm(expression: t.year, mode: OrderingMode.desc),
        (t) => OrderingTerm(expression: t.month, mode: OrderingMode.desc),
      ]);

    return query.watch().asyncMap((invoicesList) async {
      if (invoicesList.isEmpty) return <InvoiceModel>[];

      final card = await (_database.select(
        _database.creditCards,
      )..where((c) => c.id.equals(cardId))).getSingleOrNull();

      if (card == null) return <InvoiceModel>[];

      final holidaysList = await _database.select(_database.holidays).get();
      final holidayDates = holidaysList.map((h) => h.date).toList();

      // Compute each invoice's period first (pure calculation), then fetch
      // every relevant transaction for the card in a single query spanning
      // the whole range, instead of one query per invoice.
      final prevClosings = <String, DateTime>{
        for (final inv in invoicesList)
          inv.id: getPreviousClosing(
            inv.year,
            inv.month,
            card.closingDay,
            card.dueDay,
            holidayDates,
          ),
      };

      final rangeStart = prevClosings.values.reduce(
        (a, b) => a.isBefore(b) ? a : b,
      );
      final rangeEnd = invoicesList
          .map((inv) => inv.closingDate)
          .reduce((a, b) => a.isAfter(b) ? a : b);

      final allTransactions = await _fetchInvoiceTransactions(
        cardId: cardId,
        prevClosing: rangeStart,
        closingDate: rangeEnd,
      );

      return invoicesList.map((inv) {
        final prevClosing = prevClosings[inv.id]!;
        final transactions = allTransactions
            .where(
              (t) =>
                  t.date.isAfter(prevClosing) &&
                  !t.date.isAfter(inv.closingDate),
            )
            .toList();
        final totalAmount = transactions.fold(0, (sum, t) => sum + t.amount);

        return InvoiceModel.fromDb(
          inv,
          transactions: transactions,
          totalAmount: totalAmount,
        );
      }).toList();
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

      final transactions = await _fetchInvoiceTransactions(
        cardId: inv.creditCardId,
        prevClosing: prevClosing,
        closingDate: inv.closingDate,
      );

      final totalAmount = transactions.fold(0, (sum, t) => sum + t.amount);

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

      final transactions = await _fetchInvoiceTransactions(
        cardId: cardId,
        prevClosing: prevClosing,
        closingDate: inv.closingDate,
      );

      final totalAmount = transactions.fold(0, (sum, t) => sum + t.amount);

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
    final transactionId = const Uuid().v4();
    final ccTxIdsToUpdate = <String>[];
    bool isPaid = false;

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

      await _database
          .into(_database.transactions)
          .insert(
            db.TransactionsCompanion.insert(
              id: transactionId,
              date: now,
              description: desc,
              type: 'expense',
              isCompleted: const Value(true),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );

      // Débito da conta de origem (reduz saldo)
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

      // Calcula o total da fatura com base nas transações CC do período
      final holidaysList = await _database.select(_database.holidays).get();
      final holidayDates = holidaysList.map((h) => h.date).toList();
      final prevClosing = getPreviousClosing(
        inv.year,
        inv.month,
        card.closingDay,
        card.dueDay,
        holidayDates,
      );

      final ccTxQuery = _database.select(_database.transactions)
        ..where(
          (t) =>
              t.creditCardId.equals(card.id) &
              t.date.isBiggerThanValue(prevClosing) &
              t.date.isSmallerOrEqualValue(inv.closingDate) &
              t.type.equals('expense'),
        );

      final ccRows = await ccTxQuery.get();
      int invoiceTotal = ccRows.fold(0, (sum, t) => sum + (t.rawAmount ?? 0));

      // Se pagamento total: vincula as transações CC à fatura e marca como paga
      if (payAmount >= invoiceTotal) {
        isPaid = true;
        for (final tx in ccRows) {
          ccTxIdsToUpdate.add(tx.id);
          await (_database.update(
            _database.transactions,
          )..where((t) => t.id.equals(tx.id))).write(
            db.TransactionsCompanion(
              invoiceId: Value(invoiceId),
              updatedAt: Value(now),
            ),
          );
        }

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

    await _enqueueTransactionSync(transactionId, 'insert');
    if (isPaid) {
      for (final txId in ccTxIdsToUpdate) {
        await _enqueueTransactionSync(txId, 'update');
      }
      await _enqueueInvoiceSync(invoiceId, 'update');
    }
  }

  Future<void> _enqueueTransactionSync(String id, String operation) async {
    final tx = await (_database.select(
      _database.transactions,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    final entries = await (_database.select(
      _database.entries,
    )..where((e) => e.transactionId.equals(id))).get();
    final splits = await (_database.select(
      _database.transactionSplits,
    )..where((s) => s.transactionId.equals(id))).get();

    final payload = tx == null
        ? <String, dynamic>{'id': id}
        : <String, dynamic>{
            'id': tx.id,
            'date': tx.date.toIso8601String(),
            'description': tx.description,
            'type': tx.type,
            'sentiment': tx.sentiment,
            'notes': tx.notes,
            'category_id': tx.categoryId,
            'entity_id': tx.entityId,
            'goal_id': tx.goalId,
            'installment_plan_id': tx.installmentPlanId,
            'installment_number': tx.installmentNumber,
            'recurring_rule_id': tx.recurringRuleId,
            'credit_card_id': tx.creditCardId,
            'raw_amount': tx.rawAmount,
            'invoice_id': tx.invoiceId,
            'is_completed': tx.isCompleted,
            'is_confirmed': tx.isConfirmed,
            'source': tx.source,
            'created_at': tx.createdAt.toIso8601String(),
            'updated_at': tx.updatedAt.toIso8601String(),
            'entries': entries
                .map(
                  (entry) => <String, dynamic>{
                    'id': entry.id,
                    'transaction_id': entry.transactionId,
                    'account_id': entry.accountId,
                    'amount': entry.amount,
                    'type': entry.type,
                    'created_at': entry.createdAt.toIso8601String(),
                  },
                )
                .toList(),
            'splits': splits
                .map(
                  (split) => <String, dynamic>{
                    'id': split.id,
                    'transaction_id': split.transactionId,
                    'category_id': split.categoryId,
                    'amount': split.amount,
                    'description': split.description,
                  },
                )
                .toList(),
          };

    await _database.syncQueueDao.enqueue(
      id: const Uuid().v4(),
      operation: operation,
      entityType: 'transaction',
      entityId: id,
      payload: jsonEncode(payload),
    );
  }

  Future<void> _enqueueInvoiceSync(String id, String operation) async {
    final invoice = await (_database.select(
      _database.invoices,
    )..where((t) => t.id.equals(id))).getSingleOrNull();

    final payload = invoice == null
        ? <String, dynamic>{'id': id}
        : <String, dynamic>{
            'id': invoice.id,
            'credit_card_id': invoice.creditCardId,
            'month': invoice.month,
            'year': invoice.year,
            'status': invoice.status,
            'closing_date': invoice.closingDate.toIso8601String(),
            'due_date': invoice.dueDate.toIso8601String(),
            'created_at': invoice.createdAt.toIso8601String(),
            'updated_at': invoice.updatedAt.toIso8601String(),
          };

    await _database.syncQueueDao.enqueue(
      id: const Uuid().v4(),
      operation: operation,
      entityType: 'invoice',
      entityId: id,
      payload: jsonEncode(payload),
    );
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
