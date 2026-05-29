import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bestfin/core/database/app_database.dart';
import 'package:bestfin/features/backup/domain/usecases/export_csv.dart';
import 'package:uuid/uuid.dart';

void main() {
  late AppDatabase db;
  late ExportCsvUseCase exportCsv;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    exportCsv = ExportCsvUseCase(db);
  });

  tearDown(() async {
    await db.close();
  });

  test(
    'ExportCsvUseCase generates correct CSV content with UTF-8 BOM and dynamic formatting',
    () async {
      final accountId = const Uuid().v4();
      final catId = const Uuid().v4();

      // 1. Insert seed data
      await db.accountsDao.insertAccount(
        AccountsCompanion.insert(
          id: accountId,
          name: 'Carteira Principal',
          type: 'checking',
        ),
      );

      await db
          .into(db.categories)
          .insert(
            CategoriesCompanion.insert(
              id: catId,
              name: 'Alimentação',
              icon: 'restaurant',
              color: '#FF5722',
              type: 'expense',
            ),
          );

      final txId = const Uuid().v4();
      await db.transactionsDao.createTransaction(
        data: TransactionsCompanion.insert(
          id: txId,
          date: DateTime(2026, 5, 20),
          description: 'Supermercado Imperial',
          type: 'expense',
          categoryId: Value(catId),
          sentiment: const Value('neutral'),
        ),
        accountId: accountId,
        amount: 1250, // R$ 12.50
      );

      // 2. Test export with semicolon (Brazilian standard)
      final csvSemicolon = await exportCsv.execute(separator: ';');

      // BOM character
      expect(csvSemicolon.startsWith('\uFEFF'), isTrue);

      // Check headers
      expect(
        csvSemicolon.contains(
          'ID;Data;Descrição;Tipo;Valor;Categoria;Conta Origem;Conta Destino;Sentimento;Observações',
        ),
        isTrue,
      );

      // Check row contents
      expect(csvSemicolon.contains('Supermercado Imperial'), isTrue);
      expect(csvSemicolon.contains('Alimentação'), isTrue);
      expect(csvSemicolon.contains('Carteira Principal'), isTrue);

      // Brazilian comma decimal separator formatting
      expect(csvSemicolon.contains('-12,50'), isTrue);

      // 3. Test export with comma (International standard)
      final csvComma = await exportCsv.execute(separator: ',');
      expect(
        csvComma.contains(
          'ID,Data,Descrição,Tipo,Valor,Categoria,Conta Origem,Conta Destino,Sentimento,Observações',
        ),
        isTrue,
      );

      // International period decimal separator formatting
      expect(csvComma.contains('-12.50'), isTrue);
    },
  );

  test('ExportCsvUseCase applies date filters correctly', () async {
    final accountId = const Uuid().v4();

    await db.accountsDao.insertAccount(
      AccountsCompanion.insert(
        id: accountId,
        name: 'Checking',
        type: 'checking',
      ),
    );

    // Insert 3 transactions on different dates
    await db.transactionsDao.createTransaction(
      data: TransactionsCompanion.insert(
        id: const Uuid().v4(),
        date: DateTime(2026, 5, 10),
        description: 'Transacao Antiga',
        type: 'expense',
      ),
      accountId: accountId,
      amount: 1000,
    );

    await db.transactionsDao.createTransaction(
      data: TransactionsCompanion.insert(
        id: const Uuid().v4(),
        date: DateTime(2026, 5, 15),
        description: 'Transacao Dentro',
        type: 'expense',
      ),
      accountId: accountId,
      amount: 2000,
    );

    await db.transactionsDao.createTransaction(
      data: TransactionsCompanion.insert(
        id: const Uuid().v4(),
        date: DateTime(2026, 5, 20),
        description: 'Transacao Recente',
        type: 'expense',
      ),
      accountId: accountId,
      amount: 3000,
    );

    // Export with filters [May 12, May 18] -> should only contain "Transacao Dentro"
    final filteredCsv = await exportCsv.execute(
      startDate: DateTime(2026, 5, 12),
      endDate: DateTime(2026, 5, 18),
    );

    expect(filteredCsv.contains('Transacao Dentro'), isTrue);
    expect(filteredCsv.contains('Transacao Antiga'), isFalse);
    expect(filteredCsv.contains('Transacao Recente'), isFalse);
  });
}
