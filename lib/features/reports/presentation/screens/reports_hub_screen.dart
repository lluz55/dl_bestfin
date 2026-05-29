import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestfin/core/widgets/app_page_appbar.dart';
import 'package:bestfin/features/reports/presentation/providers/reports_provider.dart';
import 'package:bestfin/features/reports/presentation/widgets/report_filters_widget.dart';
import 'package:bestfin/features/reports/presentation/widgets/heatmap_widget.dart';
import 'package:bestfin/features/reports/presentation/widgets/treemap_widget.dart';
import 'package:bestfin/features/reports/domain/models/report_models.dart';
import 'package:bestfin/core/constants/transaction_types.dart';
import 'package:bestfin/features/transactions/presentation/providers/transactions_provider.dart';
import 'package:bestfin/features/reports/presentation/screens/screens.dart';

class ReportsHubScreen extends ConsumerStatefulWidget {
  const ReportsHubScreen({super.key});

  @override
  ConsumerState<ReportsHubScreen> createState() => _ReportsHubScreenState();
}

class _ReportsHubScreenState extends ConsumerState<ReportsHubScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static final _tabs = [
    (icon: Icons.pie_chart_outline, label: 'Categorias'),
    (icon: Icons.bar_chart_rounded, label: 'Mensal'),
    (icon: Icons.show_chart, label: 'Caixa'),
    (icon: Icons.account_balance_wallet_outlined, label: 'Patrimônio'),
    (icon: Icons.grid_view_outlined, label: 'Mapa'),
    (icon: Icons.account_tree_outlined, label: 'Fluxo'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppPageAppBar(title: 'Relatórios'),
      body: Column(
        children: [
          const ReportFiltersWidget(),
          const SizedBox(height: 4),
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: _tabs
                .map(
                  (t) => Tab(
                    icon: Icon(t.icon, size: 20),
                    text: t.label,
                    iconMargin: const EdgeInsets.only(bottom: 2),
                  ),
                )
                .toList(),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                const CategoryReportScreen(),
                const MonthlyReportScreen(),
                const CashFlowScreen(),
                const NetWorthScreen(),
                _HeatmapAndTreemapTab(),
                const SankeyScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeatmapAndTreemapTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(reportFiltersProvider);
    final allTxAsync = ref.watch(filteredTransactionsProvider);
    final tt = Theme.of(context).textTheme;

    return allTxAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erro: $e')),
      data: (txs) {
        final filtered = txs.where((tx) {
          if (!tx.isCompleted) return false;
          if (tx.type == TransactionType.transfer) return false;
          if (tx.date.isBefore(filters.startDate)) return false;
          if (tx.date.isAfter(filters.endDate)) return false;
          return true;
        }).toList();

        // Build heatmap cells (weekday × hour)
        final Map<String, HeatmapCell> heatCells = {};
        for (final tx in filtered) {
          if (tx.type != TransactionType.expense) continue;
          final key = '${tx.date.weekday}-${tx.date.hour}';
          final existing = heatCells[key];
          if (existing != null) {
            heatCells[key] = HeatmapCell(
              weekday: tx.date.weekday,
              hour: tx.date.hour,
              totalAmount: existing.totalAmount + tx.amount,
              count: existing.count + 1,
            );
          } else {
            heatCells[key] = HeatmapCell(
              weekday: tx.date.weekday,
              hour: tx.date.hour,
              totalAmount: tx.amount,
              count: 1,
            );
          }
        }

        // Build treemap nodes (category → total)
        final Map<String, _CatGroup> catGroups = {};
        for (final tx in filtered) {
          if (tx.type != TransactionType.expense) continue;
          final catId = tx.categoryId ?? '_none';
          final g = catGroups[catId];
          if (g != null) {
            catGroups[catId] = _CatGroup(g.name, g.color, g.total + tx.amount);
          } else {
            catGroups[catId] = _CatGroup(
              tx.category?.name ?? 'Sem categoria',
              tx.category?.color ?? '9E9E9E',
              tx.amount,
            );
          }
        }

        final treemapNodes =
            catGroups.entries
                .map(
                  (e) => TreemapNode(
                    id: e.key,
                    label: e.value.name,
                    value: e.value.total,
                    color: e.value.color,
                  ),
                )
                .toList()
              ..sort((a, b) => b.value.compareTo(a.value));

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mapa de calor — quando você gasta',
                      style: tt.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Dia da semana × hora do dia',
                      style: tt.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (heatCells.isEmpty)
                      const _EmptyChip(message: 'Nenhuma despesa no período')
                    else
                      SpendingHeatmapWidget(cells: heatCells.values.toList()),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Treemap de categorias', style: tt.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      'Área proporcional ao gasto',
                      style: tt.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (treemapNodes.isEmpty)
                      const _EmptyChip(message: 'Nenhuma despesa no período')
                    else
                      SizedBox(
                        height: 280,
                        child: TreemapWidget(nodes: treemapNodes),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CatGroup {
  final String name;
  final String color;
  final int total;
  const _CatGroup(this.name, this.color, this.total);
}

class _EmptyChip extends StatelessWidget {
  final String message;
  const _EmptyChip({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text(
          message,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
