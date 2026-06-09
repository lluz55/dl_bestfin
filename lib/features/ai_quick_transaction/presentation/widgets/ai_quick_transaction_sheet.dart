import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:bestfin/core/constants/transaction_types.dart';
import 'package:bestfin/core/constants/account_types.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/database/database_provider.dart';
import 'package:bestfin/core/widgets/entity_autocomplete.dart'
    show allEntitiesProvider;
import 'package:bestfin/core/widgets/color_picker.dart' show AppColorPicker;
import 'package:bestfin/features/accounts/presentation/providers/accounts_provider.dart';
import 'package:bestfin/features/categories/presentation/providers/categories_provider.dart'
    show allFlatCategoriesProvider, createCategoryProvider;
import 'package:bestfin/features/credit_cards/domain/models/credit_card.dart';
import 'package:bestfin/features/credit_cards/presentation/providers/credit_cards_provider.dart';
import 'package:bestfin/features/llm/domain/models/llm_state.dart';
import 'package:bestfin/features/llm/presentation/providers/llm_provider.dart';
import 'package:bestfin/features/recurring/domain/models/recurring_rule.dart';
import 'package:bestfin/features/transactions/domain/models/transaction.dart';

import 'package:bestfin/features/ai_quick_transaction/domain/models/ai_quick_tx_state.dart';
import 'package:bestfin/features/ai_quick_transaction/domain/models/ai_transaction_draft.dart';
import 'package:bestfin/features/ai_quick_transaction/presentation/providers/ai_quick_tx_notifier.dart';

class AiQuickTransactionSheet extends ConsumerStatefulWidget {
  const AiQuickTransactionSheet({super.key});

  @override
  ConsumerState<AiQuickTransactionSheet> createState() =>
      _AiQuickTransactionSheetState();
}

