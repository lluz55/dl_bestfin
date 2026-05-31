import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:bestfin/core/database/database_provider.dart';
import 'package:bestfin/features/accounts/presentation/providers/accounts_provider.dart';
import 'package:bestfin/features/categories/presentation/providers/categories_provider.dart';
import 'package:bestfin/features/goals/presentation/providers/goals_provider.dart';
import 'package:bestfin/features/recurring/presentation/providers/recurring_provider.dart';
import 'package:bestfin/features/llm/domain/services/math_evaluator.dart';
import 'package:drift/drift.dart';

class ParsedToolCall {
  final String toolName;
  final String rawMatch;
  final String argument;

  const ParsedToolCall({
    required this.toolName,
    required this.rawMatch,
    required this.argument,
  });
}

class LlmToolsService {
  // Accepts both [TOOL: arg] and [TOOL(arg)] variants from the model.
  // The \)?  strips a trailing ) if the model closed its own paren before ].
  static final RegExp _toolRegex = RegExp(
    r'\[(CALCULATE|LOOKUP_USER_DATA|GET_GOALS|GET_RECURRING|GET_SPENDING_SUMMARY)[:(]\s*([\s\S]*?)\)?]',
  );

  // Converts key="value" or key=value to a JSON-like map when the model
  // outputs arguments without braces (e.g. action="list_accounts").
  static Map<String, dynamic> _parseKeyValue(String text) {
    final result = <String, dynamic>{};
    final re = RegExp(r'(\w+)\s*=\s*"?([^,"\)\]]*)"?');
    for (final m in re.allMatches(text)) {
      result[m.group(1)!] = m.group(2)!.trim();
    }
    return result;
  }

  static ParsedToolCall? parseFirst(String text) {
    final match = _toolRegex.firstMatch(text);
    if (match == null) return null;
    return ParsedToolCall(
      toolName: match.group(1)!,
      rawMatch: match.group(0)!,
      argument: match.group(2)!.trim(),
    );
  }

  static List<ParsedToolCall> parseAll(String text) {
    final List<ParsedToolCall> list = [];
    for (final match in _toolRegex.allMatches(text)) {
      list.add(
        ParsedToolCall(
          toolName: match.group(1)!,
          rawMatch: match.group(0)!,
          argument: match.group(2)!.trim(),
        ),
      );
    }
    return list;
  }

  static Future<String> execute(Ref ref, ParsedToolCall call) async {
    if (call.toolName == 'CALCULATE') {
      try {
        final result = MathEvaluator.evaluate(call.argument);
        final formatter = NumberFormat('#,##0.00', 'pt_BR');
        return 'Resultado do cálculo: R\$ ${formatter.format(result)}';
      } catch (e) {
        return 'Erro ao executar o cálculo: $e';
      }
    } else if (call.toolName == 'LOOKUP_USER_DATA') {
      try {
        final trimmed = call.argument.trim();
        final map = trimmed.startsWith('{')
            ? jsonDecode(trimmed) as Map<String, dynamic>
            : _parseKeyValue(trimmed);
        final action = map['action'] as String?;
        if (action == 'list_accounts') {
          return await _listAccounts(ref);
        } else if (action == 'list_categories') {
          return _listCategories(ref);
        } else if (action == 'search_transactions') {
          return await _searchTransactions(ref, map);
        } else {
          return 'Erro: Ação desconhecida "$action" para LOOKUP_USER_DATA';
        }
      } catch (e) {
        return 'Erro ao decodificar os argumentos do LOOKUP_USER_DATA (deve ser um JSON válido): $e';
      }
    } else if (call.toolName == 'GET_GOALS') {
      return await _getGoals(ref);
    } else if (call.toolName == 'GET_RECURRING') {
      return await _getRecurring(ref);
    } else if (call.toolName == 'GET_SPENDING_SUMMARY') {
      try {
        final trimmed = call.argument.trim();
        final map = trimmed.isEmpty || trimmed == '{}'
            ? <String, dynamic>{}
            : trimmed.startsWith('{')
                ? jsonDecode(trimmed) as Map<String, dynamic>
                : _parseKeyValue(trimmed);
        return await _getSpendingSummary(ref, map);
      } catch (e) {
        return 'Erro ao decodificar os argumentos do GET_SPENDING_SUMMARY: $e';
      }
    }
    return 'Erro: Ferramenta desconhecida "${call.toolName}"';
  }

  static Future<String> _listAccounts(Ref ref) async {
    final accounts = ref.read(activeAccountsProvider);
    if (accounts.isEmpty) {
      return 'Nenhuma conta ativa encontrada.';
    }
    final fmt = NumberFormat('#,##0.00', 'pt_BR');
    final buf = StringBuffer();
    buf.writeln('Contas ativas encontradas:');
    int total = 0;
    for (final acc in accounts) {
      buf.writeln(
        '- ${acc.name}: R\$ ${fmt.format(acc.balance / 100)} (${acc.type.label})',
      );
      total += acc.balance;
    }
    buf.writeln('Saldo total geral das contas: R\$ ${fmt.format(total / 100)}');
    return buf.toString();
  }

