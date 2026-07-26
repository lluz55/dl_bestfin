import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
// Note: We would import 'package:lottie/lottie.dart' here when ready for Lottie assets.

import 'package:bestfin/core/extensions/context_extensions.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.description,
    this.icon,
    this.onAction,
    this.actionLabel,
  });

  final String title;
  final String description;
  final IconData? icon;
  final VoidCallback? onAction;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    return Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon ?? Icons.inbox_outlined,
                  size: 80,
                  color: context.colorScheme.primary.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 24),
                Text(
                  title,
                  style: context.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  description,
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (onAction != null && actionLabel != null) ...[
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    onPressed: onAction,
                    icon: const Icon(Icons.add),
                    label: Text(actionLabel!),
                  ),
                ],
              ],
            ),
          ),
        )
        .animate()
        .fadeIn(duration: context.motion.mediumDuration)
        .slideY(
          begin: 0.1,
          end: 0,
          curve: Curves.easeOut,
          duration: context.motion.mediumDuration,
        );
  }
}
