import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:bestfin/core/utils/currency_formatter.dart';

/// Anel de progresso animado com efeito spring (overshoot).
///
/// Usa [SpringSimulation] para animar suavemente com overshoot quando
/// o progresso é atualizado, criando uma sensação satisfatória e motivante.
class ProgressRingWidget extends StatefulWidget {
  /// Progresso de 0.0 a 1.0+ (pode ultrapassar 1.0 para overshoot visual).
  final double progress;

  /// Diâmetro do anel.
  final double size;

  /// Espessura do arco.
  final double strokeWidth;

  /// Cor primária do arco de progresso.
  final Color color;

  /// Valor atual (exibido no centro). Se null, exibe só o percentual.
  final int? currentAmountInCents;

  /// Valor total (exibido no centro).
  final int? targetAmountInCents;

  /// Se true, exibe texto de celebração ao atingir 100%.
  final bool showCelebration;

  const ProgressRingWidget({
    super.key,
    required this.progress,
    this.size = 160,
    this.strokeWidth = 14,
    required this.color,
    this.currentAmountInCents,
    this.targetAmountInCents,
    this.showCelebration = false,
  });

  @override
  State<ProgressRingWidget> createState() => _ProgressRingWidgetState();
}

class _ProgressRingWidgetState extends State<ProgressRingWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _progressAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController.unbounded(vsync: this);
    _progressAnim = _controller;
    _animateTo(widget.progress, instant: true);
  }

  @override
  void didUpdateWidget(ProgressRingWidget old) {
    super.didUpdateWidget(old);
    if (old.progress != widget.progress) {
      _animateTo(widget.progress);
    }
  }

  void _animateTo(double target, {bool instant = false}) {
    if (instant) {
      _controller.value = target;
      return;
    }
    // SpringSimulation com overshoot leve
    final spring = SpringDescription.withDampingRatio(
      mass: 1,
      stiffness: 180,
      ratio: 0.65, // sub-amortecido → overshoot
    );
    final sim = SpringSimulation(spring, _controller.value, target, 0);
    _controller.animateWith(sim);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final pct = (widget.progress * 100).clamp(0, 999).round();

    return Semantics(
      label: '$pct% do objetivo atingido',
      child: AnimatedBuilder(
        animation: _progressAnim,
        builder: (context, _) {
          return SizedBox(
            width: widget.size,
            height: widget.size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: Size(widget.size, widget.size),
                  painter: _RingPainter(
                    progress: _progressAnim.value.clamp(0.0, 1.5),
                    color: widget.color,
                    backgroundColor: cs.surfaceContainerHigh,
                    strokeWidth: widget.strokeWidth,
                  ),
                ),
                // Texto central
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$pct%',
                      style: tt.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: widget.progress >= 1.0
                            ? widget.color
                            : cs.onSurface,
                      ),
                    ),
                    if (widget.currentAmountInCents != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        CurrencyFormatter.formatCents(
                          widget.currentAmountInCents!,
                        ),
                        style: tt.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontSize: 10,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    if (widget.targetAmountInCents != null) ...[
                      Text(
                        'de ${CurrencyFormatter.formatCents(widget.targetAmountInCents!)}',
                        style: tt.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                          fontSize: 9,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color backgroundColor;
  final double strokeWidth;

  _RingPainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final bgPaint = Paint()
      ..color = backgroundColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Arco de fundo
    canvas.drawCircle(center, radius, bgPaint);

    if (progress <= 0) return;

    // Gradiente no arco de progresso
    final rect = Rect.fromCircle(center: center, radius: radius);
    final gradient = SweepGradient(
      startAngle: -math.pi / 2,
      endAngle: -math.pi / 2 + 2 * math.pi,
      colors: [color.withValues(alpha: 0.6), color, color],
      stops: const [0.0, 0.5, 1.0],
    );

    final progressPaint = Paint()
      ..shader = gradient.createShader(rect)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final sweep = 2 * math.pi * progress.clamp(0.0, 1.0);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweep,
      false,
      progressPaint,
    );

    // Ponto final brilhante
    if (progress > 0.05) {
      final angle = -math.pi / 2 + sweep;
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      final dotPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(x, y), strokeWidth / 2.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color;
}
