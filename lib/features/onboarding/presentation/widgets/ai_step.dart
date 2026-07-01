import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/features/llm/domain/models/llm_state.dart';
import 'package:bestfin/features/llm/domain/models/ai_model_type.dart';
import 'package:bestfin/features/llm/presentation/providers/llm_provider.dart';

class AiStep extends ConsumerWidget {
  const AiStep({super.key, required this.onNext});

  final VoidCallback onNext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = context.colorScheme;
    final tt = context.textTheme;
    final llmState = ref.watch(llmStateProvider);
    final selectedModel = ref.watch(selectedModelProvider);

    final isDownloading = llmState.status == LlmStatus.downloading;
    final isLoading = llmState.status == LlmStatus.loading;
    final isReady = llmState.status == LlmStatus.ready;
    final hasError = llmState.status == LlmStatus.error;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const Spacer(),

          // Icon
          Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [cs.tertiary, cs.primary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(
                  Icons.psychology_outlined,
                  size: 40,
                  color: cs.onPrimary,
                ),
              )
              .animate()
              .scaleXY(
                begin: 0.6,
                end: 1.0,
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutBack,
              )
              .fadeIn(duration: const Duration(milliseconds: 400)),

          const SizedBox(height: 16),

          Text(
                'Assistente Financeiro com IA',
                textAlign: TextAlign.center,
                style: tt.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface,
                ),
              )
              .animate(delay: 200.ms)
              .fadeIn(duration: 400.ms)
              .slideY(begin: 0.2, end: 0, curve: Curves.easeOut),

          const SizedBox(height: 8),

          Text(
                'O BestFin inclui uma IA local para analisar suas finanças de forma 100% privada e offline.',
                textAlign: TextAlign.center,
                style: tt.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  height: 1.45,
                ),
              )
              .animate(delay: 350.ms)
              .fadeIn(duration: 400.ms)
              .slideY(begin: 0.2, end: 0, curve: Curves.easeOut),

          const SizedBox(height: 20),

          // Model Selection Cards
          Row(
            children: AiModelType.values.map((model) {
              final isCurrent = model == selectedModel;
              return Expanded(
                child: GestureDetector(
                  onTap: isDownloading || isLoading || isReady
                      ? null
                      : () {
                          ref
                              .read(selectedModelProvider.notifier)
                              .setModel(model);
                        },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? cs.primaryContainer.withValues(alpha: 0.15)
                          : cs.surfaceContainerLow,
                      border: Border.all(
                        color: isCurrent ? cs.primary : cs.outlineVariant,
                        width: isCurrent ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          model == AiModelType.minicpmV4_6
                              ? Icons.camera_alt_outlined
                              : Icons.text_snippet_outlined,
                          color: isCurrent ? cs.primary : cs.onSurfaceVariant,
                          size: 24,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          model == AiModelType.minicpmV4_6
                              ? 'Multimodal'
                              : 'Apenas Texto',
                          style: tt.labelLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isCurrent ? cs.primary : cs.onSurface,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '~${model.sizeMb} MB',
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ).animate(delay: 450.ms).fadeIn().slideY(begin: 0.1, end: 0),

          const SizedBox(height: 12),

          // Dynamic Model Specs Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: cs.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, size: 14, color: cs.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Uso Recomendado',
                      style: tt.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  selectedModel == AiModelType.minicpmV4_6
                      ? 'Análise e chat com suporte a imagens e leitura visual de faturas fisicamente.'
                      : 'Análise financeira rápida em texto para tirar dúvidas, orçamentos e categorias.',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.check_circle_outline,
                                size: 12,
                                color: Colors.green,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Vantagens',
                                style: tt.labelSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ...(selectedModel == AiModelType.minicpmV4_6
                                  ? [
                                      '• Lê faturas por foto',
                                      '• Suporte multimodal',
                                    ]
                                  : [
                                      '• Respostas super rápidas',
                                      '• Menor uso de RAM',
                                    ])
                              .map(
                                (p) => Text(
                                  p,
                                  style: tt.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.remove_circle_outline,
                                size: 12,
                                color: cs.error,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Desvantagens',
                                style: tt.labelSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: cs.error,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ...(selectedModel == AiModelType.minicpmV4_6
                                  ? [
                                      '• Arquivo um pouco maior',
                                      '• Maior uso de memória',
                                    ]
                                  : [
                                      '• Apenas texto puro',
                                      '• Sem leitura de fotos',
                                    ])
                              .map(
                                (p) => Text(
                                  p,
                                  style: tt.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ).animate(delay: 550.ms).fadeIn().slideY(begin: 0.1, end: 0),

          const Spacer(),

          // Progress / status
          if (isDownloading) ...[
            _DownloadProgress(
              progress: llmState.downloadProgress,
              totalMb: selectedModel.sizeMb,
              cs: cs,
              tt: tt,
            ),
            const SizedBox(height: 16),
          ] else if (isLoading) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 10),
                Text('Carregando modelo…', style: tt.bodySmall),
              ],
            ),
            const SizedBox(height: 16),
          ] else if (hasError) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: cs.errorContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                llmState.errorMessage ?? 'Erro ao baixar o modelo.',
                style: tt.bodySmall?.copyWith(color: cs.onErrorContainer),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Action buttons
          if (isReady) ...[
            FilledButton.icon(
                  onPressed: onNext,
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Modelo instalado — Continuar'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    backgroundColor: cs.tertiary,
                    foregroundColor: cs.onTertiary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                )
                .animate()
                .fadeIn(duration: 300.ms)
                .slideY(begin: 0.2, end: 0, curve: Curves.easeOut),
          ] else if (!isDownloading && !isLoading) ...[
            FilledButton.icon(
                  onPressed: () =>
                      ref.read(llmStateProvider.notifier).downloadAndLoad(),
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Baixar modelo agora'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                )
                .animate(delay: 700.ms)
                .fadeIn()
                .slideY(begin: 0.3, end: 0, curve: Curves.easeOutBack),
            const SizedBox(height: 10),
            TextButton(
              onPressed: onNext,
              child: Text(
                'Baixar depois',
                style: tt.labelLarge?.copyWith(color: cs.onSurfaceVariant),
              ),
            ).animate(delay: 780.ms).fadeIn(),
          ] else ...[
            // Downloading/loading — show skip anyway
            TextButton(
              onPressed: onNext,
              child: Text(
                'Continuar em segundo plano',
                style: tt.labelLarge?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _DownloadProgress extends StatelessWidget {
  final double progress;
  final int totalMb;
  final ColorScheme cs;
  final TextTheme tt;

  const _DownloadProgress({
    required this.progress,
    required this.totalMb,
    required this.cs,
    required this.tt,
  });

  @override
  Widget build(BuildContext context) {
    final downloaded = (progress * totalMb).toStringAsFixed(0);
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Baixando modelo…', style: tt.bodySmall),
            Text(
              '$downloaded MB / $totalMb MB',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: progress,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }
}
