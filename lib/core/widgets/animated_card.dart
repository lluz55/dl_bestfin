import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:bestfin/core/extensions/context_extensions.dart';

class AnimatedCard extends StatefulWidget {
  const AnimatedCard({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.margin,
    this.padding,
    this.delay = Duration.zero,
    this.borderRadius,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final Duration delay;
  final BorderRadius? borderRadius;

  @override
  State<AnimatedCard> createState() => _AnimatedCardState();
}

class _AnimatedCardState extends State<AnimatedCard> {
  bool _pressed = false;

  void _handleLongPress() {
    HapticFeedback.mediumImpact();
    widget.onLongPress?.call();
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius ?? context.shapes.card;

    final card = AnimatedScale(
      scale: _pressed ? 0.98 : 1.0,
      duration: context.motion.fastDuration,
      curve: Curves.easeOut,
      child: Card(
        margin:
            widget.margin ??
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: radius),
        clipBehavior: Clip.antiAlias,
        child: GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          onTap: widget.onTap,
          onLongPress: widget.onLongPress != null ? _handleLongPress : null,
          child: Padding(
            padding: widget.padding ?? const EdgeInsets.all(16.0),
            child: widget.child,
          ),
        ),
      ),
    );

    return card
        .animate(delay: widget.delay)
        .slideX(
          begin: 0.05,
          end: 0,
          curve: Curves.easeOutBack,
          duration: context.motion.mediumDuration,
        )
        .fadeIn(duration: context.motion.fastDuration);
  }
}
