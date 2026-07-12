import 'package:flutter/material.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.isFirst = false,
  });

  final String title;
  final bool isFirst;

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.textTheme;

    return Padding(
      padding: EdgeInsets.fromLTRB(4, isFirst ? 4 : 16, 4, 8),
      child: Text(
        title,
        style: tt.titleSmall?.copyWith(
          color: cs.onSurfaceVariant,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
