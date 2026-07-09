import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../extensions/context_extensions.dart';
import '../utils/adaptive_modal.dart';
import 'custom_seed_provider.dart';
import 'theme_provider.dart';

void showThemeSettingsSheet(BuildContext context) {
  showAdaptiveModal<void>(
    context: context,
    builder: (_) => const _ThemeSettingsSheet(),
  );
}

class _ThemeSettingsSheet extends StatelessWidget {
  const _ThemeSettingsSheet();

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurfaceVariant.withAlpha(80),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const ThemeSettingsView(),
          ],
        ),
      ),
    );
  }
}

/// Conteúdo reutilizável do editor de aparência. Usado tanto no modal
/// (telas compactas) quanto no painel de detalhe da coluna direita em
/// telas grandes (master-detail), por isso não inclui o handle do modal.
class ThemeSettingsView extends ConsumerWidget {
  const ThemeSettingsView({super.key, this.showTitle = true});

  final bool showTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(themeProvider);
    final customSeed = ref.watch(customSeedProvider);
    final notifier = ref.read(themeProvider.notifier);
    final customNotifier = ref.read(customSeedProvider.notifier);
    final cs = context.colorScheme;
    final tt = context.textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showTitle) ...[
          Text(
            'Aparência',
            style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 20),
        ],
        _SectionLabel('Modo de cor', cs: cs, tt: tt),
        const SizedBox(height: 8),
        _DynamicColorToggle(
          enabled: state.useDynamicColor,
          onChanged: notifier.setDynamicColor,
          cs: cs,
          tt: tt,
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOutCubic,
          child: state.useDynamicColor
              ? const SizedBox.shrink()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    _SectionLabel('Cor personalizada', cs: cs, tt: tt),
                    const SizedBox(height: 12),
                    _CustomColorPicker(
                      currentColor: customSeed.seedColor,
                      onColorSelected: customNotifier.setSeedColor,
                      cs: cs,
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 20),
        _SectionLabel('Brilho', cs: cs, tt: tt),
        const SizedBox(height: 8),
        _ThemeModeSelector(
          current: state.mode,
          onSelected: notifier.setMode,
          cs: cs,
        ),
      ],
    );
  }
}

// ─── Section label ───────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label, {required this.cs, required this.tt});

  final String label;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: tt.labelSmall?.copyWith(
        color: cs.onSurfaceVariant,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }
}

// ─── Custom color picker ─────────────────────────────────────────────────────

class _CustomColorPicker extends StatelessWidget {
  const _CustomColorPicker({
    required this.currentColor,
    required this.onColorSelected,
    required this.cs,
  });

  final Color? currentColor;
  final ValueChanged<Color> onColorSelected;
  final ColorScheme cs;

  static const _presetColors = [
    Color(0xFF3D5AFE),
    Color(0xFF00897B),
    Color(0xFF0277BD),
    Color(0xFF7C4DFF),
    Color(0xFFE91E63),
    Color(0xFFE53935),
    Color(0xFFFFA000),
    Color(0xFF546E7A),
    Color(0xFFFF6D00),
    Color(0xFF43A047),
    Color(0xFF7B1FA2),
    Color(0xFF0097A7),
    Color(0xFF6D4C41),
    Color(0xFF9E9D24),
    Color(0xFF000000),
    Color(0xFFFFFFFF),
  ];

  @override
  Widget build(BuildContext context) {
    final color = currentColor ?? cs.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => _openColorPicker(context, color),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: cs.outlineVariant.withValues(alpha: 0.3),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Escolher cor',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                      ),
                      Text(
                        '#${color.value.toRadixString(16).substring(2).toUpperCase()}',
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final preset in _presetColors)
              GestureDetector(
                onTap: () => onColorSelected(preset),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: preset,
                    borderRadius: BorderRadius.circular(10),
                    border: color.value == preset.value
                        ? Border.all(color: cs.onSurface, width: 2.5)
                        : Border.all(color: cs.outlineVariant, width: 1),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  void _openColorPicker(BuildContext context, Color current) {
    Color pickerColor = current;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Escolha uma cor'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: pickerColor,
            onColorChanged: (color) => pickerColor = color,
            enableAlpha: false,
            labelTypes: const [],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              onColorSelected(pickerColor);
              Navigator.of(context).pop();
            },
            child: const Text('Aplicar'),
          ),
        ],
      ),
    );
  }
}

// ─── Dynamic color toggle ─────────────────────────────────────────────────────

class _DynamicColorToggle extends StatelessWidget {
  const _DynamicColorToggle({
    required this.enabled,
    required this.onChanged,
    required this.cs,
    required this.tt,
  });

  final bool enabled;
  final Future<void> Function(bool) onChanged;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => onChanged(!enabled),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: enabled
                      ? cs.primaryContainer
                      : cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.wallpaper_rounded,
                  size: 20,
                  color: enabled ? cs.onPrimaryContainer : cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cores do papel de parede',
                      style: tt.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Material You — Android 12+',
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Switch(value: enabled, onChanged: onChanged),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Theme mode selector ──────────────────────────────────────────────────────

class _ThemeModeSelector extends StatelessWidget {
  const _ThemeModeSelector({
    required this.current,
    required this.onSelected,
    required this.cs,
  });

  final ThemeMode current;
  final Future<void> Function(ThemeMode) onSelected;
  final ColorScheme cs;

  static const _options = [
    (
      mode: ThemeMode.system,
      icon: Icons.brightness_auto_rounded,
      label: 'Sistema',
    ),
    (mode: ThemeMode.light, icon: Icons.light_mode_rounded, label: 'Claro'),
    (mode: ThemeMode.dark, icon: Icons.dark_mode_rounded, label: 'Escuro'),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (int i = 0; i < _options.length; i++) ...[
          Expanded(
            child: _ModeChip(
              icon: _options[i].icon,
              label: _options[i].label,
              selected: current == _options[i].mode,
              onTap: () => onSelected(_options[i].mode),
              cs: cs,
            ),
          ),
          if (i < _options.length - 1) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.cs,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? cs.primaryContainer : cs.surfaceContainerHigh;
    final fg = selected ? cs.onPrimaryContainer : cs.onSurfaceVariant;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: selected
            ? Border.all(color: cs.primary, width: 2)
            : Border.all(color: Colors.transparent, width: 2),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Icon(icon, color: fg, size: 22),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
