import 'package:flutter/material.dart';

/// Catálogo de destinos que o usuário pode fixar como atalho na barra lateral,
/// abaixo das abas principais. Cobre as funcionalidades da página "Mais" (que
/// não têm aba dedicada) e são todas roteáveis via `context.push(route)`.
enum NavShortcut {
  accounts(
    id: 'accounts',
    label: 'Contas',
    icon: Icons.account_balance_rounded,
    route: '/accounts',
  ),
  categories(
    id: 'categories',
    label: 'Categorias',
    icon: Icons.category_rounded,
    route: '/categories',
  ),
  creditCards(
    id: 'creditCards',
    label: 'Cartões',
    icon: Icons.credit_card_rounded,
    route: '/credit-cards',
  ),
  recurring(
    id: 'recurring',
    label: 'Recorrentes',
    icon: Icons.repeat_rounded,
    route: '/recurring',
  ),
  budgets(
    id: 'budgets',
    label: 'Orçamento',
    icon: Icons.account_balance_wallet_rounded,
    route: '/budgets',
  ),
  cashflow(
    id: 'cashflow',
    label: 'Projeção',
    icon: Icons.waterfall_chart_rounded,
    route: '/cashflow',
  ),
  goals(id: 'goals', label: 'Metas', icon: Icons.flag_rounded, route: '/goals'),
  investments(
    id: 'investments',
    label: 'Investimentos',
    icon: Icons.trending_up_rounded,
    route: '/investments',
  ),
  financing(
    id: 'financing',
    label: 'Financiamentos',
    icon: Icons.home_work_rounded,
    route: '/financing',
  ),
  gamification(
    id: 'gamification',
    label: 'Conquistas',
    icon: Icons.emoji_events_rounded,
    route: '/gamification',
  ),
  suggestions(
    id: 'suggestions',
    label: 'Sugestões',
    icon: Icons.pending_actions_rounded,
    route: '/transactions/pending',
  ),
  pdfImport(
    id: 'pdfImport',
    label: 'Importar PDF',
    icon: Icons.picture_as_pdf_rounded,
    route: '/pdf-import',
  ),
  sync(
    id: 'sync',
    label: 'Sincronizar',
    icon: Icons.sync_rounded,
    route: '/sync',
  ),
  household(
    id: 'household',
    label: 'Grupos familiares',
    icon: Icons.group_outlined,
    route: '/sync/household',
  ),
  backup(
    id: 'backup',
    label: 'Exportar dados',
    icon: Icons.file_download_outlined,
    route: '/backup',
  );

  const NavShortcut({
    required this.id,
    required this.label,
    required this.icon,
    required this.route,
  });

  final String id;
  final String label;
  final IconData icon;
  final String route;

  static NavShortcut? fromId(String id) {
    for (final s in NavShortcut.values) {
      if (s.id == id) return s;
    }
    return null;
  }
}
