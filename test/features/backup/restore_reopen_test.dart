import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bestfin/core/database/app_database.dart';
import 'package:bestfin/features/backup/domain/usecases/import_data.dart';
import 'package:path/path.dart' as p;

/// Reproduz a sequência do restore no onboarding: restoreJson numa instância
/// aberta sobre arquivo, close, nova instância sobre o mesmo arquivo —
/// os dados restaurados devem sobreviver ao ciclo (WAL checkpoint no close).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('bestfin_restore_test');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  String backupJson() => jsonEncode({
    'version': 2,
    'exported_at': '2026-07-09T17:09:57.141918',
    'accounts': [
      {
        'id': '1a950e91-e9f7-4342-9e4a-0bd77af43f65',
        'name': 'BB',
        'type': 'checking',
        'icon': '62751',
        'color': '#FFC107',
        'isArchived': false,
        'createdAt': 1783533891000,
        'updatedAt': 1783533891000,
      },
    ],
    'app_settings': [
      {
        'key': 'onboarding_completed',
        'value': 'true',
        'updatedAt': 1783533891000,
      },
    ],
    'categories': [
      {
        'id': 'cat_subscriptions',
        'name': 'Assinaturas',
        'icon': 'subscriptions',
        'color': '#5E35B1',
        'type': 'expense',
        'isSystem': true,
        'parentId': null,
        'isArchived': false,
        'description': null,
        'createdAt': 1783533880000,
        'updatedAt': 1783533880000,
      },
    ],
    'entities': [
      {
        'id': '7e79d18f-c9c6-46ef-a95d-b593afad8806',
        'name': 'a',
        'type': 'payee',
        'category': 'person',
        'useCount': 2,
        'createdAt': 1783607162000,
        'updatedAt': 1783622964000,
      },
    ],
    'transactions': [
      {
        'id': '7cf07d99-aa8b-486c-acbd-213aa678fecc',
        'date': 1783622890000,
        'description': 'a',
        'type': 'expense',
        'sentiment': null,
        'notes': null,
        'categoryId': 'cat_subscriptions',
        'entityId': '7e79d18f-c9c6-46ef-a95d-b593afad8806',
        'goalId': null,
        'installmentPlanId': null,
        'installmentNumber': null,
        'recurringRuleId': null,
        'groupId': '23c6a942-8cab-4abb-8810-efe742647a5e',
        'creditCardId': null,
        'rawAmount': null,
        'invoiceId': null,
        'isSplit': false,
        'isCompleted': true,
        'isConfirmed': true,
        'source': null,
        'createdAt': 1783622964000,
        'updatedAt': 1783622964000,
      },
    ],
    'entries': [
      {
        'id': '6d895e97-cc87-4eb6-9300-b8928308128e',
        'transactionId': '7cf07d99-aa8b-486c-acbd-213aa678fecc',
        'accountId': '1a950e91-e9f7-4342-9e4a-0bd77af43f65',
        'amount': 100,
        'type': 'credit',
        'reconciledAt': null,
        'createdAt': 1783622964000,
      },
    ],
  });

  test('restoreJson survives close + reopen on a file-backed database',
      () async {
    final dbFile = File(p.join(tempDir.path, 'bestfin.sqlite'));

    // Instância "B" (a que existe durante o onboarding): restaura o backup.
    final dbB = AppDatabase.forTesting(NativeDatabase(dbFile));
    await ImportDataUseCase(dbB).restoreJson(backupJson());
    await dbB.close();

    // Instância "C" (criada após invalidate): deve ver os dados restaurados.
    final dbC = AppDatabase.forTesting(NativeDatabase(dbFile));
    final accounts = await dbC.select(dbC.accounts).get();
    final transactions = await dbC.select(dbC.transactions).get();
    final entries = await dbC.select(dbC.entries).get();

    expect(accounts.map((a) => a.name), ['BB']);
    expect(transactions, hasLength(1));
    expect(entries, hasLength(1));
    await dbC.close();
  });

  test(
      'restoreJson persists even when a stale connection is still open '
      '(clear-all does not await the old close)', () async {
    final dbFile = File(p.join(tempDir.path, 'bestfin.sqlite'));

    // Instância "A" antiga, ainda aberta (close do clear-all não é aguardado).
    final dbA = AppDatabase.forTesting(NativeDatabase(dbFile));
    await dbA.select(dbA.accounts).get(); // força a abertura real do arquivo

    final dbB = AppDatabase.forTesting(NativeDatabase(dbFile));
    await ImportDataUseCase(dbB).restoreJson(backupJson());
    await dbB.close();

    final dbC = AppDatabase.forTesting(NativeDatabase(dbFile));
    final accounts = await dbC.select(dbC.accounts).get();
    expect(accounts.map((a) => a.name), ['BB']);

    await dbA.close();
    await dbC.close();
  });
}
