import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bestfin/core/constants/transaction_types.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/widgets/app_button.dart';
import 'package:bestfin/core/utils/currency_formatter.dart';
import 'package:bestfin/core/utils/icon_mapper.dart';
import 'package:bestfin/core/widgets/account_selector.dart';
import 'package:bestfin/core/widgets/category_picker.dart';
import 'package:bestfin/core/widgets/entity_autocomplete.dart';
import 'package:bestfin/features/accounts/presentation/providers/accounts_provider.dart';
import 'package:bestfin/features/categories/domain/models/category.dart';
import 'package:bestfin/features/categories/presentation/providers/categories_provider.dart';
import 'package:bestfin/features/gamification/presentation/providers/gamification_providers.dart';
import 'package:bestfin/features/transactions/domain/models/quick_suggestion.dart';
import 'package:bestfin/features/transactions/domain/usecases/predict_category.dart';
import 'package:bestfin/features/transactions/presentation/providers/quick_suggestions_provider.dart';
import 'package:bestfin/features/transactions/presentation/providers/transaction_form_modal_provider.dart';
import 'package:bestfin/core/providers/default_account_provider.dart';
import 'package:bestfin/core/providers/pending_default_provider.dart';
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

/// [predictCategory] varre todo o histórico de 180 dias a cada chamada —
/// esperar o usuário parar de digitar evita repetir essa varredura por tecla.
const _predictCategoryDebounce = Duration(milliseconds: 300);

class _QuickTransactionSheetState extends ConsumerState<QuickTransactionSheet> {
  late TransactionType _type;
  final _descriptionController = TextEditingController();
  Timer? _predictDebounce;

  int _amountInCents = 0;
  String? _accountId;
  String? _toAccountId;
  String? _categoryId;
  String? _entityId;
  bool _saving = false;

  /// Usuário escolheu a categoria manualmente (ou via sugestão) — trava o palpite.
  bool _categoryTouched = false;

  /// A categoria atual veio de [predictCategory] (rótulo indica que é sugestão).
  bool _categoryPredicted = false;

  /// Marca a transação como pendente (ainda não aconteceu) — `isCompleted=false`.
  /// Lançamento rápido sempre usa a data de hoje, então o padrão vem direto
  /// da configuração "Pendente por padrão".
  bool _isPending = true;

  bool get _isTransfer => _type == TransactionType.transfer;

  bool get _canSave {
    if (_amountInCents <= 0) return false;
    if (_accountId == null) return false;
    if (_isTransfer) {
      if (_toAccountId == null) return false;
      if (_accountId == _toAccountId) return false;
    } else {
      // Despesa/receita exigem descrição, categoria e entidade (pago a/recebido de).
      if (_descriptionController.text.trim().isEmpty) return false;
      if (_categoryId == null) return false;
      if (_entityId == null) return false;
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    _isPending = ref.read(defaultPendingForPastProvider);
    _descriptionController.addListener(_onDescriptionChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final accounts = ref.read(activeAccountsProvider);
      if (_accountId == null && accounts.isNotEmpty) {
        final defaultId = ref.read(defaultAccountIdProvider);
        setState(() {
          if (accounts.length == 1) {
            _accountId = accounts.first.id;
          } else if (defaultId != null &&
              accounts.any((a) => a.id == defaultId)) {
            _accountId = defaultId;
          }
        });
      }
      _predictCategory();
    });
  }

  @override
  void dispose() {
    _predictDebounce?.cancel();
    _descriptionController.removeListener(_onDescriptionChanged);
    _descriptionController.dispose();
    super.dispose();
  }

  void _onDescriptionChanged() {
    // Rebuild para reavaliar _canSave (habilita/desabilita "Salvar") ao digitar.
    setState(() {});
    if (_categoryTouched) return;
    _predictDebounce?.cancel();
    _predictDebounce = Timer(_predictCategoryDebounce, _predictCategory);
  }

