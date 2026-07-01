import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bestfin/core/constants/transaction_types.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/utils/currency_formatter.dart';
import 'package:bestfin/core/utils/icon_mapper.dart';
import 'package:bestfin/features/accounts/domain/models/account.dart';
import 'package:bestfin/features/accounts/presentation/providers/accounts_provider.dart';
import 'package:bestfin/features/categories/domain/models/category.dart';
import 'package:bestfin/features/categories/presentation/providers/categories_provider.dart';
import 'package:bestfin/features/gamification/presentation/providers/gamification_providers.dart';
import 'package:bestfin/features/transactions/domain/models/quick_suggestion.dart';
import 'package:bestfin/features/transactions/presentation/providers/quick_suggestions_provider.dart';
import 'package:bestfin/features/transactions/presentation/providers/transaction_form_modal_provider.dart';
import 'package:bestfin/core/providers/default_account_provider.dart';
import 'package:bestfin/features/transactions/presentation/providers/transactions_provider.dart';
import 'package:bestfin/features/transactions/presentation/widgets/amount_input.dart';
import 'package:bestfin/features/transactions/presentation/widgets/description_autocomplete.dart';
import 'package:bestfin/features/transactions/presentation/widgets/transaction_type_tabs.dart';

/// Bottom sheet de "Lançamento Rápido": cria qualquer transação (despesa,
/// receita ou transferência) em poucos toques, com chips de sugestão vindos do
/// recomendador estatístico ([quickSuggestionsProvider]). Para edição detalhada,
/// "Mais opções" abre o formulário completo.
class QuickTransactionSheet extends ConsumerStatefulWidget {
  const QuickTransactionSheet({super.key, required this.initialType});

  final TransactionType initialType;

  @override
  ConsumerState<QuickTransactionSheet> createState() =>
      _QuickTransactionSheetState();
}

class _QuickTransactionSheetState extends ConsumerState<QuickTransactionSheet> {
  late TransactionType _type;
  final _descriptionController = TextEditingController();

  int _amountInCents = 0;
  String? _accountId;
  String? _toAccountId;
  String? _categoryId;
  String? _entityId;
  bool _saving = false;

