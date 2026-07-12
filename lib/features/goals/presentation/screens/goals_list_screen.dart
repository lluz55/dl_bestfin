import 'package:flutter/material.dart';
import 'package:bestfin/core/widgets/app_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/theme/breakpoints.dart';
import 'package:bestfin/core/utils/adaptive_modal.dart';
import 'package:bestfin/core/widgets/app_page_appbar.dart';
import 'package:bestfin/core/widgets/empty_state.dart';
import 'package:bestfin/core/widgets/loading_indicator.dart';
import 'package:bestfin/core/utils/currency_formatter.dart';
import 'package:bestfin/core/providers/privacy_provider.dart';
import 'package:bestfin/features/goals/domain/models/goal.dart';
import 'package:bestfin/features/goals/presentation/providers/goals_provider.dart';
import 'package:bestfin/features/goals/presentation/providers/goal_form_modal_provider.dart';
import 'package:bestfin/features/goals/presentation/widgets/goal_form_modal_overlay.dart';
import 'package:bestfin/features/goals/presentation/widgets/goal_card.dart';
import 'package:bestfin/features/goals/presentation/widgets/goal_celebration_widget.dart';
import 'package:bestfin/features/transactions/presentation/widgets/amount_input.dart';

class GoalsListScreen extends ConsumerStatefulWidget {
  const GoalsListScreen({super.key});

  @override
  ConsumerState<GoalsListScreen> createState() => _GoalsListScreenState();
}

