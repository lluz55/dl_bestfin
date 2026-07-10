import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bestfin/core/constants/transaction_types.dart';
import 'package:bestfin/core/shell/responsive_navigation.dart';
import 'package:bestfin/core/utils/adaptive_modal.dart';
import 'package:bestfin/features/transactions/presentation/screens/bulk_transaction_screen.dart';
import 'package:bestfin/features/transactions/presentation/widgets/transaction_form_modal_overlay.dart';
import 'package:bestfin/features/transactions/presentation/widgets/quick_transaction_sheet.dart';
import 'package:bestfin/core/widgets/global_fab.dart';
import 'package:bestfin/features/onboarding/presentation/providers/tutorial_provider.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  /// Rotas das abas, alinhadas 1:1 com [destinations] por índice.
  static const tabRoutes = ['/home', '/transactions', '/reports', '/more'];

  static const destinations = [
    NavigationDestinationItem(
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: 'Início',
    ),
    NavigationDestinationItem(
      icon: Icons.swap_horiz_outlined,
      activeIcon: Icons.swap_horiz_rounded,
      label: 'Transações',
    ),
    NavigationDestinationItem(
      icon: Icons.bar_chart_outlined,
      activeIcon: Icons.bar_chart_rounded,
      label: 'Relatórios',
    ),
    NavigationDestinationItem(
      icon: Icons.grid_view_outlined,
      activeIcon: Icons.grid_view_rounded,
      label: 'Mais',
    ),
  ];

  void _onBranchTap(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tutorialKeys = ref.watch(tutorialKeysProvider);

    void openQuickSheet(TransactionType type) {
      showAdaptiveModal<void>(
        context: context,
        maxHeightFraction: 0.95,
        builder: (_) => QuickTransactionSheet(initialType: type),
      );
    }

    return ResponsiveNavigation(
      selectedIndex: navigationShell.currentIndex,
      onDestinationSelected: _onBranchTap,
      destinations: destinations,
      // Índices: 0 Início, 1 Transações, 2 Relatórios, 3 Mais — chaves usadas
      // pelos coach marks do tutorial para destacar cada aba.
      destinationKeys: [
        null,
        tutorialKeys.transactionsTabKey,
        tutorialKeys.reportsTabKey,
        tutorialKeys.maisTabKey,
      ],
      floatingActionButton: GlobalFAB(
        key: tutorialKeys.fabKey,
        onExpense: () => openQuickSheet(TransactionType.expense),
        onIncome: () => openQuickSheet(TransactionType.income),
        onTransfer: () => openQuickSheet(TransactionType.transfer),
        onBulk: () => showBulkTransactionModal(context),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: Stack(
        children: [navigationShell, const TransactionFormModalOverlay()],
      ),
    );
  }
}
