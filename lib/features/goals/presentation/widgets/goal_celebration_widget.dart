import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Widget de celebração exibido ao atingir um objetivo.
/// Implementado com [CustomPainter] (confetti) e [flutter_animate].
/// Desaparece automaticamente após 3.5 segundos.
class GoalCelebrationWidget extends StatefulWidget {
  final String goalName;
  final VoidCallback? onDismiss;

  const GoalCelebrationWidget({
    super.key,
    required this.goalName,
    this.onDismiss,
  });

  @override
  State<GoalCelebrationWidget> createState() => _GoalCelebrationWidgetState();
}

class _GoalCelebrationWidgetState extends State<GoalCelebrationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..forward();

    // Auto-dismiss após 3.5s
    Future.delayed(const Duration(milliseconds: 3500), () {
      if (mounted) widget.onDismiss?.call();
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: widget.onDismiss,
      child: Material(
        color: Colors.black54,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Confetti layer
            AnimatedBuilder(
              animation: _confettiController,
              builder: (context, _) => CustomPaint(
                painter: _ConfettiPainter(progress: _confettiController.value),
              ),
            ),

            // Card central
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 32),
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: cs.primary.withValues(alpha: 0.3),
                      blurRadius: 40,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Emoji troféu animado
                    const Text(
                      '🏆',
                      style: TextStyle(fontSize: 64),
                    ).animate().scale(
                      begin: const Offset(0.3, 0.3),
                      end: const Offset(1, 1),
                      duration: 600.ms,
                      curve: Curves.elasticOut,
                    ),
                    const SizedBox(height: 16),
                    Text(
                          'Meta atingida!',
                          style: tt.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: cs.primary,
                          ),
                          textAlign: TextAlign.center,
                        )
                        .animate()
                        .fadeIn(delay: 300.ms)
                        .slideY(begin: 0.3, end: 0, delay: 300.ms),
                    const SizedBox(height: 8),
                    Text(
                      widget.goalName,
                      style: tt.bodyLarge?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ).animate().fadeIn(delay: 500.ms),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                          onPressed: widget.onDismiss,
                          icon: const Icon(Icons.celebration_rounded),
                          label: const Text('Incrível!'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        )
                        .animate()
                        .fadeIn(delay: 700.ms)
                        .slideY(begin: 0.3, end: 0, delay: 700.ms),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final double progress;
  static final _random = math.Random(42);
  static final _pieces = List.generate(80, (_) {
    return _ConfettiPiece(
      x: _random.nextDouble(),
      startY: -0.1 - _random.nextDouble() * 0.3,
      speedY: 0.3 + _random.nextDouble() * 0.5,
      speedX: (_random.nextDouble() - 0.5) * 0.2,
      rotation: _random.nextDouble() * math.pi * 2,
      rotationSpeed: (_random.nextDouble() - 0.5) * 8,
      size: 6 + _random.nextDouble() * 10,
      color: _randomColor(_random),
      shape: _random.nextInt(3),
    );
  });

  static Color _randomColor(math.Random r) {
    final colors = [
      const Color(0xFFE53935),
      const Color(0xFF43A047),
      const Color(0xFF1E88E5),
      const Color(0xFFFDD835),
      const Color(0xFFE91E63),
      const Color(0xFF00ACC1),
      const Color(0xFFFF7043),
      const Color(0xFF7E57C2),
    ];
    return colors[r.nextInt(colors.length)];
  }

  _ConfettiPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in _pieces) {
      final t = progress;
      final x = (p.x + p.speedX * t) * size.width;
      final y = (p.startY + p.speedY * t) * size.height;

      if (y > size.height) continue;

      final opacity = progress < 0.7 ? 1.0 : (1.0 - progress) / 0.3;
      final paint = Paint()
        ..color = p.color.withValues(alpha: opacity.clamp(0.0, 1.0))
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.rotation + p.rotationSpeed * t);

      switch (p.shape) {
        case 0: // retângulo
          canvas.drawRect(
            Rect.fromCenter(
              center: Offset.zero,
              width: p.size,
              height: p.size * 0.5,
            ),
            paint,
          );
        case 1: // círculo
          canvas.drawCircle(Offset.zero, p.size / 2, paint);
        default: // triângulo
          final path = Path()
            ..moveTo(0, -p.size / 2)
            ..lineTo(p.size / 2, p.size / 2)
            ..lineTo(-p.size / 2, p.size / 2)
            ..close();
          canvas.drawPath(path, paint);
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}

class _ConfettiPiece {
  final double x;
  final double startY;
  final double speedY;
  final double speedX;
  final double rotation;
  final double rotationSpeed;
  final double size;
  final Color color;
  final int shape;

  const _ConfettiPiece({
    required this.x,
    required this.startY,
    required this.speedY,
    required this.speedX,
    required this.rotation,
    required this.rotationSpeed,
    required this.size,
    required this.color,
    required this.shape,
  });
}
