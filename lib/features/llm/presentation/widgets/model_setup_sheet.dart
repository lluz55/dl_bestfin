import 'package:flutter/material.dart';
import 'package:bestfin/core/widgets/loading_indicator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestfin/features/llm/domain/models/llm_state.dart';
import 'package:bestfin/features/llm/presentation/providers/llm_provider.dart';

class ModelSetupSheet extends ConsumerWidget {
  const ModelSetupSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final llmState = ref.watch(llmStateProvider);
    final selectedModel = ref.watch(selectedModelProvider);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Icon(Icons.psychology_outlined, size: 48, color: cs.primary),
          const SizedBox(height: 16),
          Text(
            'Assistente Financeiro IA',
            style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'O modelo ${selectedModel.displayName} (~${selectedModel.sizeMb} MB) precisa ser baixado uma única vez. '
            'Funciona completamente offline após o download.',
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          if (llmState.status == LlmStatus.downloading) ...[
            Text(
              'Baixando… ${(llmState.downloadProgress * 100).toStringAsFixed(1)}%',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: llmState.downloadProgress,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 16),
            Text(
              '${(llmState.downloadProgress * selectedModel.sizeMb).toStringAsFixed(0)} MB de ${selectedModel.sizeMb} MB',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ] else if (llmState.status == LlmStatus.loading) ...[
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox.square(
                  dimension: 20,
                  child: AppLoadingIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Text('Carregando modelo…'),
              ],
            ),
          ] else if (llmState.status == LlmStatus.error) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                llmState.errorMessage ?? 'Erro desconhecido',
                style: TextStyle(color: cs.onErrorContainer),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                ref.read(llmStateProvider.notifier).clearError();
                ref.read(llmStateProvider.notifier).downloadAndLoad();
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tentar novamente'),
            ),
          ] else ...[
            _InfoRow(
              icon: Icons.storage_rounded,
              label: 'Tamanho',
              value: '~${selectedModel.sizeMb} MB',
            ),
            const SizedBox(height: 8),
            _InfoRow(
              icon: Icons.wifi_off_rounded,
              label: 'Funciona offline',
              value: 'Sim, após download',
            ),
            const SizedBox(height: 8),
            _InfoRow(
              icon: Icons.lock_outline_rounded,
              label: 'Privacidade',
              value: 'Dados nunca saem do dispositivo',
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                ref.read(llmStateProvider.notifier).downloadAndLoad();
              },
              icon: const Icon(Icons.download_rounded),
              label: const Text('Baixar agora'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Agora não'),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: cs.primary),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
        ),
      ],
    );
  }
}