  static String _listCategories(Ref ref) {
    final categories = ref.read(allFlatCategoriesProvider);
    if (categories.isEmpty) {
      return 'Nenhuma categoria cadastrada encontrada.';
    }
    final buf = StringBuffer();
    buf.writeln('Categorias cadastradas:');
    for (final cat in categories) {
      buf.writeln('- ${cat.name} (${cat.type})');
    }
    return buf.toString();
  }

  static Future<String> _searchTransactions(
    Ref ref,
    Map<String, dynamic> params,
  ) async {
    final db = ref.read(databaseProvider);
    final fmt = NumberFormat('#,##0.00', 'pt_BR');

    final query = params['query'] as String?;
    final categoryName = params['category'] as String?;
    final startDateStr = params['start_date'] as String?;
    final endDateStr = params['end_date'] as String?;

    // Find category ID if categoryName is provided
    final List<String> matchedCategoryIds = [];
    if (categoryName != null && categoryName.isNotEmpty) {
      final cats = ref.read(allFlatCategoriesProvider);
      final searchLower = categoryName.toLowerCase();
      for (final cat in cats) {
        if (cat.name.toLowerCase().contains(searchLower)) {
          matchedCategoryIds.add(cat.id);
        }
      }
    }

    final txQuery = db.select(db.transactions).join([
      leftOuterJoin(
        db.categories,
        db.categories.id.equalsExp(db.transactions.categoryId),
      ),
      leftOuterJoin(
        db.entities,
        db.entities.id.equalsExp(db.transactions.entityId),
      ),
    ]);

    txQuery.where(db.transactions.isConfirmed.equals(true));

    if (query != null && query.isNotEmpty) {
      txQuery.where(
        db.transactions.description.like('%$query%') |
        db.entities.name.like('%$query%'),
      );
    }

    if (matchedCategoryIds.isNotEmpty) {
      txQuery.where(db.transactions.categoryId.isIn(matchedCategoryIds));
    } else if (categoryName != null && categoryName.isNotEmpty) {
      return 'Nenhuma categoria correspondente a "$categoryName" foi encontrada.';
    }

    if (startDateStr != null && startDateStr.isNotEmpty) {
      try {
        final date = DateTime.parse(startDateStr);
        txQuery.where(db.transactions.date.isBiggerOrEqualValue(date));
      } catch (_) {}
    }

    if (endDateStr != null && endDateStr.isNotEmpty) {
      try {
        final date = DateTime.parse(endDateStr);
        txQuery.where(db.transactions.date.isSmallerOrEqualValue(date));
      } catch (_) {}
    }

    txQuery.orderBy([
      OrderingTerm(expression: db.transactions.date, mode: OrderingMode.desc),
    ]);

    txQuery.limit(20);

    final rows = await txQuery.get();
    if (rows.isEmpty) {
      return 'Nenhuma transação confirmada foi encontrada com os filtros especificados.';
    }

    final buf = StringBuffer();
    buf.writeln('Resultados da busca de transações (máximo 20 mais recentes):');

    int sumIncome = 0;
    int sumExpense = 0;

    for (final row in rows) {
      final tx = row.readTable(db.transactions);
      final cat = row.readTableOrNull(db.categories);
      final entity = row.readTableOrNull(db.entities);

      final entries = await (db.select(
        db.entries,
      )..where((e) => e.transactionId.equals(tx.id))).get();

      final amount = entries.isNotEmpty
          ? entries.first.amount
          : (tx.rawAmount ?? 0);
      final dateStr = DateFormat('dd/MM/yyyy').format(tx.date);
      final typeLabel = tx.type == 'income'
          ? 'Receita'
          : (tx.type == 'expense' ? 'Despesa' : 'Transferência');
      final catName = cat?.name ?? 'Sem categoria';
      
      final entityName = entity?.name != null
          ? ' (${entity!.type == 'payee' ? 'Recebedor' : 'Pagador'}: ${entity.name})'
          : '';

      buf.writeln(
        '- $dateStr: R\$ ${fmt.format(amount / 100)} - "${tx.description}"$entityName [$catName] ($typeLabel)',
      );

      if (tx.type == 'income') {
        sumIncome += amount;
      } else if (tx.type == 'expense') {
        sumExpense += amount;
      }
    }

    buf.writeln('\nResumo dos resultados listados:');
    buf.writeln('- Soma total de Receitas: R\$ ${fmt.format(sumIncome / 100)}');
    buf.writeln(
      '- Soma total de Despesas: R\$ ${fmt.format(sumExpense / 100)}',
    );

    return buf.toString();
  }

