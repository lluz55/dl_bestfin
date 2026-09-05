import 'package:bestfin/cli/nl_parser.dart';
import 'package:bestfin/core/constants/transaction_types.dart';
import 'package:bestfin/core/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

Account _acc(String id, String name) => Account(
  id: id,
  name: name,
  type: 'checking',
  isArchived: false,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

Category _cat(String id, String name, String type) => Category(
  id: id,
  name: name,
  icon: 'icon',
  color: '#fff',
  type: type,
  isSystem: false,
  isArchived: false,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  final accounts = [
    _acc('acc1', 'Carteira'),
    _acc('acc2', 'Banco do Brasil'),
    _acc('acc3', 'Cartão Nubank'),
  ];
  final categories = [
    _cat('cat_food', 'Alimentação', 'expense'),
    _cat('cat_salary', 'Salário', 'income'),
    _cat('cat_transport', 'Transporte', 'expense'),
    _cat('cat_market', 'Mercado', 'expense'),
  ];

  group('NlParser', () {
    test('despesa simples "mercado 50 no cartão"', () {
      final p = NlParser(accounts: accounts, categories: categories);
      final r = p.parse('mercado 50 no cartão');
      expect(r.amountCents, 5000);
      expect(r.type, TransactionType.expense);
      // categoria Mercado deve ser detectada
      expect(r.categoryId, 'cat_market');
    });

    test('receita "recebi 3000 de salário na conta corrente"', () {
      final accs = [_acc('acc2', 'Conta Corrente')];
      final p = NlParser(accounts: accs, categories: categories);
      final r = p.parse('recebi 3000 de salário na conta corrente');
      expect(r.amountCents, 300000);
      expect(r.type, TransactionType.income);
      expect(r.categoryId, 'cat_salary');
    });

    test('transferência "pix 100 da carteira para banco"', () {
      final p = NlParser(accounts: accounts, categories: categories);
      final r = p.parse('pix 100 da carteira para banco do brasil');
      expect(r.amountCents, 10000);
      expect(r.type, TransactionType.transfer);
      expect(r.accountId, 'acc1');
      expect(r.toAccountId, 'acc2');
    });

    test('valor com R\$ e vírgula', () {
      final p = NlParser(accounts: accounts, categories: categories);
      final r = p.parse('gastei R\$ 1.500,50 no mercado');
      expect(r.amountCents, 150050);
    });

    test('texto ambíguo sem valor', () {
      final p = NlParser(accounts: accounts, categories: categories);
      final r = p.parse('mercado');
      expect(r.amountCents, isNull);
      expect(r.confidences['amount'], isNotNull);
    });

    test('transferência com seta', () {
      final p = NlParser(accounts: accounts, categories: categories);
      final r = p.parse('100 carteira -> banco do brasil');
      expect(r.type, TransactionType.transfer);
      expect(r.amountCents, 10000);
    });
  });
}
