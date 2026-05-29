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
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final shapes = context.shapes;
    final motion = context.motion;
    final tt = context.textTheme;

    final radius = _expanded ? BorderRadius.circular(28) : shapes.balanceCard;

    return GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          onTap: () => setState(() => _expanded = !_expanded),
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
                          AnimatedSize(
                            duration: motion.morphDuration,
                            curve: motion.morphCurve,
                            child: _expanded
                                ? _ExpandedDetails(cs: cs, tt: tt)
                                : const SizedBox.shrink(),
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

class _ExpandedDetails extends StatelessWidget {
  const _ExpandedDetails({required this.cs, required this.tt});

  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Padding(
          padding: const EdgeInsets.only(top: 20),
          child: Row(
            children: [
              _MiniStat(
                label: 'Receitas',
                amountInCents: 580000,
                color: const Color(0xFF66BB6A),
                cs: cs,
                tt: tt,
              ),
              const SizedBox(width: 24),
              _MiniStat(
                label: 'Despesas',
                amountInCents: -220000,
                color: const Color(0xFFEF5350),
                cs: cs,
                tt: tt,
              ),
            ],
          ),
        )
        .animate()
        .fadeIn(duration: const Duration(milliseconds: 200))
        .slideY(begin: 0.2, end: 0, curve: Curves.easeOut);
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.amountInCents,
    required this.color,
    required this.cs,
    required this.tt,
  });

  final String label;
  final int amountInCents;
  final Color color;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    final double amount = amountInCents.abs() / 100.0;
    final formatted = 'R\$ ${amount.toStringAsFixed(2).replaceAll('.', ',')}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: tt.labelSmall?.copyWith(
                color: cs.onPrimary.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          formatted,
          style: tt.titleSmall?.copyWith(
            color: cs.onPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
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