  static Future<String> _getGoals(Ref ref) async {
    final fmt = NumberFormat('#,##0.00', 'pt_BR');
    final goalsAsync = ref.read(activeGoalsProvider);
    final goals = goalsAsync.value;
    if (goals == null || goals.isEmpty) {
      return 'Nenhuma meta financeira ativa encontrada.';
    }
    final buf = StringBuffer();
    buf.writeln('Metas financeiras ativas (${goals.length}):');
    for (final g in goals) {
      final pct = (g.progressFraction * 100).toStringAsFixed(1);
      final current = fmt.format(g.currentAmountInCents / 100);
      final target = fmt.format(g.targetAmountInCents / 100);
      final remaining = fmt.format(g.remainingInCents / 100);
      final dateStr = g.targetDate != null
          ? DateFormat('dd/MM/yyyy').format(g.targetDate!)
          : 'sem prazo';
      final monthsLeft = g.monthsRemaining;
      final monthlyNeeded = monthsLeft != null && monthsLeft > 0
          ? fmt.format(g.remainingInCents / 100 / monthsLeft)
          : null;
      buf.write('- "${g.name}": R\$ $current de R\$ $target ($pct%) — faltam R\$ $remaining');
      buf.write(' | Prazo: $dateStr');
      if (monthlyNeeded != null) buf.write(' | Necessário/mês: R\$ $monthlyNeeded');
      buf.write(g.isCompleted ? ' ✅ CONCLUÍDA' : '');
      buf.writeln();
    }
    return buf.toString();
  }

  static Future<String> _getRecurring(Ref ref) async {
    final fmt = NumberFormat('#,##0.00', 'pt_BR');
    final rulesAsync = ref.read(activeRecurringProvider);
    final rules = rulesAsync.value;
    if (rules == null || rules.isEmpty) {
      return 'Nenhuma transação recorrente ativa encontrada.';
    }
    final buf = StringBuffer();
    buf.writeln('Transações recorrentes ativas (${rules.length}):');
    for (final r in rules) {
      final desc = r.description ?? 'Sem descrição';
      final freq = r.frequency.label;
      final next = DateFormat('dd/MM/yyyy').format(r.nextDate);
      final amount = r.amountInCents != null
          ? 'R\$ ${fmt.format(r.amountInCents! / 100)}'
          : 'valor variável';
      buf.writeln('- "$desc": $amount — $freq — próxima: $next');
    }
    return buf.toString();
  }

  static Future<String> _getSpendingSummary(
    Ref ref,
    Map<String, dynamic> params,
  ) async {
    final db = ref.read(databaseProvider);
    final fmt = NumberFormat('#,##0.00', 'pt_BR');

    final startDateStr = params['start_date'] as String?;
    final endDateStr = params['end_date'] as String?;

    // Default: current month
    final now = DateTime.now();
    final start = startDateStr != null
        ? DateTime.tryParse(startDateStr) ?? DateTime(now.year, now.month, 1)
        : DateTime(now.year, now.month, 1);
    final end = endDateStr != null
        ? DateTime.tryParse(endDateStr) ?? DateTime(now.year, now.month + 1, 0)
        : DateTime(now.year, now.month + 1, 0);

    final txQuery = db.select(db.transactions).join([
      leftOuterJoin(
        db.categories,
        db.categories.id.equalsExp(db.transactions.categoryId),
      ),
      innerJoin(
        db.entries,
        db.entries.transactionId.equalsExp(db.transactions.id),
      ),
    ]);
    txQuery.where(db.transactions.isConfirmed.equals(true));
    txQuery.where(db.transactions.type.equals('expense'));
    txQuery.where(db.transactions.date.isBiggerOrEqualValue(start));
    txQuery.where(db.transactions.date.isSmallerOrEqualValue(end));

    final rows = await txQuery.get();

    final Map<String, int> categoryTotals = {};
    final Map<String, String> categoryNames = {};

    for (final row in rows) {
      final tx = row.readTable(db.transactions);
      final cat = row.readTableOrNull(db.categories);
      final entry = row.readTable(db.entries);

      final catId = tx.categoryId ?? 'sem_categoria';
      final catName = cat?.name ?? 'Sem categoria';
      categoryTotals[catId] = (categoryTotals[catId] ?? 0) + entry.amount;
      categoryNames[catId] = catName;
    }

    if (categoryTotals.isEmpty) {
      final startStr = DateFormat('dd/MM/yyyy').format(start);
      final endStr = DateFormat('dd/MM/yyyy').format(end);
      return 'Nenhuma despesa encontrada entre $startStr e $endStr.';
    }

    final sorted = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final total = sorted.fold(0, (sum, e) => sum + e.value);
    final startStr = DateFormat('dd/MM/yyyy').format(start);
    final endStr = DateFormat('dd/MM/yyyy').format(end);

    final buf = StringBuffer();
    buf.writeln('Resumo de gastos por categoria ($startStr a $endStr):');
    for (final entry in sorted) {
      final name = categoryNames[entry.key]!;
      final amount = fmt.format(entry.value / 100);
      final pct = (entry.value / total * 100).toStringAsFixed(1);
      buf.writeln('- $name: R\$ $amount ($pct%)');
    }
    buf.writeln('Total gasto no período: R\$ ${fmt.format(total / 100)}');
    return buf.toString();
  }
}
