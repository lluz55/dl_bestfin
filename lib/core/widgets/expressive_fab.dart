import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/theme/dimens.dart';

class ExpressiveFAB extends StatefulWidget {
  /// FAB com interação de confirmação em dois toques: o primeiro expande
  /// revelando o label, o segundo dispara [onPressed]. Long-press dispara
  /// imediatamente.
  const ExpressiveFAB({
    super.key,
    required this.onPressed,
    this.icon = Icons.add,
    this.label = 'Nova transação',
  }) : expandOnTap = true;

  /// FAB sempre expandido com toque único — substituto padronizado do
  /// [FloatingActionButton.extended].
  const ExpressiveFAB.extended({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.label,
  }) : expandOnTap = false;

  final VoidCallback onPressed;
  final IconData icon;
  final String label;

  /// Se `true` (default), o primeiro toque expande e o segundo confirma.
  /// Se `false`, o FAB nasce expandido e dispara no primeiro toque.
  final bool expandOnTap;

  @override
  State<ExpressiveFAB> createState() => _ExpressiveFABState();
}

class _ExpressiveFABState extends State<ExpressiveFAB>
    with SingleTickerProviderStateMixin {
  late bool _expanded = !widget.expandOnTap;
  bool _pressed = false;
  late final AnimationController _rotateCtrl;

  @override
  void initState() {
    super.initState();
    _rotateCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _rotateCtrl.dispose();
    super.dispose();
  }

  void _toggle() {
    HapticFeedback.lightImpact();
    if (!widget.expandOnTap) {
      widget.onPressed();
      return;
    }
    if (_expanded) {
      widget.onPressed();
      setState(() => _expanded = false);
      _rotateCtrl.reverse();
    } else {
      setState(() => _expanded = true);
      _rotateCtrl.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final shapes = context.shapes;
    final motion = context.motion;
    final tt = context.textTheme;

    final targetRadius = _expanded ? shapes.fabExpanded : shapes.fabDefault;
    final bgColor = cs.primaryContainer;
    final fgColor = cs.onPrimaryContainer;

    return GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) {
            setState(() => _pressed = false);
            _toggle();
          },
          onTapCancel: () => setState(() => _pressed = false),
          onLongPress: widget.onPressed,
          child: AnimatedScale(
            scale: _pressed ? 0.94 : 1.0,
            duration: motion.fastDuration,
            curve: Curves.easeOut,
            child: AnimatedContainer(
              duration: motion.morphDuration,
              curve: motion.morphCurve,
              height: AppDimens.fabHeight,
              // Largura intrínseca: colapsado = 16 + ícone 24 + 16 = 56;
              // expandido acomoda qualquer label sem largura fixa.
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: targetRadius,
              ),
              child: ClipRRect(
                borderRadius: targetRadius,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedRotation(
                      turns: widget.expandOnTap && _expanded ? 0.125 : 0,
                      duration: motion.morphDuration,
                      curve: motion.morphCurve,
                      child: Icon(widget.icon, color: fgColor, size: 24),
                    ),
                    AnimatedSize(
                      duration: motion.morphDuration,
                      curve: motion.morphCurve,
                      child: _expanded
                          ? Row(
                              children: [
                                const SizedBox(width: 10),
                                Text(
                                  widget.label,
                                  style: tt.labelLarge?.copyWith(
                                    color: fgColor,
                                  ),
                                ),
                                const SizedBox(width: 4),
                              ],
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        )
        .animate()
        .scaleXY(
          begin: 0.0,
          end: 1.0,
          curve: Curves.easeOutBack,
          duration: const Duration(milliseconds: 400),
          delay: const Duration(milliseconds: 300),
        )
        .fadeIn(duration: const Duration(milliseconds: 200));
  }
}
