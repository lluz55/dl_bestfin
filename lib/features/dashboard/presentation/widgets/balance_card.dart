import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/providers/privacy_provider.dart';
import 'package:bestfin/core/theme/typography.dart';

class BalanceCard extends StatefulWidget {
  final int balanceInCents;
  final int monthlyIncome;
  final int monthlyExpense;

  const BalanceCard({
    super.key,
    required this.balanceInCents,
    required this.monthlyIncome,
    required this.monthlyExpense,
  });

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
            scale: _pressed ? 0.98 : 1.0,
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
                boxShadow: [
                  BoxShadow(
                    color: cs.primary.withValues(alpha: 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: radius,
                child: Stack(
                  children: [
                    _DecorativeCircle(
                      offset: const Offset(-30, -30),
                      size: 150,
                      color: cs.onPrimary,
                    ),
                    _DecorativeCircle(
                      offset: const Offset(220, 50),
                      size: 130,
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
                                'SALDO CONSOLIDADO',
                                style: tt.labelSmall?.copyWith(
                                  color: cs.onPrimary.withValues(alpha: 0.65),
                                  letterSpacing: 1.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Icon(
                                Icons.account_balance_wallet_outlined,
                                color: cs.onPrimary.withValues(alpha: 0.8),
                                size: 20,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          AnimatedCounter(
                            value: widget.balanceInCents,
                            style: tt.displaySmall?.copyWith(
                              color: cs.onPrimary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Toque para ver detalhes do mês',
                            style: tt.bodySmall?.copyWith(
                              color: cs.onPrimary.withValues(alpha: 0.5),
                            ),
                          ),
                          AnimatedSize(
                            duration: motion.morphDuration,
                            curve: motion.morphCurve,
                            child: _expanded
                                ? Padding(
                                        padding: const EdgeInsets.only(top: 20),
                                        child: Row(
                                          children: [
                                            _MiniStat(
                                              label: 'Receitas',
                                              amountInCents:
                                                  widget.monthlyIncome,
                                              color: const Color(0xFF81C784),
                                              cs: cs,
                                              tt: tt,
                                            ),
                                            const SizedBox(width: 32),
                                            _MiniStat(
                                              label: 'Despesas',
                                              amountInCents:
                                                  widget.monthlyExpense,
                                              color: const Color(0xFFE57373),
                                              cs: cs,
                                              tt: tt,
                                            ),
                                          ],
                                        ),
                                      )
                                      .animate()
                                      .fadeIn(duration: 200.ms)
                                      .slideY(begin: 0.1, end: 0)
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
        .animate()
        .scaleXY(
          begin: 0.95,
          end: 1.0,
          curve: Curves.easeOutBack,
          duration: motion.mediumDuration,
        )
        .fadeIn(duration: motion.fastDuration);
  }
}

class AnimatedCounter extends ConsumerWidget {
  final int value;
  final TextStyle? style;

  const AnimatedCounter({super.key, required this.value, this.style});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hidden = ref.watch(valuesHiddenProvider);
    final baseStyle = (style ?? context.textTheme.displaySmall)?.merge(
      AppTypography.monospace,
    );

    if (hidden) {
      return Text(
        'R\$ •••••',
        style: baseStyle?.copyWith(color: Colors.white.withValues(alpha: 0.4)),
      );
    }

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: value.toDouble()),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutQuart,
      builder: (context, val, child) {
        final double amount = val / 100.0;
        final isNegative = amount < 0;
        final formatted =
            'R\$ ${amount.abs().toStringAsFixed(2).replaceAll('.', ',')}';
        final sign = isNegative ? '- ' : '';
        return Text('$sign$formatted', style: baseStyle);
      },
    );
  }
}

class _MiniStat extends ConsumerWidget {
  final String label;
  final int amountInCents;
  final Color color;
  final ColorScheme cs;
  final TextTheme tt;

  const _MiniStat({
    required this.label,
    required this.amountInCents,
    required this.color,
    required this.cs,
    required this.tt,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hidden = ref.watch(valuesHiddenProvider);
    final double amount = amountInCents / 100.0;
    final formatted = hidden
        ? '•••••'
        : 'R\$ ${amount.abs().toStringAsFixed(2).replaceAll('.', ',')}';

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
            const SizedBox(width: 8),
            Text(
              label,
              style: tt.labelSmall?.copyWith(
                color: cs.onPrimary.withValues(alpha: 0.7),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          formatted,
          style: tt.titleMedium
              ?.copyWith(color: cs.onPrimary, fontWeight: FontWeight.w700)
              .merge(AppTypography.monospace),
        ),
      ],
    );
  }
}

class _DecorativeCircle extends StatelessWidget {
  final Offset offset;
  final double size;
  final Color color;

  const _DecorativeCircle({
    required this.offset,
    required this.size,
    required this.color,
  });

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
            color: color.withValues(alpha: 0.05),
          ),
        ),
      ),
    );
  }
}
