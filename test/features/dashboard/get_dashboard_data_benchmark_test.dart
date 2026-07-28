@Tags(['benchmark'])
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:bestfin/core/constants/account_types.dart';
import 'package:bestfin/core/constants/transaction_types.dart';
import 'package:bestfin/features/accounts/domain/models/account.dart';
import 'package:bestfin/features/dashboard/domain/usecases/get_dashboard_data.dart';
import 'package:bestfin/features/transactions/domain/models/entry.dart';
import 'package:bestfin/features/transactions/domain/models/transaction.dart';

/// Baseline de performance para a Task 59.
///
/// Mede o custo de [GetDashboardData.aggregate] — a função pura que reprocessa
/// TODO o histórico de transações a cada gravação — em função do volume de
/// transações. O objetivo é gerar números concretos para decidir se a
/// materialização incremental (tabela de agregados) se justifica.
///
/// Rodar isolado (não roda no `flutter test` padrão por causa da tag):
///   nix develop -c flutter test --tags benchmark \
///     test/features/dashboard/get_dashboard_data_benchmark_test.dart
void main() {
  // Dataset sintético determinístico: transações espalhadas ao longo de ~5 anos,
  // metade receita / metade despesa, com categorias variadas e ~10% pendentes.
  List<TransactionModel> makeTransactions(int n) {
    final now = DateTime.now();
    final txs = <TransactionModel>[];
    for (int i = 0; i < n; i++) {
      // Espalha as datas: até ~1825 dias no passado (5 anos).
      final date = now.subtract(Duration(days: (i * 37) % 1825));
      final isIncome = i.isEven;
      final amount = 1000 + (i % 500) * 13;
      txs.add(
        TransactionModel(
          id: 'tx_$i',
          date: date,
          description: 'tx $i',
          type: isIncome ? TransactionType.income : TransactionType.expense,
          categoryId: 'cat_${i % 12}',
          isCompleted: i % 10 != 0, // ~10% pendentes
          createdAt: date,
          updatedAt: date,
          entries: [
            EntryModel(
              id: 'e_$i',
              transactionId: 'tx_$i',
              accountId: 'acc_${i % 3}',
              amount: amount,
              type: isIncome ? 'debit' : 'credit',
              createdAt: date,
            ),
          ],
        ),
      );
    }
    // watchAllTransactions entrega por data desc; espelhamos isso aqui.
    txs.sort((a, b) => b.date.compareTo(a.date));
    return txs;
  }

  final accounts = List.generate(
    3,
    (i) => Account(
      id: 'acc_$i',
      name: 'Conta $i',
      type: AccountType.checking,
      icon: '0',
      color: '000000',
      isActive: true,
      balance: 100000 * (i + 1),
    ),
  );

  // periodIndex 4 = "Ano": janela curta de agregação, mas ainda varre todo o
  // histórico. É o caso realista da carga inicial do dashboard.
  const periodIndex = 4;

  double measureMillis(List<TransactionModel> txs) {
    // Warmup (JIT/inlining) antes de medir.
    for (int i = 0; i < 3; i++) {
      GetDashboardData.aggregate(txs, accounts, const [], periodIndex: periodIndex);
    }
    const iterations = 20;
    final sw = Stopwatch()..start();
    for (int i = 0; i < iterations; i++) {
      GetDashboardData.aggregate(txs, accounts, const [], periodIndex: periodIndex);
    }
    sw.stop();
    return sw.elapsedMicroseconds / iterations / 1000.0;
  }

  test('baseline: custo de aggregate() por volume de transações', () {
    const sizes = [100, 1000, 5000, 10000, 25000, 50000];
    final results = <int, double>{};
    for (final n in sizes) {
      final txs = makeTransactions(n);
      results[n] = measureMillis(txs);
    }

    // ignore: avoid_print
    print('\n=== Baseline aggregate() — Task 59 ===');
    // ignore: avoid_print
    print('n transações | tempo médio/agregação (ms)');
    for (final n in sizes) {
      // ignore: avoid_print
      print('${n.toString().padLeft(12)} | ${results[n]!.toStringAsFixed(3)}');
    }
    // ignore: avoid_print
    print('(frame budget 60fps = 16.67ms; agregação roda em isolate via compute)\n');

    // Não é um teste de threshold — é uma sonda de baseline. Só garante que
    // rodou para todos os tamanhos.
    expect(results.length, sizes.length);
  });
}
