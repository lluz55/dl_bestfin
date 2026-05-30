import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/providers/privacy_provider.dart';
import 'package:bestfin/core/theme/typography.dart';

const _maskedValue = 'R\$ •••••';

class AmountDisplay extends ConsumerWidget {
  const AmountDisplay({
    super.key,
    required this.amountInCents,
    this.style,
    this.color,
    this.showSign = true,
  });

  /// The amount in cents. Positive for income, negative for expense.
  final int amountInCents;
  final TextStyle? style;
  final Color? color;
  final bool showSign;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hidden = ref.watch(valuesHiddenProvider);
    final baseStyle = (style ?? context.textTheme.titleMedium)?.merge(
      AppTypography.monospace,
    );

    if (hidden) {
      return Text(
        _maskedValue,
        style: baseStyle?.copyWith(
          color: context.colorScheme.onSurface.withValues(alpha: 0.4),
        ),
      );
    }

    final double amount = amountInCents / 100.0;
    final isNegative = amount < 0;
    final isPositive = amount > 0;

    // Prioridade de cor:
    // 1. Parâmetro color explícito
    // 2. Cor definida no style
    // 3. Lógica automática baseada no sinal
    Color finalColor = color ?? style?.color ?? context.colorScheme.onSurface;

    if (color == null && style?.color == null) {
      if (isPositive) {
        finalColor = context.customColors.income;
      } else if (isNegative) {
        finalColor = context.customColors.expense;
      }
    }

    final String formattedValue =
        'R\$ ${amount.abs().toStringAsFixed(2).replaceAll('.', ',')}';

    final String sign = (isNegative && showSign)
        ? '- '
        : (isPositive && showSign ? '+ ' : '');

    return Text(
      '$sign$formattedValue',
      style: baseStyle?.copyWith(color: finalColor),
    );
  }
}
