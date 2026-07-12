import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/providers/sidebar_provider.dart';
import 'package:bestfin/core/providers/sidebar_shortcuts_provider.dart';
import 'package:bestfin/core/shell/sidebar_shortcuts_edit_sheet.dart';
import 'package:bestfin/core/theme/breakpoints.dart';
import 'package:bestfin/core/theme/motion.dart';
import 'package:bestfin/core/utils/adaptive_modal.dart';

/// Respiro reservado para a barra de navegação inferior flutuante — o
/// [Scaffold] usa `extendBody: true`, então o corpo (e qualquer overlay,
/// como o [SnackBar] de sincronismo) precisa reservar esse espaço manualmente
/// para não ficar atrás da barra.
const double kFloatingNavClearance = 96;

class NavigationDestinationItem {
  const NavigationDestinationItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
}

class ResponsiveNavigation extends ConsumerStatefulWidget {
  const ResponsiveNavigation({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    required this.body,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.bottomOverlay,
    this.destinationKeys,
  });

  final int selectedIndex;
  final void Function(int) onDestinationSelected;
  final List<NavigationDestinationItem> destinations;
  final Widget body;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Widget? bottomOverlay;

  /// GlobalKeys por destino (índice), usadas pelos coach marks do tutorial para
  /// destacar abas específicas. `null` em posições que não são alvo.
  final List<GlobalKey?>? destinationKeys;

  @override
  ConsumerState<ResponsiveNavigation> createState() =>
      _ResponsiveNavigationState();
}

class _ResponsiveNavigationState extends ConsumerState<ResponsiveNavigation> {
  void _onTap(int index) {
    HapticFeedback.selectionClick();
    widget.onDestinationSelected(index);
  }

  @override
  Widget build(BuildContext context) {
    final isCollapsed = ref.watch(sidebarCollapsedProvider);

    if (Breakpoints.isExpanded(context)) {
      return _ExpandedLayout(
        selectedIndex: widget.selectedIndex,
        onDestinationSelected: _onTap,
        destinations: widget.destinations,
        body: widget.body,
        floatingActionButton: widget.floatingActionButton,
        bottomOverlay: widget.bottomOverlay,
        isCollapsed: isCollapsed,
        onToggleCollapsed: () =>
            ref.read(sidebarCollapsedProvider.notifier).toggle(),
      );
    }
    if (Breakpoints.isMedium(context)) {
      return _MediumLayout(
        selectedIndex: widget.selectedIndex,
        onDestinationSelected: _onTap,
        destinations: widget.destinations,
        body: widget.body,
        floatingActionButton: widget.floatingActionButton,
        bottomOverlay: widget.bottomOverlay,
      );
    }
    return _CompactLayout(
      selectedIndex: widget.selectedIndex,
      onDestinationSelected: _onTap,
      destinations: widget.destinations,
      body: widget.body,
      floatingActionButton: widget.floatingActionButton,
      floatingActionButtonLocation: widget.floatingActionButtonLocation,
      bottomOverlay: widget.bottomOverlay,
      destinationKeys: widget.destinationKeys,
    );
  }
}

// ─── Compact (mobile) ────────────────────────────────────────────────────────

class _CompactLayout extends StatelessWidget {
  const _CompactLayout({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    required this.body,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.bottomOverlay,
    this.destinationKeys,
  });

  final int selectedIndex;
  final void Function(int) onDestinationSelected;
  final List<NavigationDestinationItem> destinations;
  final Widget body;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Widget? bottomOverlay;

  /// GlobalKeys por destino (índice), usadas pelos coach marks do tutorial para
  /// destacar abas específicas. `null` em posições que não são alvo.
  final List<GlobalKey?>? destinationKeys;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      extendBody: true,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      body: Stack(
        children: [
          Padding(
            padding: EdgeInsets.only(
              bottom:
                  kFloatingNavClearance + MediaQuery.paddingOf(context).bottom,
            ),
            child: body,
          ),
          ?bottomOverlay,
        ],
      ),
      bottomNavigationBar: _AnimatedBottomBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: onDestinationSelected,
        destinations: destinations,
        cs: cs,
        destinationKeys: destinationKeys,
      ),
    );
  }
}

// ─── Medium (tablet — Collapsed sidebar + overlay drawer) ────────────────────

class _MediumLayout extends StatefulWidget {
  const _MediumLayout({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    required this.body,
    this.floatingActionButton,
    this.bottomOverlay,
  });

  final int selectedIndex;
  final void Function(int) onDestinationSelected;
  final List<NavigationDestinationItem> destinations;
  final Widget body;
  final Widget? floatingActionButton;
  final Widget? bottomOverlay;

