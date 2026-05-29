import 'package:flutter/material.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';

class AppColorPicker extends StatelessWidget {
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

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (previewIcon != null) ...[
          Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: hexToColor(selectedColorHex).withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(
                  color: hexToColor(selectedColorHex),
                  width: 2,
                ),
              ),
              child: Icon(
                previewIcon,
                size: 32,
                color: hexToColor(selectedColorHex),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
        Text(
          'Selecione uma cor',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: colors.map((item) {
            final isSelected =
                item.$1.toLowerCase() == selectedColorHex.toLowerCase();
            final color = hexToColor(item.$1);

            return Tooltip(
              message: item.$2,
              child: InkWell(
                onTap: () => onColorSelected(item.$1),
                customBorder: const CircleBorder(),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: color.withValues(alpha: 0.4),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                    border: Border.all(
                      color: isSelected
                          ? theme.colorScheme.outline
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white, size: 20)
                      : null,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
