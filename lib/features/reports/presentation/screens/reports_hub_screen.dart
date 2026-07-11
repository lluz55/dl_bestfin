import 'package:flutter/material.dart';
import 'package:bestfin/core/widgets/loading_indicator.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bestfin/core/constants/transaction_types.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/providers/privacy_provider.dart';
import 'package:bestfin/core/theme/breakpoints.dart';
import 'package:bestfin/core/widgets/app_page_appbar.dart';
import 'package:bestfin/features/reports/domain/models/report_models.dart';
import 'package:bestfin/features/reports/presentation/providers/reports_provider.dart';
import 'package:bestfin/features/reports/presentation/widgets/heatmap_widget.dart';
import 'package:bestfin/features/reports/presentation/widgets/report_filters_widget.dart';
import 'package:bestfin/features/reports/presentation/widgets/treemap_widget.dart';
import 'package:bestfin/features/reports/presentation/screens/screens.dart';
import 'package:bestfin/features/transactions/presentation/providers/transactions_provider.dart';

// ─── Entry model ─────────────────────────────────────────────────────────────

class _ReportEntry {
  const _ReportEntry({
    required this.title,
    required this.description,
    required this.icon,
    required this.colorFn,
    required this.buildContent,
  });

  final String title;
  final String description;
  final IconData icon;
  final Color Function(ColorScheme) colorFn;
  final Widget Function() buildContent;
}

// ─── Hub screen ───────────────────────────────────────────────────────────────

class ReportsHubScreen extends ConsumerWidget {
  const ReportsHubScreen({super.key});

  static final List<_ReportEntry> _entries = [
    _ReportEntry(
      title: 'Categorias',
      description: 'Gastos por categoria com drill-down',
      icon: Icons.pie_chart_outline,
      colorFn: (cs) => cs.primary,
      buildContent: () => const CategoryReportScreen(),
    ),
    _ReportEntry(
      title: 'Mensal',
      description: 'Comparativo receita × despesa mês a mês',
      icon: Icons.bar_chart_rounded,
      colorFn: (cs) => cs.tertiary,
      buildContent: () => const MonthlyReportScreen(),
    ),
    _ReportEntry(
      title: 'Fluxo de Caixa',
      description: 'Projeção de entradas e saídas futuras',
      icon: Icons.show_chart,
      colorFn: (cs) => cs.secondary,
      buildContent: () => const CashFlowScreen(),
    ),
    _ReportEntry(
      title: 'Patrimônio',
      description: 'Evolução do patrimônio líquido ao longo do tempo',
      icon: Icons.account_balance_wallet_outlined,
      colorFn: (cs) => cs.primary,
      buildContent: () => const NetWorthScreen(),
    ),
    _ReportEntry(
      title: 'Mapa de Calor',
      description: 'Quando e quanto você gasta por dia e hora',
      icon: Icons.grid_4x4_outlined,
      colorFn: (cs) => cs.tertiary,
      buildContent: () => const _MapaContent(),
    ),
    _ReportEntry(
      title: 'Sankey',
      description: 'Fluxo visual de dinheiro entre contas e categorias',
      icon: Icons.account_tree_outlined,
      colorFn: (cs) => cs.secondary,
      buildContent: () => const SankeyScreen(),
    ),
  ];

  void _openReport(BuildContext context, _ReportEntry entry) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            _ReportDetailPage(title: entry.title, child: entry.buildContent()),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = context.colorScheme;

    // Em telas expandidas o hub vira master-detail: lista de relatórios à
    // esquerda e o relatório aberto à direita, sem push de página.
    if (Breakpoints.isExpanded(context)) {
      return Scaffold(
        backgroundColor: cs.surface,
        appBar: const AppPageAppBar(
          title: 'Relatórios',
          showVisibilityToggle: true,
        ),
        body: _ReportsMasterDetail(entries: _entries),
      );
    }

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: const AppPageAppBar(
        title: 'Relatórios',
        showVisibilityToggle: true,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Mesmo em telas estreitas, mantém pelo menos 2 colunas;
          // em telas grandes, quanto menor o extent, mais colunas cabem.
          const maxCrossAxisExtent = 260.0;
          const horizontalPadding = 32.0;
          final availableWidth = constraints.maxWidth - horizontalPadding;
          final crossAxisCount = (availableWidth / maxCrossAxisExtent)
              .floor()
              .clamp(2, _entries.length);

          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.95,
            ),
            itemCount: _entries.length,
            itemBuilder: (context, i) => _ReportHubCard(
              entry: _entries[i],
              delay: Duration(milliseconds: 60 * i.clamp(0, 5)),
              onTap: () => _openReport(context, _entries[i]),
            ),
          );
        },
      ),
    );
  }
}

// ─── Hub card ─────────────────────────────────────────────────────────────────

class _ReportHubCard extends StatefulWidget {
  const _ReportHubCard({
    required this.entry,
    required this.delay,
    required this.onTap,
  });

  final _ReportEntry entry;
  final Duration delay;
  final VoidCallback onTap;

  @override
  State<_ReportHubCard> createState() => _ReportHubCardState();
}

