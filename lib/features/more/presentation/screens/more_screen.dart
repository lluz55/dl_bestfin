import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/theme/breakpoints.dart';
import 'package:bestfin/core/widgets/app_page_appbar.dart';
import 'package:bestfin/features/accounts/presentation/screens/accounts_list_screen.dart';
import 'package:bestfin/features/backup/presentation/screens/backup_screen.dart';
import 'package:bestfin/features/budgets/presentation/screens/budgets_list_screen.dart';
import 'package:bestfin/features/cashflow/presentation/screens/cashflow_screen.dart';
import 'package:bestfin/features/categories/presentation/screens/categories_screen.dart';
import 'package:bestfin/features/credit_cards/presentation/screens/credit_cards_list_screen.dart';
import 'package:bestfin/features/financing/presentation/screens/financing_list_screen.dart';
import 'package:bestfin/features/gamification/presentation/screens/gamification_hub_screen.dart';
import 'package:bestfin/features/goals/presentation/screens/goals_list_screen.dart';
import 'package:bestfin/features/investments/presentation/screens/portfolio_screen.dart';
import 'package:bestfin/features/notifications/presentation/screens/notification_settings_screen.dart';
import 'package:bestfin/features/notifications/presentation/screens/review_queue_screen.dart';
import 'package:bestfin/features/pdf_import/presentation/screens/pdf_import_screen.dart';
import 'package:bestfin/features/recurring/presentation/screens/recurring_list_screen.dart';
import 'package:bestfin/features/settings/presentation/screens/settings_screen.dart';
import 'package:bestfin/features/sync/presentation/screens/household_screen.dart';
import 'package:bestfin/features/sync/presentation/screens/sync_settings_screen.dart';

// ─── Modelo dos itens do menu ────────────────────────────────────────────────

class _MoreItem {
  const _MoreItem({
    required this.icon,
    required this.label,
    required this.route,
    required this.buildScreen,
    this.colorFn,
  });

  final IconData icon;
  final String label;

  /// Rota usada no mobile (push em tela cheia).
  final String route;

  /// Tela embutida no painel de detalhe (telas médias/grandes).
  final Widget Function() buildScreen;

  /// Cor de destaque do ícone (atalhos em card); nulo usa a cor neutra.
  final Color Function(ColorScheme)? colorFn;
}

class _MoreSection {
  const _MoreSection({
    required this.title,
    required this.items,
    this.isGrid = false,
  });

  final String title;
  final List<_MoreItem> items;

  /// No mobile, seções em grid viram cards de atalho; as demais, lista.
  final bool isGrid;
}

