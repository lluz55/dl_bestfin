import 'package:flutter/material.dart';

import 'package:bestfin/core/extensions/context_extensions.dart';

/// Wrapper para o painel de detalhe em layouts master-detail.
///
/// Quando [keyValue] muda, o conteúdo desliza rapidamente da esquerda
/// (direção da barra de navegação/master) com um fade sutil, usando
/// [ExpressiveMotion.fastDuration] para a transição.
class AnimatedDetailPanel extends StatelessWidget {
  const AnimatedDetailPanel({
    super.key,
    required this.keyValue,
    required this.child,
  });

  final Object? keyValue;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final motion = context.motion;

    return AnimatedSwitcher(
      duration: motion.fastDuration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(-0.12, 0),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          ),
          child: FadeTransition(opacity: animation, child: child),
        );
      },
      child: KeyedSubtree(key: ValueKey(keyValue), child: child),
    );
  }
}
