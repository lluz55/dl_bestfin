import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';

class AppColorPicker extends StatefulWidget {
  const AppColorPicker({
    super.key,
    required this.selectedColorHex,
    required this.onColorSelected,
    this.previewIcon,
  });

  final String selectedColorHex;
  final ValueChanged<String> onColorSelected;
  final IconData? previewIcon;

  static const List<(String hex, String label)> colors = [
    ('#2196F3', 'Azul'),
    ('#4CAF50', 'Verde'),
    ('#FF9800', 'Laranja'),
    ('#009688', 'Teal'),
    ('#9C27B0', 'Roxo'),
    ('#F44336', 'Vermelho'),
    ('#E91E63', 'Rosa'),
    ('#00BCD4', 'Ciano'),
    ('#FFC107', 'Amarelo'),
    ('#795548', 'Marrom'),
    ('#607D8B', 'Slate'),
    ('#8BC34A', 'Lima'),
  ];

  static Color hexToColor(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  static String colorToHex(Color color) {
    return '#${color.r.toInt().toRadixString(16).padLeft(2, '0')}${color.g.toInt().toRadixString(16).padLeft(2, '0')}${color.b.toInt().toRadixString(16).padLeft(2, '0')}'
        .toUpperCase();
  }

  @override
  State<AppColorPicker> createState() => _AppColorPickerState();
}

class _AppColorPickerState extends State<AppColorPicker> {
  bool get _isCustom => !AppColorPicker.colors.any(
    (c) => c.$1.toLowerCase() == widget.selectedColorHex.toLowerCase(),
  );

  Future<void> _openCustomPicker() async {
    Color pickerColor = AppColorPicker.hexToColor(widget.selectedColorHex);
    Color confirmedColor = pickerColor;

    final picked = await showDialog<Color>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Escolha uma cor'),
        content: SingleChildScrollView(
          child: StatefulBuilder(
            builder: (_, setState) => ColorPicker(
              pickerColor: pickerColor,
              onColorChanged: (c) {
                setState(() => pickerColor = c);
                confirmedColor = c;
              },
              enableAlpha: false,
              labelTypes: const [],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(confirmedColor),
            child: const Text('OK'),
          ),
        ],
      ),
    );

    if (picked != null) {
      widget.onColorSelected(AppColorPicker.colorToHex(picked));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final cs = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.previewIcon != null) ...[
          Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColorPicker.hexToColor(
                  widget.selectedColorHex,
                ).withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColorPicker.hexToColor(widget.selectedColorHex),
                  width: 2,
                ),
              ),
              child: Icon(
                widget.previewIcon,
                size: 32,
                color: AppColorPicker.hexToColor(widget.selectedColorHex),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
        Text(
          'Selecione uma cor',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            ...AppColorPicker.colors.map((item) {
              final isSelected =
                  item.$1.toLowerCase() ==
                  widget.selectedColorHex.toLowerCase();
              final color = AppColorPicker.hexToColor(item.$1);

              return Tooltip(
                message: item.$2,
                child: InkWell(
                  onTap: () => widget.onColorSelected(item.$1),
                  customBorder: const CircleBorder(),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? cs.outline : cs.outlineVariant,
                        width: isSelected ? 2.5 : 1,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 20)
                        : null,
                  ),
                ),
              );
            }),
            // Custom color swatch
            Tooltip(
              message: 'Cor personalizada',
              child: InkWell(
                onTap: _openCustomPicker,
                customBorder: const CircleBorder(),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _isCustom
                        ? AppColorPicker.hexToColor(widget.selectedColorHex)
                        : cs.surfaceContainerHighest,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _isCustom ? cs.outline : cs.outlineVariant,
                      width: _isCustom ? 2.5 : 1.5,
                    ),
                  ),
                  child: _isCustom
                      ? const Icon(Icons.check, color: Colors.white, size: 20)
                      : Icon(Icons.add, color: cs.onSurfaceVariant, size: 20),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
