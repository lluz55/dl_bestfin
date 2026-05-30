import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';

class GlobalFAB extends StatefulWidget {
  const GlobalFAB({
    super.key,
    required this.onExpense,
    required this.onIncome,
    required this.onTransfer,
  });

  final VoidCallback onExpense;
  final VoidCallback onIncome;
  final VoidCallback onTransfer;

  @override
  State<GlobalFAB> createState() => _GlobalFABState();
}

class _GlobalFABState extends State<GlobalFAB>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;

  void _toggle() => setState(() => _isExpanded = !_isExpanded);

  void _select(VoidCallback action) {
    setState(() => _isExpanded = false);
    action();
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final motion = context.motion;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_isExpanded) ...[
          _FABOption(
            label: 'Nova Receita',
            icon: Icons.arrow_downward_rounded,
            color: cs.tertiary,
            onTap: () => _select(widget.onIncome),
            delay: const Duration(milliseconds: 80),
          ),
          const SizedBox(height: 8),
          _FABOption(
            label: 'Nova Despesa',
            icon: Icons.arrow_upward_rounded,
            color: cs.error,
            onTap: () => _select(widget.onExpense),
            delay: const Duration(milliseconds: 40),
          ),
          const SizedBox(height: 8),
          _FABOption(
            label: 'Transferência',
            icon: Icons.swap_horiz_rounded,
            color: cs.secondary,
            onTap: () => _select(widget.onTransfer),
            delay: Duration.zero,
          ),
          const SizedBox(height: 12),
        ],
        AnimatedContainer(
          duration: motion.morphDuration,
          curve: motion.morphCurve,
          decoration: BoxDecoration(
            color: _isExpanded ? cs.surfaceContainerHighest : cs.primary,
            borderRadius: BorderRadius.circular(_isExpanded ? 20 : 16),
          ),
          child: InkWell(
            onTap: _toggle,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: AnimatedRotation(
                turns: _isExpanded ? 0.125 : 0,
                duration: motion.morphDuration,
                curve: motion.morphCurve,
                child: Icon(
                  Icons.add_rounded,
                  size: 28,
                  color: _isExpanded ? cs.onSurface : cs.onPrimary,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FABOption extends StatelessWidget {
  const _FABOption({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    required this.delay,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return GestureDetector(
          onTap: onTap,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  label,
                  style: tt.labelLarge?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
            ],
          ),
        )
        .animate(delay: delay)
        .fadeIn(duration: const Duration(milliseconds: 200))
        .slideX(begin: 0.3, end: 0, curve: Curves.easeOutCubic);
  }
}
