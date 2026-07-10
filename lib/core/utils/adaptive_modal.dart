import 'package:flutter/material.dart';
import 'package:bestfin/core/theme/breakpoints.dart';
import 'package:bestfin/core/widgets/adaptive_modal_panel.dart';

Future<T?> showAdaptiveModal<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  bool useSafeArea = true,
  double? maxHeightFraction,
}) {
  if (Breakpoints.isCompact(context)) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      useSafeArea: useSafeArea,
      builder: builder,
    );
  }

  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: false,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.transparent,
    transitionDuration: Duration.zero,
    pageBuilder: (context, animation, secondaryAnimation) {
      return _AdaptiveModalDialog(
        builder: builder,
        maxHeightFraction: maxHeightFraction,
      );
    },
  );
}

class _AdaptiveModalDialog extends StatelessWidget {
  const _AdaptiveModalDialog({required this.builder, this.maxHeightFraction});

  final WidgetBuilder builder;
  final double? maxHeightFraction;

  @override
  Widget build(BuildContext context) {
    return AdaptiveModalPanel(
      onClose: () => Navigator.of(context).pop(),
      maxHeightFraction: maxHeightFraction ?? 0.6,
      builder: (context, requestClose) => builder(context),
    );
  }
}