  bool get _isTransfer => _type == TransactionType.transfer;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _accountId != null) return;
      final accounts = ref.read(activeAccountsProvider);
      if (accounts.isEmpty) return;
      final defaultId = ref.read(defaultAccountIdProvider);
      setState(() {
        if (accounts.length == 1) {
          _accountId = accounts.first.id;
        } else if (defaultId != null &&
            accounts.any((a) => a.id == defaultId)) {
          _accountId = defaultId;
        }
      });
    });
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Color _typeColor(BuildContext context) {
    final colors = context.customColors;
    switch (_type) {
      case TransactionType.income:
        return colors.income;
      case TransactionType.expense:
        return colors.expense;
      case TransactionType.transfer:
        return colors.transfer;
    }
  }

  void _onTypeChanged(TransactionType type) {
    setState(() {
      _type = type;
      // Campos específicos de tipo deixam de fazer sentido ao trocar.
      _categoryId = null;
      _entityId = null;
      _toAccountId = null;
    });
  }

  void _applySuggestion(QuickSuggestion s) {
    setState(() {
      _amountInCents = s.amount;
      _accountId = s.accountId;
      _toAccountId = s.toAccountId;
      _categoryId = s.categoryId;
      _entityId = s.entityId;
      _descriptionController.text = s.description;
    });
  }

  void _openFullForm() {
    Navigator.of(context).pop();
    ref.read(transactionFormModalProvider.notifier).open(type: _type);
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    if (_amountInCents <= 0) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Informe um valor.')),
      );
      return;
    }
    if (_accountId == null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            _isTransfer
                ? 'Selecione a conta de origem.'
                : 'Selecione uma conta.',
          ),
        ),
      );
      return;
    }
    if (_isTransfer) {
      if (_toAccountId == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Selecione a conta de destino.')),
        );
        return;
      }
      if (_accountId == _toAccountId) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'As contas de origem e destino devem ser diferentes.',
            ),
          ),
        );
        return;
      }
    }

    setState(() => _saving = true);

    String description = _descriptionController.text.trim();
    if (description.isEmpty) {
      if (_isTransfer) {
        final accounts = ref.read(activeAccountsProvider);
        final from = accounts.where((a) => a.id == _accountId).firstOrNull;
        final to = accounts.where((a) => a.id == _toAccountId).firstOrNull;
        description =
            'Transferência: ${from?.name ?? "Origem"} -> ${to?.name ?? "Destino"}';
      } else {
        description = _type.label;
      }
    }

    try {
      await ref.read(createTransactionProvider)(
        date: DateTime.now(),
        description: description,
        type: _type.name,
        amount: _amountInCents,
        categoryId: _isTransfer ? null : _categoryId,
        entityId: _isTransfer ? null : _entityId,
        accountId: _accountId!,
        toAccountId: _isTransfer ? _toAccountId : null,
      );
      await ref.read(gamificationServiceProvider).onTransactionCreated();

      messenger.showSnackBar(
        const SnackBar(content: Text('Transação cadastrada!')),
      );
      navigator.pop();
    } catch (e) {
      if (mounted) setState(() => _saving = false);
      messenger.showSnackBar(
        SnackBar(content: Text('Erro ao salvar transação: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final color = _typeColor(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'Lançamento rápido',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TransactionTypeTabs(
                selectedType: _type,
                onTypeChanged: _onTypeChanged,
              ),
              const SizedBox(height: 16),
              _SuggestionStrip(type: _type, onSelected: _applySuggestion),
              AmountInput(
                amountInCents: _amountInCents,
                color: color,
                onChanged: (v) => setState(() => _amountInCents = v),
              ),
              const SizedBox(height: 16),
              DescriptionAutocomplete(
                controller: _descriptionController,
                transactionType: _type.name,
                onSelected: (_) {},
              ),
              const SizedBox(height: 16),
              _accountSelector(
                label: _isTransfer ? 'De' : 'Conta',
                selectedId: _accountId,
                onSelected: (id) => setState(() => _accountId = id),
                color: color,
              ),
              if (_isTransfer) ...[
                const SizedBox(height: 12),
                _accountSelector(
                  label: 'Para',
                  selectedId: _toAccountId,
                  onSelected: (id) => setState(() => _toAccountId = id),
                  color: color,
                ),
              ] else ...[
                const SizedBox(height: 12),
                _categorySelector(color: color),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: _saving ? null : _openFullForm,
                    icon: const Icon(Icons.tune_rounded, size: 18),
                    label: const Text('Mais opções'),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(backgroundColor: color),
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_rounded),
                    label: const Text('Salvar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _accountSelector({
    required String label,
    required String? selectedId,
    required ValueChanged<String> onSelected,
    required Color color,
  }) {
    final accounts = ref.watch(activeAccountsProvider);
    return _SelectorRow(
      label: label,
      child: accounts.isEmpty
          ? const _EmptyHint('Nenhuma conta cadastrada')
          : SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: accounts.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final Account a = accounts[i];
                  return _PickChip(
                    label: a.name,
                    icon: IconMapper.fromCodePoint(
                      int.tryParse(a.icon) ??
                          Icons.account_balance_rounded.codePoint,
                    ),
                    selected: a.id == selectedId,
                    color: color,
                    onTap: () => onSelected(a.id),
                  );
                },
              ),
            ),
    );
  }

  Widget _categorySelector({required Color color}) {
    final allCats = ref.watch(allFlatCategoriesProvider);
    final cats = allCats
        .where((c) => c.type == _type.name && !c.isArchived)
        .toList();
    return _SelectorRow(
      label: 'Categoria',
      child: cats.isEmpty
          ? const _EmptyHint('Nenhuma categoria')
          : SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: cats.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final CategoryModel c = cats[i];
                  return _PickChip(
                    label: c.name,
                    icon: IconMapper.fromString(c.icon),
                    selected: c.id == _categoryId,
                    color: color,
                    onTap: () => setState(() => _categoryId = c.id),
                  );
                },
              ),
            ),
    );
  }
}

/// Faixa horizontal de chips de sugestão para o tipo selecionado.
class _SuggestionStrip extends ConsumerWidget {
  const _SuggestionStrip({required this.type, required this.onSelected});

  final TransactionType type;
  final ValueChanged<QuickSuggestion> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suggestionsAsync = ref.watch(quickSuggestionsProvider(type));
    final suggestions = suggestionsAsync.value ?? const [];
    if (suggestions.isEmpty) return const SizedBox.shrink();

    final cs = context.colorScheme;
    final accounts = ref.watch(activeAccountsProvider);
    String accountName(String? id) =>
        accounts.where((a) => a.id == id).firstOrNull?.name ?? '?';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        height: 64,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: suggestions.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final s = suggestions[i];
            final isTransfer = s.type == TransactionType.transfer;
            final title = isTransfer
                ? '${accountName(s.accountId)} → ${accountName(s.toAccountId)}'
                : s.description;
            return InkWell(
              onTap: () => onSelected(s),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: cs.outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(s.type.icon, size: 14, color: cs.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      CurrencyFormatter.formatCents(s.amount),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SelectorRow extends StatelessWidget {
  const _SelectorRow({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _PickChip extends StatelessWidget {
  const _PickChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.16)
              : cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : cs.outlineVariant.withValues(alpha: 0.4),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: selected ? color : cs.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: selected ? color : cs.onSurface,
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: context.colorScheme.onSurfaceVariant,
      ),
    );
  }
}
