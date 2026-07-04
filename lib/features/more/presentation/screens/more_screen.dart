import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/widgets/app_page_appbar.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.textTheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: const AppPageAppBar(title: 'Mais'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          _SectionHeader(title: 'Finanças', cs: cs, tt: tt, isFirst: true),
          _MenuGrid(
            items: [
              _MenuItem(
                icon: Icons.account_balance_rounded,
                label: 'Contas',
                color: cs.primary,
                onTap: () => context.push('/accounts'),
              ),
              _MenuItem(
                icon: Icons.category_rounded,
                label: 'Categorias',
                color: cs.secondary,
                onTap: () => context.push('/categories'),
              ),
              _MenuItem(
                icon: Icons.credit_card_rounded,
                label: 'Cartões',
                color: cs.tertiary,
                onTap: () => context.push('/credit-cards'),
              ),
              _MenuItem(
                icon: Icons.repeat_rounded,
                label: 'Recorrentes',
                color: cs.error,
                onTap: () => context.push('/recurring'),
              ),
            ],
          ),
          _SectionHeader(title: 'Planejamento', cs: cs, tt: tt),
          _MenuGrid(
            items: [
              _MenuItem(
                icon: Icons.account_balance_wallet_rounded,
                label: 'Orçamento',
                color: const Color(0xFF4CAF50),
                onTap: () => context.push('/budgets'),
              ),
              _MenuItem(
                icon: Icons.waterfall_chart_rounded,
                label: 'Projeção',
                color: cs.primary,
                onTap: () => context.push('/cashflow'),
              ),
            ],
          ),
          _SectionHeader(title: 'Objetivos', cs: cs, tt: tt),
          _MenuGrid(
            items: [
              _MenuItem(
                icon: Icons.flag_rounded,
                label: 'Metas',
                color: cs.tertiary,
                onTap: () => context.push('/goals'),
              ),
              _MenuItem(
                icon: Icons.trending_up_rounded,
                label: 'Investimentos',
                color: cs.secondary,
                onTap: () => context.push('/investments'),
              ),
              _MenuItem(
                icon: Icons.home_work_rounded,
                label: 'Financiamentos',
                color: cs.primary,
                onTap: () => context.push('/financing'),
              ),
              _MenuItem(
                icon: Icons.emoji_events_rounded,
                label: 'Conquistas',
                color: Colors.orange,
                onTap: () => context.push('/gamification'),
              ),
            ],
          ),
          _SectionHeader(title: 'Automação', cs: cs, tt: tt),
          _MenuList(
            items: [
              _MenuListItem(
                icon: Icons.notifications_active_outlined,
                label: 'Sugestões',
                onTap: () => context.push('/notifications/review'),
                cs: cs,
                tt: tt,
              ),
              _MenuListItem(
                icon: Icons.tune_rounded,
                label: 'Captura de notificações',
                onTap: () => context.push('/notifications/settings'),
                cs: cs,
                tt: tt,
              ),
              _MenuListItem(
                icon: Icons.picture_as_pdf_rounded,
                label: 'Importar PDF',
                onTap: () => context.push('/pdf-import'),
                cs: cs,
                tt: tt,
              ),
            ],
          ),
          _SectionHeader(title: 'Sincronização', cs: cs, tt: tt),
          _MenuList(
            items: [
              _MenuListItem(
                icon: Icons.sync_rounded,
                label: 'Sincronizar',
                onTap: () => context.push('/sync'),
                cs: cs,
                tt: tt,
              ),
              _MenuListItem(
                icon: Icons.group_outlined,
                label: 'Grupos familiares',
                onTap: () => context.push('/sync/household'),
                cs: cs,
                tt: tt,
              ),
            ],
          ),
          _SectionHeader(title: 'App', cs: cs, tt: tt),
          _MenuList(
            items: [
              _MenuListItem(
                icon: Icons.file_download_outlined,
                label: 'Exportar dados',
                onTap: () => context.push('/backup'),
                cs: cs,
                tt: tt,
              ),
              _MenuListItem(
                icon: Icons.settings_outlined,
                label: 'Configurações',
                onTap: () => context.push('/settings'),
                cs: cs,
                tt: tt,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.cs,
    required this.tt,
    this.isFirst = false,
  });

  final String title;
  final ColorScheme cs;
  final TextTheme tt;
  final bool isFirst;

  @override
  Widget build(BuildContext context) {
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
