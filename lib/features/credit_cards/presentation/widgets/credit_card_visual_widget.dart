import 'package:flutter/material.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/theme/typography.dart';
import 'package:bestfin/features/credit_cards/domain/models/credit_card.dart';

class CreditCardVisualWidget extends StatelessWidget {
  final CreditCardModel card;
  final bool showLimit;

  const CreditCardVisualWidget({
    super.key,
    required this.card,
    this.showLimit = true,
  });

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.textTheme;

    final baseColor = card.color != null
        ? _hexToColor(card.color!)
        : cs.primary;
    final gradientColors = [
      baseColor,
      baseColor.withValues(alpha: 0.7),
      baseColor.withValues(alpha: 0.85),
    ];

    final limitDouble = card.limitAmount / 100.0;
    final formattedLimit =
        'R\$ ${limitDouble.toStringAsFixed(2).replaceAll('.', ',')}';

    final availableDouble = card.availableLimit / 100.0;
    final formattedAvailable =
        'R\$ ${availableDouble.toStringAsFixed(2).replaceAll('.', ',')}';

    return AspectRatio(
      aspectRatio: 1.586, // Proporção padrão do cartão de crédito ID-1
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradientColors,
          ),
          boxShadow: [
            BoxShadow(
              color: baseColor.withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // Círculos Decorativos do Background
              Positioned(
                right: -40,
                top: -40,
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
              ),
              Positioned(
                left: -20,
                bottom: -40,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withValues(alpha: 0.06),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              card.name.toUpperCase(),
                              style: tt.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'BESTFIN PREMIUM',
                              style: tt.labelSmall?.copyWith(
                                color: Colors.white.withValues(alpha: 0.6),
                                letterSpacing: 1.0,
                              ),
                            ),
                          ],
                        ),
                        // Ícone da bandeira estilizado
                        Container(
                          width: 44,
                          height: 28,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'MC',
                            style: tt.labelLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontStyle: FontStyle.italic,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    // Chip do cartão em glossmorphism
                    Container(
                      width: 36,
                      height: 26,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.yellow.shade200.withValues(alpha: 0.8),
                            Colors.yellow.shade600.withValues(alpha: 0.6),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (showLimit)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'LIMITE DISPONÍVEL',
                                style: tt.labelSmall?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.65),
                                  letterSpacing: 1.0,
                                  fontSize: 9,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                formattedAvailable,
                                style: tt.titleLarge
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                    )
                                    .merge(AppTypography.monospace),
                              ),
                            ],
                          )
                        else
                          Text(
                            '**** **** **** 8852',
                            style: tt.titleMedium
                                ?.copyWith(
                                  color: Colors.white,
                                  letterSpacing: 2,
                                )
                                .merge(AppTypography.monospace),
                          ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'VENCE DIA',
                              style: tt.labelSmall?.copyWith(
                                color: Colors.white.withValues(alpha: 0.65),
                                letterSpacing: 0.8,
                                fontSize: 9,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              card.dueDay.toString().padLeft(2, '0'),
                              style: tt.titleMedium
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  )
                                  .merge(AppTypography.monospace),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _hexToColor(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }
}