  @override
  State<_MediumLayout> createState() => _MediumLayoutState();
}

class _MediumLayoutState extends State<_MediumLayout> {
  bool _isExpanded = false;

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      body: Stack(
        children: [
          Row(
            children: [
              _CollapsedDrawer(
                selectedIndex: widget.selectedIndex,
                onDestinationSelected: (i) {
                  widget.onDestinationSelected(i);
                  if (_isExpanded) setState(() => _isExpanded = false);
                },
                destinations: widget.destinations,
                cs: cs,
                onExpand: _toggleExpanded,
              ),
              Expanded(
                child: Stack(children: [widget.body, ?widget.bottomOverlay]),
              ),
            ],
          ),
          if (_isExpanded)
            GestureDetector(
              onTap: () => setState(() => _isExpanded = false),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 250),
                opacity: _isExpanded ? 1.0 : 0.0,
                child: Container(color: cs.scrim.withValues(alpha: 0.45)),
              ),
            ),
          if (_isExpanded)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              left: 0,
              top: 0,
              bottom: 0,
              width: 240,
              child: _MediumOverlayDrawer(
                selectedIndex: widget.selectedIndex,
                onDestinationSelected: (i) {
                  widget.onDestinationSelected(i);
                  setState(() => _isExpanded = false);
                },
                destinations: widget.destinations,
                cs: cs,
                tt: tt,
                onClose: () => setState(() => _isExpanded = false),
              ),
            ),
        ],
      ),
      floatingActionButton: widget.floatingActionButton,
    );
  }
}

class _MediumOverlayDrawer extends StatelessWidget {
  const _MediumOverlayDrawer({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    required this.cs,
    required this.tt,
    this.onClose,
  });

