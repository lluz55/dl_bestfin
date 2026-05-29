import 'package:flutter/material.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';

class InstallmentProgressWidget extends StatelessWidget {
  final int paid;
  final int total;

  const InstallmentProgressWidget({
    super.key,
    required this.paid,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.textTheme;
    final progress = total == 0 ? 0.0 : paid / total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: cs.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '$paid de $total parcelas pagas',
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}