class _GoalsListScreenState extends ConsumerState<GoalsListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  GoalModel? _celebratingGoal;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Reseta goals recorrentes cujo período expirou
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(resetExpiredGoalsProvider)();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _contribute(GoalModel goal) async {
    final result = await _showContributeSheet(goal);
    if (result == true && mounted) {
      // Verifica se atingiu meta após contribuição
      final updated = await ref
          .read(goalRepositoryProvider)
          .watchGoalById(goal.id)
          .first;
      if (updated != null && updated.isCompleted && !goal.isCompleted) {
        setState(() => _celebratingGoal = updated);
      }
    }
  }

  Future<bool?> _showContributeSheet(GoalModel goal) {
    return showAdaptiveModal<bool>(
      context: context,
      builder: (ctx) => _ContributeSheet(goal: goal),
    );
  }

  Future<void> _archive(GoalModel goal) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Arquivar objetivo?'),
        content: Text(
          'O objetivo "${goal.name}" será arquivado. Você pode ver objetivos arquivados nos filtros.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Arquivar'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(archiveGoalProvider)(goal.id);
    }
  }

  Future<void> _delete(GoalModel goal) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir objetivo?'),
        content: Text(
          'O objetivo "${goal.name}" será removido permanentemente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          AppButton(
            label: 'Excluir',
            variant: AppButtonVariant.destructive,
            size: AppButtonSize.compact,
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(deleteGoalProvider)(goal.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(valuesHiddenProvider);
    final cs = context.colorScheme;

    return Stack(
      children: [
        Scaffold(
          backgroundColor: cs.surface,
          appBar: AppPageAppBar(
            title: 'Metas',
            showVisibilityToggle: true,
            infoDescription: 'Defina metas financeiras com valor alvo e prazo, acompanhe o progresso e mantenha o foco nos seus objetivos.',
            infoFeatures: [
              'Metas com valor alvo e data limite',
              'Acompanhamento de progresso',
              'Celebração ao atingir a meta',
              'Editar ou excluir metas',
            ],
            actions: [
              IconButton(
                icon: const Icon(Icons.add_rounded),
                tooltip: 'Nova meta',
                onPressed: () =>
                    ref.read(goalFormModalProvider.notifier).open(),
              ),
            ],
          ),
          body: Column(
            children: [
              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'Ativas'),
                  Tab(text: 'Concluídas'),
                ],
                labelStyle: context.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _GoalsList(
                      watchProvider: (ref) => ref.watch(activeGoalsProvider),
                      onContribute: _contribute,
                      onArchive: _archive,
                      onDelete: _delete,
                      emptyTitle: 'Nenhuma meta ativa',
                      emptyDescription:
                          'Crie seu primeiro objetivo financeiro e acompanhe o progresso!',
                      emptyIcon: Icons.flag_rounded,
                      onAction: () =>
                          ref.read(goalFormModalProvider.notifier).open(),
                      actionLabel: 'Criar meta',
                    ),
                    _GoalsList(
                      watchProvider: (ref) => ref.watch(completedGoalsProvider),
                      onContribute: _contribute,
                      onArchive: _archive,
                      onDelete: _delete,
                      emptyTitle: 'Nenhuma meta concluída',
                      emptyDescription:
                          'Metas que você atingiu aparecerão aqui. Continue assim!',
                      emptyIcon: Icons.check_circle_outline_rounded,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Celebração overlay
        if (_celebratingGoal != null)
          GoalCelebrationWidget(
            goalName: _celebratingGoal!.name,
            onDismiss: () => setState(() => _celebratingGoal = null),
          ),

        const GoalFormModalOverlay(),
      ],
    );
  }
}

class _GoalsList extends ConsumerWidget {
  final AsyncValue<List<GoalModel>> Function(WidgetRef) watchProvider;
  final Future<void> Function(GoalModel) onContribute;
  final Future<void> Function(GoalModel) onArchive;
  final Future<void> Function(GoalModel) onDelete;
  final String emptyTitle;
  final String emptyDescription;
  final IconData emptyIcon;
  final VoidCallback? onAction;
  final String? actionLabel;

  const _GoalsList({
    required this.watchProvider,
    required this.onContribute,
    required this.onArchive,
    required this.onDelete,
    required this.emptyTitle,
    required this.emptyDescription,
    required this.emptyIcon,
    this.onAction,
    this.actionLabel,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncGoals = watchProvider(ref);
    final isExpanded = Breakpoints.isExpanded(context);

    return asyncGoals.when(
      loading: () => const Center(child: AppLoadingIndicator()),
      error: (e, _) => Center(child: Text('Erro: $e')),
      data: (goals) {
        if (goals.isEmpty) {
          return EmptyState(
            title: emptyTitle,
            description: emptyDescription,
            icon: emptyIcon,
            onAction: onAction,
            actionLabel: actionLabel,
          );
        }
        if (isExpanded) {
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 3.2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: goals.length,
            itemBuilder: (ctx, i) {
              final goal = goals[i];
              return GoalCard(
                goal: goal,
                onTap: () => context.push('/goals/${goal.id}'),
                onContribute: () => onContribute(goal),
                onArchive: () => onArchive(goal),
                onDelete: () => onDelete(goal),
              );
            },
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.only(top: 8, bottom: 100),
          itemCount: goals.length,
          itemBuilder: (ctx, i) {
            final goal = goals[i];
            return GoalCard(
              goal: goal,
              onTap: () => context.push('/goals/${goal.id}'),
              onContribute: () => onContribute(goal),
              onArchive: () => onArchive(goal),
              onDelete: () => onDelete(goal),
            );
          },
        );
      },
    );
  }
}

/// Bottom sheet de contribuição.
class _ContributeSheet extends ConsumerStatefulWidget {
  final GoalModel goal;
  const _ContributeSheet({required this.goal});

  @override
  ConsumerState<_ContributeSheet> createState() => _ContributeSheetState();
}

class _ContributeSheetState extends ConsumerState<_ContributeSheet> {
  int _amountInCents = 0;
  String? _fromAccountId;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
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
          const SizedBox(height: 16),
          Text(
            'Contribuir para: ${widget.goal.name}',
            style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Restante: ${CurrencyFormatter.formatCents(widget.goal.remainingInCents)}',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 20),

          // Campo de valor simples
          AmountInput(
            amountInCents: _amountInCents,
            label: 'Valor',
            color: cs.primary,
            onChanged: (val) => setState(() => _amountInCents = val),
          ),
          const SizedBox(height: 12),

          // Seletor de conta (simplificado - campo de texto por ora)
          // TODO: integrar AccountSelector quando disponível no contexto
          TextFormField(
            decoration: InputDecoration(
              labelText: 'ID da Conta de Origem',
              hintText: 'Cole o ID da conta',
              prefixIcon: const Icon(Icons.account_balance_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onChanged: (val) => setState(
              () => _fromAccountId = val.trim().isEmpty ? null : val.trim(),
            ),
          ),
          const SizedBox(height: 24),

          AppButton(
            label: 'Contribuir',
            expanded: true,
            loading: _saving,
            onPressed: _amountInCents <= 0 || _fromAccountId == null
                ? null
                : _save,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(addContributionProvider)(
        goalId: widget.goal.id,
        amountInCents: _amountInCents,
        fromAccountId: _fromAccountId!,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
