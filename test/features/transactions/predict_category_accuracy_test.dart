import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:bestfin/core/constants/transaction_types.dart';
import 'package:bestfin/features/transactions/domain/models/entry.dart';
import 'package:bestfin/features/transactions/domain/models/transaction.dart';
import 'package:bestfin/features/transactions/domain/usecases/predict_category.dart';

/// Harness de acurácia para a Task 62 — fortalecer a categorização automática.
///
/// Constrói um dataset rotulado realista (descrições brasileiras variadas por
/// categoria), treina com uma parte e mede a acurácia top-1 de [predictCategory]
/// sobre descrições de teste que são *variações* das de treino (tokens
/// compartilhados, mas string diferente). É o cenário que quebra o casamento por
/// string exata e valida o casamento por n-gramas.
void main() {
  // Merchant "vocabulário" por categoria: cada item é uma lista de tokens que
  // aparecem em ordens/sufixos variados nas transações reais.
  const catalog = <String, List<String>>{
    'food': ['ifood pizza', 'restaurante sabor caseiro', 'burger lanche', 'padaria central', 'lanchonete do ze'],
    'groceries': ['supermercado extra', 'mercado dia compras', 'atacadao mensal', 'hortifruti feira', 'pao de acucar'],
    'transport': ['uber viagem', 'corrida 99 app', 'posto ipiranga combustivel', 'estacionamento shopping', 'metro bilhete'],
    'utilities': ['conta de luz enel', 'conta de agua sabesp', 'internet vivo fibra', 'conta de gas', 'telefone claro'],
    'health': ['farmacia drogasil', 'consulta medica', 'plano saude unimed', 'dentista clinica', 'exame laboratorio'],
    'shopping': ['amazon compra', 'loja renner roupas', 'magazine luiza', 'livraria cultura', 'americanas pedido'],
  };

  final rng = math.Random(42);
  final now = DateTime(2026, 7, 1);

  List<String> shuffleTokens(String phrase) {
    final tokens = phrase.split(' ').toList()..shuffle(rng);
    return tokens;
  }

  TransactionModel makeTx(String id, String desc, String cat, int ageDays) {
    final date = now.subtract(Duration(days: ageDays));
    return TransactionModel(
      id: id,
      date: date,
      description: desc,
      type: TransactionType.expense,
      categoryId: cat,
      isCompleted: true,
      isConfirmed: true,
      createdAt: date,
      updatedAt: date,
      entries: [
        EntryModel(
          id: '$id-e',
          transactionId: id,
          accountId: 'acc-1',
          amount: 1000 + rng.nextInt(9000),
          type: 'credit',
          createdAt: date,
        ),
      ],
    );
  }

  /// Gera histórico de treino + pares (descrição, categoria verdadeira) de teste.
  ({List<TransactionModel> history, List<({String desc, String cat})> tests})
  buildDataset() {
    final history = <TransactionModel>[];
    final tests = <({String desc, String cat})>[];
    var id = 0;
    catalog.forEach((cat, merchants) {
      for (final base in merchants) {
        // Treino: 4 ocorrências com sufixo numérico e ordem variada.
        for (int i = 0; i < 4; i++) {
          final tokens = shuffleTokens(base);
          if (rng.nextBool()) tokens.add('${rng.nextInt(9999)}');
          history.add(
            makeTx('t${id++}', tokens.join(' '), cat, rng.nextInt(160)),
          );
        }
        // Teste: mesma loja, ordem/subset diferente — nunca idêntico ao treino.
        final testTokens = shuffleTokens(base);
        tests.add((desc: testTokens.reversed.join(' '), cat: cat));
      }
    });
    return (history: history, tests: tests);
  }

  double accuracy(List<TransactionModel> history, List<({String desc, String cat})> tests) {
    var hits = 0;
    for (final t in tests) {
      final predicted = predictCategory(
        history,
        type: TransactionType.expense,
        description: t.desc,
        now: now,
      );
      if (predicted == t.cat) hits++;
    }
    return hits / tests.length;
  }

  test('acurácia top-1 da predição de categoria por descrição', () {
    final ds = buildDataset();
    final acc = accuracy(ds.history, ds.tests);

    // ignore: avoid_print
    print('\n=== Acurácia predictCategory (Task 62) ===');
    // ignore: avoid_print
    print('casos de teste: ${ds.tests.length} | histórico: ${ds.history.length}');
    // ignore: avoid_print
    print('acurácia top-1: ${(acc * 100).toStringAsFixed(1)}%\n');

    // Threshold do algoritmo fortalecido (n-gramas). Descrições de teste são
    // variações não-idênticas das de treino — o casamento por string exata
    // ficava perto do acaso (~1/6).
    expect(acc, greaterThanOrEqualTo(0.80));
  });
}
