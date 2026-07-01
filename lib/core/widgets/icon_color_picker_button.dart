import 'package:flutter/material.dart';
import 'package:bestfin/core/utils/icon_mapper.dart';
import 'package:bestfin/core/widgets/color_picker.dart';

/// Button that opens a modal bottom sheet with combined icon + color picker.
/// Uses IconMapper string-name system for icons.
class IconColorPickerButton extends StatelessWidget {
  final String selectedIcon;
  final String selectedColorHex;
  final void Function(String icon, String color) onChanged;
  final String label;

  const IconColorPickerButton({
    super.key,
    required this.selectedIcon,
    required this.selectedColorHex,
    required this.onChanged,
    this.label = 'Personalizar',
  });

  static Color _hex(String hex) {
    final h = hex.replaceAll('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final color = _hex(selectedColorHex);
    final iconData = IconMapper.fromString(selectedIcon);

    return InkWell(
      onTap: () => _openSheet(context),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(iconData, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: tt.bodyMedium?.copyWith(color: cs.onSurface),
              ),
            ),
            Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  void _openSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _IconColorSheet(
        selectedIcon: selectedIcon,
        selectedColorHex: selectedColorHex,
        onConfirm: onChanged,
      ),
    );
  }
}

class _IconColorSheet extends StatefulWidget {
  final String selectedIcon;
  final String selectedColorHex;
  final void Function(String icon, String color) onConfirm;

  const _IconColorSheet({
    required this.selectedIcon,
    required this.selectedColorHex,
    required this.onConfirm,
  });

  @override
  State<_IconColorSheet> createState() => _IconColorSheetState();
}

class _IconColorSheetState extends State<_IconColorSheet> {
  late String _icon;
  late String _color;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _icon = widget.selectedIcon;
    _color = widget.selectedColorHex;
  }

  Map<String, List<MapEntry<String, IconData>>> get _displayMap {
    if (_query.isEmpty) return IconMapper.categorized;
    final q = _query.toLowerCase();
    final filtered = IconMapper.all.entries
        .where((e) => e.key.contains(q))
        .toList();
    return {'Resultados': filtered};
  }

  static Color _hex(String hex) {
    final h = hex.replaceAll('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final selectedColor = _hex(_color);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.65,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Handle(cs: cs),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: selectedColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: selectedColor, width: 2),
                      ),
                      child: Icon(
                        IconMapper.fromString(_icon),
                        color: selectedColor,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Personalizar',
                        style: tt.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    FilledButton(
                      onPressed: () {
                        widget.onConfirm(_icon, _color);
                        Navigator.pop(context);
                      },
                      child: const Text('Confirmar'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SearchBar(
                  hintText: 'Buscar ícone...',
                  leading: const Icon(Icons.search_rounded),
                  onChanged: (v) => setState(() => _query = v),
                  elevation: const WidgetStatePropertyAll(0),
                  backgroundColor: WidgetStatePropertyAll(
                    cs.surfaceContainerHighest,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  children: [
                    for (final entry in _displayMap.entries)
                      if (entry.value.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.only(top: 16, bottom: 8),
                          child: Text(
                            entry.key,
                            style: tt.labelLarge?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 6,
                                mainAxisSpacing: 8,
                                crossAxisSpacing: 8,
                              ),
                          itemCount: entry.value.length,
                          itemBuilder: (ctx, i) {
                            final e = entry.value[i];
                            final isSelected = _icon == e.key;
                            return GestureDetector(
                              onTap: () => setState(() => _icon = e.key),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? selectedColor.withValues(alpha: 0.15)
                                      : cs.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(12),
                                  border: isSelected
                                      ? Border.all(
                                          color: selectedColor,
                                          width: 2,
                                        )
                                      : null,
                                ),
                                child: Icon(
                                  e.value,
                                  size: 22,
                                  color: isSelected
                                      ? selectedColor
                                      : cs.onSurfaceVariant,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    const SizedBox(height: 20),
                    Text(
                      'Cor',
                      style: tt.labelLarge?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: AppColorPicker.colors.map((item) {
                        final isSelected =
                            item.$1.toLowerCase() == _color.toLowerCase();
                        final color = AppColorPicker.hexToColor(item.$1);
                        return Tooltip(
                          message: item.$2,
                          child: InkWell(
                            onTap: () => setState(() => _color = item.$1),
                            customBorder: const CircleBorder(),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected
                                      ? cs.outline
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: isSelected
                                  ? const Icon(
                                      Icons.check,
                                      color: Colors.white,
                                      size: 20,
                                    )
                                  : null,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
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

class _Handle extends StatelessWidget {
  final ColorScheme cs;
  const _Handle({required this.cs});

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      margin: const EdgeInsets.only(top: 12, bottom: 4),
      width: 36,
      height: 4,
      decoration: BoxDecoration(
        color: cs.onSurfaceVariant.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );
}
