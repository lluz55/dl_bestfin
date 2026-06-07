import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/features/llm/domain/models/llm_state.dart';
import 'package:bestfin/features/llm/presentation/providers/llm_provider.dart';

class AiQuickTxFab extends ConsumerWidget {
  final VoidCallback onTap;

  const AiQuickTxFab({super.key, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = context.colorScheme;
    final llmState = ref.watch(llmStateProvider);
    final isReady = llmState.status == LlmStatus.ready;

    return FloatingActionButton.small(
      heroTag: 'ai_quick_tx_fab',
      onPressed: onTap,
      backgroundColor: isReady
          ? cs.secondaryContainer
          : cs.surfaceContainerHighest,
      foregroundColor: isReady ? cs.onSecondaryContainer : cs.onSurfaceVariant,
      tooltip: 'Transação Rápida com IA',
      child: const Icon(Icons.auto_awesome_rounded, size: 20),
    );
  }
}
