import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:bestfin/core/constants/sentiment_types.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';

class SentimentSelector extends StatelessWidget {
  final SentimentType? selectedSentiment;
  final Function(SentimentType) onSentimentSelected;

  const SentimentSelector({
    super.key,
    required this.selectedSentiment,
    required this.onSentimentSelected,
  });

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Como você se sente com essa compra?',
                style: tt.labelLarge?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (selectedSentiment != null)
                Text(
                      selectedSentiment!.label,
                      style: tt.labelMedium?.copyWith(
                        color: selectedSentiment!.color,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                    .animate()
                    .fadeIn(duration: 200.ms)
                    .scale(begin: const Offset(0.8, 0.8)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (var sentiment in SentimentType.values)
                _SentimentButton(
                  sentiment: sentiment,
                  isSelected: selectedSentiment == sentiment,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onSentimentSelected(sentiment);
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SentimentButton extends StatelessWidget {
  final SentimentType sentiment;
  final bool isSelected;
  final VoidCallback onTap;

  const _SentimentButton({
    required this.sentiment,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: isSelected
                      ? sentiment.color.withValues(alpha: 0.15)
                      : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? sentiment.color : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    sentiment.emoji,
                    style: const TextStyle(fontSize: 28),
                  ),
                ),
              )
              .animate(target: isSelected ? 1 : 0)
              .scale(
                begin: const Offset(1.0, 1.0),
                end: const Offset(1.18, 1.18),
                duration: 250.ms,
                curve: Curves.easeOutBack,
              )
              .shake(hz: 3, duration: 300.ms),
          const SizedBox(height: 4),
          Text(
            sentiment.label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected
                  ? sentiment.color
                  : cs.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}
