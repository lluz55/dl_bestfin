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
  });
  Future<void> updateCreditCard({
    required String id,
    required String name,
    required int limitAmount,
    required int closingDay,
    required int dueDay,
    String? accountId,
    String? color,
  });
  Future<void> deleteCreditCard(String id);
}

class CreditCardRepositoryImpl implements CreditCardRepository {
  final db.AppDatabase _database;

  CreditCardRepositoryImpl(this._database);

  @override
  Stream<List<CreditCardModel>> watchAllCreditCards() {
    final query = _database.select(_database.creditCards).join([
      leftOuterJoin(
        _database.entries,
        _database.entries.accountId.equalsExp(_database.creditCards.accountId),
      ),
    ])..where(_database.creditCards.isArchived.equals(false));

    return query.watch().map((rows) {
      final Map<String, db.CreditCard> cardsMap = {};
      final Map<String, int> balancesMap = {};

      for (final row in rows) {
        final card = row.readTable(_database.creditCards);
        final entry = row.readTableOrNull(_database.entries);

        cardsMap[card.id] = card;

        if (entry != null) {
          final current = balancesMap[card.accountId] ?? 0;
          final change = entry.type == 'debit' ? entry.amount : -entry.amount;
          balancesMap[card.accountId] = current + change;
        } else {
          balancesMap[card.accountId] ??= 0;
        }
      }

      return cardsMap.values.map((dbCard) {
        final balance = balancesMap[dbCard.accountId] ?? 0;
        final usedLimit = balance < 0 ? -balance : 0;
        return CreditCardModel.fromDb(dbCard, usedLimit: usedLimit);
      }).toList();
    });
  }

  @override
  Stream<CreditCardModel> watchCreditCardById(String id) {
    final query = _database.select(_database.creditCards).join([
      leftOuterJoin(
        _database.entries,
        _database.entries.accountId.equalsExp(_database.creditCards.accountId),
      ),
    ])..where(_database.creditCards.id.equals(id));

    return query.watch().map((rows) {
      if (rows.isEmpty) {
        throw Exception('Credit Card not found');
      }

      final dbCard = rows.first.readTable(_database.creditCards);
      int balance = 0;

      for (final row in rows) {
        final entry = row.readTableOrNull(_database.entries);
        if (entry != null) {
          final change = entry.type == 'debit' ? entry.amount : -entry.amount;
          balance += change;
        }
      }

      final usedLimit = balance < 0 ? -balance : 0;
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
  }) async {
    final cardId = const Uuid().v4();
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
              id: const Uuid().v4(),
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
        updatedAt: Value(now),
      ),
    );
  }

  @override
  Future<void> deleteCreditCard(String id) async {
    await (_database.delete(
      _database.creditCards,
    )..where((t) => t.id.equals(id))).go();
  }
}
