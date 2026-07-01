import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bestfin/core/constants/transaction_types.dart';
import 'package:bestfin/core/shell/responsive_navigation.dart';
import 'package:bestfin/core/utils/adaptive_modal.dart';
import 'package:bestfin/features/llm/domain/models/llm_state.dart';
import 'package:bestfin/features/llm/presentation/providers/llm_provider.dart';
import 'package:bestfin/features/llm/presentation/widgets/model_setup_sheet.dart';
import 'package:bestfin/features/transactions/presentation/widgets/transaction_form_modal_overlay.dart';
import 'package:bestfin/features/transactions/presentation/widgets/quick_transaction_sheet.dart';
import 'package:bestfin/core/widgets/global_fab.dart';
import 'package:bestfin/features/onboarding/presentation/providers/tutorial_provider.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _destinations = [
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
    final llmState = ref.watch(llmStateProvider);
    final selectedModel = ref.watch(selectedModelProvider);
    final tutorialKeys = ref.watch(tutorialKeysProvider);

    void openQuickSheet(TransactionType type) {
      showAdaptiveModal<void>(
        context: context,
        builder: (_) => QuickTransactionSheet(initialType: type),
      );
    }

    return ResponsiveNavigation(
      selectedIndex: navigationShell.currentIndex,
      onDestinationSelected: _onBranchTap,
      destinations: _destinations,
      lastDestinationKey: tutorialKeys.maisTabKey,
      floatingActionButton: GlobalFAB(
        key: tutorialKeys.fabKey,
        onExpense: () => openQuickSheet(TransactionType.expense),
        onIncome: () => openQuickSheet(TransactionType.income),
        onTransfer: () => openQuickSheet(TransactionType.transfer),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: Stack(
        children: [navigationShell, const TransactionFormModalOverlay()],
      ),
      bottomOverlay: llmState.status == LlmStatus.downloading
          ? _LlmDownloadBanner(
              progress: llmState.downloadProgress,
              modelName: selectedModel.displayName,
            )
          : null,
    );
  }
}

class _LlmDownloadBanner extends StatelessWidget {
  const _LlmDownloadBanner({required this.progress, required this.modelName});

  final double progress;
  final String modelName;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Positioned(
      left: 16,
      right: 16,
      bottom: 104 + MediaQuery.paddingOf(context).bottom,
      child: GestureDetector(
        onTap: () {
          showAdaptiveModal(
            context: context,
            builder: (_) => const ModelSetupSheet(),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 3,
                  color: cs.primary,
                  backgroundColor: cs.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Baixando modelo em segundo plano...',
                      style: tt.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$modelName · ${(progress * 100).toStringAsFixed(1)}%',
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
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
