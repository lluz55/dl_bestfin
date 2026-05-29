import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bestfin/core/database/app_database.dart';
import 'package:bestfin/features/backup/domain/usecases/import_data.dart';

void main() {
  late AppDatabase db;
  late ImportDataUseCase importData;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    importData = ImportDataUseCase(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('CSV Import Tests', () {
    test('previewCsv detects layout and row counts correctly', () async {
      const csvStr =
          'ID;Data;Descrição;Tipo;Valor;Categoria;Conta Origem\r\n'
          '1;25/05/2026;Almoço Executivo;expense;-25,50;Alimentação;Carteira\r\n'
          '2;26/05/2026;Salário;income;3500,00;Receitas;Banco\r\n';

      final preview = await importData.previewCsv(csvStr);
      expect(preview['type'], 'csv');
      expect(preview['total_rows'], 2);
      expect(preview['valid_rows'], 2);
    });

    test(
      'previewCsv throws FormatException when essential columns are missing',
      () async {
        const badCsv = 'ID;Nome;Preço\r\n1;Almoço;25\r\n';
        expect(
          () => importData.previewCsv(badCsv),
          throwsA(isA<FormatException>()),
        );
      },
    );

    test(
      'importCsv inserts transactions, auto-creates accounts and categories, and builds double entry balances',
      () async {
        const csvStr =
            'Data;Descrição;Tipo;Valor;Categoria;Conta Origem;Conta Destino\r\n'
            '25/05/2026;Almoço Executivo;expense;-25,50;Refeição;Dinheiro;\r\n'
            '26/05/2026;Transferência Interna;transfer;100.00;;Dinheiro;Conta Corrente\r\n';

        final importedCount = await importData.importCsv(
          csvStr,
          separator: ';',
        );
        expect(importedCount, 2);

        final categories = await db.select(db.categories).get();
        expect(categories.any((c) => c.name == 'Refeição'), isTrue);

        final accounts = await db.select(db.accounts).get();
        expect(accounts.any((a) => a.name == 'Dinheiro'), isTrue);
        expect(accounts.any((a) => a.name == 'Conta Corrente'), isTrue);

        final txs = await db.select(db.transactions).get();
        expect(txs.length, 2);
        expect(txs.first.description, 'Almoço Executivo');
        expect(txs.first.type, 'expense');

        final dinheiroAcc = accounts.firstWhere((a) => a.name == 'Dinheiro');
        final contaCorrenteAcc = accounts.firstWhere(
          (a) => a.name == 'Conta Corrente',
        );

        final dinheiroBalance = await db.accountsDao
            .watchAccountBalance(dinheiroAcc.id)
            .first;
        final ccBalance = await db.accountsDao
            .watchAccountBalance(contaCorrenteAcc.id)
            .first;

        // In BestFin double entry account balance logic:
        // Credit increases the numeric value, Debit decreases the numeric value.
        // 1. Expense creates credit entry (amount = 2550). dinero balance increases by 2550
        // 2. Transfer from dinheiro to CC: credit dinheiro 10000, debit CC 10000.
        // Total dinheiro balance: -2550 - 10000 = -12550
        // Total CC balance: 10000 (debit)
        expect(dinheiroBalance, -12550);
        expect(ccBalance, 10000);
      },
    );
  });

  group('JSON Restore Tests', () {
    test('previewJson validates metadata correctly', () async {
      final validJson = json.encode({
        'version': 1,
        'exported_at': '2026-05-28T12:00:00Z',
        'accounts': [
          {
            'id': 'acc_1',
            'name': 'CC',
            'type': 'checking',
            'color': '#FFFFFF',
            'isArchived': false,
            'createdAt': '2026-05-28T12:00:00Z',
            'updatedAt': '2026-05-28T12:00:00Z',
          },
        ],
      });

      final preview = await importData.previewJson(validJson);
      expect(preview['type'], 'json');
      expect(preview['version'], 1);
      expect(preview['counts']['accounts'], 1);
    });

    test(
      'restoreJson purges current database and restores structure in order',
      () async {
        await db.accountsDao.insertAccount(
          AccountsCompanion.insert(
            id: 'old_acc',
            name: 'Velha Conta',
            type: 'checking',
          ),
        );

        final mockBackup = json.encode({
          'version': 1,
          'exported_at': '2026-05-28T12:00:00Z',
          'app_settings': [],
          'categories': [
            {
              'id': 'cat_comida',
              'name': 'Comida',
              'icon': 'food',
              'color': '#FF5722',
              'type': 'expense',
              'isSystem': false,
              'isArchived': false,
              'createdAt': '2026-05-28T12:00:00Z',
              'updatedAt': '2026-05-28T12:00:00Z',
            },
          ],
          'accounts': [
            {
              'id': 'new_acc',
              'name': 'Nova Conta',
              'type': 'checking',
              'color': '#00FF00',
              'isArchived': false,
              'createdAt': '2026-05-28T12:00:00Z',
              'updatedAt': '2026-05-28T12:00:00Z',
            },
          ],
          'entities': [],
          'holidays': [],
          'notification_patterns': [],
          'goals': [],
          'installment_plans': [],
          'recurring_rules': [],
          'financings': [],
          'financing_installments': [],
          'investments': [],
          'credit_cards': [],
          'invoices': [],
          'transactions': [],
          'entries': [],
          'attachments': [],
        });

        await importData.restoreJson(mockBackup);

        final restoredAccounts = await db.select(db.accounts).get();
        expect(restoredAccounts.length, 1);
        expect(restoredAccounts.first.id, 'new_acc');
        expect(restoredAccounts.first.name, 'Nova Conta');

        final restoredCategories = await db.select(db.categories).get();
        expect(restoredCategories.any((c) => c.id == 'cat_comida'), isTrue);
      },
    );
  });
}
