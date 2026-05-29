import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:bestfin/core/extensions/context_extensions.dart';

class AnimatedChip extends StatefulWidget {
  const AnimatedChip({
    super.key,
    required this.label,
    this.icon,
    this.selected = false,
    this.onTap,
    this.delay = Duration.zero,
  });

  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback? onTap;
  final Duration delay;

  @override
  State<AnimatedChip> createState() => _AnimatedChipState();
}

class _AnimatedChipState extends State<AnimatedChip> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final shapes = context.shapes;
    final motion = context.motion;

    final bgColor = widget.selected
        ? cs.secondaryContainer
        : cs.surfaceContainerHighest;
    final fgColor = widget.selected
        ? cs.onSecondaryContainer
        : cs.onSurfaceVariant;
    final radius = widget.selected ? shapes.chipSelected : shapes.chip;

    final chip = GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onTap?.call();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: motion.fastDuration,
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: motion.morphDuration,
          curve: motion.morphCurve,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: bgColor, borderRadius: radius),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                AnimatedSwitcher(
                  duration: motion.fastDuration,
                  child: Icon(
                    widget.icon,
                    key: ValueKey(widget.selected),
                    size: 16,
                    color: fgColor,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                widget.label,
                style: context.textTheme.labelMedium?.copyWith(color: fgColor),
              ),
            ],
          ),
        ),
      ),
    );

    return chip
        .animate(delay: widget.delay)
        .fadeIn(duration: motion.fastDuration)
        .scaleXY(begin: 0.9, end: 1.0, curve: Curves.easeOutBack);
  }
}
