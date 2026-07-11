import 'dart:async';
import 'package:flutter/foundation.dart' show compute;
import 'package:bestfin/features/accounts/data/repositories/account_repository.dart';
import 'package:bestfin/features/accounts/domain/models/account.dart';
import 'package:bestfin/features/categories/domain/models/category.dart';
import 'package:bestfin/features/dashboard/domain/models/dashboard_data.dart';
import 'package:bestfin/features/goals/data/repositories/goal_repository.dart';
import 'package:bestfin/features/goals/domain/models/goal.dart';
import 'package:bestfin/features/transactions/data/repositories/transaction_repository.dart';
import 'package:bestfin/features/transactions/domain/models/transaction.dart';
import 'package:bestfin/core/constants/transaction_types.dart';
import 'package:bestfin/core/constants/account_types.dart';
import 'package:bestfin/features/reports/domain/models/report_models.dart';

class GetDashboardData {
  final TransactionRepository transactionRepository;
  final AccountRepository accountRepository;
  final GoalRepository goalRepository;

  GetDashboardData({
    required this.transactionRepository,
    required this.accountRepository,
    required this.goalRepository,
  });

  static DateTime periodStart(int periodIndex) {
    final now = DateTime.now();
    switch (periodIndex) {
      case 1: // Semana
        final today = DateTime(now.year, now.month, now.day);
        return today.subtract(Duration(days: today.weekday - 1));
      case 2: // 3 meses
        return now.subtract(const Duration(days: 90));
      case 3: // 6 meses
        return now.subtract(const Duration(days: 180));
      case 4: // Ano
        return DateTime(now.year, 1, 1);
      default: // Este mês
        return DateTime(now.year, now.month, 1);
    }
  }

  Stream<DashboardData> call({int periodIndex = 0}) {
    final controller = StreamController<DashboardData>();
    StreamSubscription? subTx;
    StreamSubscription? subAcc;
    StreamSubscription? subGoals;

    List<TransactionModel>? lastTx;
    List<Account>? lastAcc;
    List<GoalModel>? lastGoals;

    Timer? debounceTimer;

    // A agregação reprocessa TODO o histórico de transações (várias passadas
    // O(n) + ordenações). Rodá-la em um isolate de fundo via [compute] evita
    // travar a thread da UI a cada gravação — a lógica em [aggregate] é pura,
    // então o resultado é idêntico ao cálculo síncrono.
    Future<void> flush() async {
      if (lastTx == null || lastAcc == null || lastGoals == null) return;
      try {
        final data = await compute(
          _aggregateDashboardData,
          _DashboardAggregateArgs(
            transactions: lastTx!,
            accounts: lastAcc!,
            activeGoals: lastGoals!,
            periodIndex: periodIndex,
          ),
        );
        if (!controller.isClosed) controller.add(data);
      } catch (e, stackTrace) {
        if (!controller.isClosed) controller.addError(e, stackTrace);
      }
    }

    void scheduleUpdate() {
      debounceTimer?.cancel();
      debounceTimer = Timer(const Duration(milliseconds: 300), flush);
    }

    subTx = transactionRepository.watchAllTransactions().listen(
      (txs) {
        lastTx = txs;
        scheduleUpdate();
      },
      onError: (err) {
        if (!controller.isClosed) controller.addError(err);
      },
    );

    subAcc = accountRepository.watchAllAccounts().listen(
      (accs) {
        lastAcc = accs;
        scheduleUpdate();
      },
      onError: (err) {
        if (!controller.isClosed) controller.addError(err);
      },
    );

    subGoals = goalRepository.watchActiveGoals().listen(
      (goals) {
        lastGoals = goals;
        scheduleUpdate();
      },
      onError: (err) {
        if (!controller.isClosed) controller.addError(err);
      },
    );

    controller.onCancel = () {
      debounceTimer?.cancel();
      subTx?.cancel();
      subAcc?.cancel();
      subGoals?.cancel();
    };

    return controller.stream;
  }

  static DashboardData aggregate(
    List<TransactionModel> transactions,
    List<Account> accounts,
    List<GoalModel> activeGoals, {
    int periodIndex = 0,
  }) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = periodStart(periodIndex);

    // ── Saldo total (todas as contas ativas) ──────────────────────────────────
    final totalBalance = accounts
        .where((a) => a.isActive)
        .fold<int>(0, (sum, acc) => sum + acc.balance);

