import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/theme/breakpoints.dart';
import 'package:bestfin/core/theme/motion.dart';

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

class ResponsiveNavigation extends StatefulWidget {
  const ResponsiveNavigation({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    required this.body,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.bottomOverlay,
    this.lastDestinationKey,
  });

  final int selectedIndex;
  final void Function(int) onDestinationSelected;
  final List<NavigationDestinationItem> destinations;
  final Widget body;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Widget? bottomOverlay;
  final GlobalKey? lastDestinationKey;

  @override
  State<ResponsiveNavigation> createState() => _ResponsiveNavigationState();
}

class _ResponsiveNavigationState extends State<ResponsiveNavigation> {
  bool _isCollapsed = false;

  static const _prefsKey = 'sidebar_collapsed';

  @override
  void initState() {
    super.initState();
    _loadCollapsed();
  }

  Future<void> _loadCollapsed() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _isCollapsed = prefs.getBool(_prefsKey) ?? false;
    });
  }

  Future<void> _toggleCollapsed() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isCollapsed = !_isCollapsed;
    });
    await prefs.setBool(_prefsKey, _isCollapsed);
  }

  void _onTap(int index) {
    HapticFeedback.selectionClick();
    widget.onDestinationSelected(index);
  }

  @override
  Widget build(BuildContext context) {
    if (Breakpoints.isExpanded(context)) {
      return _ExpandedLayout(
        selectedIndex: widget.selectedIndex,
        onDestinationSelected: _onTap,
        destinations: widget.destinations,
        body: widget.body,
        floatingActionButton: widget.floatingActionButton,
        bottomOverlay: widget.bottomOverlay,
        isCollapsed: _isCollapsed,
        onToggleCollapsed: _toggleCollapsed,
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
      lastDestinationKey: widget.lastDestinationKey,
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
    this.lastDestinationKey,
  });

  final int selectedIndex;
  final void Function(int) onDestinationSelected;
  final List<NavigationDestinationItem> destinations;
  final Widget body;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Widget? bottomOverlay;
  final GlobalKey? lastDestinationKey;

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
              bottom: 96 + MediaQuery.paddingOf(context).bottom,
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
        lastItemKey: lastDestinationKey,
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
                child: Container(color: Colors.black45),
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
                    style: IconButton.styleFrom(
                      foregroundColor: cs.onSurfaceVariant,
                    ),
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
              ],
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
    this.lastItemKey,
  });

  final int selectedIndex;
  final void Function(int) onDestinationSelected;
  final List<NavigationDestinationItem> destinations;
  final ColorScheme cs;
  final GlobalKey? lastItemKey;

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
                        key: (i == destinations.length - 1)
                            ? lastItemKey
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
                    style: IconButton.styleFrom(
                      foregroundColor: cs.onSurfaceVariant,
                    ),
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
              ],
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
          Center(
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [cs.primary, cs.secondary]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.account_balance_wallet_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (onExpand != null)
            IconButton(
              onPressed: onExpand,
              icon: const Icon(Icons.chevron_right_rounded, size: 20),
              visualDensity: VisualDensity.compact,
              tooltip: 'Expandir menu',
              style: IconButton.styleFrom(foregroundColor: cs.onSurfaceVariant),
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
              ],
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
