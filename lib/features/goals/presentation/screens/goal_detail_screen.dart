import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/utils/adaptive_modal.dart';
import 'package:bestfin/core/widgets/app_page_appbar.dart';
import 'package:bestfin/core/utils/currency_formatter.dart';
import 'package:bestfin/core/providers/privacy_provider.dart';
import 'package:bestfin/core/widgets/loading_indicator.dart';
import 'package:bestfin/features/goals/domain/models/goal.dart';
import 'package:bestfin/features/goals/presentation/providers/goals_provider.dart';
import 'package:bestfin/features/goals/presentation/providers/goal_form_modal_provider.dart';
import 'package:bestfin/features/goals/presentation/widgets/progress_ring_widget.dart';
import 'package:bestfin/features/goals/presentation/widgets/monthly_simulator_widget.dart';
import 'package:bestfin/features/goals/presentation/widgets/goal_celebration_widget.dart';
import 'package:bestfin/features/transactions/presentation/widgets/amount_input.dart';

class GoalDetailScreen extends ConsumerStatefulWidget {
  final String goalId;

  const GoalDetailScreen({super.key, required this.goalId});

  @override
  ConsumerState<GoalDetailScreen> createState() => _GoalDetailScreenState();
}

class _GoalDetailScreenState extends ConsumerState<GoalDetailScreen> {
  bool _showCelebration = false;
  bool _wasCompleted = false;

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final asyncGoal = ref.watch(goalByIdProvider(widget.goalId));