    // ── Saldo líquido (contas de liquidez imediata) ───────────────────────────
    const liquidTypes = {
      AccountType.checking,
      AccountType.savings,
      AccountType.wallet,
      AccountType.reserve,
      AccountType.foodVoucher,
      AccountType.mealVoucher,
    };
    final liquidBalance = accounts
        .where((a) => a.isActive && liquidTypes.contains(a.type))
        .fold<int>(0, (sum, acc) => sum + acc.balance);

    // ── Transações completadas do período selecionado ─────────────────────────
    final currentMonthTransactions = transactions.where((tx) {
      return tx.isCompleted && !tx.date.isBefore(start);
    }).toList();

    final monthlyIncome = currentMonthTransactions
        .where((tx) => tx.type == TransactionType.income)
        .fold<int>(0, (sum, tx) => sum + tx.amount);

    final monthlyExpense = currentMonthTransactions
        .where((tx) => tx.type == TransactionType.expense)
        .fold<int>(0, (sum, tx) => sum + tx.amount);

    // ── Meta de poupança mensal dos objetivos ─────────────────────────────────
    final monthlyGoalTarget = activeGoals.fold<int>(
      0,
      (sum, g) => sum + (g.monthlyTargetInCents ?? 0),
    );

    // ── Livre para gastar ─────────────────────────────────────────────────────
    // O liquidBalance já reflete entradas de transações pendentes (sistema de
    // partida dobrada cria entries mesmo antes da confirmação). Por isso a
    // fórmula não subtrai pendingExpenses novamente para evitar double-counting.
    final freeToSpend = liquidBalance - monthlyGoalTarget;
    final freeToSpendPercentage = liquidBalance > 0
        ? (freeToSpend / liquidBalance).clamp(0.0, 1.0)
        : 0.0;