// ─── Tela ────────────────────────────────────────────────────────────────────

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  static final List<_MoreSection> _sections = [
    _MoreSection(
      title: 'Finanças',
      isGrid: true,
      items: [
        _MoreItem(
          icon: Icons.account_balance_rounded,
          label: 'Contas',
          route: '/accounts',
          colorFn: (cs) => cs.primary,
          buildScreen: () => const AccountsListScreen(),
        ),
        _MoreItem(
          icon: Icons.category_rounded,
          label: 'Categorias',
          route: '/categories',
          colorFn: (cs) => cs.secondary,
          buildScreen: () => const CategoriesScreen(),
        ),
        _MoreItem(
          icon: Icons.credit_card_rounded,
          label: 'Cartões',
          route: '/credit-cards',
          colorFn: (cs) => cs.tertiary,
          buildScreen: () => const CreditCardsListScreen(),
        ),
        _MoreItem(
          icon: Icons.repeat_rounded,
          label: 'Recorrentes',
          route: '/recurring',
          colorFn: (cs) => cs.error,
          buildScreen: () => const RecurringListScreen(),
        ),
      ],
    ),
    _MoreSection(
      title: 'Planejamento',
      isGrid: true,
      items: [
        _MoreItem(
          icon: Icons.account_balance_wallet_rounded,
          label: 'Orçamento',
          route: '/budgets',
          colorFn: (_) => const Color(0xFF4CAF50),
          buildScreen: () => const BudgetsListScreen(),
        ),
        _MoreItem(
          icon: Icons.waterfall_chart_rounded,
          label: 'Projeção',
          route: '/cashflow',
          colorFn: (cs) => cs.primary,
          buildScreen: () => const CashFlowScreen(),
        ),
      ],
    ),
    _MoreSection(
      title: 'Objetivos',
      isGrid: true,
      items: [
        _MoreItem(
          icon: Icons.flag_rounded,
          label: 'Metas',
          route: '/goals',
          colorFn: (cs) => cs.tertiary,
          buildScreen: () => const GoalsListScreen(),
        ),
        _MoreItem(
          icon: Icons.trending_up_rounded,
          label: 'Investimentos',
          route: '/investments',
          colorFn: (cs) => cs.secondary,
          buildScreen: () => const PortfolioScreen(),
        ),
        _MoreItem(
          icon: Icons.home_work_rounded,
          label: 'Financiamentos',
          route: '/financing',
          colorFn: (cs) => cs.primary,
          buildScreen: () => const FinancingListScreen(),
        ),
        _MoreItem(
          icon: Icons.emoji_events_rounded,
          label: 'Conquistas',
          route: '/gamification',
          colorFn: (_) => Colors.orange,
          buildScreen: () => const GamificationHubScreen(),
        ),
      ],
    ),
    _MoreSection(
      title: 'Automação',
      items: [
        _MoreItem(
          icon: Icons.notifications_active_outlined,
          label: 'Sugestões',
          route: '/notifications/review',
          buildScreen: () => const ReviewQueueScreen(),
        ),
        _MoreItem(
          icon: Icons.tune_rounded,
          label: 'Captura de notificações',
          route: '/notifications/settings',
          buildScreen: () => const NotificationSettingsScreen(),
        ),
        _MoreItem(
          icon: Icons.picture_as_pdf_rounded,
          label: 'Importar PDF',
          route: '/pdf-import',
          buildScreen: () => const PdfImportScreen(),
        ),
      ],
    ),
    _MoreSection(
      title: 'Sincronização',
      items: [
        _MoreItem(
          icon: Icons.sync_rounded,
          label: 'Sincronizar',
          route: '/sync',
          buildScreen: () => const SyncSettingsScreen(),
        ),
        _MoreItem(
          icon: Icons.group_outlined,
          label: 'Grupos familiares',
          route: '/sync/household',
          buildScreen: () => const HouseholdScreen(),
        ),
      ],
    ),
    _MoreSection(
      title: 'App',
      items: [
        _MoreItem(
          icon: Icons.file_download_outlined,
          label: 'Exportar dados',
          route: '/backup',
          buildScreen: () => const BackupScreen(),
        ),
        _MoreItem(
          icon: Icons.settings_outlined,
          label: 'Configurações',
          route: '/settings',
          buildScreen: () => const SettingsScreen(),
        ),
      ],
    ),
  ];

  /// Seções de lista antes das de cards (preferência para telas maiores).
  static List<_MoreSection> get _listsFirst => [
    ..._sections.where((s) => !s.isGrid),
    ..._sections.where((s) => s.isGrid),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: const AppPageAppBar(title: 'Mais'),
      body: Breakpoints.isCompact(context)
          ? _MenuColumnBody(sections: _sections)
          : LayoutBuilder(
              builder: (context, constraints) {
                // O painel de detalhe precisa de espaço mínimo útil; abaixo
                // disso degrada para o menu em coluna única.
                if (constraints.maxWidth < 640) {
                  return _MenuColumnBody(sections: _listsFirst, maxWidth: 600);
                }
                return _MoreMasterDetail(sections: _listsFirst);
              },
            ),
    );
  }
}

// ─── Menu em coluna única (mobile / fallback estreito) ───────────────────────