    return asyncGoal.when(
      loading: () => const Scaffold(body: Center(child: AppLoadingIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Erro: $e'))),
      data: (goal) {
        if (goal == null) {
          return Scaffold(
            appBar: const AppPageAppBar(title: ''),
            body: const Center(child: Text('Objetivo não encontrado.')),
          );
        }

        // Detecta conclusão
        if (!_wasCompleted && goal.isCompleted) {
          _wasCompleted = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _showCelebration = true);
          });
        }

        final goalColor = _parseColor(goal.color, cs.primary);

        return Stack(
          children: [
            _buildContent(context, goal, goalColor),
            if (_showCelebration)
              GoalCelebrationWidget(
                goalName: goal.name,
                onDismiss: () => setState(() => _showCelebration = false),
              ),
          ],
        );
      },
    );
  }

  Widget _buildContent(BuildContext context, GoalModel goal, Color goalColor) {
    ref.watch(valuesHiddenProvider);
    final cs = context.colorScheme;
    final tt = context.textTheme;
    final dateFormat = DateFormat('dd/MM/yyyy');

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppPageAppBar(
        title: goal.name,
        showVisibilityToggle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            onPressed: () =>
                ref.read(goalFormModalProvider.notifier).open(goal: goal),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // Hero card com progress ring e descrição
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [goalColor, goalColor.withValues(alpha: 0.7)],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  ProgressRingWidget(
                    progress: goal.progressFraction,
                    size: 140,
                    strokeWidth: 13,
                    color: Colors.white,
                    currentAmountInCents: goal.currentAmountInCents,
                    targetAmountInCents: goal.targetAmountInCents,
                  ),
                  if (goal.description != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      goal.description!,
                      style: tt.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Conteúdo
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stats rápidas
                  _StatsRow(goal: goal, goalColor: goalColor),
                  const SizedBox(height: 24),

                  // Botão contribuir
                  if (!goal.isCompleted) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: () => _showContributeSheet(goal),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Contribuir'),
                        style: FilledButton.styleFrom(
                          backgroundColor: goalColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Informações
                  _InfoCard(
                    goal: goal,
                    goalColor: goalColor,
                    dateFormat: dateFormat,
                  ),
                  const SizedBox(height: 24),

                  // Simulador mensal
                  if (!goal.isCompleted && goal.remainingInCents > 0) ...[
                    Text(
                      'Simulador',
                      style: tt.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    MonthlySimulatorWidget(
                      remainingInCents: goal.remainingInCents,
                      initialMonths: goal.monthsRemaining,
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Ações
                  _ActionsSection(goal: goal),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showContributeSheet(GoalModel goal) async {
    final result = await showAdaptiveModal<bool>(
      context: context,
      builder: (ctx) => _ContributeSheetDetail(goal: goal),
    );
    if (result == true && mounted) {
      final updated = await ref
          .read(goalRepositoryProvider)
          .watchGoalById(goal.id)
          .first;
      if (updated != null && updated.isCompleted && !goal.isCompleted) {
        setState(() => _showCelebration = true);
      }
    }
  }

  Color _parseColor(String? hex, Color fallback) {
    if (hex == null) return fallback;
    try {
      final h = hex.replaceAll('#', '');
      return Color(int.parse('FF$h', radix: 16));
    } catch (_) {
      return fallback;
    }
  }
}

class _StatsRow extends StatelessWidget {
  final GoalModel goal;
  final Color goalColor;

  const _StatsRow({required this.goal, required this.goalColor});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: goal.type == GoalType.saving ? 'Poupado' : 'Gasto',
            value: CurrencyFormatter.formatCents(goal.currentAmountInCents),
            color: goalColor,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatCard(
            label: goal.type == GoalType.saving ? 'Restante' : 'Disponível',
            value: goal.remainingInCents > 0
                ? CurrencyFormatter.formatCents(goal.remainingInCents)
                : goal.type == GoalType.saving
                ? 'Meta atingida!'
                : 'Orçamento excedido!',
            color: goal.isCompleted
                ? const Color(0xFF43A047)
                : (goal.type == GoalType.spending && goal.remainingInCents < 0)
                ? cs.error
                : cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatCard(
            label: goal.type == GoalType.saving ? 'Meta total' : 'Limite total',
            value: CurrencyFormatter.formatCents(goal.targetAmountInCents),
            color: cs.onSurface,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: tt.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: tt.bodySmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: color,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final GoalModel goal;
  final Color goalColor;
  final DateFormat dateFormat;

  const _InfoCard({
    required this.goal,
    required this.goalColor,
    required this.dateFormat,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          if (goal.targetDate != null) ...[
            _InfoRow(
              icon: Icons.calendar_today_rounded,
              label: 'Prazo',
              value: dateFormat.format(goal.targetDate!),
              color: goalColor,
            ),
            Divider(height: 1, color: cs.outlineVariant),
          ],
          if (goal.monthsRemaining != null) ...[
            _InfoRow(
              icon: Icons.timer_rounded,
              label: 'Meses restantes',
              value: '${goal.monthsRemaining} meses',
              color: cs.onSurface,
            ),
            Divider(height: 1, color: cs.outlineVariant),
          ],
          if (goal.monthlyTargetInCents != null) ...[
            _InfoRow(
              icon: Icons.trending_up_rounded,
              label: goal.type == GoalType.saving
                  ? 'Poupar por mês'
                  : 'Orçamento mensal',
              value: CurrencyFormatter.formatCents(goal.monthlyTargetInCents!),
              color: goalColor,
            ),
            Divider(height: 1, color: cs.outlineVariant),
          ],
          _InfoRow(
            icon: Icons.flag_rounded,
            label: 'Status',
            value: goal.status.label,
            color: goal.isCompleted ? const Color(0xFF43A047) : cs.onSurface,
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 18, color: cs.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
          Text(
            value,
            style: tt.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionsSection extends ConsumerWidget {
  final GoalModel goal;

  const _ActionsSection({required this.goal});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        if (goal.status == GoalStatus.active)
          OutlinedButton.icon(
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Arquivar objetivo?'),
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
                if (context.mounted) context.pop();
              }
            },
            icon: const Icon(Icons.archive_outlined),
            label: const Text('Arquivar objetivo'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Excluir objetivo?'),
                content: const Text('Esta ação não pode ser desfeita.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancelar'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: FilledButton.styleFrom(backgroundColor: cs.error),
                    child: const Text('Excluir'),
                  ),
                ],
              ),
            );
            if (confirm == true) {
              await ref.read(deleteGoalProvider)(goal.id);
              if (context.mounted) context.pop();
            }
          },
          icon: Icon(Icons.delete_outline_rounded, color: cs.error),
          label: Text('Excluir objetivo', style: TextStyle(color: cs.error)),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
            side: BorderSide(color: cs.error.withValues(alpha: 0.5)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ],
    );
  }
}

// Versão do sheet de contribuição para tela de detalhe
class _ContributeSheetDetail extends ConsumerStatefulWidget {
  final GoalModel goal;
  const _ContributeSheetDetail({required this.goal});

  @override
  ConsumerState<_ContributeSheetDetail> createState() =>
      _ContributeSheetDetailState();
}

class _ContributeSheetDetailState
    extends ConsumerState<_ContributeSheetDetail> {
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
            'Contribuir para "${widget.goal.name}"',
            style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Faltam ${CurrencyFormatter.formatCents(widget.goal.remainingInCents)} para atingir a meta',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          AmountInput(
            amountInCents: _amountInCents,
            label: 'Valor',
            color: cs.primary,
            onChanged: (val) => setState(() => _amountInCents = val),
          ),
          const SizedBox(height: 12),
          TextFormField(
            decoration: InputDecoration(
              labelText: 'ID da Conta de Origem',
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
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed:
                  _saving || _amountInCents <= 0 || _fromAccountId == null
                  ? null
                  : _save,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Confirmar contribuição',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
            ),
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