  final int selectedIndex;
  final void Function(int) onDestinationSelected;
  final List<NavigationDestinationItem> destinations;
  final ColorScheme cs;
  final TextTheme tt;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: cs.surfaceContainerLow,
      elevation: 4,
      child: Column(
        children: [
          SizedBox(height: MediaQuery.paddingOf(context).top + 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [cs.primary, cs.secondary],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'BestFin',
                    style: tt.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                ),
                if (onClose != null)
                  IconButton(
                    onPressed: onClose,
                    icon: const Icon(Icons.close_rounded, size: 20),
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Fechar menu',
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (int i = 0; i < destinations.length; i++)
                  _DrawerItem(
                    icon: destinations[i].icon,
                    activeIcon: destinations[i].activeIcon,
                    label: destinations[i].label,
                    isSelected: selectedIndex == i,
                    onTap: () => onDestinationSelected(i),
                    cs: cs,
                    tt: tt,
                  ),
                _SidebarShortcuts(cs: cs, tt: tt),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.only(
              left: 12,
              right: 12,
              bottom: 12 + MediaQuery.paddingOf(context).bottom,
            ),
            child: ListenableBuilder(
              listenable: GoRouter.of(context).routerDelegate,
              builder: (context, _) {
                final isSettings = GoRouterState.of(context).uri.toString() == '/settings';
                return _DrawerItem(
                  icon: Icons.settings_outlined,
                  activeIcon: Icons.settings_rounded,
                  label: 'Configurações',
                  isSelected: isSettings,
                  onTap: () {
                    if (onClose != null) onClose!();
                    context.push('/settings');
                  },
                  cs: cs,
                  tt: tt,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Expanded (desktop — NavigationDrawer) ───────────────────────────────────

class _ExpandedLayout extends StatelessWidget {
  const _ExpandedLayout({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    required this.body,
    this.floatingActionButton,
    this.bottomOverlay,
    this.isCollapsed = false,
    this.onToggleCollapsed,
  });

  final int selectedIndex;
  final void Function(int) onDestinationSelected;
  final List<NavigationDestinationItem> destinations;
  final Widget body;
  final Widget? floatingActionButton;
  final Widget? bottomOverlay;
  final bool isCollapsed;
  final VoidCallback? onToggleCollapsed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      body: Row(
        children: [
          isCollapsed
              ? _CollapsedDrawer(
                  selectedIndex: selectedIndex,
                  onDestinationSelected: onDestinationSelected,
                  destinations: destinations,
                  cs: cs,
                  onExpand: onToggleCollapsed,
                )
              : _AnimatedNavigationDrawer(
                  selectedIndex: selectedIndex,
                  onDestinationSelected: onDestinationSelected,
                  destinations: destinations,
                  cs: cs,
                  tt: tt,
                  onCollapse: onToggleCollapsed,
                ),
          Expanded(child: Stack(children: [body, ?bottomOverlay])),
        ],
      ),
      floatingActionButton: floatingActionButton,
    );
  }
}

// ─── Animated Bottom Bar ─────────────────────────────────────────────────────

class _AnimatedBottomBar extends StatelessWidget {
  const _AnimatedBottomBar({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    required this.cs,
    this.destinationKeys,
  });

  final int selectedIndex;
  final void Function(int) onDestinationSelected;
  final List<NavigationDestinationItem> destinations;
  final ColorScheme cs;
  final List<GlobalKey?>? destinationKeys;

  @override
  Widget build(BuildContext context) {
    final motion = context.motion;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: 12 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: cs.surfaceContainer,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: cs.outlineVariant.withValues(alpha: 0.30),
            width: 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final totalWidth = constraints.maxWidth;
            final itemWidth = totalWidth / destinations.length;

            return Stack(
              children: [
                AnimatedPositioned(
                  duration: motion.morphDuration,
                  curve: motion.morphCurve,
                  left: selectedIndex * itemWidth + 8,
                  width: itemWidth - 16,
                  top: 6,
                  bottom: 6,
                  child: Container(
                    decoration: BoxDecoration(
                      color: cs.secondaryContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (int i = 0; i < destinations.length; i++)
                      Expanded(
                        key:
                            (destinationKeys != null &&
                                i < destinationKeys!.length)
                            ? destinationKeys![i]
                            : null,
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
      begin: 0.6,
      end: 0,
      curve: Curves.easeOutCubic,
      duration: const Duration(milliseconds: 400),
      delay: const Duration(milliseconds: 100),
    );
  }
}

// ─── Animated Navigation Drawer ──────────────────────────────────────────────

class _AnimatedNavigationDrawer extends StatelessWidget {
  const _AnimatedNavigationDrawer({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    required this.cs,
    required this.tt,
    this.onCollapse,
  });

  final int selectedIndex;
  final void Function(int) onDestinationSelected;
  final List<NavigationDestinationItem> destinations;
  final ColorScheme cs;
  final TextTheme tt;
  final VoidCallback? onCollapse;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        border: Border(
          right: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.20)),
        ),
      ),
      child: Column(
        children: [
          SizedBox(height: MediaQuery.paddingOf(context).top + 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [cs.primary, cs.secondary],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'BestFin',
                    style: tt.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                ),
                if (onCollapse != null)
                  IconButton(
                    onPressed: onCollapse,
                    icon: const Icon(Icons.chevron_left_rounded, size: 20),
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Recolher menu',
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (int i = 0; i < destinations.length; i++)
                  _DrawerItem(
                    icon: destinations[i].icon,
                    activeIcon: destinations[i].activeIcon,
                    label: destinations[i].label,
                    isSelected: selectedIndex == i,
                    onTap: () => onDestinationSelected(i),
                    cs: cs,
                    tt: tt,
                  ),
                _SidebarShortcuts(cs: cs, tt: tt),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.only(
              left: 12,
              right: 12,
              bottom: 12 + MediaQuery.paddingOf(context).bottom,
            ),
            child: ListenableBuilder(
              listenable: GoRouter.of(context).routerDelegate,
              builder: (context, _) {
                final isSettings = GoRouterState.of(context).uri.toString() == '/settings';
                return _DrawerItem(
                  icon: Icons.settings_outlined,
                  activeIcon: Icons.settings_rounded,
                  label: 'Configurações',
                  isSelected: isSettings,
                  onTap: () => context.push('/settings'),
                  cs: cs,
                  tt: tt,
                );
              },
            ),
          ),
        ],
      ),
    ).animate().slideX(
      begin: -0.4,
      end: 0,
      curve: Curves.easeOutCubic,
      duration: const Duration(milliseconds: 400),
    );
  }
}

class _CollapsedDrawer extends StatelessWidget {
  const _CollapsedDrawer({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    required this.cs,
    this.onExpand,
  });

  final int selectedIndex;
  final void Function(int) onDestinationSelected;
  final List<NavigationDestinationItem> destinations;
  final ColorScheme cs;
  final VoidCallback? onExpand;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        border: Border(
          right: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.20)),
        ),
      ),
      child: Column(
        children: [
          SizedBox(height: MediaQuery.paddingOf(context).top + 20),
          if (onExpand != null)
            IconButton(
              onPressed: onExpand,
              icon: const Icon(Icons.chevron_right_rounded, size: 20),
              visualDensity: VisualDensity.compact,
              tooltip: 'Expandir menu',
            ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                for (int i = 0; i < destinations.length; i++)
                  _CollapsedDrawerItem(
                    icon: destinations[i].icon,
                    activeIcon: destinations[i].activeIcon,
                    label: destinations[i].label,
                    isSelected: selectedIndex == i,
                    onTap: () => onDestinationSelected(i),
                    cs: cs,
                  ),
                _CollapsedSidebarShortcuts(cs: cs),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.only(
              bottom: 12 + MediaQuery.paddingOf(context).bottom,
            ),
            child: ListenableBuilder(
              listenable: GoRouter.of(context).routerDelegate,
              builder: (context, _) {
                final isSettings = GoRouterState.of(context).uri.toString() == '/settings';
                return _CollapsedDrawerItem(
                  icon: Icons.settings_outlined,
                  activeIcon: Icons.settings_rounded,
                  label: 'Configurações',
                  isSelected: isSettings,
                  onTap: () => context.push('/settings'),
                  cs: cs,
                );
              },
            ),
          ),
        ],
      ),
    ).animate().slideX(
      begin: -0.4,
      end: 0,
      curve: Curves.easeOutCubic,
      duration: const Duration(milliseconds: 400),
    );
  }
}