class _ReportHubCardState extends State<_ReportHubCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.textTheme;
    final shapes = context.shapes;
    final motion = context.motion;
    final color = widget.entry.colorFn(cs);

    return AnimatedScale(
          scale: _pressed ? 0.96 : 1.0,
          duration: motion.fastDuration,
          curve: Curves.easeOut,
          child: Material(
            color: cs.surfaceContainerLow,
            borderRadius: shapes.card,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: widget.onTap,
              onTapDown: (_) => setState(() => _pressed = true),
              onTapUp: (_) => setState(() => _pressed = false),
              onTapCancel: () => setState(() => _pressed = false),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Icon(
                      widget.entry.icon,
                      size: 120,
                      color: color.withValues(alpha: 0.08),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Spacer(),
                        Text(
                          widget.entry.title,
                          style: tt.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.entry.description,
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            height: 1.3,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        )
        .animate(delay: widget.delay)
        .fadeIn(duration: motion.fastDuration)
        .slideY(
          begin: 0.08,
          end: 0,
          curve: Curves.easeOutCubic,
          duration: motion.mediumDuration,
        );
  }
}

// ─── Master-detail (telas expandidas) ────────────────────────────────────────

class _ReportsMasterDetail extends StatefulWidget {
  const _ReportsMasterDetail({required this.entries});

  final List<_ReportEntry> entries;

  @override
  State<_ReportsMasterDetail> createState() => _ReportsMasterDetailState();
}

class _ReportsMasterDetailState extends State<_ReportsMasterDetail> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final selected = widget.entries[_selectedIndex];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 300,
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: widget.entries.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) => _ReportNavTile(
              entry: widget.entries[i],
              selected: i == _selectedIndex,
              onTap: () => setState(() => _selectedIndex = i),
            ),
          ),
        ),
        const VerticalDivider(width: 1, thickness: 0.5),
        Expanded(
          child: Column(
            children: [
              const ReportFiltersWidget(),
              const Divider(height: 1, thickness: 0.5),
              Expanded(
                // KeyedSubtree força a troca de estado ao mudar de relatório.
                child: KeyedSubtree(
                  key: ValueKey(_selectedIndex),
                  child: selected.buildContent(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReportNavTile extends StatelessWidget {
  const _ReportNavTile({
    required this.entry,
    required this.selected,
    required this.onTap,
  });

  final _ReportEntry entry;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.textTheme;
    final shapes = context.shapes;
    final color = entry.colorFn(cs);

    return Material(
      color: selected ? cs.secondaryContainer : cs.surfaceContainerLow,
      borderRadius: shapes.card,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(entry.icon, size: 20, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      style: tt.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? cs.onSecondaryContainer
                            : cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      entry.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: tt.bodySmall?.copyWith(
                        color: selected
                            ? cs.onSecondaryContainer.withValues(alpha: 0.8)
                            : cs.onSurfaceVariant,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Detail page wrapper ──────────────────────────────────────────────────────

class _ReportDetailPage extends StatelessWidget {
  const _ReportDetailPage({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppPageAppBar(title: title, showVisibilityToggle: true),
      body: Column(
        children: [
          const ReportFiltersWidget(),
          const Divider(height: 1, thickness: 0.5),
          Expanded(child: child),
        ],
      ),
    );
  }
}

// ─── Mapa de Calor + Treemap (conteúdo combinado) ────────────────────────────

class _MapaContent extends ConsumerWidget {
  const _MapaContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(valuesHiddenProvider);
    final filters = ref.watch(reportFiltersProvider);
    final allTxAsync = ref.watch(filteredTransactionsProvider);
    final cs = context.colorScheme;
    final tt = context.textTheme;

    return allTxAsync.when(
      loading: () => const Center(child: AppLoadingIndicator()),
      error: (e, _) => Center(
        child: Text(
          'Não foi possível carregar os dados.',
          style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
      ),
      data: (txs) {
        final filtered = txs.where((tx) {
          if (!tx.isCompleted) return false;
          if (tx.type == TransactionType.transfer) return false;
          if (tx.date.isBefore(filters.startDate)) return false;
          if (tx.date.isAfter(filters.endDate)) return false;
          return true;
        }).toList();

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

        final Map<String, _CatGroup> catGroups = {};
        for (final tx in filtered) {
          if (tx.type != TransactionType.expense) continue;
          final catId = tx.categoryId ?? '_none';
          final g = catGroups[catId];
          if (g != null) {
            catGroups[catId] = _CatGroup(g.name, g.color, g.total + tx.amount);
          } else {
            catGroups[catId] = _CatGroup(
              tx.category?.displayName ?? 'Sem categoria',
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
                    Text('Quando você gasta', style: tt.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      'Dia da semana × hora do dia',
                      style: tt.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (heatCells.isEmpty)
                      const _EmptyMessage(message: 'Nenhuma despesa no período')
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
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (treemapNodes.isEmpty)
                      const _EmptyMessage(message: 'Nenhuma despesa no período')
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
  const _CatGroup(this.name, this.color, this.total);
  final String name;
  final String color;
  final int total;
}

class _EmptyMessage extends StatelessWidget {
  const _EmptyMessage({required this.message});
  final String message;

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
