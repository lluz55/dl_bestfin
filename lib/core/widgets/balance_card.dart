import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../extensions/context_extensions.dart';
import 'amount_display.dart';

class BalanceCard extends StatefulWidget {
  const BalanceCard({
    super.key,
    required this.balanceInCents,
    required this.accountName,
    this.subtitle,
    this.delay = Duration.zero,
  });

  final int balanceInCents;
  final String accountName;
  final String? subtitle;
  final Duration delay;

  @override
  State<BalanceCard> createState() => _BalanceCardState();
}

class _BalanceCardState extends State<BalanceCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final shapes = context.shapes;
    final motion = context.motion;
    final tt = context.textTheme;

    final radius = shapes.balanceCard;

    return GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          child: AnimatedScale(
            scale: _pressed ? 0.97 : 1.0,
            duration: motion.fastDuration,
            curve: Curves.easeOut,
            child: AnimatedContainer(
              duration: motion.morphDuration,
              curve: motion.morphCurve,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: radius,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [cs.primary, cs.tertiary],
                  stops: const [0.0, 1.0],
                ),
              ),
              child: ClipRRect(
                borderRadius: radius,
                child: Stack(
                  children: [
                    _DecorativeCircle(
                      offset: const Offset(-40, -40),
                      size: 160,
                      color: cs.onPrimary,
                    ),
                    _DecorativeCircle(
                      offset: const Offset(200, 60),
                      size: 120,
                      color: cs.onPrimary,
                    ),
                    _DecorativeCircle(
                      offset: const Offset(80, 100),
                      size: 80,
                      color: cs.onPrimary,
                    ),
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                widget.accountName,
                                style: tt.titleMedium?.copyWith(
                                  color: cs.onPrimary.withValues(alpha: 0.85),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Icon(
                                Icons.account_balance_wallet_outlined,
                                color: cs.onPrimary.withValues(alpha: 0.7),
                                size: 20,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (widget.subtitle != null)
                            Text(
                              widget.subtitle!,
                              style: tt.labelSmall?.copyWith(
                                color: cs.onPrimary.withValues(alpha: 0.6),
                                letterSpacing: 1.2,
                              ),
                            ),
                          const SizedBox(height: 16),
                          AmountDisplay(
                            amountInCents: widget.balanceInCents,
                            showSign: false,
                            style: tt.displayMedium?.copyWith(
                              color: cs.onPrimary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Saldo total',
                            style: tt.labelMedium?.copyWith(
                              color: cs.onPrimary.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        )
        .animate(delay: widget.delay)
        .scaleXY(
          begin: 0.92,
          end: 1.0,
          curve: Curves.easeOutBack,
          duration: context.motion.mediumDuration,
        )
        .fadeIn(duration: context.motion.fastDuration);
  }
}

class _DecorativeCircle extends StatelessWidget {
  const _DecorativeCircle({
    required this.offset,
    required this.size,
    required this.color,
  });

  final Offset offset;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: offset.dx,
      top: offset.dy,
      child: IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.06),
          ),
        ),
      ),
    );
  }
}
