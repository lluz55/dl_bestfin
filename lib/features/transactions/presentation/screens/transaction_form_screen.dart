import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bestfin/core/constants/transaction_types.dart';
import 'package:bestfin/core/constants/sentiment_types.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/providers/default_account_provider.dart';
import 'package:bestfin/core/widgets/app_page_appbar.dart';
import 'package:bestfin/core/widgets/account_selector.dart';
import 'package:bestfin/core/widgets/category_picker.dart';
import 'package:bestfin/core/widgets/category_icon.dart';
import 'package:bestfin/core/widgets/entity_autocomplete.dart';
import 'package:bestfin/core/widgets/sentiment_emoji_button.dart';
import 'package:bestfin/features/accounts/presentation/providers/accounts_provider.dart';
import 'package:bestfin/features/transactions/domain/models/transaction.dart';
import 'package:bestfin/features/transactions/presentation/widgets/description_autocomplete.dart';
import 'package:bestfin/features/transactions/presentation/widgets/amount_input.dart';
import 'package:bestfin/features/transactions/presentation/widgets/transaction_type_tabs.dart';
import 'package:bestfin/features/installments/presentation/providers/installments_provider.dart';
import 'package:bestfin/features/installments/presentation/screens/installment_wizard_screen.dart';
import 'package:bestfin/features/transactions/presentation/providers/transactions_provider.dart';
import 'package:bestfin/features/transactions/presentation/widgets/delete_transaction_sheet.dart';
import 'package:bestfin/features/ai/presentation/providers/ai_provider.dart';
import 'package:bestfin/core/utils/icon_mapper.dart';
import 'package:bestfin/features/gamification/presentation/providers/gamification_providers.dart';
import 'package:bestfin/features/goals/presentation/providers/goals_provider.dart';
import 'package:bestfin/features/categories/presentation/providers/categories_provider.dart';
import 'package:bestfin/features/credit_cards/presentation/providers/credit_cards_provider.dart';

class TransactionFormScreen extends ConsumerStatefulWidget {
  final TransactionModel? transaction;
  final TransactionType? initialType;
  final bool isCloning;

  const TransactionFormScreen({
    super.key,
    this.transaction,
    this.initialType,
    this.isCloning = false,
  });

  @override
  ConsumerState<TransactionFormScreen> createState() =>
      _TransactionFormScreenState();
}

