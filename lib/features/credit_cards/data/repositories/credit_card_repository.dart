import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:bestfin/core/database/app_database.dart' as db;
import 'package:bestfin/features/credit_cards/domain/models/credit_card.dart';
import 'package:bestfin/features/credit_cards/data/repositories/invoice_repository.dart';
import 'package:uuid/uuid.dart';

abstract class CreditCardRepository {
  Stream<List<CreditCardModel>> watchAllCreditCards();
  Stream<CreditCardModel> watchCreditCardById(String id);
  Future<void> createCreditCard({
    required String name,
    required int limitAmount,
    required int closingDay,
    required int dueDay,
    required String accountId,
    String? color,
    int minPaymentPercent = 15,
  });
  Future<void> updateCreditCard({
    required String id,
    required String name,
    required int limitAmount,
    required int closingDay,
    required int dueDay,
    String? accountId,
    String? color,
    int minPaymentPercent = 15,
  });
  Future<void> deleteCreditCard(String id);
}

class CreditCardRepositoryImpl implements CreditCardRepository {
  final db.AppDatabase _database;

  CreditCardRepositoryImpl(this._database);

  @override
  Stream<List<CreditCardModel>> watchAllCreditCards() {
    // Junção com transactions para somar apenas despesas CC sem fatura quitada
    final query = _database.select(_database.creditCards).join([
      leftOuterJoin(
        _database.transactions,
        _database.transactions.creditCardId.equalsExp(
              _database.creditCards.id,
            ) &
            _database.transactions.type.equals('expense') &
            _database.transactions.invoiceId.isNull(),
      ),
    ])..where(_database.creditCards.isArchived.equals(false));

    return query.watch().map((rows) {
      final Map<String, db.CreditCard> cardsMap = {};
      final Map<String, int> usedMap = {};

      for (final row in rows) {
        final card = row.readTable(_database.creditCards);
        final tx = row.readTableOrNull(_database.transactions);

        cardsMap[card.id] = card;

        if (tx != null) {
          final current = usedMap[card.id] ?? 0;
          usedMap[card.id] = current + (tx.rawAmount ?? 0);
        } else {
          usedMap[card.id] ??= 0;
        }
      }

      return cardsMap.values.map((dbCard) {
        final usedLimit = usedMap[dbCard.id] ?? 0;
        return CreditCardModel.fromDb(dbCard, usedLimit: usedLimit);
      }).toList();
    });
  }

  @override
  Stream<CreditCardModel> watchCreditCardById(String id) {
    final query = _database.select(_database.creditCards).join([
      leftOuterJoin(
        _database.transactions,
        _database.transactions.creditCardId.equalsExp(
              _database.creditCards.id,
            ) &
            _database.transactions.type.equals('expense') &
            _database.transactions.invoiceId.isNull(),
      ),
    ])..where(_database.creditCards.id.equals(id));

    return query.watch().map((rows) {
      if (rows.isEmpty) {
        throw Exception('Credit Card not found');
      }

      final dbCard = rows.first.readTable(_database.creditCards);
      int usedLimit = 0;

      for (final row in rows) {
        final tx = row.readTableOrNull(_database.transactions);
        if (tx != null) {
          usedLimit += tx.rawAmount ?? 0;
        }
      }

      return CreditCardModel.fromDb(dbCard, usedLimit: usedLimit);
    });
  }

  @override
  Future<void> createCreditCard({
    required String name,
    required int limitAmount,
    required int closingDay,
    required int dueDay,
    required String accountId,
    String? color,
    int minPaymentPercent = 15,
  }) async {
    final cardId = const Uuid().v4();
    final invoiceId = const Uuid().v4();
    final now = DateTime.now();

    await _database.transaction(() async {
      await _database
          .into(_database.creditCards)
          .insert(
            db.CreditCardsCompanion.insert(
              id: cardId,
              name: name,
              limitAmount: limitAmount,
              closingDay: closingDay,
              dueDay: dueDay,
              accountId: accountId,
              color: Value(color),
              minPaymentPercent: Value(minPaymentPercent),
              isArchived: const Value(false),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );

      final holidaysList = await _database.select(_database.holidays).get();
      final holidayDates = holidaysList.map((h) => h.date).toList();

      final closingDate = InvoiceRepositoryImpl.calculateClosingDateStatic(
        year: now.year,
        month: now.month,
        closingDay: closingDay,
        dueDay: dueDay,
        holidays: holidayDates,
      );

      final dueDate = DateTime(now.year, now.month, dueDay);

      await _database
          .into(_database.invoices)
          .insert(
            db.InvoicesCompanion.insert(
              id: invoiceId,
              creditCardId: cardId,
              month: now.month,
              year: now.year,
              status: 'open',
              closingDate: closingDate,
              dueDate: dueDate,
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
    });

    await _enqueueCreditCardSync(cardId, 'insert');
    await _enqueueInvoiceSync(invoiceId, 'insert');
  }

  @override
  Future<void> updateCreditCard({
    required String id,
    required String name,
    required int limitAmount,
    required int closingDay,
    required int dueDay,
    String? accountId,
    String? color,
    int minPaymentPercent = 15,
  }) async {
    final now = DateTime.now();
    await (_database.update(
      _database.creditCards,
    )..where((t) => t.id.equals(id))).write(
      db.CreditCardsCompanion(
        name: Value(name),
        limitAmount: Value(limitAmount),
        closingDay: Value(closingDay),
        dueDay: Value(dueDay),
        accountId: accountId != null ? Value(accountId) : const Value.absent(),
        color: Value(color),
        minPaymentPercent: Value(minPaymentPercent),
        updatedAt: Value(now),
      ),
    );
    await _enqueueCreditCardSync(id, 'update');
  }

  @override
  Future<void> deleteCreditCard(String id) async {
    await _enqueueCreditCardSync(id, 'delete');
    await (_database.delete(
      _database.creditCards,
    )..where((t) => t.id.equals(id))).go();
  }

  Future<void> _enqueueCreditCardSync(String id, String operation) async {
    final card = await (_database.select(
      _database.creditCards,
    )..where((t) => t.id.equals(id))).getSingleOrNull();

    final payload = card == null
        ? <String, dynamic>{'id': id}
        : <String, dynamic>{
            'id': card.id,
            'name': card.name,
            'limit_amount': card.limitAmount,
            'closing_day': card.closingDay,
            'due_day': card.dueDay,
            'account_id': card.accountId,
            'color': card.color,
            'min_payment_percent': card.minPaymentPercent,
            'is_archived': card.isArchived,
            'created_at': card.createdAt.toIso8601String(),
            'updated_at': card.updatedAt.toIso8601String(),
          };

    await _database.syncQueueDao.enqueue(
      id: const Uuid().v4(),
      operation: operation,
      entityType: 'credit_card',
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
}
