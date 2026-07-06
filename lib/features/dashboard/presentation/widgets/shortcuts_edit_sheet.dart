import 'package:flutter/material.dart';
import 'package:bestfin/core/widgets/app_button.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/features/dashboard/domain/models/app_shortcut.dart';
import 'package:bestfin/features/dashboard/presentation/providers/shortcuts_provider.dart';

class ShortcutsEditSheet extends ConsumerStatefulWidget {
  const ShortcutsEditSheet({super.key});

  @override
  ConsumerState<ShortcutsEditSheet> createState() => _ShortcutsEditSheetState();
}

class _ShortcutsEditSheetState extends ConsumerState<ShortcutsEditSheet> {
  late List<AppShortcut> _selectedShortcuts;

  @override
  void initState() {
    super.initState();
    final currentShortcuts = ref.read(shortcutsProvider).value ?? [];
    _selectedShortcuts = List.from(currentShortcuts);
  }

  void _toggleShortcut(AppShortcut shortcut) {
    setState(() {
      if (_selectedShortcuts.contains(shortcut)) {
        _selectedShortcuts.remove(shortcut);
      } else {
        if (_selectedShortcuts.length < 4) {
          _selectedShortcuts.add(shortcut);
        } else {
          final cs = context.colorScheme;
          final tt = context.textTheme;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: cs.errorContainer,
              shape: RoundedRectangleBorder(borderRadius: context.shapes.card),
              content: Text(
                'Máximo de 4 atalhos atingido.',
                style: tt.bodyMedium?.copyWith(color: cs.onErrorContainer),
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    });
  }

  void _save() {
    ref.read(shortcutsProvider.notifier).saveShortcuts(_selectedShortcuts);
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.textTheme;
    final shapes = context.shapes;
    final motion = context.motion;
    final isFull = _selectedShortcuts.length == 4;

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
          // Drag handle
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

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Editar Atalhos',
                    style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                AnimatedSwitcher(
                  duration: motion.fastDuration,
                  transitionBuilder: (child, animation) =>
                      ScaleTransition(scale: animation, child: child),
                  child: Container(
                    key: ValueKey(_selectedShortcuts.length),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isFull
                          ? cs.primaryContainer
                          : cs.surfaceContainerHighest,
                      borderRadius: shapes.chipSelected,
                    ),
                    child: Text(
                      '${_selectedShortcuts.length}/4',
                      style: tt.labelSmall?.copyWith(
                        color: isFull
                            ? cs.onPrimaryContainer
                            : cs.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Escolha até 4 atalhos para a página inicial.',
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 16),

          // Chips grid
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (int i = 0; i < AppShortcut.values.length; i++)
                    _ShortcutChip(
                      shortcut: AppShortcut.values[i],
                      isSelected: _selectedShortcuts.contains(
                        AppShortcut.values[i],
                      ),
                      onTap: () => _toggleShortcut(AppShortcut.values[i]),
                      delay: motion.staggerInterval * i,
                    ),
                ],
              ),
            ),
          ),

          // Save button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
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

class _ShortcutChip extends StatefulWidget {
  const _ShortcutChip({
    required this.shortcut,
    required this.isSelected,
    required this.onTap,
    required this.delay,
  });

  final AppShortcut shortcut;
  final bool isSelected;
  final VoidCallback onTap;
  final Duration delay;

  @override
  State<_ShortcutChip> createState() => _ShortcutChipState();
}

class _ShortcutChipState extends State<_ShortcutChip> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.textTheme;
    final shapes = context.shapes;
    final motion = context.motion;
    final color = widget.shortcut.getColor(cs);
    final isSelected = widget.isSelected;

    final chip = GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: motion.fastDuration,
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: motion.morphDuration,
          curve: motion.morphCurve,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? color : color.withValues(alpha: 0.1),
            borderRadius: isSelected ? shapes.chipSelected : shapes.chip,
            border: Border.all(
              color: isSelected
                  ? Colors.transparent
                  : color.withValues(alpha: 0.25),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: motion.fastDuration,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.2)
                      : color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  widget.shortcut.icon,
                  size: 16,
                  color: isSelected ? Colors.white : color,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                widget.shortcut.label,
                style: tt.labelMedium?.copyWith(
                  color: isSelected ? Colors.white : cs.onSurface,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return chip
        .animate(delay: widget.delay)
        .fadeIn(duration: motion.fastDuration)
        .scaleXY(begin: 0.88, end: 1.0, curve: Curves.easeOutBack);
  }
}
