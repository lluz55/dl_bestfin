import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:bestfin/core/utils/adaptive_modal.dart';
import 'package:bestfin/core/widgets/app_page_appbar.dart';
import 'package:bestfin/features/llm/domain/models/llm_state.dart';
import 'package:bestfin/features/llm/presentation/providers/llm_provider.dart';
import 'package:bestfin/features/llm/presentation/providers/chat_provider.dart';
import 'package:bestfin/features/llm/presentation/widgets/chat_bubble.dart';
import 'package:bestfin/features/llm/presentation/widgets/chat_input_bar.dart';
import 'package:bestfin/features/llm/presentation/widgets/model_setup_sheet.dart';
import 'package:bestfin/features/ai/presentation/providers/ai_provider.dart';
import 'package:bestfin/features/llm/presentation/providers/llm_provider.dart'
    show llmThinkingEnabledProvider;

const _genericPrompts = [
  'Quanto gastei este mês?',
  'Qual meu maior gasto?',
  'Estou no caminho das minhas metas?',
  'Tenho gastos incomuns?',
  'Quais são minhas metas financeiras?',
  'Liste minhas transações recorrentes',
];

class AiChatScreen extends ConsumerStatefulWidget {
  final String? initialMessage;

  const AiChatScreen({super.key, this.initialMessage});

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> {
  final _scrollCtrl = ScrollController();
  final _picker = ImagePicker();
  bool _debugMode = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _initModel();
      if (widget.initialMessage != null && mounted) {
        final llmState = ref.read(llmStateProvider);
        if (llmState.canChat) {
          ref
              .read(chatHistoryProvider.notifier)
              .sendMessage(widget.initialMessage!);
          _scrollToBottom();
        }
      }
    });
  }

  Future<void> _initModel() async {
    if (kIsWeb) return; // Web não suporta llama.cpp

    final notifier = ref.read(llmStateProvider.notifier);
    await notifier.initialize();

    final state = ref.read(llmStateProvider);
    if (state.status == LlmStatus.uninitialized && mounted) {
      _showSetupSheet();
    }
  }

  void _showSetupSheet() {
    showAdaptiveModal(
      context: context,
      builder: (_) => const ModelSetupSheet(),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  List<String> _buildSuggestedPrompts() {
    final anomalies = ref.read(anomalyDetectionProvider);
    final goals = ref.read(goalAchievabilityProvider);
    final trends = ref.read(spendingTrendsProvider);
    final health = ref.read(financialHealthScoreProvider);
    final result = <String>[];

    if (anomalies.isNotEmpty) {
      result.add('Explique meu gasto anormal em "${anomalies.first.title}"');
    }

    final offTrack = goals.where((g) => !g.isOnTrack).toList();
    if (offTrack.isNotEmpty) {
      result.add(
        'Como atingir minha meta "${offTrack.first.goalName}" mais rápido?',
      );
    }

    final increasing = trends.where((t) => t.trend == 'increasing').toList();
    if (increasing.isNotEmpty) {
      result.add(
        'Meus gastos com ${increasing.first.categoryName} subiram — o que fazer?',
      );
    }

    if (health.score < 60) {
      result.add('Como melhorar minha saúde financeira?');
    }

    for (final g in _genericPrompts) {
      if (result.length >= 6) break;
      if (!result.contains(g)) result.add(g);
    }

    return result.take(6).toList();
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    // For now, send as a text note; full multimodal requires mmproj support
    ref
        .read(chatHistoryProvider.notifier)
        .sendMessage(
          '[Imagem: ${picked.name}] O que você consegue extrair desta imagem de recibo?',
        );
    _scrollToBottom();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final llmState = ref.watch(llmStateProvider);
    final messages = ref.watch(chatHistoryProvider);
    final isGenerating = llmState.status == LlmStatus.generating;

    // Auto-scroll when new tokens arrive
    ref.listen(chatHistoryProvider, (_, __) => _scrollToBottom());

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppPageAppBar(
        title: 'Assistente Financeiro',
        leading: BackButton(onPressed: () => Navigator.of(context).pop()),
        actions: [
          // Status indicator
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _LlmStatusChip(status: llmState.status),
          ),
          IconButton(
            icon: Icon(
              Icons.bug_report_outlined,
              color: _debugMode ? Theme.of(context).colorScheme.primary : null,
            ),
            tooltip: _debugMode
                ? 'Ocultar debug/thinking'
                : 'Mostrar debug e ativar thinking',
            onPressed: () {
              setState(() => _debugMode = !_debugMode);
              // Sync thinking mode with debug toggle
              ref.read(llmThinkingEnabledProvider.notifier).set(_debugMode);
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Nova conversa',
            onPressed: llmState.isReady
                ? () => ref.read(chatHistoryProvider.notifier).clearHistory()
                : null,
          ),
        ],
      ),
      body: kIsWeb
          ? _WebUnsupportedBanner(cs: cs)
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: Column(
                  children: [
                    Expanded(
                      child: messages.isEmpty
                          ? _EmptyState(
                              llmState: llmState,
                              suggestedPrompts: _buildSuggestedPrompts(),
                              onSuggestion: (s) {
                                ref
                                    .read(chatHistoryProvider.notifier)
                                    .sendMessage(s);
                                _scrollToBottom();
                              },
                              onSetup: _showSetupSheet,
                            )
                          : ListView.builder(
                              controller: _scrollCtrl,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              itemCount: messages.length,
                              itemBuilder: (ctx, i) {
                                final msg = messages[i];
                                final isLast = i == messages.length - 1;
                                return ChatBubble(
                                  message: msg,
                                  isStreaming:
                                      isGenerating && isLast && msg.isAssistant,
                                  showDebug: _debugMode,
                                );
                              },
                            ),
                    ),
                    ChatInputBar(
                      enabled: llmState.canChat,
                      onSend: (text) {
                        ref
                            .read(chatHistoryProvider.notifier)
                            .sendMessage(text);
                        _scrollToBottom();
                      },
                      onImageTap: _pickImage,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _LlmStatusChip extends StatelessWidget {
  final LlmStatus status;

  const _LlmStatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final (color, icon, label) = switch (status) {
      LlmStatus.ready => (cs.primary, Icons.check_circle_rounded, 'Pronto'),
      LlmStatus.generating => (cs.tertiary, Icons.auto_awesome, 'Gerando…'),
      LlmStatus.downloading => (
        cs.secondary,
        Icons.download_rounded,
        'Baixando…',
      ),
      LlmStatus.loading => (
        cs.secondary,
        Icons.hourglass_top_rounded,
        'Carregando…',
      ),
      LlmStatus.error => (cs.error, Icons.error_outline_rounded, 'Erro'),
      LlmStatus.uninitialized => (
        cs.onSurfaceVariant,
        Icons.psychology_outlined,
        'Modelo não instalado',
      ),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: color, fontSize: 12)),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final LlmState llmState;
  final List<String> suggestedPrompts;
  final void Function(String) onSuggestion;
  final VoidCallback onSetup;

  const _EmptyState({
    required this.llmState,
    required this.suggestedPrompts,
    required this.onSuggestion,
    required this.onSetup,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    if (llmState.status == LlmStatus.uninitialized) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.download_for_offline_rounded,
                size: 64,
                color: cs.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Modelo não instalado',
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Baixe o modelo para usar o assistente.',
                style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onSetup,
                icon: const Icon(Icons.download_rounded),
                label: const Text('Instalar modelo'),
              ),
            ],
          ),
        ),
      );
    }

    if (llmState.status == LlmStatus.loading ||
        llmState.status == LlmStatus.downloading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              llmState.status == LlmStatus.loading
                  ? 'Carregando modelo na memória…'
                  : 'Baixando modelo…',
              style: tt.bodyMedium,
            ),
          ],
        ),
      );
    }

    // Ready — show suggested prompts
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 20, color: cs.primary),
              const SizedBox(width: 8),
              Text(
                'Sugestões de perguntas',
                style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: suggestedPrompts
                .map(
                  (s) => ActionChip(
                    label: Text(s),
                    onPressed: () => onSuggestion(s),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _WebUnsupportedBanner extends StatelessWidget {
  final ColorScheme cs;

  const _WebUnsupportedBanner({required this.cs});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.phonelink_erase_rounded, size: 64, color: cs.error),
            const SizedBox(height: 16),
            Text(
              'Não disponível no Web',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'O assistente IA local requer o app Android ou Linux.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
