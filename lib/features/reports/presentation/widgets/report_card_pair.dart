import 'package:flutter/material.dart';
import 'package:bestfin/core/theme/breakpoints.dart';

/// Coloca dois cards lado a lado (2 colunas) em telas grandes (wide),
/// e empilhados verticalmente em telas menores.
class ReportCardPair extends StatelessWidget {
  const ReportCardPair({
    super.key,
    required this.first,
    required this.second,
    this.spacing = 16,
  });

  final Widget first;
  final Widget second;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    if (Breakpoints.isWide(context)) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: first),
          SizedBox(width: spacing),
          Expanded(child: second),
        ],
      );
    }
    return Column(
      children: [
        first,
        SizedBox(height: spacing),
        second,
      ],
    );
  }
}
