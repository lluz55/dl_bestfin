import 'package:flutter_test/flutter_test.dart';
import 'package:bestfin/core/constants/transaction_types.dart';
import 'package:bestfin/features/transactions/domain/models/entry.dart';
import 'package:bestfin/features/transactions/domain/models/transaction.dart';
import 'package:bestfin/features/transactions/domain/usecases/predict_category.dart';

void main() {
  final now = DateTime(2026, 6, 30);

  TransactionModel tx({
    required String id,
    required DateTime date,
    required String description,
    required int amount,
    required String categoryId,
    String accountId = 'acc-1',
    String? entityId,
    TransactionType type = TransactionType.expense,
    bool isCompleted = true,
    bool isConfirmed = true,
  }) {
    return TransactionModel(
      id: id,
      date: date,
      description: description,
      type: type,
      categoryId: categoryId,
      entityId: entityId,
      isCompleted: isCompleted,
      isConfirmed: isConfirmed,
      createdAt: date,
      updatedAt: date,
      entries: [
        EntryModel(
          id: '$id-e',
          transactionId: id,
          accountId: accountId,
          amount: amount,
          type: type == TransactionType.income ? 'debit' : 'credit',
          createdAt: date,
        ),
      ],
    );
  }

  group('predictCategory', () {
    test('retorna null sem histórico', () {
      expect(
        predictCategory(const [], type: TransactionType.expense, now: now),
        isNull,
      );
    });

    test('retorna null para transferência', () {
      final history = [
        tx(
          id: '1',
          date: now,
          description: 'x',
          amount: 100,
          categoryId: 'cat-food',
        ),
      ];
      expect(
        predictCategory(history, type: TransactionType.transfer, now: now),
        isNull,
      );
    });

    test('sem sinal de entidade/descrição, usa a categoria mais frequente', () {
      final history = [
        tx(
          id: '1',
          date: now,
          description: 'a',
          amount: 100,
          categoryId: 'food',
        ),
        tx(
          id: '2',
          date: now,
          description: 'b',
          amount: 100,
          categoryId: 'food',
        ),
        tx(
          id: '3',
          date: now,
          description: 'c',
          amount: 100,
          categoryId: 'transport',
        ),
      ];
      expect(
        predictCategory(history, type: TransactionType.expense, now: now),
        'food',
      );
    });

    test('entidade conhecida vence a frequência geral', () {
      final history = [
        // "food" é mais frequente no geral...
        tx(
          id: '1',
          date: now,
          description: 'a',
          amount: 100,
          categoryId: 'food',
        ),
        tx(
          id: '2',
          date: now,
          description: 'b',
          amount: 100,
          categoryId: 'food',
        ),
        tx(
          id: '3',
          date: now,
          description: 'c',
          amount: 100,
          categoryId: 'food',
        ),
        // ...mas a entidade e-42 sempre foi "pets".
        tx(
          id: '4',
          date: now,
          description: 'petshop',
          amount: 100,
          categoryId: 'pets',
          entityId: 'e-42',
        ),
      ];
      expect(
        predictCategory(
          history,
          type: TransactionType.expense,
          entityId: 'e-42',
          now: now,
        ),
        'pets',
      );
    });

    test('descrição idêntica é usada quando não há sinal de entidade', () {
      final history = [
        tx(
          id: '1',
          date: now,
          description: 'a',
          amount: 100,
          categoryId: 'food',
        ),
        tx(
          id: '2',
          date: now,
          description: 'a',
          amount: 100,
          categoryId: 'food',
        ),
        tx(
          id: '3',
          date: now,
          description: 'Conta de luz',
          amount: 100,
          categoryId: 'utilities',
        ),
      ];
      expect(
        predictCategory(
          history,
          type: TransactionType.expense,
          description: '  conta de LUZ ',
          now: now,
        ),
        'utilities',
      );
    });

    test('ignora transações pendentes/não confirmadas', () {
      final history = [
        tx(
          id: '1',
          date: now,
          description: 'a',
          amount: 100,
          categoryId: 'pending-only',
          isCompleted: false,
        ),
        tx(
          id: '2',
          date: now,
          description: 'b',
          amount: 100,
          categoryId: 'unconfirmed-only',
          isConfirmed: false,
        ),
      ];
      expect(
        predictCategory(history, type: TransactionType.expense, now: now),
        isNull,
      );
    });

    test('só considera o tipo pedido', () {
      final history = [
        tx(
          id: '1',
          date: now,
          description: 'salário',
          amount: 100,
          categoryId: 'salary',
          type: TransactionType.income,
        ),
      ];
      expect(
        predictCategory(history, type: TransactionType.expense, now: now),
        isNull,
      );
      expect(
        predictCategory(history, type: TransactionType.income, now: now),
        'salary',
      );
    });
  });

  group('predictCategory — casamento por n-gramas (Task 62)', () {
    test('casa por sobreposição de tokens, não exige string idêntica', () {
      final history = [
        tx(
          id: '1',
          date: now,
          description: 'Supermercado Extra 1234',
          amount: 100,
          categoryId: 'groceries',
        ),
        tx(
          id: '2',
          date: now,
          description: 'Uber viagem centro',
          amount: 100,
          categoryId: 'transport',
        ),
      ];
      // Ordem e sufixo diferentes do treino — casamento exato falharia.
      expect(
        predictCategory(
          history,
          type: TransactionType.expense,
          description: 'Extra Supermercado',
          now: now,
        ),
        'groceries',
      );
    });

    test('normaliza acentos e caixa', () {
      final history = [
        tx(
          id: '1',
          date: now,
          description: 'Farmácia Drogasil',
          amount: 100,
          categoryId: 'health',
        ),
        tx(
          id: '2',
          date: now,
          description: 'Padaria Central',
          amount: 100,
          categoryId: 'food',
        ),
      ];
      expect(
        predictCategory(
          history,
          type: TransactionType.expense,
          description: 'FARMACIA drogasil',
          now: now,
        ),
        'health',
      );
    });

    test('ignora stopwords e ruído de meio de pagamento', () {
      // "conta de luz" e "conta de agua" compartilham só stopwords + "conta";
      // o token discriminante ("luz") é que decide.
      final history = [
        tx(
          id: '1',
          date: now,
          description: 'Conta de Luz Enel',
          amount: 100,
          categoryId: 'utilities-luz',
        ),
        tx(
          id: '2',
          date: now,
          description: 'Pix para João mercado',
          amount: 100,
          categoryId: 'groceries',
        ),
      ];
      expect(
        predictCategory(
          history,
          type: TransactionType.expense,
          description: 'pagamento conta luz',
          now: now,
        ),
        'utilities-luz',
      );
    });

    test('feedback loop: correções recentes dominam o histórico antigo', () {
      final history = <TransactionModel>[
        // 8 lançamentos antigos de "mercado pao" rotulados como 'food'.
        for (int i = 0; i < 8; i++)
          tx(
            id: 'old$i',
            date: now.subtract(const Duration(days: 150)),
            description: 'Mercado Pao de Acucar',
            amount: 5000,
            categoryId: 'food',
          ),
        // 2 correções recentes: o usuário passou a classificar como 'groceries'.
        tx(
          id: 'new1',
          date: now,
          description: 'Mercado Pao de Acucar',
          amount: 5000,
          categoryId: 'groceries',
        ),
        tx(
          id: 'new2',
          date: now.subtract(const Duration(days: 1)),
          description: 'Mercado Pao de Acucar',
          amount: 5000,
          categoryId: 'groceries',
        ),
      ];
      expect(
        predictCategory(
          history,
          type: TransactionType.expense,
          description: 'Mercado Pao de Acucar',
          now: now,
        ),
        'groceries',
      );
    });

    test('valor próximo desempata entre casamentos de descrição iguais', () {
      // Duas categorias com a mesma descrição e mesma recência; o valor da
      // consulta (≈ 20000) aproxima 'assinatura', desempatando.
      final history = [
        tx(
          id: '1',
          date: now,
          description: 'Loja Online',
          amount: 500, // muito menor
          categoryId: 'avulso',
        ),
        tx(
          id: '2',
          date: now,
          description: 'Loja Online',
          amount: 20000, // próximo da consulta
          categoryId: 'assinatura',
        ),
      ];
      expect(
        predictCategory(
          history,
          type: TransactionType.expense,
          description: 'Loja Online',
          amountInCents: 20500,
          now: now,
        ),
        'assinatura',
      );
    });
  });
}
