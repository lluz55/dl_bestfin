import 'package:flutter/material.dart';

enum AppShortcut {
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
  goals(
    id: 'goals',
    label: 'Metas',
    icon: Icons.flag_rounded,
    route: '/goals',
  ),
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
  ai(
    id: 'ai',
    label: 'Painel IA',
    icon: Icons.psychology_rounded,
    route: '/ai',
  ),
  gamification(
    id: 'gamification',
    label: 'Conquistas',
    icon: Icons.emoji_events_rounded,
    route: '/gamification',
  );

  const AppShortcut({
    required this.id,
    required this.label,
    required this.icon,
    required this.route,
  });

  final String id;
  final String label;
  final IconData icon;
  final String route;

  Color getColor(ColorScheme cs) {
    switch (this) {
      case AppShortcut.accounts:
        return cs.primary;
      case AppShortcut.categories:
        return cs.secondary;
      case AppShortcut.creditCards:
        return cs.tertiary;
      case AppShortcut.recurring:
        return cs.error;
      case AppShortcut.goals:
        return cs.tertiary;
      case AppShortcut.investments:
        return cs.secondary;
      case AppShortcut.financing:
        return cs.primary;
      case AppShortcut.ai:
        return cs.primary;
      case AppShortcut.gamification:
        return Colors.orange;
    }
  }

  static AppShortcut? fromId(String id) {
    try {
      return AppShortcut.values.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }
}
