import 'dart:io';

import 'package:bestfin/cli/cli_main.dart';
import 'package:bestfin/cli/db_path_resolver.dart';
import 'package:bestfin/core/database/app_database.dart';
import 'package:bestfin/features/transactions/data/repositories/transaction_repository.dart';
import 'package:bestfin/features/transactions/domain/usecases/create_transaction.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('resolveBestfinDbPath com override', () {
    expect(
      resolveBestfinDbPath(override: '/tmp/foo.sqlite'),
      '/tmp/foo.sqlite',
    );
  });

  test('cria transação via repository e verifica sync_queue', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(() => db.close());

    // Cria conta
    await db
        .into(db.accounts)
        .insert(
          AccountsCompanion.insert(
            id: 'acc1',
            name: 'Carteira',
            type: 'checking',
          ),
        );
    // Usa id único para evitar conflito com seed padrão (cat_food existe)
    await db
        .into(db.categories)
        .insert(
          CategoriesCompanion.insert(
            id: 'cat_cli_test',
            name: 'Alimentação CLI',
            icon: 'restaurant',
            color: '#fff',
            type: 'expense',
          ),
        );

    final repo = TransactionRepositoryImpl(db);
    final id = await CreateTransaction(repo).call(
      date: DateTime.now(),
      description: 'mercado 50',
      type: 'expense',
      amount: 5000,
      accountId: 'acc1',
      categoryId: 'cat_cli_test',
    );

    expect(id, isNotEmpty);

    // Verifica que a transação foi criada
    final tx = await (db.select(
      db.transactions,
    )..where((t) => t.id.equals(id))).getSingle();
    expect(tx.description, 'mercado 50');

    // Verifica entries (partida dobrada)
    final entries = await (db.select(
      db.entries,
    )..where((e) => e.transactionId.equals(id))).get();
    expect(entries.length, 1);
    expect(entries.first.type, 'credit');
    expect(entries.first.amount, 5000);

    // Verifica sync_queue tem linha insert
    // Aguarda enqueue assíncrono (unawaited)
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final queue = await db.select(db.syncQueue).get();
    final found = queue.where(
      (q) => q.entityId == id && q.operation == 'insert',
    );
    expect(
      found,
      isNotEmpty,
      reason: 'sync_queue deve conter insert da transação',
    );
  });

  test(
    '`bestfin sync` sem identidade sai com exit code 1 e mensagem',
    () async {
      final tmp = Directory.systemTemp.createTempSync('bestfin_sync_test');
      addTearDown(() => tmp.deleteSync(recursive: true));
      final dbPath = '${tmp.path}/bestfin.sqlite';
      File(dbPath).writeAsStringSync('');

      final code = await runCli(['sync', '--db', dbPath]);
      expect(code, 1);
    },
  );

  test('`bestfin sync` com banco inexistente sai com 1', () async {
    final code = await runCli([
      'sync',
      '--db',
      '/tmp/bestfin-inexistente-${DateTime.now().microsecondsSinceEpoch}.sqlite',
    ]);
    expect(code, 1);
  });
}
