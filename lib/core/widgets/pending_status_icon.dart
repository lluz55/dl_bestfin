import 'package:flutter/material.dart';

/// Indicador do status pendente de uma transação. Só desenha algo quando a
/// transação **não está confirmada** (pendente): um ícone de alerta que entra
/// e sai de forma animada. Transações confirmadas não recebem ícone algum —
/// confirmado é o estado neutro.
///
/// O relógio é reservado exclusivamente a transações futuras (agendadas); como
/// o toggle "Pendente" só aparece em datas de hoje/passadas, aqui o estado
/// pendente é uma pendência vencida e usa o ícone de alerta.
///
/// Reusado no formulário de transação, no lançamento rápido e na inserção em
/// massa para manter o mesmo comportamento visual.
class PendingStatusIcon extends StatelessWidget {
  final bool isPending;
  final Color color;
  final double size;

  const PendingStatusIcon({
    super.key,
    required this.isPending,
    required this.color,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      switchInCurve: Curves.easeOutBack,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: animation, child: child),
        );
      },
      child: isPending
          ? Icon(
              Icons.error_outline_rounded,
              key: const ValueKey('pending'),
              size: size,
              color: color,
            )
          // Confirmada: nada a mostrar (estado neutro).
          : const SizedBox.shrink(key: ValueKey('confirmed')),
    );
  }
}