class _AiQuickTransactionSheetState
    extends ConsumerState<AiQuickTransactionSheet> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(aiQuickTxProvider.notifier).reset();
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    HapticFeedback.mediumImpact();
    ref.read(aiQuickTxProvider.notifier).parse(text);
  }

  void _editRawInput(String rawInput) {
    _controller.text = rawInput;
    ref.read(aiQuickTxProvider.notifier).reset();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _focusNode.requestFocus(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(aiQuickTxProvider);
    final cs = context.colorScheme;
    final shapes = context.shapes;
    final motion = context.motion;

    ref.listen(aiQuickTxProvider, (_, next) {
      if (next is AiQuickTxDone) {
        HapticFeedback.lightImpact();
        final nav = Navigator.of(context);
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) nav.pop();
        });
      }
    });

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(shapes.bottomSheet.topLeft.x),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        8,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DragHandle(cs: cs),
          const SizedBox(height: 16),
          _SheetHeader(cs: cs),
          const SizedBox(height: 20),
          AnimatedSwitcher(
            duration: motion.morphDuration,
            switchInCurve: motion.morphCurve,
            switchOutCurve: motion.morphCurve,
            child: switch (state) {
              AiQuickTxIdle() => _InputPhase(
                key: const ValueKey('input'),
                controller: _controller,
                focusNode: _focusNode,
                onSubmit: _submit,
              ),
              AiQuickTxError(:final message) => _InputPhase(
                key: const ValueKey('input_error'),
                controller: _controller,
                focusNode: _focusNode,
                onSubmit: _submit,
                error: message,
              ),
              AiQuickTxParsing() => const _ParsingIndicator(
                key: ValueKey('parsing'),
              ),
              AiQuickTxNeedsType(:final partial) => _NeedsTypePhase(
                key: const ValueKey('needs_type'),
                partial: partial,
                controller: _controller,
                focusNode: _focusNode,
                onSubmit: _submit,
                onEditInput: () => _editRawInput(partial.rawInput),
              ),
              AiQuickTxPreview(:final draft) => _PreviewPhase(
                key: const ValueKey('preview'),
                draft: draft,
                onConfirm: () => ref.read(aiQuickTxProvider.notifier).confirm(),
                onExpand: () => _expandToFullForm(draft),
                onEditInput: () => _editRawInput(draft.rawInput),
              ),
              AiQuickTxSaving() => const _SavingIndicator(
                key: ValueKey('saving'),
              ),
              AiQuickTxDone() => _DoneWidget(
                key: const ValueKey('done'),
                cs: cs,
              ),
            },
          ),
        ],
      ),
    );
  }

  void _expandToFullForm(AiTransactionDraft draft) {
    Navigator.of(context).pop();
    context.push(
      '/transaction/new?type=${(draft.type ?? TransactionType.expense).name}&isCloning=true',
      extra: TransactionModel(
        id: '',
        date: draft.date,
        description: draft.description,
        type: draft.type ?? TransactionType.expense,
        isCompleted: true,
        createdAt: draft.date,
        updatedAt: draft.date,
        categoryId: draft.categoryId,
        rawAmount: (draft.amount * 100).round(),
        entries: const [],
      ),
    );
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────

class _RawInputPill extends StatelessWidget {
  final String rawInput;
  final VoidCallback onEdit;
  const _RawInputPill({required this.rawInput, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.textTheme;
    return GestureDetector(
      onTap: onEdit,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.edit_outlined, size: 13, color: cs.onSurfaceVariant),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                rawInput,
                style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// An [ActionChip] that renders in a "required / missing" style when [filled] is false.
class _FieldChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool filled;
  final VoidCallback onTap;

  const _FieldChip({
    required this.icon,
    required this.label,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final color = filled ? cs.onSurface : cs.error;
    return ActionChip(
      avatar: Icon(
        filled ? icon : Icons.error_outline_rounded,
        size: 14,
        color: color,
      ),
      label: Text(label, style: TextStyle(fontSize: 12, color: color)),
      backgroundColor: filled ? null : cs.errorContainer.withValues(alpha: 0.3),
      side: filled ? null : BorderSide(color: cs.error.withValues(alpha: 0.5)),
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
    );
  }
}

// ── Sub-widgets ──────────────────────────────────────────────────────────────

class _DragHandle extends StatelessWidget {
  final ColorScheme cs;
  const _DragHandle({required this.cs});

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: cs.onSurfaceVariant.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );
}

class _SheetHeader extends StatelessWidget {
  final ColorScheme cs;
  const _SheetHeader({required this.cs});

  @override
  Widget build(BuildContext context) {
    final tt = context.textTheme;
    return Row(
      children: [
        Icon(Icons.auto_awesome_rounded, size: 20, color: cs.secondary),
        const SizedBox(width: 8),
        Text(
          'Transação Rápida',
          style: tt.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: cs.onSurface,
          ),
        ),
      ],
    );
  }
}

class _InputPhase extends ConsumerWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSubmit;
  final String? error;

  const _InputPhase({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onSubmit,
    this.error,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = context.colorScheme;
    final tt = context.textTheme;
    final shapes = context.shapes;
    final isReady = ref.watch(llmStateProvider).status == LlmStatus.ready;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (error != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: cs.errorContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 16,
                  color: cs.onErrorContainer,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    error!,
                    style: tt.labelMedium?.copyWith(color: cs.onErrorContainer),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: controller,
          focusNode: focusNode,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => onSubmit(),
          style: tt.bodyLarge,
          decoration: InputDecoration(
            hintText: 'Ex: paguei 50 no almoço ontem no Outback',
            hintStyle: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
            filled: true,
            fillColor: cs.surfaceContainerHigh,
            border: OutlineInputBorder(
              borderRadius: shapes.card,
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
        if (!isReady) ...[
          const SizedBox(height: 6),
          Text(
            'IA não disponível · modo básico ativo',
            style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 12),
        FilledButton(onPressed: onSubmit, child: const Text('Analisar')),
      ],
    ).animate().fadeIn(duration: 200.ms);
  }
}

class _ParsingIndicator extends StatelessWidget {
  const _ParsingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          CircularProgressIndicator(color: cs.secondary),
          const SizedBox(height: 16),
          Text(
            'Interpretando transação...',
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 200.ms);
  }
}

class _NeedsTypePhase extends ConsumerWidget {
  final AiTransactionDraft partial;
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSubmit;
  final VoidCallback onEditInput;

  const _NeedsTypePhase({
    super.key,
    required this.partial,
    required this.controller,
    required this.focusNode,
    required this.onSubmit,
    required this.onEditInput,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = context.colorScheme;
    final tt = context.textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _InputPhase(
          controller: controller,
          focusNode: focusNode,
          onSubmit: onSubmit,
        ),
        const SizedBox(height: 16),
        Text(
          'Qual o tipo da transação?',
          style: tt.labelLarge?.copyWith(
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: TransactionType.values.map((type) {
            return ChoiceChip(
              selected: false,
              onSelected: (_) =>
                  ref.read(aiQuickTxProvider.notifier).selectType(type),
              avatar: Icon(type.icon, size: 16, color: cs.onSurfaceVariant),
              label: Text(type.label),
            );
          }).toList(),
        ),
      ],
    ).animate().fadeIn(duration: 200.ms);
  }
}

class _PreviewPhase extends ConsumerWidget {
  final AiTransactionDraft draft;
  final VoidCallback onConfirm;
  final VoidCallback onExpand;
  final VoidCallback onEditInput;

  const _PreviewPhase({
    super.key,
    required this.draft,
    required this.onConfirm,
    required this.onExpand,
    required this.onEditInput,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = context.colorScheme;
    final tt = context.textTheme;
    final shapes = context.shapes;
    final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final notifier = ref.read(aiQuickTxProvider.notifier);
    final now = DateTime.now();
    final type = draft.type ?? TransactionType.expense;
    final isTransfer = type == TransactionType.transfer;

    final typeColor = switch (type) {
      TransactionType.income => Colors.green,
      TransactionType.expense => cs.error,
      TransactionType.transfer => cs.secondary,
    };

    final allAccounts = ref.watch(activeAccountsProvider);
    final creditCards = ref.watch(creditCardsStreamProvider).value ?? [];

    final isToday =
        draft.date.year == now.year &&
        draft.date.month == now.month &&
        draft.date.day == now.day;
    final dateLabel = isToday
        ? 'Hoje'
        : DateFormat('dd/MM/yyyy').format(draft.date);

    final entityLabel = isTransfer
        ? null
        : (type == TransactionType.income ? 'De quem?' : 'Para quem?');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Edit-input pill
        Align(
          alignment: Alignment.centerLeft,
          child: _RawInputPill(rawInput: draft.rawInput, onEdit: onEditInput),
        ),
        const SizedBox(height: 12),

        // ── Preview card ──────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHigh,
            borderRadius: shapes.card,
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Amount + description row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      draft.description,
                      style: tt.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    draft.amount > 0 ? fmt.format(draft.amount) : '—',
                    style: tt.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: draft.amount > 0 ? typeColor : cs.error,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // All field chips
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  // Type
                  ActionChip(
                    avatar: Icon(type.icon, size: 14, color: typeColor),
                    label: Text(
                      type.label,
                      style: TextStyle(color: typeColor, fontSize: 12),
                    ),
                    backgroundColor: typeColor.withValues(alpha: 0.12),
                    side: BorderSide(color: typeColor.withValues(alpha: 0.3)),
                    onPressed: () => _showTypeSelector(context, ref),
                    visualDensity: VisualDensity.compact,
                  ),

                  // Amount (if missing)
                  if (draft.amount <= 0)
                    _FieldChip(
                      icon: Icons.monetization_on_outlined,
                      label: 'Valor?',
                      filled: false,
                      onTap: onExpand,
                    ),

                  // Category
                  _FieldChip(
                    icon: draft.categoryId != null
                        ? Icons.label_rounded
                        : Icons.label_outline_rounded,
                    label: draft.categoryName ?? 'Categoria?',
                    filled: draft.categoryId != null,
                    onTap: () => _showCategorySelector(context, ref),
                  ),

                  // Origin account
                  _FieldChip(
                    icon: draft.creditCardId != null
                        ? Icons.credit_card_rounded
                        : (draft.accountId != null
                            ? Icons.account_balance_wallet_rounded
                            : Icons.account_balance_wallet_outlined),
                    label: draft.creditCardId != null
                        ? (isTransfer ? 'De: ${draft.creditCardName}' : draft.creditCardName!)
                        : (isTransfer
                            ? 'De: ${draft.accountName ?? '?'}'
                            : (draft.accountName ?? 'Conta?')),
                    filled: draft.accountId != null || draft.creditCardId != null,
                    onTap: () => _showAccountSelector(
                      context,
                      ref,
                      allAccounts,
                      creditCards,
                      isOrigin: true,
                    ),
                  ),

                  // Destination account (transfers only)
                  if (isTransfer)
                    _FieldChip(
                      icon: draft.toAccountId != null
                          ? Icons.account_balance_wallet_rounded
                          : Icons.account_balance_wallet_outlined,
                      label: 'Para: ${draft.toAccountName ?? '?'}',
                      filled:
                          draft.toAccountId != null &&
                          draft.toAccountId != draft.accountId,
                      onTap: () => _showAccountSelector(
                        context,
                        ref,
                        allAccounts,
                        creditCards,
                        isOrigin: false,
                      ),
                    ),

                  // Entity (expense/income only)
                  if (!isTransfer)
                    _FieldChip(
                      icon: draft.entityName != null
                          ? Icons.person_rounded
                          : Icons.person_outline_rounded,
                      label: draft.entityName ?? entityLabel!,
                      filled: draft.entityName != null,
                      onTap: () => _showEntitySelector(context, ref, type),
                    ),

                  // Date
                  ActionChip(
                    avatar: const Icon(Icons.calendar_today_outlined, size: 14),
                    label: Text(
                      dateLabel,
                      style: const TextStyle(fontSize: 12),
                    ),
                    onPressed: () => _showDatePicker(context, ref),
                    visualDensity: VisualDensity.compact,
                  ),

                  // Recurrence
                  ActionChip(
                    avatar: Icon(
                      draft.isRecurring
                          ? Icons.repeat_rounded
                          : Icons.repeat_outlined,
                      size: 14,
                      color: draft.isRecurring
                          ? cs.primary
                          : cs.onSurfaceVariant,
                    ),
                    label: Text(
                      draft.isRecurring
                          ? (draft.recurringFrequency?.label ?? 'Recorrente')
                          : 'Recorrente?',
                      style: TextStyle(
                        fontSize: 12,
                        color: draft.isRecurring
                            ? cs.primary
                            : cs.onSurfaceVariant,
                      ),
                    ),
                    backgroundColor: draft.isRecurring
                        ? cs.primaryContainer.withValues(alpha: 0.5)
                        : null,
                    side: draft.isRecurring
                        ? BorderSide(color: cs.primary.withValues(alpha: 0.4))
                        : null,
                    onPressed: () => draft.isRecurring
                        ? _showFrequencySelector(context, ref)
                        : notifier.toggleRecurring(),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ],
          ),
        ),

        // Category suggestion row
        if (draft.categoryId == null &&
            draft.categorySuggestions.isNotEmpty) ...[
          const SizedBox(height: 10),
          _SuggestionRow(
            label: 'Sugestões:',
            icon: Icons.label_outline_rounded,
            children: draft.categorySuggestions
                .map(
                  (s) => ActionChip(
                    label: Text(s.name, style: const TextStyle(fontSize: 12)),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => notifier.selectCategory(s.id, s.name),
                  ),
                )
                .toList(),
          ),
        ],

        // Incomplete hint
        if (!draft.isComplete) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 14,
                color: cs.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Preencha os campos em vermelho para continuar.',
                  style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ],

        const SizedBox(height: 16),
        FilledButton(
          onPressed: draft.isComplete ? onConfirm : null,
          child: Text(
            draft.isRecurring ? 'Confirmar e criar recorrência' : 'Confirmar',
          ),
        ),
        const SizedBox(height: 8),
        TextButton(onPressed: onExpand, child: const Text('Editar completo')),
      ],
    ).animate().fadeIn(duration: 200.ms).slideY(begin: 0.05, end: 0);
  }

  // ── Selectors ─────────────────────────────────────────────────────────────

  void _showTypeSelector(BuildContext context, WidgetRef ref) {
    final cs = context.colorScheme;
    showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Tipo de transação',
              style: context.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...TransactionType.values.map(
              (t) => ListTile(
                leading: Icon(t.icon),
                title: Text(t.label),
                selected: draft.type == t,
                selectedTileColor: cs.secondaryContainer.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onTap: () {
                  ref.read(aiQuickTxProvider.notifier).selectType(t);
                  Navigator.of(context).pop();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCategorySelector(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _CategorySelectorSheet(
        draft: draft,
        onSelect: (id, name) {
          ref.read(aiQuickTxProvider.notifier).selectCategory(id, name);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  void _showAccountSelector(
    BuildContext context,
    WidgetRef ref,
    List accounts,
    List<CreditCardModel> creditCards, {
    required bool isOrigin,
  }) {
    final cs = context.colorScheme;
    final currentId = isOrigin ? (draft.creditCardId ?? draft.accountId) : draft.toAccountId;
    final excludeId = isOrigin ? draft.toAccountId : draft.accountId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          16,
          24,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isOrigin ? 'Conta / Cartão de origem' : 'Conta de destino',
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Novo(a)'),
                  onPressed: () {
                    Navigator.of(context).pop();
                    _showCreateAccountOrCardSheet(context, ref, isOrigin);
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (accounts.isNotEmpty) ...[
              Text(
                'Contas',
                style: context.textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 4),
              ...accounts
                  .where((a) => a.id != excludeId)
                  .map(
                    (a) => ListTile(
                      leading: const Icon(Icons.account_balance_wallet_outlined),
                      title: Text(a.name),
                      selected: currentId == a.id && draft.creditCardId == null,
                      selectedTileColor: cs.secondaryContainer.withValues(
                        alpha: 0.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      onTap: () {
                        if (isOrigin) {
                          ref
                              .read(aiQuickTxProvider.notifier)
                              .selectAccount(a.id, a.name);
                        } else {
                          ref
                              .read(aiQuickTxProvider.notifier)
                              .selectToAccount(a.id, a.name);
                        }
                        Navigator.of(context).pop();
                      },
                    ),
                  ),
            ],
            if (isOrigin && draft.type == TransactionType.expense && creditCards.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Cartões de Crédito',
                style: context.textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 4),
              ...creditCards.map(
                (c) => ListTile(
                  leading: const Icon(Icons.credit_card_rounded),
                  title: Text(c.name),
                  selected: currentId == c.id && draft.creditCardId != null,
                  selectedTileColor: cs.secondaryContainer.withValues(
                    alpha: 0.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onTap: () {
                    final linkedAccount = accounts.where((a) => a.id == c.accountId).firstOrNull;
                    ref
                        .read(aiQuickTxProvider.notifier)
                        .selectCreditCard(c.id, c.name, c.accountId, linkedAccount?.name ?? 'Conta Vinculada');
                    Navigator.of(context).pop();
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showCreateAccountOrCardSheet(
    BuildContext context,
    WidgetRef ref,
    bool isOrigin,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _CreateAccountOrCardSheet(
        isOrigin: isOrigin,
        type: draft.type,
      ),
    );
  }

  void _showEntitySelector(
    BuildContext context,
    WidgetRef ref,
    TransactionType type,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _EntitySelectorSheet(
        currentName: draft.entityName,
        entityType: type == TransactionType.income ? 'payer' : 'payee',
        label: type == TransactionType.income ? 'De quem?' : 'Para quem?',
        onSelect: (name) {
          ref.read(aiQuickTxProvider.notifier).selectEntity(name);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  Future<void> _showDatePicker(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: draft.date,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 1),
    );
    if (picked != null) ref.read(aiQuickTxProvider.notifier).selectDate(picked);
  }

  void _showFrequencySelector(BuildContext context, WidgetRef ref) {
    final cs = context.colorScheme;
    showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Frequência da recorrência',
                    style: context.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    ref.read(aiQuickTxProvider.notifier).toggleRecurring();
                    Navigator.of(context).pop();
                  },
                  child: const Text('Remover'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...RecurringFrequency.values.map(
              (f) => ListTile(
                title: Text(f.label),
                trailing: Text(
                  f.shortLabel,
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
                selected: draft.recurringFrequency == f,
                selectedTileColor: cs.primaryContainer.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onTap: () {
                  ref.read(aiQuickTxProvider.notifier).selectFrequency(f);
                  Navigator.of(context).pop();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Entity selector sheet ─────────────────────────────────────────────────────

class _EntitySelectorSheet extends ConsumerStatefulWidget {
  final String? currentName;
  final String entityType;
  final String label;
  final void Function(String name) onSelect;

  const _EntitySelectorSheet({
    required this.currentName,
    required this.entityType,
    required this.label,
    required this.onSelect,
  });

  @override
  ConsumerState<_EntitySelectorSheet> createState() =>
      _EntitySelectorSheetState();
}

class _EntitySelectorSheetState extends ConsumerState<_EntitySelectorSheet> {
  late final TextEditingController _controller;
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentName ?? '');
    _controller.addListener(_onTextChanged);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _focusNode.requestFocus(),
    );
  }

  void _onTextChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _confirm() {
    final name = _controller.text.trim();
    if (name.isNotEmpty) widget.onSelect(name);
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.textTheme;
    final shapes = context.shapes;
    final entitiesAsync = ref.watch(allEntitiesProvider);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.label,
            style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            focusNode: _focusNode,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _confirm(),
            decoration: InputDecoration(
              hintText: 'Nome da pessoa ou empresa',
              filled: true,
              fillColor: cs.surfaceContainerHigh,
              border: OutlineInputBorder(
                borderRadius: shapes.card,
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              suffixIcon: IconButton(
                icon: const Icon(Icons.check_rounded),
                onPressed: _confirm,
              ),
            ),
          ),
          // Existing entities as quick-select
          entitiesAsync.when(
            data: (entities) {
              final filtered = entities
                  .where((e) => e.type == widget.entityType)
                  .toList();
              final typedName = _controller.text.trim();
              final exists = filtered.any((e) => e.name.toLowerCase() == typedName.toLowerCase());

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (typedName.isNotEmpty && !exists) ...[
                    const SizedBox(height: 12),
                    ListTile(
                      leading: Icon(Icons.person_add_alt_1_rounded, color: cs.primary),
                      title: Text('Criar nova pessoa: "$typedName"'),
                      subtitle: Text(widget.entityType == 'payer' ? 'Registrar como pagador' : 'Registrar como recebedor'),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      tileColor: cs.primaryContainer.withValues(alpha: 0.15),
                      onTap: _confirm,
                    ),
                  ],
                  if (filtered.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Sugestões',
                      style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: filtered
                          .where((e) => typedName.isEmpty || e.name.toLowerCase().contains(typedName.toLowerCase()))
                          .take(8)
                          .map(
                            (e) => FilterChip(
                              label: Text(
                                e.name,
                                style: const TextStyle(fontSize: 12),
                              ),
                              visualDensity: VisualDensity.compact,
                              selected: _controller.text == e.name,
                              onSelected: (_) {
                                _controller.text = e.name;
                                widget.onSelect(e.name);
                              },
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ],
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _confirm, child: const Text('Confirmar')),
        ],
      ),
    );
  }
}

// ── Category selector sheet ───────────────────────────────────────────────────

class _CategorySelectorSheet extends ConsumerStatefulWidget {
  final AiTransactionDraft draft;
  final void Function(String id, String name) onSelect;

  const _CategorySelectorSheet({required this.draft, required this.onSelect});

  @override
  ConsumerState<_CategorySelectorSheet> createState() =>
      _CategorySelectorSheetState();
}

class _CategorySelectorSheetState
    extends ConsumerState<_CategorySelectorSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showCreateCategorySheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _CreateCategorySheet(
        initialType: widget.draft.type,
        onCategoryCreated: (id, name) {
          widget.onSelect(id, name);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.textTheme;
    final shapes = context.shapes;
    final all = ref.watch(allFlatCategoriesProvider);

    final typeStr = widget.draft.type?.name;
    final filtered = all
        .where((c) => !c.isArchived)
        .where((c) => typeStr == null || c.type == typeStr)
        .where(
          (c) =>
              _query.isEmpty ||
              c.name.toLowerCase().contains(_query.toLowerCase()) ||
              (c.parentName?.toLowerCase().contains(_query.toLowerCase()) ??
                  false),
        )
        .toList();

    final suggestedIds = widget.draft.categorySuggestions
        .map((s) => s.id)
        .toSet();
    final suggested = filtered
        .where((c) => suggestedIds.contains(c.id))
        .toList();
    final rest = filtered.where((c) => !suggestedIds.contains(c.id)).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Categoria',
                      style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Nova'),
                      onPressed: () {
                        _showCreateCategorySheet(context, ref);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: 'Buscar...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    filled: true,
                    fillColor: cs.surfaceContainerHigh,
                    border: OutlineInputBorder(
                      borderRadius: shapes.card,
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                if (suggested.isNotEmpty && _query.isEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                    child: Text(
                      'Sugeridas pela IA',
                      style: tt.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  ...suggested.map(
                    (c) => _CategoryTile(
                      category: c,
                      selected: widget.draft.categoryId == c.id,
                      cs: cs,
                      tt: tt,
                      onTap: () => widget.onSelect(c.id, c.name),
                    ),
                  ),
                  const Divider(height: 16),
                ],
                ...rest.map(
                  (c) => _CategoryTile(
                    category: c,
                    selected: widget.draft.categoryId == c.id,
                    cs: cs,
                    tt: tt,
                    onTap: () => widget.onSelect(c.id, c.name),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final dynamic category;
  final bool selected;
  final ColorScheme cs;
  final TextTheme tt;
  final VoidCallback onTap;

  const _CategoryTile({
    required this.category,
    required this.selected,
    required this.cs,
    required this.tt,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => ListTile(
    dense: true,
    title: Text(
      category.parentName != null
          ? '${category.parentName} › ${category.name}'
          : category.name,
      style: tt.bodyMedium,
    ),
    selected: selected,
    selectedTileColor: cs.secondaryContainer.withValues(alpha: 0.5),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    onTap: onTap,
  );
}

class _SuggestionRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final List<Widget> children;

  const _SuggestionRow({
    required this.label,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 14, color: cs.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(label, style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
        const SizedBox(width: 8),
        Expanded(child: Wrap(spacing: 6, runSpacing: 4, children: children)),
      ],
    ).animate().fadeIn(duration: 200.ms).slideX(begin: -0.05, end: 0);
  }
}

class _SavingIndicator extends StatelessWidget {
  const _SavingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          LinearProgressIndicator(color: cs.secondary),
          const SizedBox(height: 16),
          Text(
            'Salvando transação...',
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 200.ms);
  }
}

class _DoneWidget extends StatelessWidget {
  final ColorScheme cs;
  const _DoneWidget({super.key, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          const Icon(Icons.check_circle_rounded, size: 48, color: Colors.green),
          const SizedBox(height: 12),
          Text(
            'Transação salva!',
            style: context.textTheme.titleMedium?.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).scale(begin: const Offset(0.8, 0.8));
  }
}

// ── New Entity / Category / Account Creation Sheets ──────────────────────────

class _CreateCategorySheet extends ConsumerStatefulWidget {
  final TransactionType? initialType;
  final void Function(String id, String name) onCategoryCreated;

  const _CreateCategorySheet({
    required this.initialType,
    required this.onCategoryCreated,
  });

  @override
  ConsumerState<_CreateCategorySheet> createState() => _CreateCategorySheetState();
}

class _CreateCategorySheetState extends ConsumerState<_CreateCategorySheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  late String _type;
  String _color = '#2196F3';
  String _icon = 'category';

  @override
  void initState() {
    super.initState();
    _type = widget.initialType?.name ?? 'expense';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      final name = _nameController.text.trim();
      final description = _descriptionController.text.trim();
      final descVal = description.isEmpty ? null : description;

      final newId = await ref.read(createCategoryProvider)(
        name: name,
        icon: _icon,
        color: _color,
        type: _type,
        description: descVal,
      );

      ref.invalidate(allFlatCategoriesProvider);

      if (mounted) {
        widget.onCategoryCreated(newId, name);
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar categoria: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.textTheme;
    final shapes = context.shapes;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Nova Categoria',
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Nome',
                hintText: 'Ex: Alimentação',
                filled: true,
                fillColor: cs.surfaceContainerHigh,
                border: OutlineInputBorder(
                  borderRadius: shapes.card,
                  borderSide: BorderSide.none,
                ),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: 'Descrição (opcional)',
                hintText: 'Ex: Compras de supermercado',
                filled: true,
                fillColor: cs.surfaceContainerHigh,
                border: OutlineInputBorder(
                  borderRadius: shapes.card,
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Cor', style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 8),
            _buildColorSelector(),
            const SizedBox(height: 16),
            Text('Ícone', style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 8),
            _buildIconSelector(),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _save,
              child: const Text('Salvar e Selecionar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorSelector() {
    final presetColors = ['#2196F3', '#4CAF50', '#FF9800', '#009688', '#9C27B0', '#F44336'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: presetColors.map((hex) {
        final color = AppColorPicker.hexToColor(hex);
        final isSelected = hex == _color;
        return GestureDetector(
          onTap: () => setState(() => _color = hex),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? Colors.white : Colors.transparent,
                width: 2,
              ),
            ),
            child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildIconSelector() {
    final icons = {
      'category': Icons.category_rounded,
      'shopping_bag': Icons.shopping_bag_rounded,
      'restaurant': Icons.restaurant_rounded,
      'directions_car': Icons.directions_car_rounded,
      'home': Icons.home_rounded,
      'local_grocery_store': Icons.local_grocery_store_rounded,
    };

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: icons.entries.map((entry) {
        final isSelected = entry.key == _icon;
        final color = AppColorPicker.hexToColor(_color);
        return GestureDetector(
          onTap: () => setState(() => _icon = entry.key),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isSelected ? color.withValues(alpha: 0.15) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? color : Colors.grey.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Icon(entry.value, color: isSelected ? color : Colors.grey),
          ),
        );
      }).toList(),
    );
  }
}

class _CreateAccountOrCardSheet extends ConsumerStatefulWidget {
  final bool isOrigin;
  final TransactionType? type;

  const _CreateAccountOrCardSheet({
    required this.isOrigin,
    required this.type,
  });

  @override
  ConsumerState<_CreateAccountOrCardSheet> createState() => _CreateAccountOrCardSheetState();
}

class _CreateAccountOrCardSheetState extends ConsumerState<_CreateAccountOrCardSheet> {
  bool _isCard = false;

  // Account form state
  final _accFormKey = GlobalKey<FormState>();
  final _accNameController = TextEditingController();
  final _accBalanceController = TextEditingController();
  AccountType _accType = AccountType.checking;
  String _accColor = '#2196F3';
  late String _accIcon;

  // Credit Card form state
  final _cardFormKey = GlobalKey<FormState>();
  final _cardNameController = TextEditingController();
  final _cardLimitController = TextEditingController();
  int _closingDay = 10;
  int _dueDay = 20;
  String? _cardAccountId;
  String _cardColor = '#2196F3';

  @override
  void initState() {
    super.initState();
    _accIcon = _accType.defaultIcon.codePoint.toString();
  }

  @override
  void dispose() {
    _accNameController.dispose();
    _accBalanceController.dispose();
    _cardNameController.dispose();
    _cardLimitController.dispose();
    super.dispose();
  }

  void _onAccTypeChanged(AccountType type) {
    setState(() {
      _accType = type;
      _accIcon = type.defaultIcon.codePoint.toString();
      _accColor = type.defaultColorHex;
    });
  }

  Future<void> _saveAccount() async {
    if (!_accFormKey.currentState!.validate()) return;
    try {
      final name = _accNameController.text.trim();
      final balance = (double.tryParse(_accBalanceController.text.trim().replaceAll(',', '.')) ?? 0.0) * 100;

      await ref.read(createAccountProvider)(
        name: name,
        type: _accType.name,
        icon: _accIcon,
        color: _accColor,
        initialBalance: balance.round(),
      );

      ref.invalidate(activeAccountsProvider);

      final db = ref.read(databaseProvider);
      final list = await db.select(db.accounts).get();
      final created = list.where((a) => a.name == name).firstOrNull;

      if (!mounted) return;

      if (created != null) {
        if (widget.isOrigin) {
          ref.read(aiQuickTxProvider.notifier).selectAccount(created.id, created.name);
        } else {
          ref.read(aiQuickTxProvider.notifier).selectToAccount(created.id, created.name);
        }
      }
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao criar conta: $e')),
        );
      }
    }
  }

  Future<void> _saveCard() async {
    if (!_cardFormKey.currentState!.validate()) return;
    if (_cardAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione uma conta para vincular o cartão')),
      );
      return;
    }
    try {
      final name = _cardNameController.text.trim();
      final limit = (double.tryParse(_cardLimitController.text.trim().replaceAll(',', '.')) ?? 0.0) * 100;

      final repository = ref.read(creditCardRepositoryProvider);
      await repository.createCreditCard(
        name: name,
        limitAmount: limit.round(),
        closingDay: _closingDay,
        dueDay: _dueDay,
        accountId: _cardAccountId!,
        color: _cardColor,
        minPaymentPercent: 15,
      );

      ref.invalidate(creditCardsStreamProvider);

      final db = ref.read(databaseProvider);
      final list = await db.select(db.creditCards).get();
      final created = list.where((c) => c.name == name).firstOrNull;

      if (!mounted) return;

      if (created != null) {
        final accounts = ref.read(activeAccountsProvider);
        final linkedAccount = accounts.where((a) => a.id == created.accountId).firstOrNull;
        ref
            .read(aiQuickTxProvider.notifier)
            .selectCreditCard(created.id, created.name, created.accountId, linkedAccount?.name ?? 'Conta Vinculada');
      }
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao criar cartão: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.textTheme;
    final shapes = context.shapes;
    final accounts = ref.watch(activeAccountsProvider);

    final showCardOption = widget.type == TransactionType.expense;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _isCard ? 'Novo Cartão' : 'Nova Conta',
                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              if (showCardOption)
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('Conta'), icon: Icon(Icons.account_balance_wallet)),
                    ButtonSegment(value: true, label: Text('Cartão'), icon: Icon(Icons.credit_card)),
                  ],
                  selected: {_isCard},
                  onSelectionChanged: (val) => setState(() => _isCard = val.first),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (!_isCard)
            Form(
              key: _accFormKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _accNameController,
                    decoration: InputDecoration(
                      labelText: 'Nome da Conta',
                      hintText: 'Ex: Itaú, Nubank, Carteira',
                      filled: true,
                      fillColor: cs.surfaceContainerHigh,
                      border: OutlineInputBorder(
                        borderRadius: shapes.card,
                        borderSide: BorderSide.none,
                      ),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _accBalanceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Saldo Inicial (R\$)',
                      hintText: 'Ex: 1500,00',
                      filled: true,
                      fillColor: cs.surfaceContainerHigh,
                      border: OutlineInputBorder(
                        borderRadius: shapes.card,
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Tipo de Conta', style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<AccountType>(
                    initialValue: _accType,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: cs.surfaceContainerHigh,
                      border: OutlineInputBorder(
                        borderRadius: shapes.card,
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: AccountType.values
                        .map((type) => DropdownMenuItem(value: type, child: Text(type.label)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) _onAccTypeChanged(val);
                    },
                  ),
                  const SizedBox(height: 16),
                  Text('Cor', style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  _buildColorSelector(_accColor, (c) => setState(() => _accColor = c)),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _saveAccount,
                    child: const Text('Criar Conta'),
                  ),
                ],
              ),
            )
          else
            Form(
              key: _cardFormKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _cardNameController,
                    decoration: InputDecoration(
                      labelText: 'Nome do Cartão',
                      hintText: 'Ex: Nubank, Inter',
                      filled: true,
                      fillColor: cs.surfaceContainerHigh,
                      border: OutlineInputBorder(
                        borderRadius: shapes.card,
                        borderSide: BorderSide.none,
                      ),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _cardLimitController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Limite do Cartão (R\$)',
                      hintText: 'Ex: 5000,00',
                      filled: true,
                      fillColor: cs.surfaceContainerHigh,
                      border: OutlineInputBorder(
                        borderRadius: shapes.card,
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: _closingDay,
                          decoration: InputDecoration(
                            labelText: 'Dia de Fechamento',
                            filled: true,
                            fillColor: cs.surfaceContainerHigh,
                            border: OutlineInputBorder(
                              borderRadius: shapes.card,
                              borderSide: BorderSide.none,
                            ),
                          ),
                          items: List.generate(31, (index) => index + 1)
                              .map((day) => DropdownMenuItem(value: day, child: Text('$day')))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _closingDay = val);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: _dueDay,
                          decoration: InputDecoration(
                            labelText: 'Dia de Vencimento',
                            filled: true,
                            fillColor: cs.surfaceContainerHigh,
                            border: OutlineInputBorder(
                              borderRadius: shapes.card,
                              borderSide: BorderSide.none,
                            ),
                          ),
                          items: List.generate(31, (index) => index + 1)
                              .map((day) => DropdownMenuItem(value: day, child: Text('$day')))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _dueDay = val);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _cardAccountId,
                    decoration: InputDecoration(
                      labelText: 'Conta para Débito da Fatura',
                      filled: true,
                      fillColor: cs.surfaceContainerHigh,
                      border: OutlineInputBorder(
                        borderRadius: shapes.card,
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: accounts
                        .map((acc) => DropdownMenuItem(value: acc.id, child: Text(acc.name)))
                        .toList(),
                    onChanged: (val) => setState(() => _cardAccountId = val),
                    validator: (v) => v == null ? 'Selecione a conta' : null,
                  ),
                  const SizedBox(height: 16),
                  Text('Cor', style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  _buildColorSelector(_cardColor, (c) => setState(() => _cardColor = c)),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _saveCard,
                    child: const Text('Criar Cartão'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildColorSelector(String selectedColor, ValueChanged<String> onSelected) {
    final presetColors = ['#2196F3', '#4CAF50', '#FF9800', '#009688', '#9C27B0', '#F44336'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: presetColors.map((hex) {
        final color = AppColorPicker.hexToColor(hex);
        final isSelected = hex == selectedColor;
        return GestureDetector(
          onTap: () => onSelected(hex),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? Colors.white : Colors.transparent,
                width: 2,
              ),
            ),
            child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
          ),
        );
      }).toList(),
    );
  }
}
