import 'package:flutter/material.dart';
import 'package:bestfin/features/recurring/domain/models/recurring_rule.dart';

/// Seletor visual de frequência com chips animados.
class FrequencySelector extends StatelessWidget {
  final RecurringFrequency selected;
  final ValueChanged<RecurringFrequency> onChanged;

  const FrequencySelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: RecurringFrequency.values.map((freq) {
        final isSelected = freq == selected;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          child: ChoiceChip(
            label: Text(freq.label),
            selected: isSelected,
            onSelected: (_) => onChanged(freq),
            selectedColor: cs.primaryContainer,
            backgroundColor: cs.surfaceContainerHigh,
            labelStyle: tt.labelMedium?.copyWith(
              color: isSelected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
            ),
            side: BorderSide(
              color: isSelected
                  ? cs.primary.withValues(alpha: 0.4)
                  : cs.outlineVariant.withValues(alpha: 0.3),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            showCheckmark: false,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          ),
        );
      }).toList(),
    );
  }
}
