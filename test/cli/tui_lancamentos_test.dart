import 'package:bestfin/cli/bulk_parser.dart';
import 'package:bestfin/cli/tui/context.dart';
import 'package:bestfin/core/database/app_database.dart';
import 'package:bestfin/features/transactions/domain/models/split_entry.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late TuiContext ctx;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    ctx = TuiContext(db, dbPath: ':memory:');
  });

  tearDown(() async {
    await ctx.close();
  });

  group('bulk parser (task 58)', () {
    test('linhas válidas viram itens; inválidas voltam com motivo', () {
      final result = parseBulkLines(
        [
          'Mercado; 152,30',
          'Aluguel; 1200; 05/08/2026',
          'Sem valor',
          'Valor ruim; abc',
        ],
        accountId: 'acc1',
        categoryId: 'cat1',
        now: DateTime(2026, 9, 5),
      );

      expect(result.items.length, 2);
      expect(result.problems.length, 2);
      expect(result.problems[0], contains('falta o valor'));
      expect(result.problems[1], contains('valor inválido'));
      expect(result.items[0].description, 'Mercado');
      expect(result.items[0].amount, 15230);
      expect(result.items[1].date, DateTime(2026, 8, 5));
      expect(result.totalCents, 15230 + 120000);
    });
  });

  group('bulk via repositório (task 58)', () {
    test('cria todos os itens de uma vez e enfileira sync', () async {
      await db
          .into(db.accounts)
          .insert(
            AccountsCompanion.insert(
              id: 'acc1',
              name: 'Banco',
              type: 'checking',
            ),
          );
      final result = parseBulkLines(
        ['Mercado; 100', 'Farmácia; 50,50', 'Uber; 20; 01/09/2026'],
        accountId: 'acc1',
        now: DateTime(2026, 9, 5),
      );
      final ids = await ctx.transactions.createTransactionsBulk(result.items);
      expect(ids.length, 3);

      final txs = await db.select(db.transactions).get();
      expect(txs.where((t) => ids.contains(t.id)).length, 3);

      await Future<void>.delayed(const Duration(milliseconds: 200));
      final queue = await db.select(db.syncQueue).get();
      for (final id in ids) {
        expect(
          queue.any((q) => q.entityId == id && q.operation == 'insert'),
          isTrue,
          reason: 'bulk deve enfileirar sync por item',
        );
      }
    });
  });

  group('split de transações (task 58)', () {
    test('cria transação com split e grava as partes', () async {
      await db
          .into(db.accounts)
          .insert(
            AccountsCompanion.insert(
              id: 'acc1',
              name: 'Banco',
              type: 'checking',
            ),
          );
      await db
          .into(db.categories)
          .insert(
            CategoriesCompanion.insert(
              id: 'catA',
              name: 'Comida',
              icon: 'restaurant',
              color: '#fff',
              type: 'expense',
            ),
          );
      await db
          .into(db.categories)
          .insert(
            CategoriesCompanion.insert(
              id: 'catB',
              name: 'Limpeza',
              icon: 'cleaning',
              color: '#fff',
              type: 'expense',
            ),
          );

      final id = await ctx.transactions.createTransaction(
        date: DateTime(2026, 9, 5),
        description: 'Compra dividida',
        type: 'expense',
        amount: 10000,
        accountId: 'acc1',
        splits: const [
          SplitEntry(categoryId: 'catA', categoryName: 'Comida', amount: 6000),
          SplitEntry(
            categoryId: 'catB',
            categoryName: 'Limpeza',
            amount: 4000,
            description: 'produtos',
          ),
        ],
      );

      final splits = await (db.select(
        db.transactionSplits,
      )..where((s) => s.transactionId.equals(id))).get();
      expect(splits.length, 2);
      expect(splits.fold<int>(0, (s, p) => s + p.amount), 10000);

      final tx = await (db.select(
        db.transactions,
      )..where((t) => t.id.equals(id))).getSingle();
      expect(tx.isSplit, isTrue);
      expect(tx.categoryId, isNull, reason: 'categoria fica nas partes');
    });
  });

  group('reconciliação (task 59)', () {
    test('marca entradas, fecha checkpoint e reabre o último', () async {
      await db
          .into(db.accounts)
          .insert(
            AccountsCompanion.insert(
              id: 'acc1',
              name: 'Banco',
              type: 'checking',
            ),
          );
      final dao = db.reconciliationDao;

      // Transação base para as entradas (FK).
      await db
          .into(db.transactions)
          .insert(
            TransactionsCompanion.insert(
              id: 't1',
              date: DateTime(2026, 9, 1),
              description: 'Compra',
              type: 'expense',
            ),
          );

      // Checkpoint inicial (depois reaberto).
      final cp1 = await dao.insertCheckpoint(
        accountId: 'acc1',
        statementBalance: 10000,
        entriesCount: 2,
      );
      expect((await dao.getLatest('acc1'))!.id, cp1.id);

      // Marca duas entradas (mesmo update que a TUI faz).
      final entryIds = <String>['e1', 'e2'];
      for (final eid in entryIds) {
        await db
            .into(db.entries)
            .insert(
              EntriesCompanion.insert(
                id: eid,
                transactionId: 't1',
                accountId: 'acc1',
                type: 'debit',
                amount: 5000,
              ),
            );
      }
      await (db.update(db.entries)..where((e) => e.id.isIn(entryIds))).write(
        EntriesCompanion(reconciledAt: Value(DateTime.now())),
      );

      final reconciled =
          await (db.select(db.entries)..where(
                (e) => e.accountId.equals('acc1') & e.reconciledAt.isNotNull(),
              ))
              .get();
      expect(reconciled.length, 2);

      // Fecha um segundo checkpoint com as entradas marcadas.
      await dao.insertCheckpoint(
        accountId: 'acc1',
        statementBalance: 5000,
        entriesCount: 2,
      );
      expect((await dao.getByAccount('acc1')).length, 2);

      // Reabrir o último = apagar o registro mais recente.
      final latest = await dao.getLatest('acc1');
      await dao.deleteCheckpoint(latest!.id);
      expect((await dao.getByAccount('acc1')).length, 1);
      expect(
        (await (db.select(
          db.entries,
        )..where((e) => e.reconciledAt.isNotNull())).get()).length,
        2,
        reason: 'desmarcar é individual; reabrir só apaga o checkpoint',
      );
    });
  });
}
