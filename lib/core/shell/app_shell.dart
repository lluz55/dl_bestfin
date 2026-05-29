import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bestfin/core/constants/transaction_types.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/theme/motion.dart';
import 'package:bestfin/core/widgets/global_fab.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _destinations = [
    (
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: 'Início',
    ),
    (
      icon: Icons.swap_horiz_outlined,
      activeIcon: Icons.swap_horiz_rounded,
      label: 'Transações',
    ),
    (
      icon: Icons.bar_chart_outlined,
      activeIcon: Icons.bar_chart_rounded,
      label: 'Relatórios',
    ),
    (
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
    final cs = context.colorScheme;
    final currentIndex = navigationShell.currentIndex;

    return Scaffold(
      extendBody: true,
      floatingActionButton: GlobalFAB(
        onExpense: () => context.push(
          '/transaction/new?type=${TransactionType.expense.name}',
        ),
        onIncome: () => context.push(
          '/transaction/new?type=${TransactionType.income.name}',
        ),
        onTransfer: () => context.push(
          '/transaction/new?type=${TransactionType.transfer.name}',
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: Padding(
        padding: EdgeInsets.only(
          bottom: 96 + MediaQuery.paddingOf(context).bottom,
        ),
        child: navigationShell,
      ),
      bottomNavigationBar: _AnimatedNavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: _onBranchTap,
        destinations: _destinations,
        cs: cs,
      ),
    );
  }
}

class _AnimatedNavigationBar extends StatelessWidget {
  const _AnimatedNavigationBar({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    required this.cs,
  });

  final int selectedIndex;
  final void Function(int) onDestinationSelected;
  final List<({IconData icon, IconData activeIcon, String label})> destinations;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final motion = context.motion;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: 16 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          color: cs.surfaceContainer.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double totalWidth = constraints.maxWidth;
            final int itemCount = destinations.length;
            final double itemWidth = totalWidth / itemCount;

            return Stack(
              children: [
                AnimatedPositioned(
                  duration: motion.morphDuration,
                  curve: motion.morphCurve,
                  left: selectedIndex * itemWidth + 8,
                  width: itemWidth - 16,
                  top: 8,
                  bottom: 8,
                  child: Container(
                    decoration: BoxDecoration(
                      color: cs.secondaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (int i = 0; i < itemCount; i++)
                      Expanded(
                        child: _NavBarItem(
                          icon: destinations[i].icon,
                          activeIcon: destinations[i].activeIcon,
                          label: destinations[i].label,
                          isSelected: selectedIndex == i,
                          onTap: () => onDestinationSelected(i),
                          cs: cs,
                          motion: motion,
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    ).animate().slideY(
      begin: 1.0,
      end: 0,
      curve: Curves.easeOutCubic,
      duration: const Duration(milliseconds: 500),
      delay: const Duration(milliseconds: 200),
    );
  }
}

class _NavBarItem extends StatelessWidget {
  const _NavBarItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.cs,
    required this.motion,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final ColorScheme cs;
  final ExpressiveMotion motion;

  @override
  Widget build(BuildContext context) {
    final labelStyle = context.textTheme.labelMedium?.copyWith(
      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
    );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      splashColor: cs.primary.withValues(alpha: 0.15),
      highlightColor: Colors.transparent,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder<Color?>(
            duration: motion.fastDuration,
            tween: ColorTween(
              end: isSelected ? cs.onSecondaryContainer : cs.onSurfaceVariant,
            ),
            builder: (context, color, child) {
              return Icon(isSelected ? activeIcon : icon, color: color);
            },
          ),
          const SizedBox(height: 4),
          AnimatedDefaultTextStyle(
            duration: motion.fastDuration,
            style: labelStyle!.copyWith(
              color: isSelected ? cs.onSecondaryContainer : cs.onSurfaceVariant,
            ),
            child: Text(label),
          ),
        ],
      ),
    );
  }
}