class _MenuColumnBody extends StatelessWidget {
  const _MenuColumnBody({required this.sections, this.maxWidth});

  final List<_MoreSection> sections;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.textTheme;

    final list = ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        for (var i = 0; i < sections.length; i++) ...[
          _SectionHeader(title: sections[i].title, isFirst: i == 0),
          if (sections[i].isGrid)
            _MenuGrid(
              items: [
                for (final item in sections[i].items)
                  _MenuItem(
                    icon: item.icon,
                    label: item.label,
                    color: item.colorFn?.call(cs) ?? cs.primary,
                    onTap: () => context.push(item.route),
                  ),
              ],
            )
          else
            _MenuList(
              items: [
                for (final item in sections[i].items)
                  _MenuListItem(
                    icon: item.icon,
                    label: item.label,
                    onTap: () => context.push(item.route),
                    cs: cs,
                    tt: tt,
                  ),
              ],
            ),
        ],
      ],
    );

    if (maxWidth == null) return list;
    return Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth!),
        child: list,
      ),
    );
  }
}

// ─── Master-detail (telas médias/grandes) ────────────────────────────────────

class _MoreMasterDetail extends StatefulWidget {
  const _MoreMasterDetail({required this.sections});

  final List<_MoreSection> sections;

  @override
  State<_MoreMasterDetail> createState() => _MoreMasterDetailState();
}

class _MoreMasterDetailState extends State<_MoreMasterDetail> {
  late _MoreItem _selected = widget.sections.first.items.first;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 300,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              for (var s = 0; s < widget.sections.length; s++) ...[
                _SectionHeader(
                  title: widget.sections[s].title,
                  isFirst: s == 0,
                ),
                for (final item in widget.sections[s].items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: _MasterNavTile(
                      item: item,
                      selected: identical(item, _selected),
                      onTap: () => setState(() => _selected = item),
                    ),
                  ),
              ],
            ],
          ),
        ),
        const VerticalDivider(width: 1, thickness: 0.5),
        Expanded(
          // KeyedSubtree descarta o estado da tela anterior ao trocar de item.
          child: KeyedSubtree(
            key: ValueKey(_selected.route),
            child: _selected.buildScreen(),
          ),
        ),
      ],
    );
  }
}

class _MasterNavTile extends StatelessWidget {
  const _MasterNavTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _MoreItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.textTheme;
    final color = item.colorFn?.call(cs) ?? cs.onSurfaceVariant;

    return Material(
      color: selected ? cs.secondaryContainer : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(item.icon, size: 18, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.bodyMedium?.copyWith(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? cs.onSecondaryContainer : cs.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Widgets do menu mobile ──────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.isFirst = false});

  final String title;
  final bool isFirst;

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.textTheme;

    return Padding(
      padding: EdgeInsets.fromLTRB(4, isFirst ? 4 : 16, 4, 8),
      child: Text(
        title,
        style: tt.titleSmall?.copyWith(
          color: cs.onSurfaceVariant,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _MenuGrid extends StatelessWidget {
  const _MenuGrid({required this.items});

  final List<_MenuItem> items;

  @override
  Widget build(BuildContext context) {
    if (Breakpoints.isCompact(context)) {
      return Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 0.85,
            padding: EdgeInsets.zero,
            children: items,
          ),
        ),
      );
    }

    // Telas maiores: os atalhos fluem com a largura disponível da coluna.
    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 110,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.85,
      ),
      children: items,
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, size: 22, color: color),
            ),
            const SizedBox(height: 4),
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tt.labelSmall?.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuList extends StatelessWidget {
  const _MenuList({required this.items});

  final List<_MenuListItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: items),
    );
  }
}

class _MenuListItem extends StatelessWidget {
  const _MenuListItem({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.cs,
    required this.tt,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: cs.onSurface),
      title: Text(
        label,
        style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: cs.onSurfaceVariant,
        size: 20,
      ),
      onTap: onTap,
    );
  }
}