  /// Preenche a categoria com o palpite do histórico ([predictCategory]),
  /// exceto se o usuário já escolheu uma manualmente. Só vale para despesa/receita.
  void _predictCategory() {
    if (!mounted || _isTransfer || _categoryTouched) return;
    final history = ref.read(categoryPredictionHistoryProvider(_type)).value;
    if (history == null || history.isEmpty) return;
    final predicted = predictCategory(
      history,
      type: _type,
      entityId: _entityId,
      description: _descriptionController.text,
      now: DateTime.now(),
    );
    if (predicted == null || predicted == _categoryId) return;
    // A categoria prevista precisa continuar existindo e ativa para o tipo.
    final exists = ref
        .read(allFlatCategoriesProvider)
        .any((c) => c.id == predicted && c.type == _type.name && !c.isArchived);
    if (!exists) return;
    setState(() {
      _categoryId = predicted;
      _categoryPredicted = true;
    });
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
      _categoryTouched = false;
      _categoryPredicted = false;
    });
    _predictCategory();
  }

  void _applySuggestion(QuickSuggestion s) {
    setState(() {
      // A sugestão é uma escolha explícita: trava o palpite automático.
      _categoryTouched = true;
      _categoryPredicted = false;
      _amountInCents = s.amount;
      _accountId = s.accountId;
      _toAccountId = s.toAccountId;
      _categoryId = s.categoryId;
      _entityId = s.entityId;
      _descriptionController.text = s.description;
    });
  }

  void _openFullForm() {
    final type = _type;
    // Leva tudo que já foi preenchido para o formulário completo, para não
    // perder o rascunho ao trocar de tela.
    final draft = TransactionDraft(
      type: _type,
      amountInCents: _amountInCents,
      description: _descriptionController.text.trim(),
      accountId: _accountId,
      toAccountId: _isTransfer ? _toAccountId : null,
      categoryId: _isTransfer ? null : _categoryId,
      entityId: _isTransfer ? null : _entityId,
      isPending: _isPending,
    );
    // Captura o notifier antes do pop: depois que a rota é removida, este
    // State fica desmontado e `ref.read` passa a lançar (Riverpod proíbe
    // usar `ref` de um widget já desativado).
    final notifier = ref.read(transactionFormModalProvider.notifier);
    Navigator.of(context).pop();
    // Adia a abertura do formulário completo para depois desta rota terminar
    // de ser removida, evitando popar e empurrar rotas no mesmo frame (o que
    // pode deixar o Navigator num estado inconsistente).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifier.open(type: type, draft: draft);
    });
  }

  Future<void> _save() async {
    if (_saving) return;
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

    if (!_isTransfer && _descriptionController.text.trim().isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Informe uma descrição.')),
      );
      return;
    }

    if (!_isTransfer && _categoryId == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Selecione uma categoria.')),
      );
      return;
    }

    if (!_isTransfer && _entityId == null) {
      final label = _type == TransactionType.income ? 'pagador' : 'recebedor';
      messenger.showSnackBar(SnackBar(content: Text('Informe o $label.')));
      return;
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
        isCompleted: !_isPending,
      );
      await ref.read(gamificationServiceProvider).onTransactionCreated();

      messenger.showSnackBar(
        const SnackBar(content: Text('Transação cadastrada!')),
      );
      if (mounted) navigator.pop();
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

    // Quando o histórico chega (stream assíncrono), tenta prever a categoria.
    ref.listen(categoryPredictionHistoryProvider(_type), (_, _) {
      _predictCategory();
    });

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
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
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TransactionTypeTabs(
                      selectedType: _type,
                      onTypeChanged: _onTypeChanged,
                    ),
                    const SizedBox(height: 16),
                    _SuggestionStrip(type: _type, onSelected: _applySuggestion),
                    // Amount-first: abre o teclado assim que o sheet monta.
                    AmountInput(
                      amountInCents: _amountInCents,
                      color: color,
                      autoOpen: true,
                      onChanged: (v) => setState(() => _amountInCents = v),
                    ),
                    const SizedBox(height: 16),
                    DescriptionAutocomplete(
                      controller: _descriptionController,
                      transactionType: _type.name,
                      onSelected: (_) {},
                    ),
                    if (!_isTransfer) ...[
                      const SizedBox(height: 16),
                      EntityAutocomplete(
                        selectedEntityId: _entityId,
                        entityType: _type == TransactionType.income
                            ? 'payer'
                            : 'payee',
                        label: _type == TransactionType.income
                            ? 'Recebido de *'
                            : 'Pago a *',
                        onEntitySelected: (entity) {
                          setState(() => _entityId = entity?.id);
                          // Entidade é sinal forte para o palpite de categoria.
                          _predictCategory();
                        },
                      ),
                    ],
                    const SizedBox(height: 16),
                    _SelectorRow(
                      label: _isTransfer ? 'De' : 'Conta',
                      child: AccountSelector(
                        selectedAccountId: _accountId,
                        onAccountSelected: (a) =>
                            setState(() => _accountId = a?.id),
                      ),
                    ),
                    if (_isTransfer) ...[
                      const SizedBox(height: 12),
                      _SelectorRow(
                        label: 'Para',
                        child: AccountSelector(
                          selectedAccountId: _toAccountId,
                          hint: 'Conta de destino',
                          onAccountSelected: (a) =>
                              setState(() => _toAccountId = a?.id),
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 12),
                      _categorySelector(color: color),
                    ],
                    const SizedBox(height: 16),
                    _pendingToggle(color),
                  ],
                ),
              ),
            ),
            // Footer fixo: "Salvar" sempre visível, fora da área rolável.
            Container(
              decoration: BoxDecoration(
                color: cs.surface,
                border: Border(
                  top: BorderSide(
                    color: cs.outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: _saving ? null : _openFullForm,
                    icon: const Icon(Icons.tune_rounded, size: 18),
                    label: const Text('Mais opções'),
                  ),
                  const Spacer(),
                  AppButton(
                    label: 'Salvar',
                    icon: Icons.check_rounded,
                    color: color,
                    loading: _saving,
                    onPressed: (_saving || !_canSave) ? null : _save,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Chip que alterna entre "Confirmada" (já aconteceu) e "Pendente" (futura).
  Widget _pendingToggle(Color color) {
    final cs = context.colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: InkWell(
        onTap: () => setState(() => _isPending = !_isPending),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _isPending
                ? color.withValues(alpha: 0.16)
                : cs.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _isPending
                  ? color
                  : cs.outlineVariant.withValues(alpha: 0.4),
              width: _isPending ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _isPending
                    ? Icons.schedule_rounded
                    : Icons.check_circle_outline_rounded,
                size: 16,
                color: _isPending ? color : cs.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                _isPending ? 'Pendente' : 'Confirmada',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: _isPending ? color : cs.onSurface,
                  fontWeight: _isPending ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Abre o mesmo picker hierárquico (com busca) usado no formulário completo,
  /// garantindo consistência entre as duas telas.
  Future<void> _openCategoryPicker() async {
    final picked = await showCategoryPicker(
      context,
      typeFilter: _type.name,
      selectedCategoryId: _categoryId,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _categoryId = picked.id;
      _categoryTouched = true;
      _categoryPredicted = false;
    });
  }

  Widget _categorySelector({required Color color}) {
    final allCats = ref.watch(allFlatCategoriesProvider);
    final cats = allCats
        .where((c) => c.type == _type.name && !c.isArchived)
        .toList();
    final isSuggested = _categoryPredicted && _categoryId != null;
    return _SelectorRow(
      label: isSuggested ? 'Categoria · sugerida' : 'Categoria',
      child: SizedBox(
        height: 40,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          // Último item é o atalho para o picker completo (busca + hierarquia).
          itemCount: cats.length + 1,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            if (i == cats.length) {
              return _PickChip(
                label: 'Buscar',
                icon: Icons.search_rounded,
                selected: false,
                color: color,
                onTap: _openCategoryPicker,
              );
            }
            final CategoryModel c = cats[i];
            return _PickChip(
              label: c.name,
              icon: IconMapper.fromString(c.icon),
              selected: c.id == _categoryId,
              color: color,
              onTap: () => setState(() {
                _categoryId = c.id;
                _categoryTouched = true;
                _categoryPredicted = false;
              }),
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
