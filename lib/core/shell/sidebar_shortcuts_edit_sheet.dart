import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/providers/sidebar_shortcuts_provider.dart';
import 'package:bestfin/core/shell/nav_shortcut.dart';
import 'package:bestfin/core/widgets/app_button.dart';

/// Modal para escolher quais atalhos aparecem na barra lateral, abaixo das
/// abas principais.
class SidebarShortcutsEditSheet extends ConsumerStatefulWidget {
  const SidebarShortcutsEditSheet({super.key});

  @override
  ConsumerState<SidebarShortcutsEditSheet> createState() =>
      _SidebarShortcutsEditSheetState();
}

class _SidebarShortcutsEditSheetState
    extends ConsumerState<SidebarShortcutsEditSheet> {
  late Set<NavShortcut> _selected;

  @override
  void initState() {
    super.initState();
    _selected = (ref.read(sidebarShortcutsProvider).value ?? const []).toSet();
  }

  void _toggle(NavShortcut shortcut) {
    HapticFeedback.selectionClick();
    setState(() {
      if (!_selected.remove(shortcut)) _selected.add(shortcut);
    });
  }

  void _save() {
    ref.read(sidebarShortcutsProvider.notifier).save(_selected.toList());
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.textTheme;
    final shapes = context.shapes;

    return Container(
      padding: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: shapes.bottomSheet,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Atalhos da barra lateral',
              style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Fixe funcionalidades da página "Mais" para acessá-las direto do menu.',
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 12),
          Flexible(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shrinkWrap: true,
              children: [
                for (final shortcut in NavShortcut.values)
                  _ShortcutToggleTile(
                    shortcut: shortcut,
                    selected: _selected.contains(shortcut),
                    onTap: () => _toggle(shortcut),
                    cs: cs,
                    tt: tt,
                  ),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: AppButton(
                label: 'Salvar',
                expanded: true,
                onPressed: _save,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShortcutToggleTile extends StatelessWidget {
  const _ShortcutToggleTile({
    required this.shortcut,
    required this.selected,
    required this.onTap,
    required this.cs,
    required this.tt,
  });

  final NavShortcut shortcut;
  final bool selected;
  final VoidCallback onTap;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected ? cs.secondaryContainer : cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(
                  shortcut.icon,
                  size: 22,
                  color: selected
                      ? cs.onSecondaryContainer
                      : cs.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    shortcut.label,
                    style: tt.bodyLarge?.copyWith(
                      color: selected ? cs.onSecondaryContainer : cs.onSurface,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.add_circle_outline_rounded,
                  size: 20,
                  color: selected ? cs.primary : cs.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
