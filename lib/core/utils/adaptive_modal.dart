import 'package:flutter/material.dart';
import 'package:bestfin/core/theme/breakpoints.dart';
import 'package:bestfin/core/widgets/adaptive_modal_panel.dart';

/// Fração de altura padrão dos bottom sheets no mobile — mesmo limite do
/// formulário de adicionar/editar transação.
const double kAppSheetMaxHeightFraction = 0.65;

/// Raio padrão do topo dos bottom sheets — mesmo formato do formulário de
/// adicionar/editar transação.
const BorderRadius kAppSheetBorderRadius = BorderRadius.vertical(
  top: Radius.circular(28),
);

/// Bottom sheet com o chrome padrão do app (padrão do formulário de
/// transação): fundo transparente, cantos arredondados de 28 no topo e altura
/// limitada a [maxHeightFraction] da tela (65% por padrão; `null` desativa o
/// limite). O conteúdo recebe um `Material` com a cor de superfície padrão de
/// sheets, então builders não precisam pintar o próprio fundo.
Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool useSafeArea = true,
  double? maxHeightFraction = kAppSheetMaxHeightFraction,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: useSafeArea,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      Widget child = Material(
        color: Theme.of(sheetContext).colorScheme.surfaceContainerLow,
        child: builder(sheetContext),
      );
      if (maxHeightFraction != null) {
        child = ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * maxHeightFraction,
          ),
          child: child,
        );
      }
      return ClipRRect(borderRadius: kAppSheetBorderRadius, child: child);
    },
  );
}

/// Apresentação modal padrão do app: bottom sheet com chrome padrão
/// ([showAppBottomSheet]) em telas compactas e painel flutuante
/// ([AdaptiveModalPanel]) em telas largas.
Future<T?> showAdaptiveModal<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool useSafeArea = true,
  double? maxHeightFraction,
}) {
  if (Breakpoints.isCompact(context)) {
    return showAppBottomSheet<T>(
      context: context,
      builder: builder,
      useSafeArea: useSafeArea,
      maxHeightFraction: maxHeightFraction ?? kAppSheetMaxHeightFraction,
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