class _CollapsedDrawerItem extends StatelessWidget {
  const _CollapsedDrawerItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.cs,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Tooltip(
        message: label,
        child: Material(
          color: isSelected ? cs.secondaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Center(
                child: Icon(
                  isSelected ? activeIcon : icon,
                  color: isSelected
                      ? cs.onSecondaryContainer
                      : cs.onSurfaceVariant,
                  size: 22,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.cs,
    required this.tt,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: isSelected ? cs.secondaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(
                  isSelected ? activeIcon : icon,
                  color: isSelected
                      ? cs.onSecondaryContainer
                      : cs.onSurfaceVariant,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: tt.labelLarge?.copyWith(
                    color: isSelected
                        ? cs.onSecondaryContainer
                        : cs.onSurfaceVariant,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Bottom nav item (shared) ────────────────────────────────────────────────

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
    final labelStyle = TextStyle(
      fontSize: 11,
      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
      letterSpacing: 0.3,
      color: isSelected ? cs.onSecondaryContainer : cs.onSurfaceVariant,
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
              return AnimatedSwitcher(
                duration: motion.fastDuration,
                transitionBuilder: (child, animation) =>
                    ScaleTransition(scale: animation, child: child),
                child: Icon(
                  isSelected ? activeIcon : icon,
                  key: ValueKey(isSelected),
                  color: color,
                  size: 22,
                ),
              );
            },
          ),
          const SizedBox(height: 3),
          AnimatedDefaultTextStyle(
            duration: motion.fastDuration,
            style: labelStyle,
            child: Text(label),
          ),
        ],
      ),
    );
  }
}

// ─── Sidebar shortcuts (below "Mais", after a divider) ───────────────────────

void _openShortcutsEditor(BuildContext context) {
  showAdaptiveModal<void>(
    context: context,
    builder: (_) => const SidebarShortcutsEditSheet(),
  );
}

/// Atalhos fixados exibidos nos drawers com rótulo (expandido e overlay médio),
/// logo abaixo das abas principais e após um separador.
class _SidebarShortcuts extends ConsumerWidget {
  const _SidebarShortcuts({required this.cs, required this.tt});

  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shortcuts = ref.watch(sidebarShortcutsProvider).value ?? const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Divider(
            height: 1,
            color: cs.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        for (final s in shortcuts)
          _DrawerItem(
            icon: s.icon,
            activeIcon: s.icon,
            label: s.label,
            isSelected: false,
            onTap: () => context.push(s.route),
            cs: cs,
            tt: tt,
          ),
        _DrawerItem(
          icon: Icons.add_rounded,
          activeIcon: Icons.add_rounded,
          label: shortcuts.isEmpty ? 'Adicionar atalho' : 'Editar atalhos',
          isSelected: false,
          onTap: () => _openShortcutsEditor(context),
          cs: cs,
          tt: tt,
        ),
      ],
    );
  }
}

/// Versão icon-only dos atalhos para o drawer recolhido (72px).
class _CollapsedSidebarShortcuts extends ConsumerWidget {
  const _CollapsedSidebarShortcuts({required this.cs});

  final ColorScheme cs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shortcuts = ref.watch(sidebarShortcutsProvider).value ?? const [];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          child: Divider(
            height: 1,
            color: cs.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        for (final s in shortcuts)
          _CollapsedDrawerItem(
            icon: s.icon,
            activeIcon: s.icon,
            label: s.label,
            isSelected: false,
            onTap: () => context.push(s.route),
            cs: cs,
          ),
        _CollapsedDrawerItem(
          icon: Icons.add_rounded,
          activeIcon: Icons.add_rounded,
          label: 'Atalhos',
          isSelected: false,
          onTap: () => _openShortcutsEditor(context),
          cs: cs,
        ),
      ],
    );
  }
}
