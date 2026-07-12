import 'package:flutter/material.dart';
import 'package:bestfin/features/reports/domain/models/sankey_models.dart';
import 'package:bestfin/features/transactions/data/repositories/transaction_repository.dart';
import 'package:bestfin/core/constants/transaction_types.dart';

class GenerateSankeyReport {
  final TransactionRepository _repository;

  GenerateSankeyReport(this._repository);

  Stream<SankeyData> call({
    Color incomeColor = const Color(0xFF66BB6A),
    Color expenseColor = const Color(0xFFFF7043),
    Color merchantColor = const Color(0xFF78909C),
    required DateTime startDate,
    required DateTime endDate,
    List<String>? accountIds,
    List<String>? creditCardIds,
    int maxMerchants = 8,
  }) {
    return _repository
        .watchTransactionsWithFilters(
          accountIds: accountIds,
          creditCardIds: creditCardIds,
          startDate: startDate,
          endDate: endDate,
        )
        .map((transactions) {
          final completed = transactions
              .where(
                (tx) => tx.isCompleted && tx.type != TransactionType.transfer,
              )
              .toList();

          final Map<String, _Group> incomeGroups = {};
          for (final tx in completed) {
            if (tx.type != TransactionType.income) continue;
            final key = tx.categoryId ?? '_income_other';
            final g =
                incomeGroups[key] ??
                _Group(
                  tx.category?.displayName ?? 'Outras receitas',
                  tx.category?.color ?? '66BB6A',
                );
            incomeGroups[key] = g.add(tx.amount);
          }

          final Map<String, _Group> expenseGroups = {};
          for (final tx in completed) {
            if (tx.type != TransactionType.expense) continue;
            final key = tx.categoryId ?? '_exp_other';
            final g =
                expenseGroups[key] ??
                _Group(
                  tx.category?.displayName ?? 'Sem categoria',
                  tx.category?.color ?? '9E9E9E',
                );
            expenseGroups[key] = g.add(tx.amount);
          }

          final Map<String, _Merchant> merchantGroups = {};
          for (final tx in completed) {
            if (tx.type != TransactionType.expense) continue;
            if (tx.entityId == null) continue;
            final key = tx.entityId!;
            final m =
                merchantGroups[key] ??
                _Merchant(
                  tx.entity?.name ?? 'Desconhecido',
                  tx.categoryId ?? '_exp_other',
                );
            merchantGroups[key] = m.add(tx.amount);
          }

          if (expenseGroups.isEmpty) {
            return const SankeyData(nodes: [], links: []);
          }

          final topMerchants = merchantGroups.entries.toList()
            ..sort((a, b) => b.value.total.compareTo(a.value.total));
          final selectedMerchants = topMerchants.take(maxMerchants).toList();

          final nodes = <SankeyNode>[];
          final links = <SankeyLink>[];

          // Column 0: income sources (or synthetic node if none)
          if (incomeGroups.isNotEmpty) {
            for (final e in incomeGroups.entries) {
              nodes.add(
                SankeyNode(
                  id: 'inc_${e.key}',
                  label: e.value.name,
                  value: e.value.total,
                  color: _parseHex(e.value.colorHex, incomeColor),
                  column: 0,
                ),
              );
            }
          } else {
            final totalExp = expenseGroups.values.fold<int>(
              0,
              (s, g) => s + g.total,
            );
            nodes.add(
              SankeyNode(
                id: 'inc__all',
                label: 'Entradas',
                value: totalExp,
                color: incomeColor,
                column: 0,
              ),
            );
          }

          // Column 1: expense categories
          for (final e in expenseGroups.entries) {
            nodes.add(
              SankeyNode(
                id: 'cat_${e.key}',
                label: e.value.name,
                value: e.value.total,
                color: _parseHex(e.value.colorHex, expenseColor),
                column: 1,
              ),
            );
          }

          // Column 2: top merchants
          for (final e in selectedMerchants) {
            final catColor =
                expenseGroups[e.value.categoryId]?.colorHex ?? '9E9E9E';
            nodes.add(
              SankeyNode(
                id: 'mer_${e.key}',
                label: e.value.name,
                value: e.value.total,
                color: _parseHex(
                  catColor,
                  merchantColor,
                ).withValues(alpha: 0.75),
                column: 2,
              ),
            );
          }

          // Links: income → expense categories (proportional distribution)
          final incomeNodes = nodes.where((n) => n.column == 0).toList();
          final totalIncome = incomeNodes.fold<int>(0, (s, n) => s + n.value);
          for (final incNode in incomeNodes) {
            final ratio = totalIncome > 0 ? incNode.value / totalIncome : 1.0;
            for (final catE in expenseGroups.entries) {
              final linkVal = (catE.value.total * ratio).round();
              if (linkVal > 0) {
                links.add(
                  SankeyLink(
                    sourceId: incNode.id,
                    targetId: 'cat_${catE.key}',
                    value: linkVal,
                  ),
                );
              }
            }
          }

          // Links: expense categories → merchants (actual)
          for (final e in selectedMerchants) {
            links.add(
              SankeyLink(
                sourceId: 'cat_${e.value.categoryId}',
                targetId: 'mer_${e.key}',
                value: e.value.total,
              ),
            );
          }

          return SankeyData(nodes: nodes, links: links);
        });
  }

  static Color _parseHex(String hex, Color fallback) {
    try {
      return Color(int.parse('FF${hex.replaceFirst('#', '')}', radix: 16));
    } catch (_) {
      return fallback;
    }
  }
}

class _Group {
  final String name;
  final String colorHex;
  final int total;
  const _Group(this.name, this.colorHex, [this.total = 0]);
  _Group add(int amount) => _Group(name, colorHex, total + amount);
}

class _Merchant {
  final String name;
  final String categoryId;
  final int total;
  const _Merchant(this.name, this.categoryId, [this.total = 0]);
  _Merchant add(int amount) => _Merchant(name, categoryId, total + amount);
}