class _TransactionFormScreenState extends ConsumerState<TransactionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final FocusNode _descriptionFocusNode = FocusNode();
  final FocusNode _amountFocusNode = FocusNode();
  final FocusNode _accountFocusNode = FocusNode();
  final FocusNode _toAccountFocusNode = FocusNode();
  final FocusNode _entityFocusNode = FocusNode();

  late TransactionType _type;
  late int _amountInCents;
  late TextEditingController _descriptionController;
  late bool _isCloningState;
  bool _extrasExpanded = false;

  bool get _isEditing =>
      widget.transaction != null &&
      widget.transaction!.id.isNotEmpty &&
      !_isCloningState;

  bool get _isReadyToSave {
    final bool basicInfo =
        _amountInCents > 0 &&
        _descriptionController.text.trim().isNotEmpty &&
        _accountId != null;

    if (!basicInfo) return false;

    if (_type == TransactionType.transfer) {
      return _toAccountId != null && _accountId != _toAccountId;
    } else {
      return _categoryId != null && _entityId != null;
    }
  }

  void _focusNextUnfilledObligatoryField() {
    if (_amountInCents <= 0) {
      _amountFocusNode.requestFocus();
      return;
    }
    if (_descriptionController.text.trim().isEmpty) {
      _descriptionFocusNode.requestFocus();
      return;
    }
    if (_accountId == null) {
      _accountFocusNode.requestFocus();
      return;
    }

    if (_type == TransactionType.transfer) {
      if (_toAccountId == null) {
        _toAccountFocusNode.requestFocus();
        return;
      }
    } else {
      if (_categoryId == null) {
        _pickCategory();
        return;
      }
      if (_entityId == null) {
        _entityFocusNode.requestFocus();
        return;
      }
    }

    // Se todos estiverem preenchidos e válidos para salvar, envia
    if (_isReadyToSave) {
      _save();
    }
  }

  void _onDescriptionChanged() {
    setState(() {});
  }

  late TextEditingController _notesController;

  String? _accountId;
  String? _toAccountId;
  String? _selectedCreditCardId;

  String? _categoryId;
  String? _categoryName;
  String? _categoryColor;
  String? _categoryIcon;

  String? _entityId;
  String? _goalId;
  SentimentType? _sentiment;

  late DateTime _date;
  int? _installmentCount;

  @override
  void initState() {
    super.initState();
    _isCloningState = widget.isCloning;
    final tx = widget.transaction;

    _type = tx?.type ?? widget.initialType ?? TransactionType.expense;
    _amountInCents = tx?.amount ?? 0;
    _descriptionController = TextEditingController(text: tx?.description ?? '');
    _notesController = TextEditingController(text: tx?.notes ?? '');

    _accountId = tx?.accountId;
    _toAccountId = tx?.toAccountId;
    _selectedCreditCardId = tx?.creditCardId;

    _categoryId = tx?.categoryId;
    _categoryName = tx?.category?.name;
    _categoryColor = tx?.category?.color;
    _categoryIcon = tx?.category?.icon;

    _entityId = tx?.entityId;
    _goalId = tx?.goalId;
    _sentiment = tx?.sentiment;
    _date = _isCloningState ? DateTime.now() : (tx?.date ?? DateTime.now());

    // Auto-expand extras section if editing a transaction with extras
    _extrasExpanded =
        tx?.notes?.isNotEmpty == true ||
        tx?.goalId != null ||
        _installmentCount != null;

    _descriptionController.addListener(_onDescriptionChanged);

    // Para transações CC, accountId vem do cartão (não de entries).
    // Para transações novas sem conta, auto-seleciona a conta padrão.
    if (_accountId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_selectedCreditCardId != null) {
          _tryRestoreAccountFromCreditCard();
        } else {
          _tryAutoSelectAccount();
        }
      });
    }
  }

  void _tryAutoSelectAccount() {
    if (_accountId != null) return;
    final accounts = ref.read(activeAccountsProvider);
    if (accounts.isEmpty || !mounted) return;
    final defaultId = ref.read(defaultAccountIdProvider);
    setState(() {
      if (accounts.length == 1) {
        _accountId = accounts.first.id;
      } else if (defaultId != null && accounts.any((a) => a.id == defaultId)) {
        _accountId = defaultId;
      }
    });
  }

  void _tryRestoreAccountFromCreditCard() {
    if (_selectedCreditCardId == null) return;
    final cards = ref.read(creditCardsStreamProvider).value ?? [];
    final card = cards.where((c) => c.id == _selectedCreditCardId).firstOrNull;
    if (card == null || !mounted) return;
    setState(() {
      _accountId = card.accountId;
    });
  }

  Future<void> _pickDateTime() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (pickedDate == null || !mounted) return;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_date),
    );
    setState(() {
      _date = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime?.hour ?? _date.hour,
        pickedTime?.minute ?? _date.minute,
      );
    });
  }

  @override
  void dispose() {
    _descriptionController.removeListener(_onDescriptionChanged);
    _descriptionController.dispose();
    _notesController.dispose();
    _descriptionFocusNode.dispose();
    _amountFocusNode.dispose();
    _accountFocusNode.dispose();
    _toAccountFocusNode.dispose();
    _entityFocusNode.dispose();
    super.dispose();
  }

  Future<void> _pickCategory() async {
    final cat = await showCategoryPicker(
      context,
      typeFilter: _type == TransactionType.transfer ? null : _type.name,
      selectedCategoryId: _categoryId,
    );
    if (cat != null) {
      setState(() {
        _categoryId = cat.id;
        _categoryName = cat.displayName;
        _categoryColor = cat.color;
        _categoryIcon = cat.icon;
      });
      _focusNextUnfilledObligatoryField();
    }
  }

  Future<void> _openInstallmentWizard() async {
    if (_amountInCents <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Insira um valor antes de parcelar.')),
      );
      return;
    }

    final count = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (context) => InstallmentWizardSheet(
        totalAmountInCents: _amountInCents,
        description: _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : 'Parcelamento',
      ),
    );

    if (count != null && mounted) {
      setState(() {
        _installmentCount = count;
      });
    }
  }

  void _clearInstallment() {
    setState(() {
      _installmentCount = null;
    });
  }

  void _openRecurringForm() {
    context.push(
      '/recurring/new',
      extra: {
        'amountInCents': _amountInCents,
        'description': _descriptionController.text.trim(),
        'type': _type,
        'accountId': _accountId,
        'categoryId': _categoryId,
        'categoryName': _categoryName,
        'categoryColor': _categoryColor,
        'categoryIcon': _categoryIcon,
      },
    );
  }

  Future<void> _checkAndOfferDefaultAccount(String accountId) async {
    final defaultId = ref.read(defaultAccountIdProvider);
    if (defaultId != null) return;

    final accounts = ref.read(activeAccountsProvider);
    final account = accounts.where((a) => a.id == accountId).firstOrNull;
    final accountName = account?.name ?? 'esta conta';

    if (!mounted) return;

    final setAsDefault = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Definir Conta Padrão?'),
        content: Text(
          'Você ainda não possui uma conta padrão configurada. Deseja tornar "$accountName" a sua conta padrão para novas transações?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Agora não'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sim, definir'),
          ),
        ],
      ),
    );

    if (setAsDefault == true) {
      await ref.read(defaultAccountIdProvider.notifier).set(accountId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"$accountName" agora é a sua conta padrão.'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _save() async {
    if (_amountInCents <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Insira um valor maior que R\$ 0,00')),
      );
      return;
    }

    if (_descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, informe uma descrição.')),
      );
      return;
    }

    if (_accountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _type == TransactionType.transfer
                ? 'Selecione a conta de origem.'
                : 'Selecione uma conta.',
          ),
        ),
      );
      return;
    }

    if (_type == TransactionType.transfer && _toAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione a conta de destino.')),
      );
      return;
    }

    if (_type == TransactionType.transfer && _accountId == _toAccountId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('As contas de origem e destino devem ser diferentes.'),
        ),
      );
      return;
    }

    if (_type != TransactionType.transfer) {
      if (_categoryId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Por favor, selecione uma categoria.')),
        );
        return;
      }
      if (_entityId == null) {
        final label = _type == TransactionType.income ? 'pagador' : 'recebedor';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Por favor, informe o $label.')));
        return;
      }
    }

    // Handle installment creation
    if (_installmentCount != null && _installmentCount! >= 2) {
      try {
        await ref
            .read(installmentRepositoryProvider)
            .createInstallmentPlan(
              baseDate: _date,
              description: _descriptionController.text.trim(),
              totalAmount: _amountInCents,
              totalInstallments: _installmentCount!,
              accountId: _accountId!,
              categoryId: _categoryId,
              entityId: _type == TransactionType.transfer ? null : _entityId,
              sentiment: _sentiment?.name,
              notes: _notesController.text.trim().isEmpty
                  ? null
                  : _notesController.text.trim(),
              type: _type.name,
            );

        await ref.read(gamificationServiceProvider).onTransactionCreated();

        if (mounted) {
          await _checkAndOfferDefaultAccount(_accountId!);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Parcelamento criado com sucesso!')),
            );
            Navigator.pop(context);
          }
        }
        return;
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao criar parcelamento: $e')),
          );
        }
        return;
      }
    }

    try {
      if (_isEditing) {
        await ref.read(updateTransactionProvider)(
          id: widget.transaction!.id,
          date: _date,
          description: _descriptionController.text.trim(),
          type: _type.name,
          amount: _amountInCents,
          categoryId: _categoryId,
          entityId: _type == TransactionType.transfer ? null : _entityId,
          accountId: _accountId!,
          toAccountId: _toAccountId,
          sentiment: _sentiment?.name,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          goalId: _type == TransactionType.transfer ? null : _goalId,
          creditCardId: _type == TransactionType.expense
              ? _selectedCreditCardId
              : null,
        );
      } else {
        await ref.read(createTransactionProvider)(
          date: _date,
          description: _descriptionController.text.trim(),
          type: _type.name,
          amount: _amountInCents,
          categoryId: _categoryId,
          entityId: _type == TransactionType.transfer ? null : _entityId,
          accountId: _accountId!,
          toAccountId: _toAccountId,
          sentiment: _sentiment?.name,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          goalId: _type == TransactionType.transfer ? null : _goalId,
          creditCardId: _type == TransactionType.expense
              ? _selectedCreditCardId
              : null,
        );
      }

      await ref.read(gamificationServiceProvider).onTransactionCreated();

      if (mounted) {
        await _checkAndOfferDefaultAccount(_accountId!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _isEditing
                    ? 'Transação atualizada!'
                    : (_isCloningState
                        ? 'Transação duplicada com sucesso!'
                        : 'Transação cadastrada!'),
              ),
            ),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao salvar transação: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.textTheme;
    final colors = context.customColors;

    final Color activeColor = _type == TransactionType.income
        ? colors.income
        : _type == TransactionType.transfer
        ? colors.transfer
        : colors.expense;

    // Auto-select account when stream loads for the first time
    ref.listen(activeAccountsProvider, (prev, next) {
      if (_accountId == null && widget.transaction == null && next.isNotEmpty) {
        _tryAutoSelectAccount();
      }
    });

    final String saveLabel = _isEditing
        ? 'Atualizar'
        : (_isCloningState ? 'Duplicar' : 'Confirmar');

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppPageAppBar(
        title: _isEditing
            ? 'Editar Transação'
            : (_isCloningState ? 'Duplicar Transação' : 'Nova Transação'),
        actions: [
          if (_isEditing) ...[
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: 'Excluir transação',
              onPressed: () async {
                final deleted = await showDeleteTransactionSheet(
                  context,
                  ref,
                  widget.transaction!,
                );
                if (deleted && context.mounted) {
                  context.pop();
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.copy_rounded),
              tooltip: 'Duplicar transação',
              onPressed: () {
                setState(() {
                  _isCloningState = true;
                  _date = DateTime.now();
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Modo de duplicação ativado. Salve para criar uma nova transação.',
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
      floatingActionButton: AnimatedScale(
        scale: _isReadyToSave ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutBack,
        child: AnimatedOpacity(
          opacity: _isReadyToSave ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: FloatingActionButton.extended(
            onPressed: _save,
            backgroundColor: activeColor,
            icon: const Icon(Icons.check_rounded, color: Colors.white),
            label: Text(
              saveLabel,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
          children: [
            // Tabs Despesa / Receita / Transferência
            TransactionTypeTabs(
              selectedType: _type,
              onTypeChanged: (type) {
                setState(() {
                  _type = type;
                  if (type == TransactionType.transfer) {
                    _categoryId = null;
                    _categoryName = null;
                    _categoryIcon = null;
                    _categoryColor = null;
                    _entityId = null;
                    _goalId = null;
                  }
                });
              },
            ),
            const SizedBox(height: 24),

            // Amount Input — abre teclado automaticamente em novas transações
            AmountInput(
              amountInCents: _amountInCents,
              color: activeColor,
              autoOpen: !_isEditing && !_isCloningState,
              focusNode: _amountFocusNode,
              onChanged: (val) {
                setState(() {
                  _amountInCents = val;
                });
              },
              onConfirmed: () {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _focusNextUnfilledObligatoryField();
                });
              },
            ),
            const SizedBox(height: 24),

            // Descrição + Emoji de sentimento na mesma linha
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: DescriptionAutocomplete(
                    controller: _descriptionController,
                    transactionType: _type.name,
                    focusNode: _descriptionFocusNode,
                    onSelected: (selection) {
                      setState(() {
                        _descriptionController.text = selection;
                      });
                      _focusNextUnfilledObligatoryField();
                    },
                    onFieldSubmitted: (val) => _focusNextUnfilledObligatoryField(),
                    onChanged: _onDescriptionChanged,
                  ),
                ),
                const SizedBox(width: 8),
                SentimentEmojiButton(
                  selectedSentiment: _sentiment,
                  onSentimentSelected: (s) => setState(() => _sentiment = s),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // AI Category Suggestion Chip
            () {
              final suggestion = ref.watch(
                autoCategorizeProvider(_descriptionController.text),
              );

              // Auto-apply when confidence >= 80% and no category is set
              if (suggestion != null &&
                  suggestion.confidence >= 0.80 &&
                  _categoryId == null) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && _categoryId == null) {
                    setState(() {
                      _categoryId = suggestion.categoryId;
                      _categoryName = suggestion.categoryName;
                      _categoryColor = suggestion.categoryColor;
                      _categoryIcon = suggestion.categoryIcon;
                    });
                  }
                });
              }

              if (suggestion != null) {
                final suggestionColor = Color(
                  int.parse(
                    'FF${suggestion.categoryColor.replaceAll('#', '')}',
                    radix: 16,
                  ),
                );
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: ActionChip(
                      avatar: CircleAvatar(
                        backgroundColor: suggestionColor.withValues(
                          alpha: 0.15,
                        ),
                        child: Icon(
                          IconMapper.fromString(suggestion.categoryIcon),
                          color: suggestionColor,
                          size: 14,
                        ),
                      ),
                      label: Text(
                        'Sugerido: ${suggestion.categoryName} (${(suggestion.confidence * 100).toStringAsFixed(0)}%)',
                        style: TextStyle(
                          color: cs.onSurface,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      backgroundColor: cs.surfaceContainerHigh,
                      side: BorderSide(color: cs.outlineVariant, width: 0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      onPressed: () {
                        setState(() {
                          _categoryId = suggestion.categoryId;
                          _categoryName = suggestion.categoryName;
                          _categoryColor = suggestion.categoryColor;
                          _categoryIcon = suggestion.categoryIcon;
                        });
                        _focusNextUnfilledObligatoryField();
                      },
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            }(),
            const SizedBox(height: 16),

            // Conta + Categoria na mesma linha (ou duas contas em transferência, cada uma na sua linha)
            if (_type == TransactionType.transfer) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AccountSelector(
                    selectedAccountId: _accountId,
                    onAccountSelected: (acc) {
                      setState(() => _accountId = acc?.id);
                      _focusNextUnfilledObligatoryField();
                    },
                    hint: 'Conta de origem',
                    showBalance: false,
                    focusNode: _accountFocusNode,
                  ),
                  const SizedBox(height: 16),
                  AccountSelector(
                    selectedAccountId: _toAccountId,
                    onAccountSelected: (acc) {
                      setState(() => _toAccountId = acc?.id);
                      _focusNextUnfilledObligatoryField();
                    },
                    hint: 'Conta de destino',
                    showBalance: false,
                    focusNode: _toAccountFocusNode,
                  ),
                ],
              ),
            ] else ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: AccountSelector(
                      selectedAccountId: _accountId,
                      onAccountSelected: (acc) {
                        setState(() {
                          _accountId = acc?.id;
                          _selectedCreditCardId = null;
                        });
                        _focusNextUnfilledObligatoryField();
                      },
                      hint: 'Conta',
                      showBalance: false,
                      showCreditCards: _type == TransactionType.expense,
                      selectedCreditCardId: _selectedCreditCardId,
                      onCreditCardSelected: (card) {
                        setState(() {
                          _selectedCreditCardId = card?.id;
                        });
                        _focusNextUnfilledObligatoryField();
                      },
                      focusNode: _accountFocusNode,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Botão da categoria com tooltip e suporte a mescla de ícones
                  (() {
                    final allCats = ref.watch(allFlatCategoriesProvider);
                    final cat = allCats
                        .where((c) => c.id == _categoryId)
                        .firstOrNull;
                    final displayName =
                        cat?.displayName ??
                        _categoryName ??
                        'Selecionar Categoria';
                    return Tooltip(
                      message: displayName,
                      child: InkWell(
                        onTap: _pickCategory,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: cs.outlineVariant.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Center(
                                child:
                                    _categoryId != null &&
                                        _categoryIcon != null &&
                                        _categoryColor != null
                                    ? CategoryIcon(
                                        icon: _categoryIcon!,
                                        color: _categoryColor!,
                                        parentIcon: cat?.parentIcon,
                                        parentColor: cat?.parentColor,
                                        size: 28,
                                      )
                                    : Icon(
                                        Icons.category_outlined,
                                        color: cs.onSurfaceVariant,
                                        size: 22,
                                      ),
                              ),
                              if (_categoryId == null)
                                Positioned(
                                  top: 2,
                                  right: 2,
                                  child: Text(
                                    '*',
                                    style: TextStyle(
                                      color: cs.error,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  })(),
                ],
              ),
            ],
            const SizedBox(height: 16),

            // Entidade + botão de data/hora na mesma linha (ou apenas o botão de data/hora para transferência)
            if (_type == TransactionType.transfer) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: _DateTimeButton(
                  date: _date,
                  onTap: _pickDateTime,
                  cs: cs,
                  tt: tt,
                ),
              ),
            ] else ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: EntityAutocomplete(
                      selectedEntityId: _entityId,
                      entityType: _type == TransactionType.income
                          ? 'payer'
                          : 'payee',
                      label: _type == TransactionType.income
                          ? 'Recebido de *'
                          : 'Pago a *',
                      onEntitySelected: (entity) {
                        setState(() => _entityId = entity?.id);
                        _focusNextUnfilledObligatoryField();
                      },
                      focusNode: _entityFocusNode,
                      onFieldSubmitted: (val) => _focusNextUnfilledObligatoryField(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _DateTimeButton(
                    date: _date,
                    onTap: _pickDateTime,
                    cs: cs,
                    tt: tt,
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),

            // Seção colapsável: Metas, Observações, Parcelar, Repetir
            _ExtrasToggle(
              expanded: _extrasExpanded,
              onToggle: () =>
                  setState(() => _extrasExpanded = !_extrasExpanded),
              cs: cs,
              tt: tt,
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: _extrasExpanded
                  ? _ExtrasContent(
                      cs: cs,
                      tt: tt,
                      goalId: _goalId,
                      notesController: _notesController,
                      installmentCount: _installmentCount,
                      type: _type,
                      onGoalChanged: (val) => setState(() => _goalId = val),
                      onClearInstallment: _clearInstallment,
                      onOpenInstallmentWizard: _openInstallmentWizard,
                      onOpenRecurring: _openRecurringForm,
                    )
                  : const SizedBox.shrink(),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _ExtrasToggle extends StatelessWidget {
  const _ExtrasToggle({
    required this.expanded,
    required this.onToggle,
    required this.cs,
    required this.tt,
  });

  final bool expanded;
  final VoidCallback onToggle;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            Icon(Icons.tune_rounded, size: 18, color: cs.onSurfaceVariant),
            const SizedBox(width: 8),
            Text(
              'Mais opções',
              style: tt.labelLarge?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            AnimatedRotation(
              turns: expanded ? 0.5 : 0.0,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExtrasContent extends ConsumerWidget {
  const _ExtrasContent({
    required this.cs,
    required this.tt,
    required this.goalId,
    required this.notesController,
    required this.installmentCount,
    required this.type,
    required this.onGoalChanged,
    required this.onClearInstallment,
    required this.onOpenInstallmentWizard,
    required this.onOpenRecurring,
  });

  final ColorScheme cs;
  final TextTheme tt;
  final String? goalId;
  final TextEditingController notesController;
  final int? installmentCount;
  final TransactionType type;
  final ValueChanged<String?> onGoalChanged;
  final VoidCallback onClearInstallment;
  final VoidCallback onOpenInstallmentWizard;
  final VoidCallback onOpenRecurring;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),

        // Vínculo com Meta
        if (type != TransactionType.transfer) ...[
          Text(
            'Vincular a uma Meta',
            style: tt.labelLarge?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Builder(
            builder: (context) {
              final goalsAsync = ref.watch(activeGoalsProvider);
              return goalsAsync.when(
                data: (goals) {
                  if (goals.isEmpty) {
                    return Text(
                      'Nenhuma meta ativa encontrada',
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    );
                  }
                  return DropdownButtonFormField<String>(
                    value: goalId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.flag_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      hintText: 'Selecione uma meta',
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('Nenhuma meta'),
                      ),
                      ...goals.map(
                        (g) =>
                            DropdownMenuItem(value: g.id, child: Text(g.name)),
                      ),
                    ],
                    onChanged: onGoalChanged,
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (e, s) => const Text('Erro ao carregar metas'),
              );
            },
          ),
          const SizedBox(height: 24),
        ],

        // Observações
        TextFormField(
          controller: notesController,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: 'Observações / Notas',
            hintText: 'Adicione informações adicionais sobre essa transação...',
            alignLabelWithHint: true,
            prefixIcon: const Padding(
              padding: EdgeInsets.only(bottom: 40),
              child: Icon(Icons.notes_outlined),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        const SizedBox(height: 24),

        // Parcelamento e Recorrência
        if (type != TransactionType.transfer) ...[
          Row(
            children: [
              Expanded(
                child: installmentCount != null
                    ? FilledButton.icon(
                        onPressed: onClearInstallment,
                        icon: const Icon(Icons.close),
                        label: Text('Parcelado em ${installmentCount}x'),
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      )
                    : OutlinedButton.icon(
                        onPressed: onOpenInstallmentWizard,
                        icon: const Icon(Icons.date_range_outlined),
                        label: const Text('Parcelar'),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onOpenRecurring,
                  icon: const Icon(Icons.repeat),
                  label: const Text('Repetir'),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

class _DateTimeButton extends StatelessWidget {
  const _DateTimeButton({
    required this.date,
    required this.onTap,
    required this.cs,
    required this.tt,
  });

  final DateTime date;
  final VoidCallback onTap;
  final ColorScheme cs;
  final TextTheme tt;

  String _formatDate(DateTime d) {
    const months = [
      'jan',
      'fev',
      'mar',
      'abr',
      'mai',
      'jun',
      'jul',
      'ago',
      'set',
      'out',
      'nov',
      'dez',
    ];
    return '${d.day} ${months[d.month - 1]}';
  }

  String _formatTime(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 64,
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _formatDate(date),
              style: tt.labelSmall?.copyWith(
                color: cs.onSurface,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              _formatTime(date),
              style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
