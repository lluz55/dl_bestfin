import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/theme/breakpoints.dart';
import 'package:bestfin/core/widgets/app_page_appbar.dart';
import 'package:bestfin/core/widgets/app_button.dart';
import 'package:bestfin/core/widgets/empty_state.dart';
import 'package:bestfin/core/widgets/loading_indicator.dart';
import 'package:bestfin/features/recurring/domain/models/recurring_rule.dart';
import 'package:bestfin/features/recurring/presentation/providers/recurring_provider.dart';
import 'package:bestfin/features/recurring/presentation/widgets/recurring_card.dart';
import 'package:bestfin/features/transactions/presentation/providers/transaction_form_modal_provider.dart';

class RecurringListScreen extends ConsumerStatefulWidget {
  const RecurringListScreen({super.key});

  @override
  ConsumerState<RecurringListScreen> createState() =>
      _RecurringListScreenState();
}

class _RecurringListScreenState extends ConsumerState<RecurringListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _pause(String id) async {
    await ref.read(pauseRecurringProvider)(id);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Recorrência pausada.')));
    }
  }

  Future<void> _resume(String id) async {
    await ref.read(resumeRecurringProvider)(id);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Recorrência retomada.')));
    }
  }

  Future<void> _delete(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir recorrência?'),
        content: const Text(
          'As transações já geradas não serão excluídas. '
          'Apenas a regra de recorrência será removida.',
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
      await ref.read(deleteRecurringProvider)(id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Recorrência excluída.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final isExpanded = Breakpoints.isExpanded(context);

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppPageAppBar(
        title: 'Recorrentes',
        infoDescription: 'Gerencie transações recorrentes como assinaturas, mensalidades e contas fixas. Configure a frequência e a renovação automática.',
        infoFeatures: const [
          'Transações com renovação automática',
          'Frequência: diária, semanal, mensal, anual',
          'Hub de assinaturas dedicado',
          'Controle de próximos vencimentos',
        ],
        actions: [
          IconButton(
            icon: const Icon(Icons.dashboard_rounded),
            tooltip: 'Hub de Assinaturas',
            onPressed: () => context.push('/recurring/subscriptions'),
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Nova recorrência',
            onPressed: () => ref
                .read(transactionFormModalProvider.notifier)
                .open(openRecurringWizard: true),
          ),
        ],
      ),
      body: Column(
        children: [
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Ativas'),
              Tab(text: 'Pausadas'),
              Tab(text: 'Finalizadas'),
            ],
            labelStyle: context.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _RuleList(
                  watchProvider: (ref) => ref.watch(activeRecurringProvider),
                  onPause: _pause,
                  onResume: _resume,
                  onDelete: _delete,
                  emptyTitle: 'Nenhuma recorrência ativa',
                  emptyDescription:
                      'Crie uma recorrência para automatizar despesas e receitas que se repetem.',
                  emptyIcon: Icons.repeat_rounded,
                  isExpanded: isExpanded,
                ),
                _RuleList(
                  watchProvider: (ref) => ref.watch(pausedRecurringProvider),
                  onPause: _pause,
                  onResume: _resume,
                  onDelete: _delete,
                  emptyTitle: 'Nenhuma recorrência pausada',
                  emptyDescription:
                      'Recorrências pausadas aparecem aqui. Você pode retomá-las a qualquer momento.',
                  emptyIcon: Icons.pause_circle_outline_rounded,
                  isExpanded: isExpanded,
                ),
                _RuleList(
                  watchProvider: (ref) => ref.watch(finishedRecurringProvider),
                  onPause: _pause,
                  onResume: _resume,
                  onDelete: _delete,
                  emptyTitle: 'Nenhuma recorrência finalizada',
                  emptyDescription:
                      'Recorrências que atingiram a data de término aparecem aqui.',
                  emptyIcon: Icons.check_circle_outline_rounded,
                  isExpanded: isExpanded,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RuleList extends ConsumerWidget {
  final AsyncValue<List<RecurringRuleModel>> Function(WidgetRef) watchProvider;
  final Future<void> Function(String) onPause;
  final Future<void> Function(String) onResume;
  final Future<void> Function(String) onDelete;
  final String emptyTitle;
  final String emptyDescription;
  final IconData emptyIcon;
  final bool isExpanded;

  const _RuleList({
    required this.watchProvider,
    required this.onPause,
    required this.onResume,
    required this.onDelete,
    required this.emptyTitle,
    required this.emptyDescription,
    required this.emptyIcon,
    this.isExpanded = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncRules = watchProvider(ref);

    return asyncRules.when(
      loading: () => const Center(child: AppLoadingIndicator()),
      error: (e, _) => Center(child: Text('Erro: $e')),
      data: (rules) {
        if (rules.isEmpty) {
          return EmptyState(
            title: emptyTitle,
            description: emptyDescription,
            icon: emptyIcon,
          );
        }

        if (isExpanded) {
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 3.5,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: rules.length,
            itemBuilder: (context, index) {
              final rule = rules[index];
              return RecurringCard(
                rule: rule,
                onPause: () => onPause(rule.id),
                onResume: () => onResume(rule.id),
                onDelete: () => onDelete(rule.id),
              );
            },
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(top: 8, bottom: 100),
          itemCount: rules.length,
          itemBuilder: (context, index) {
            final rule = rules[index];
            return RecurringCard(
              rule: rule,
              onPause: () => onPause(rule.id),
              onResume: () => onResume(rule.id),
              onDelete: () => onDelete(rule.id),
            );
          },
        );
      },
    );
  }
}
