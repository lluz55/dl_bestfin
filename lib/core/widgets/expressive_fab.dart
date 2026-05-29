import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../extensions/context_extensions.dart';

class ExpressiveFAB extends StatefulWidget {
  const ExpressiveFAB({
    super.key,
    required this.onPressed,
    this.icon = Icons.add,
    this.label = 'Nova transação',
  });

  final VoidCallback onPressed;
  final IconData icon;
  final String label;

  @override
  State<ExpressiveFAB> createState() => _ExpressiveFABState();
}

class _ExpressiveFABState extends State<ExpressiveFAB>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
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
              height: 56,
              width: _expanded ? 196 : 56,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: targetRadius,
                boxShadow: [
                  BoxShadow(
                    color: cs.primary.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: targetRadius,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedRotation(
                      turns: _expanded ? 0.125 : 0,
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
