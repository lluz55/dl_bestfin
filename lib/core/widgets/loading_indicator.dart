import 'package:flutter/material.dart';

import '../extensions/context_extensions.dart';

class AppLoadingIndicator extends StatelessWidget {
  const AppLoadingIndicator({super.key, this.value, this.strokeWidth = 4.0});

  final double? value;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return CircularProgressIndicator(
      value: value,
      strokeWidth: strokeWidth,
      valueColor: AlwaysStoppedAnimation<Color>(context.colorScheme.primary),
      backgroundColor: context.colorScheme.surfaceContainerHighest,
      strokeCap: StrokeCap.round,
    );
  }
}