    // ── Próximos lançamentos (top 3, futuros, não completados) ────────────────
    final upcoming =
        transactions
            .where((tx) => !tx.isCompleted && !tx.date.isBefore(today))
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));
    final upcomingTransactions = upcoming.take(3).toList();

    // ── Agrupamento de despesas por categoria ─────────────────────────────────
    final expenseTransactions = currentMonthTransactions
        .where((tx) => tx.type == TransactionType.expense)
        .toList();

    final Map<String, _CategoryGroup> groupedExpenses = {};
    int totalExpenseForCategories = 0;

    for (final tx in expenseTransactions) {
      final catId = tx.categoryId ?? 'no_category';
      final currentGroup =
          groupedExpenses[catId] ??
          _CategoryGroup(category: tx.category, totalAmount: 0);
      groupedExpenses[catId] = currentGroup.copyWith(
        totalAmount: currentGroup.totalAmount + tx.amount,
      );
      totalExpenseForCategories += tx.amount;
    }

    final sortedGroups = groupedExpenses.values.toList()
      ..sort((a, b) => b.totalAmount.compareTo(a.totalAmount));

    final List<DashboardCategorySpending> categoryExpenses = [];

    if (sortedGroups.isNotEmpty) {
      if (sortedGroups.length <= 5) {
        for (final group in sortedGroups) {
          final percentage = totalExpenseForCategories > 0
              ? (group.totalAmount / totalExpenseForCategories)
              : 0.0;
          categoryExpenses.add(
            DashboardCategorySpending(
              category: group.category,
              amountInCents: group.totalAmount,
              percentage: percentage,
            ),
          );
        }
      } else {
        for (int i = 0; i < 4; i++) {
          final group = sortedGroups[i];
          final percentage = totalExpenseForCategories > 0
              ? (group.totalAmount / totalExpenseForCategories)
              : 0.0;
          categoryExpenses.add(
            DashboardCategorySpending(
              category: group.category,
              amountInCents: group.totalAmount,
              percentage: percentage,
            ),
          );
        }

        int otherAmount = 0;
        for (int i = 4; i < sortedGroups.length; i++) {
          otherAmount += sortedGroups[i].totalAmount;
        }

        final otherPercentage = totalExpenseForCategories > 0
            ? (otherAmount / totalExpenseForCategories)
            : 0.0;

        final virtualOtherCategory = CategoryModel(
          id: 'other_categories_summary',
          name: 'Outros',
          icon: 'more_horiz',
          color: '9E9E9E',
          type: 'expense',
          isSystem: true,
          isArchived: false,
          createdAt: now,
        );

        categoryExpenses.add(
          DashboardCategorySpending(
            category: virtualOtherCategory,
            amountInCents: otherAmount,
            percentage: otherPercentage,
          ),
        );
      }
    }

    // Últimas transações do período selecionado (já vêm ordenadas por data
    // desc de watchAllTransactions), limitadas às 10 mais recentes.
    final recentTransactions = transactions
        .where((tx) => !tx.date.isBefore(start))
        .take(10)
        .toList();

    // ── Monthly History (meses da janela do período selecionado) ──────────────
    final monthlyHistory = _calculateMonthlyHistory(transactions, now, start);

    // ── Cash Flow History (cumulative balance ao longo do período) ────────────
    final cashFlowHistory = _calculateCashFlowHistory(transactions, now, start);

    // ── Net Worth History (evolução patrimonial na janela do período) ─────────
    final netWorthHistory = _calculateNetWorthHistory(
      accounts,
      transactions,
      now,
      start,
    );

    // ── Category Ranking (all categories sorted by spending) ────────────────────
    final categoryRanking = _calculateCategoryRanking(transactions, start);

    return DashboardData(
      totalBalance: totalBalance,
      monthlyIncome: monthlyIncome,
      monthlyExpense: monthlyExpense,
      categoryExpenses: categoryExpenses,
      recentTransactions: recentTransactions,
      freeToSpendAmount: freeToSpend,
      freeToSpendPercentage: freeToSpendPercentage,
      upcomingTransactions: upcomingTransactions,
      activeGoals: activeGoals.take(3).toList(),
      monthlyHistory: monthlyHistory,
      netWorthHistory: netWorthHistory,
      cashFlowHistory: cashFlowHistory,
      categoryRanking: categoryRanking,
    );
  }

  /// Número de meses (>= 1) cobertos pela janela [start] → agora, usado para
  /// dimensionar os gráficos de histórico conforme o período selecionado.
  static int _monthsInWindow(DateTime start, DateTime now) {
    final startMonth = DateTime(start.year, start.month, 1);
    final count =
        (now.year - startMonth.year) * 12 + (now.month - startMonth.month) + 1;
    return count < 1 ? 1 : count;
  }

  static List<MonthlyBar> _calculateMonthlyHistory(
    List<TransactionModel> transactions,
    DateTime now,
    DateTime start,
  ) {
    final Map<String, MonthlyBar> monthlyMap = {};
    final months = _monthsInWindow(start, now);

    // Inicializa os meses da janela em ordem cronológica para garantir que
    // todos os meses do período estejam sempre representados.
    for (int i = 0; i < months; i++) {
      final date = DateTime(now.year, now.month - (months - 1 - i), 1);
      final key = '${date.year}-${date.month}';
      monthlyMap[key] = MonthlyBar(
        year: date.year,
        month: date.month,
        income: 0,
        expense: 0,
      );
    }

    final windowStart = DateTime(now.year, now.month - (months - 1), 1);

    // A agregação por chave de mês independe da ordem de iteração — sortear
    // o histórico inteiro aqui custaria O(n log n) sobre TODAS as transações
    // do usuário a cada save, só para descartar tudo fora da janela.
    for (final tx in transactions) {
      if (tx.date.isBefore(windowStart)) continue;
      final key = '${tx.date.year}-${tx.date.month}';
      final existing = monthlyMap[key];
      if (existing != null) {
        if (tx.type == TransactionType.income) {
          monthlyMap[key] = MonthlyBar(
            year: tx.date.year,
            month: tx.date.month,
            income: tx.isCompleted
                ? existing.income + tx.amount
                : existing.income,
            expense: existing.expense,
            pendingIncome: tx.isCompleted
                ? existing.pendingIncome
                : existing.pendingIncome + tx.amount,
            pendingExpense: existing.pendingExpense,
          );
        } else if (tx.type == TransactionType.expense) {
          monthlyMap[key] = MonthlyBar(
            year: tx.date.year,
            month: tx.date.month,
            income: existing.income,
            expense: tx.isCompleted
                ? existing.expense + tx.amount
                : existing.expense,
            pendingIncome: existing.pendingIncome,
            pendingExpense: tx.isCompleted
                ? existing.pendingExpense
                : existing.pendingExpense + tx.amount,
          );
        }
      }
    }

    final bars = monthlyMap.values.toList()
      ..sort((a, b) {
        final aKey = a.year * 100 + a.month;
        final bKey = b.year * 100 + b.month;
        return aKey.compareTo(bKey);
      });

    return bars;
  }

  static List<CashFlowPoint> _calculateCashFlowHistory(
    List<TransactionModel> transactions,
    DateTime now,
    DateTime windowStart,
  ) {
    // Particiona antes de ordenar: o saldo acumulado anterior à janela é uma
    // soma simples (não depende de ordem), então só a janela do período
    // precisa ser ordenada — o custo deixa de crescer com o histórico total.
    int cumulative = 0;
    final filtered = <TransactionModel>[];
    for (final tx in transactions) {
      if (!tx.isCompleted) continue;
      if (tx.date.isBefore(windowStart)) {
        if (tx.type == TransactionType.income) {
          cumulative += tx.amount;
        } else if (tx.type == TransactionType.expense) {
          cumulative -= tx.amount;
        }
      } else {
        filtered.add(tx);
      }
    }
    filtered.sort((a, b) => a.date.compareTo(b.date));

    final Map<String, CashFlowPoint> pointsMap = {};

    // Add a baseline starting point at the beginning of the selected window
    pointsMap['start'] = CashFlowPoint(
      date: windowStart,
      income: 0,
      expense: 0,
      cumulativeBalance: cumulative,
    );

    for (final tx in filtered) {
      if (tx.type == TransactionType.income) {
        cumulative += tx.amount;
      } else {
        cumulative -= tx.amount;
      }
      final key = '${tx.date.year}-${tx.date.month}-${tx.date.day}';
      pointsMap[key] = CashFlowPoint(
        date: tx.date,
        income: tx.type == TransactionType.income ? tx.amount : 0,
        expense: tx.type == TransactionType.expense ? tx.amount : 0,
        cumulativeBalance: cumulative,
      );
    }

    // Ensure we have an endpoint at the current date
    final nowKey = '${now.year}-${now.month}-${now.day}';
    if (!pointsMap.containsKey(nowKey)) {
      pointsMap[nowKey] = CashFlowPoint(
        date: now,
        income: 0,
        expense: 0,
        cumulativeBalance: cumulative,
      );
    }

    // Merge in "previsto" (pending/future) income and expense per day —
    // additive layer only, cumulativeBalance stays confirmed-only to match
    // the fix in CalculateCashFlowProjection (see getConfirmedBalance).
    final Map<String, ({int income, int expense})> pendingByDay = {};
    for (final tx in transactions) {
      if (tx.isCompleted) continue;
      if (tx.date.isBefore(windowStart)) continue;
      final key = '${tx.date.year}-${tx.date.month}-${tx.date.day}';
      final existing = pendingByDay[key] ?? (income: 0, expense: 0);
      pendingByDay[key] = (
        income:
            existing.income +
            (tx.type == TransactionType.income ? tx.amount : 0),
        expense:
            existing.expense +
            (tx.type == TransactionType.expense ? tx.amount : 0),
      );
    }

    for (final entry in pendingByDay.entries) {
      final existingPoint = pointsMap[entry.key];
      if (existingPoint != null) {
        pointsMap[entry.key] = CashFlowPoint(
          date: existingPoint.date,
          income: existingPoint.income,
          expense: existingPoint.expense,
          cumulativeBalance: existingPoint.cumulativeBalance,
          pendingIncome: entry.value.income,
          pendingExpense: entry.value.expense,
        );
      }
    }

    final points = pointsMap.values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    return points;
  }

  static List<NetWorthPoint> _calculateNetWorthHistory(
    List<Account> accounts,
    List<TransactionModel> transactions,
    DateTime now,
    DateTime start,
  ) {
    const liquidTypes = {
      AccountType.checking,
      AccountType.savings,
      AccountType.wallet,
      AccountType.reserve,
      AccountType.foodVoucher,
      AccountType.mealVoucher,
    };

    // Calculate current liquid balance
    final currentNetWorth = accounts
        .where((a) => a.isActive && liquidTypes.contains(a.type))
        .fold<int>(0, (sum, acc) => sum + acc.balance);

    // Inicializa as chaves de mês da janela do período para garantir uma
    // linha do tempo completa mesmo em meses sem movimentação.
    final monthsCount = _monthsInWindow(start, now);
    final Map<String, int> monthlyNet = {};
    final List<String> orderedKeys = [];

    for (int i = 0; i < monthsCount; i++) {
      final d = DateTime(now.year, now.month - (monthsCount - 1 - i), 1);
      final key = '${d.year}-${d.month}';
      monthlyNet[key] = 0;
      orderedKeys.add(key);
    }

    // Agregação por chave de mês independe de ordem — evita sortear o
    // histórico inteiro (ver mesmo raciocínio em _calculateMonthlyHistory).
    // Aggregate monthly changes within the 6-month window
    for (final tx in transactions) {
      if (!tx.isCompleted) continue;
      if (tx.type == TransactionType.transfer) continue;
      final key = '${tx.date.year}-${tx.date.month}';
      if (!monthlyNet.containsKey(key)) continue;

      if (tx.type == TransactionType.income) {
        monthlyNet[key] = monthlyNet[key]! + tx.amount;
      } else if (tx.type == TransactionType.expense) {
        monthlyNet[key] = monthlyNet[key]! - tx.amount;
      }
    }

    // Deduct backwards to calculate historical monthly ending values
    final List<int> monthEndValues = List.filled(monthsCount, 0);
    monthEndValues[monthsCount - 1] = currentNetWorth;
    for (int i = monthsCount - 2; i >= 0; i--) {
      final futureKey = orderedKeys[i + 1];
      monthEndValues[i] = monthEndValues[i + 1] - (monthlyNet[futureKey] ?? 0);
    }

    final List<NetWorthPoint> points = [];
    for (int i = 0; i < orderedKeys.length; i++) {
      final parts = orderedKeys[i].split('-');
      points.add(
        NetWorthPoint(
          date: DateTime(int.parse(parts[0]), int.parse(parts[1])),
          netWorth: monthEndValues[i],
        ),
      );
    }

    return points;
  }

  static List<CategoryRankingItem> _calculateCategoryRanking(
    List<TransactionModel> transactions,
    DateTime start,
  ) {
    final expenseTx = transactions
        .where(
          (tx) =>
              tx.isCompleted &&
              tx.type == TransactionType.expense &&
              !tx.date.isBefore(start),
        )
        .toList();

    final Map<String, _CategoryGroup> grouped = {};
    int total = 0;

    for (final tx in expenseTx) {
      final catId = tx.categoryId ?? 'no_category';
      final current =
          grouped[catId] ??
          _CategoryGroup(category: tx.category, totalAmount: 0);
      grouped[catId] = current.copyWith(
        totalAmount: current.totalAmount + tx.amount,
      );
      total += tx.amount;
    }

    final sorted = grouped.values.toList()
      ..sort((a, b) => b.totalAmount.compareTo(a.totalAmount));

    return sorted.map((g) {
      final percentage = total > 0 ? (g.totalAmount / total) : 0.0;
      return CategoryRankingItem(
        category: g.category,
        amountInCents: g.totalAmount,
        percentage: percentage,
      );
    }).toList();
  }
}

/// Argumentos serializáveis passados ao isolate de fundo em [compute].
class _DashboardAggregateArgs {
  final List<TransactionModel> transactions;
  final List<Account> accounts;
  final List<GoalModel> activeGoals;
  final int periodIndex;

  const _DashboardAggregateArgs({
    required this.transactions,
    required this.accounts,
    required this.activeGoals,
    required this.periodIndex,
  });
}

/// Ponto de entrada do isolate: precisa ser uma função de nível de topo para
/// o [compute]. Delega para a lógica pura [GetDashboardData.aggregate].
DashboardData _aggregateDashboardData(_DashboardAggregateArgs args) {
  return GetDashboardData.aggregate(
    args.transactions,
    args.accounts,
    args.activeGoals,
    periodIndex: args.periodIndex,
  );
}

class _CategoryGroup {
  final CategoryModel? category;
  final int totalAmount;

  const _CategoryGroup({this.category, required this.totalAmount});

  _CategoryGroup copyWith({CategoryModel? category, int? totalAmount}) {
    return _CategoryGroup(
      category: category ?? this.category,
      totalAmount: totalAmount ?? this.totalAmount,
    );
  }
}
