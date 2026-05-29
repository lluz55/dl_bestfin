import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../extensions/context_extensions.dart';
import 'theme_presets.dart';
import 'theme_provider.dart';

void showThemeSettingsSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const _ThemeSettingsSheet(),
  );
}

class _ThemeSettingsSheet extends ConsumerWidget {
  const _ThemeSettingsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(themeProvider);
    final notifier = ref.read(themeProvider.notifier);
    final cs = context.colorScheme;
    final tt = context.textTheme;

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
            Text(
              'Aparência',
              style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 20),
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
                        _SectionLabel('Paleta de cores', cs: cs, tt: tt),
                        const SizedBox(height: 12),
                        _PresetGrid(
                          selected: state.preset,
                          onSelected: notifier.setPreset,
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
        ),
      ),
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

// ─── Preset color grid ────────────────────────────────────────────────────────

class _PresetGrid extends StatelessWidget {
  const _PresetGrid({required this.selected, required this.onSelected});

  final ThemePreset selected;
  final Future<void> Function(ThemePreset) onSelected;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final preset in ThemePreset.values)
          _PresetSwatch(
            preset: preset,
            isSelected: selected == preset,
            brightness: brightness,
            onTap: () => onSelected(preset),
          ),
      ],
    );
  }
}

class _PresetSwatch extends StatelessWidget {
  const _PresetSwatch({
    required this.preset,
    required this.isSelected,
    required this.brightness,
    required this.onTap,
  });

  final ThemePreset preset;
  final bool isSelected;
  final Brightness brightness;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = brightness == Brightness.dark
        ? preset.dark()
        : preset.light();
    final ring = isSelected;

    return Tooltip(
      message: preset.label,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutBack,
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: ring ? scheme.primary : Colors.transparent,
              width: ring ? 3 : 0,
            ),
          ),
          padding: EdgeInsets.all(ring ? 4 : 0),
          child: _ColorCircle(scheme: scheme, isSelected: isSelected),
        ),
      ),
    );
  }
}

class _ColorCircle extends StatelessWidget {
  const _ColorCircle({required this.scheme, required this.isSelected});

  final ColorScheme scheme;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: SizedBox.expand(
        child: Stack(
          children: [
            // Quadrante esquerdo: primary
            Positioned.fill(
              child: Row(
                children: [
                  Expanded(child: ColoredBox(color: scheme.primary)),
                  Expanded(child: ColoredBox(color: scheme.secondary)),
                ],
              ),
            ),
            // Check mark
            if (isSelected)
              Center(
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: scheme.onPrimary, width: 2),
                  ),
                  child: Icon(
                    Icons.check_rounded,
                    size: 12,
                    color: scheme.onPrimary,
                  ),
                ),
              ),
          ],
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
