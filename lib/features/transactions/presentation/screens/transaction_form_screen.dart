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
import 'package:bestfin/core/widgets/numeric_keypad.dart';
import 'package:bestfin/core/utils/currency_formatter.dart';
import 'package:bestfin/features/accounts/presentation/providers/accounts_provider.dart';
import 'package:bestfin/features/transactions/domain/models/transaction.dart';
import 'package:bestfin/features/transactions/presentation/widgets/description_autocomplete.dart';
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
import 'package:bestfin/features/recurring/domain/models/recurring_rule.dart';
import 'package:bestfin/features/recurring/presentation/providers/recurring_provider.dart';
import 'package:bestfin/features/recurring/presentation/widgets/recurring_wizard_sheet.dart';

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
  final FocusNode _descriptionFocusNode = FocusNode();
  final FocusNode _entityFocusNode = FocusNode();
  final FocusNode _notesFocusNode = FocusNode();

  // Stepper navigation
  late PageController _pageController;
  int _currentPage = 0;
  int _maxPageReached = 0;

  // Form state
  late TransactionType _type;
  late int _amountInCents;
  String _amountDigits = '';
  late TextEditingController _descriptionController;
  late TextEditingController _notesController;
  late bool _isCloningState;

  String? _accountId;
  String? _toAccountId;
  String? _selectedCreditCardId;

  String? _categoryId;
  String? _categoryName;
  String? _categoryColor;
  String? _categoryIcon;

  String? _entityId;
  String? _entityName;
  String? _goalId;
  SentimentType? _sentiment;

  late DateTime _date;
  int? _installmentCount;

  // Recurring state
  RecurringFrequency? _recurringFrequency;
  DateTime? _recurringStartDate;
  DateTime? _recurringEndDate;
  bool _recurringAutoConfirm = false;

  bool get _isEditing =>
      widget.transaction != null &&
      widget.transaction!.id.isNotEmpty &&
      !_isCloningState;

  bool get _isInstallmentEdit =>
      _isEditing && widget.transaction?.installmentPlanId != null;

  Color get _activeColor {
    final colors = context.customColors;
    return _type == TransactionType.income
        ? colors.income
        : _type == TransactionType.transfer
        ? colors.transfer
        : colors.expense;
  }

  void _onDescriptionChanged() => setState(() {});

  @override
  void initState() {
    super.initState();
    _isCloningState = widget.isCloning;
    final tx = widget.transaction;

    _type = tx?.type ?? widget.initialType ?? TransactionType.expense;
    _amountInCents = tx?.amount ?? 0;
    _amountDigits = _amountInCents == 0 ? '' : _amountInCents.toString();

    // Strip installment suffix from description when editing a parcelated transaction
    final rawDesc = tx?.description ?? '';
    final cleanedDesc = (tx?.installmentPlanId != null && !_isCloningState)
        ? rawDesc.replaceAll(RegExp(r'\s*\(\d+/\d+\)$'), '').trim()
        : rawDesc;
    _descriptionController = TextEditingController(text: cleanedDesc);
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

    _descriptionController.addListener(_onDescriptionChanged);

    // Start on page 1 for editing; page 0 (keypad) for new/cloning
    final initialPage = _isEditing ? 1 : 0;
    _pageController = PageController(initialPage: initialPage);
    _currentPage = initialPage;
    _maxPageReached = initialPage;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (_accountId == null) {
        if (_selectedCreditCardId != null) {
          _tryRestoreAccountFromCreditCard();
        } else {
          _tryAutoSelectAccount();
        }
      }
      // Load installment plan to show total amount and count when editing
      if (tx?.installmentPlanId != null && !_isCloningState) {
        final plan = await ref
            .read(installmentRepositoryProvider)
            .getInstallmentPlanById(tx!.installmentPlanId!);
        if (plan != null && mounted) {
          setState(() {
            _installmentCount = plan.totalInstallments;
            _amountInCents = plan.installmentValue * plan.totalInstallments;
            _amountDigits = _amountInCents.toString();
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _descriptionController.removeListener(_onDescriptionChanged);
    _descriptionController.dispose();
    _notesController.dispose();
    _descriptionFocusNode.dispose();
    _entityFocusNode.dispose();
    _notesFocusNode.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // ── Navigation ─────────────────────────────────────────────────────────────

  String? _advanceError() {
    switch (_currentPage) {
      case 0:
        if (_amountInCents <= 0) return 'Insira um valor para continuar.';
      case 1:
        if (_type != TransactionType.transfer &&
            _descriptionController.text.trim().isEmpty) {
          return 'Informe uma descrição.';
        }
        if (_type != TransactionType.transfer && _categoryId == null) {
          return 'Selecione uma categoria.';
        }
      case 2:
        if (_accountId == null) {
          return _type == TransactionType.transfer
              ? 'Selecione a conta de origem.'
              : 'Selecione uma conta.';
        }
        if (_type == TransactionType.transfer) {
          if (_toAccountId == null) return 'Selecione a conta de destino.';
          if (_accountId == _toAccountId) {
            return 'As contas de origem e destino devem ser diferentes.';
          }
        } else if (_entityId == null) {
          final label = _type == TransactionType.income
              ? 'pagador'
              : 'recebedor';
          return 'Informe o $label.';
        }
    }
    return null;
  }

  void _goNext() {
    final error = _advanceError();
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    final next = _currentPage + 1;
    _pageController.animateToPage(
      next,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    setState(() {
      _currentPage = next;
      if (next > _maxPageReached) _maxPageReached = next;
    });

    Future.delayed(const Duration(milliseconds: 320), () {
      if (!mounted) return;
      switch (next) {
        case 1:
          _descriptionFocusNode.requestFocus();
        case 2:
          if (_type != TransactionType.transfer) {
            _entityFocusNode.requestFocus();
          }
        case 3:
          break; // Extras: nenhum campo recebe foco automaticamente
      }
    });
  }

  void _goBack() {
    if (_currentPage <= 0) return;
    final prev = _currentPage - 1;
    _pageController.animateToPage(
      prev,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    setState(() => _currentPage = prev);
  }

  void _goToPage(int page) {
    if (page > _maxPageReached) return;
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    setState(() => _currentPage = page);
  }

  // ── Keypad ─────────────────────────────────────────────────────────────────

  void _handleAmountKeyPress(String key) {
    if (key == ',') return;
    if ((_amountDigits.isEmpty || _amountDigits == '0') &&
        (key == '0' || key == '00')) {
      return;
    }
    setState(() {
      _amountDigits += key;
      _amountInCents = int.tryParse(_amountDigits) ?? 0;
    });
  }

  void _handleAmountDelete() {
    if (_amountDigits.isEmpty) return;
    setState(() {
      _amountDigits = _amountDigits.substring(0, _amountDigits.length - 1);
      _amountInCents = int.tryParse(_amountDigits) ?? 0;
    });
  }

  // ── Account helpers ────────────────────────────────────────────────────────

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
    setState(() => _accountId = card.accountId);
  }

  // ── Form actions ───────────────────────────────────────────────────────────

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
    }
  }

  Future<void> _openInstallmentWizard() async {
    if (_amountInCents <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Insira um valor antes de parcelar.')),
      );
      return;
    }

    final result = await showModalBottomSheet<InstallmentWizardResult>(
      context: context,
      isScrollControlled: true,
      builder: (context) => InstallmentWizardSheet(
        totalAmountInCents: _amountInCents,
        description: _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : 'Parcelamento',
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _installmentCount = result.installments;
        _amountInCents = result.totalAmount;
        _amountDigits = _amountInCents.toString();
        _clearRecurring();
      });
    }
  }

  void _clearInstallment() => setState(() => _installmentCount = null);

  void _clearRecurring() {
    setState(() {
      _recurringFrequency = null;
      _recurringStartDate = null;
      _recurringEndDate = null;
      _recurringAutoConfirm = false;
    });
  }

  Future<void> _openRecurringForm() async {
    final result = await showModalBottomSheet<RecurringWizardResult>(
      context: context,
      isScrollControlled: true,
      builder: (context) => RecurringWizardSheet(
        initialFrequency: _recurringFrequency ?? RecurringFrequency.monthly,
        initialStartDate: _recurringStartDate ?? _date,
        initialEndDate: _recurringEndDate,
        initialAutoConfirm: _recurringAutoConfirm,
        isTransfer: _type == TransactionType.transfer,
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _recurringFrequency = result.frequency;
        _recurringStartDate = result.startDate;
        _recurringEndDate = result.endDate;
        _recurringAutoConfirm = result.autoConfirm;
        _clearInstallment();
      });
    }
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
    String description = _descriptionController.text.trim();
    if (description.isEmpty) {
      if (_type == TransactionType.transfer) {
        final accounts = ref.read(activeAccountsProvider);
        final account = accounts.where((a) => a.id == _accountId).firstOrNull;
        final toAccount = accounts
            .where((a) => a.id == _toAccountId)
            .firstOrNull;
        description =
            'Transferência: ${account?.name ?? "Origem"} -> ${toAccount?.name ?? "Destino"}';
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Por favor, informe uma descrição.')),
        );
        return;
      }
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

    if (_isInstallmentEdit) {
      try {
        await ref.read(installmentRepositoryProvider).updateInstallmentPlan(
          planId: widget.transaction!.installmentPlanId!,
          totalAmount: _amountInCents,
          description: description,
          categoryId: _categoryId,
          entityId: _type == TransactionType.transfer ? null : _entityId,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          sentiment: _sentiment?.name,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Parcelamento atualizado com sucesso!'),
            ),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao atualizar parcelamento: $e')),
          );
        }
      }
      return;
    }

    if (_installmentCount != null && _installmentCount! >= 2) {
      try {
        await ref
            .read(installmentRepositoryProvider)
            .createInstallmentPlan(
              baseDate: _date,
              description: description,
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

    if (_recurringFrequency != null) {
      try {
        final String baseTransactionId;
        if (_isEditing) {
          baseTransactionId = widget.transaction!.id;
          await ref.read(updateTransactionProvider)(
            id: baseTransactionId,
            date: _recurringStartDate ?? _date,
            description: description,
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
          baseTransactionId = await ref.read(createTransactionProvider)(
            date: _recurringStartDate ?? _date,
            description: description,
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

        await ref.read(createRecurringRuleProvider)(
          baseTransactionId: baseTransactionId,
          frequency: _recurringFrequency!,
          interval: 1,
          startDate: _recurringStartDate ?? _date,
          endDate: _recurringEndDate,
          autoConfirm: _type == TransactionType.transfer ? false : _recurringAutoConfirm,
        );

        await ref.read(gamificationServiceProvider).onTransactionCreated();

        if (mounted) {
          await _checkAndOfferDefaultAccount(_accountId!);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Recorrência criada com sucesso!')),
            );
            Navigator.pop(context);
          }
        }
        return;
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao criar recorrência: $e')),
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
          description: description,
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
          description: description,
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

  // ── Layout helpers ─────────────────────────────────────────────────────────

  // Aligns content to the bottom of the available space and scrolls if overflow.
  Widget _bottomScrollable(List<Widget> children) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.textTheme;

    ref.listen(activeAccountsProvider, (prev, next) {
      if (_accountId == null && widget.transaction == null && next.isNotEmpty) {
        _tryAutoSelectAccount();
      }
    });

    return PopScope(
      canPop: _currentPage == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goBack();
      },
      child: Scaffold(
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
                if (deleted && context.mounted) context.pop();
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
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(cs, tt),
          Divider(
            height: 1,
            thickness: 1,
            color: cs.outlineVariant.withValues(alpha: 0.3),
          ),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildPageAmount(cs, tt),
                _buildPageOQue(cs, tt),
                _buildPageComo(cs, tt),
                _buildPageExtras(cs, tt),
                _buildPageResumo(cs, tt),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildFooter(cs, tt),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(ColorScheme cs, TextTheme tt) {
    final activeColor = _activeColor;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: TransactionTypeTabs(
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
                  _entityName = null;
                  _goalId = null;
                }
              });
            },
          ),
        ),
        GestureDetector(
          onTap: _currentPage > 0 ? () => _goToPage(0) : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  CurrencyFormatter.formatCents(_amountInCents),
                  style: tt.displayMedium?.copyWith(
                    color: activeColor,
                    fontWeight: FontWeight.w900,
                    fontSize: _amountInCents.toString().length > 7 ? 30 : 36,
                  ),
                ),
                if (_currentPage > 0) ...[
                  const SizedBox(width: 6),
                  Icon(
                    Icons.edit_outlined,
                    size: 14,
                    color: activeColor.withValues(alpha: 0.5),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (_currentPage > 0)
          _StepIndicator(
            currentStep: _currentPage,
            maxStep: _maxPageReached,
            onStepTap: _goToPage,
          ),
        const SizedBox(height: 4),
      ],
    );
  }

  // ── Footer ─────────────────────────────────────────────────────────────────

  Widget _buildFooter(ColorScheme cs, TextTheme tt) {
    final activeColor = _activeColor;
    final isLastPage = _currentPage == 4;
    final saveLabel = _isEditing
        ? 'Atualizar'
        : (_isCloningState ? 'Duplicar' : 'Confirmar e Salvar');

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: [
            if (_currentPage > 0) ...[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _goBack,
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: const Text('Voltar'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              flex: 2,
              child: FilledButton(
                onPressed: isLastPage ? _save : _goNext,
                style: FilledButton.styleFrom(
                  backgroundColor: activeColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      isLastPage ? saveLabel : 'Próxima',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    if (!isLastPage) ...[
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ] else ...[
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Page 0: Valor ──────────────────────────────────────────────────────────

  Widget _buildPageAmount(ColorScheme cs, TextTheme tt) {
    return _bottomScrollable([
      Text(
        'Digite o valor',
        style: tt.labelLarge?.copyWith(color: cs.onSurfaceVariant),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 16),
      NumericKeypad(
        onKeyPressed: _handleAmountKeyPress,
        onDeletePressed: _handleAmountDelete,
      ),
    ]);
  }

  // ── Page 1: O quê ─────────────────────────────────────────────────────────

  Widget _buildPageOQue(ColorScheme cs, TextTheme tt) {
    final activeColor = _activeColor;

    // AI auto-categorize
    final suggestion = ref.watch(
      autoCategorizeProvider(_descriptionController.text),
    );
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

    return _bottomScrollable([
      // Description + sentiment — AI chip é passado para dentro do widget
      Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: DescriptionAutocomplete(
              controller: _descriptionController,
              transactionType: _type.name,
              focusNode: _descriptionFocusNode,
              onSelected: (selection) {
                setState(() => _descriptionController.text = selection);
              },
              onFieldSubmitted: (_) {},
              onChanged: _onDescriptionChanged,
              aiSuggestionWidget: suggestion != null
                  ? _buildAiChip(suggestion, cs)
                  : null,
            ),
          ),
          const SizedBox(width: 8),
          SentimentEmojiButton(
            selectedSentiment: _sentiment,
            onSentimentSelected: (s) => setState(() => _sentiment = s),
          ),
        ],
      ),

      // Category button (non-transfer only)
      if (_type != TransactionType.transfer) ...[
        const SizedBox(height: 16),
        _buildCategoryButton(cs, tt, activeColor),
      ],
    ]);
  }

  Widget _buildAiChip(dynamic suggestion, ColorScheme cs) {
    final suggestionColor = Color(
      int.parse('FF${suggestion.categoryColor.replaceAll('#', '')}', radix: 16),
    );
    return ActionChip(
      avatar: CircleAvatar(
        backgroundColor: suggestionColor.withValues(alpha: 0.15),
        child: Icon(
          IconMapper.fromString(suggestion.categoryIcon),
          color: suggestionColor,
          size: 14,
        ),
      ),
      label: Text(
        'IA: ${suggestion.categoryName} (${(suggestion.confidence * 100).toStringAsFixed(0)}%)',
        style: TextStyle(
          color: cs.onSurface,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
      backgroundColor: cs.surfaceContainerHigh,
      side: BorderSide(color: cs.outlineVariant, width: 0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onPressed: () {
        setState(() {
          _categoryId = suggestion.categoryId;
          _categoryName = suggestion.categoryName;
          _categoryColor = suggestion.categoryColor;
          _categoryIcon = suggestion.categoryIcon;
        });
      },
    );
  }

  Widget _buildCategoryButton(ColorScheme cs, TextTheme tt, Color activeColor) {
    final allCats = ref.watch(allFlatCategoriesProvider);
    final cat = allCats.where((c) => c.id == _categoryId).firstOrNull;
    final displayName =
        cat?.displayName ?? _categoryName ?? 'Selecionar categoria';

    return InkWell(
      onTap: _pickCategory,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _categoryId != null
              ? activeColor.withValues(alpha: 0.06)
              : cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _categoryId != null
                ? activeColor.withValues(alpha: 0.25)
                : cs.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _categoryId != null
                    ? activeColor.withValues(alpha: 0.12)
                    : cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child:
                    _categoryId != null &&
                        _categoryIcon != null &&
                        _categoryColor != null
                    ? CategoryIcon(
                        icon: _categoryIcon!,
                        color: _categoryColor!,
                        parentIcon: cat?.parentIcon,
                        parentColor: cat?.parentColor,
                        size: 24,
                      )
                    : Icon(
                        Icons.category_outlined,
                        color: cs.onSurfaceVariant,
                        size: 22,
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Categoria',
                    style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  Text(
                    displayName,
                    style: tt.bodyMedium?.copyWith(
                      color: _categoryId != null
                          ? cs.onSurface
                          : cs.onSurfaceVariant,
                      fontWeight: _categoryId != null
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            if (_categoryId == null)
              Text(
                '*',
                style: TextStyle(
                  color: cs.error,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              )
            else
              Icon(Icons.check_circle_rounded, color: activeColor, size: 20),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              color: cs.onSurfaceVariant,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  // ── Page 2: Como ──────────────────────────────────────────────────────────

  Widget _buildPageComo(ColorScheme cs, TextTheme tt) {
    return _bottomScrollable([
      if (_type == TransactionType.transfer) ...[
        AccountSelector(
          selectedAccountId: _accountId,
          onAccountSelected: (acc) => setState(() => _accountId = acc?.id),
          hint: 'Conta de origem',
          showBalance: false,
        ),
        const SizedBox(height: 16),
        AccountSelector(
          selectedAccountId: _toAccountId,
          onAccountSelected: (acc) => setState(() => _toAccountId = acc?.id),
          hint: 'Conta de destino',
          showBalance: false,
        ),
      ] else ...[
        EntityAutocomplete(
          selectedEntityId: _entityId,
          entityType: _type == TransactionType.income ? 'payer' : 'payee',
          label: _type == TransactionType.income ? 'Recebido de *' : 'Pago a *',
          onEntitySelected: (entity) {
            setState(() {
              _entityId = entity?.id;
              _entityName = entity?.name;
            });
          },
          focusNode: _entityFocusNode,
        ),
        const SizedBox(height: 16),
        AccountSelector(
          selectedAccountId: _accountId,
          onAccountSelected: (acc) {
            setState(() {
              _accountId = acc?.id;
              _selectedCreditCardId = null;
            });
          },
          hint: 'Conta',
          showBalance: false,
          showCreditCards: _type == TransactionType.expense,
          selectedCreditCardId: _selectedCreditCardId,
          onCreditCardSelected: (card) {
            setState(() => _selectedCreditCardId = card?.id);
          },
        ),
      ],
      const SizedBox(height: 16),
      _DateTimeButton(date: _date, onTap: _pickDateTime, cs: cs, tt: tt),
    ]);
  }

  // ── Page 3: Extras ────────────────────────────────────────────────────────

  Widget _buildPageExtras(ColorScheme cs, TextTheme tt) {
    return _bottomScrollable([
      if (_type != TransactionType.transfer) ...[
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
                  // ignore: deprecated_member_use
                  value: _goalId,
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
                      (g) => DropdownMenuItem(value: g.id, child: Text(g.name)),
                    ),
                  ],
                  onChanged: (val) => setState(() => _goalId = val),
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (e, s) => const Text('Erro ao carregar metas'),
            );
          },
        ),
        const SizedBox(height: 24),
      ],

      TextFormField(
        controller: _notesController,
        focusNode: _notesFocusNode,
        maxLines: 3,
        decoration: InputDecoration(
          labelText: 'Observações / Notas',
          hintText: 'Adicione informações adicionais...',
          alignLabelWithHint: true,
          prefixIcon: const Padding(
            padding: EdgeInsets.only(bottom: 40),
            child: Icon(Icons.notes_outlined),
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),

      if (_type != TransactionType.transfer) ...[
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: _installmentCount != null
                  ? FilledButton.icon(
                      onPressed: _clearInstallment,
                      icon: const Icon(Icons.close),
                      label: Text('${_installmentCount}x'),
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    )
                  : OutlinedButton.icon(
                      onPressed: _openInstallmentWizard,
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
              child: _recurringFrequency != null
                  ? FilledButton.icon(
                      onPressed: _clearRecurring,
                      icon: const Icon(Icons.close),
                      label: Text(_recurringFrequency!.label),
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    )
                  : OutlinedButton.icon(
                      onPressed: _openRecurringForm,
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
      ],
    ]);
  }

  // ── Page 4: Resumo ────────────────────────────────────────────────────────

  Widget _buildPageResumo(ColorScheme cs, TextTheme tt) {
    final activeColor = _activeColor;
    final accounts = ref.watch(activeAccountsProvider);
    final account = accounts.where((a) => a.id == _accountId).firstOrNull;
    final toAccount = accounts.where((a) => a.id == _toAccountId).firstOrNull;

    final String typeLabel;
    switch (_type) {
      case TransactionType.expense:
        typeLabel = 'Despesa';
      case TransactionType.income:
        typeLabel = 'Receita';
      case TransactionType.transfer:
        typeLabel = 'Transferência';
    }

    return _bottomScrollable([
      // Hero summary card
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: activeColor.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: activeColor.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: activeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    typeLabel,
                    style: tt.labelMedium?.copyWith(
                      color: activeColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (_sentiment != null) ...[
                  const SizedBox(width: 8),
                  Text(_sentiment!.emoji, style: const TextStyle(fontSize: 18)),
                ],
              ],
            ),
            const SizedBox(height: 10),
            Text(
              CurrencyFormatter.formatCents(_amountInCents),
              style: tt.headlineLarge?.copyWith(
                color: activeColor,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _descriptionController.text,
              style: tt.bodyLarge?.copyWith(color: cs.onSurface),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),

      // Details card
      Card(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          children: [
            if (_type != TransactionType.transfer && _categoryName != null)
              _summaryRow(
                Icons.category_outlined,
                'Categoria',
                _categoryName!,
                cs,
                tt,
              ),
            _summaryRow(
              Icons.account_balance_wallet_outlined,
              _type == TransactionType.transfer ? 'De' : 'Conta',
              account?.name ?? '—',
              cs,
              tt,
            ),
            if (_type == TransactionType.transfer && toAccount != null)
              _summaryRow(
                Icons.arrow_forward_rounded,
                'Para',
                toAccount.name,
                cs,
                tt,
              ),
            if (_type != TransactionType.transfer && _entityName != null)
              _summaryRow(
                _type == TransactionType.income
                    ? Icons.person_outlined
                    : Icons.store_outlined,
                _type == TransactionType.income ? 'Recebido de' : 'Pago a',
                _entityName!,
                cs,
                tt,
              ),
            _summaryRow(
              Icons.calendar_today_outlined,
              'Data',
              _formatDateFull(_date),
              cs,
              tt,
            ),
          ],
        ),
      ),

      // Extras card (shown only if any extra is set)
      if (_notesController.text.isNotEmpty || _installmentCount != null || _recurringFrequency != null) ...[
        const SizedBox(height: 12),
        Card(
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              if (_installmentCount != null)
                _summaryRow(
                  Icons.date_range_outlined,
                  'Parcelamento',
                  '${_installmentCount}x',
                  cs,
                  tt,
                ),
              if (_recurringFrequency != null)
                _summaryRow(
                  Icons.repeat,
                  'Recorrência',
                  _recurringFrequency!.label,
                  cs,
                  tt,
                ),
              if (_notesController.text.isNotEmpty)
                _summaryRow(
                  Icons.notes_outlined,
                  'Notas',
                  _notesController.text,
                  cs,
                  tt,
                ),
            ],
          ),
        ),
      ],

      const SizedBox(height: 16),
      Text(
        'Revise os dados acima antes de confirmar.',
        style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        textAlign: TextAlign.center,
      ),
    ]);
  }

  Widget _summaryRow(
    IconData icon,
    String label,
    String value,
    ColorScheme cs,
    TextTheme tt,
  ) {
    return ListTile(
      leading: Icon(icon, size: 20, color: cs.onSurfaceVariant),
      title: Text(
        label,
        style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
      ),
      subtitle: Text(
        value,
        style: tt.bodyMedium?.copyWith(
          color: cs.onSurface,
          fontWeight: FontWeight.w500,
        ),
      ),
      dense: true,
      visualDensity: VisualDensity.compact,
    );
  }

  String _formatDateFull(DateTime d) {
    const months = [
      'janeiro',
      'fevereiro',
      'março',
      'abril',
      'maio',
      'junho',
      'julho',
      'agosto',
      'setembro',
      'outubro',
      'novembro',
      'dezembro',
    ];
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '${d.day} de ${months[d.month - 1]} de ${d.year}, $h:$m';
  }
}

// ── Stepper indicator ────────────────────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  final int currentStep; // 1–4 (maps to pages 1–4)
  final int maxStep;
  final ValueChanged<int> onStepTap;

  const _StepIndicator({
    required this.currentStep,
    required this.maxStep,
    required this.onStepTap,
  });

  static const _labels = ['O quê', 'Como', 'Extras', 'Resumo'];

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          for (int i = 0; i < 4; i++) ...[
            GestureDetector(
              onTap: (i + 1) <= maxStep ? () => onStepTap(i + 1) : null,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    width: (i + 1) == currentStep ? 20 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: (i + 1) <= maxStep
                          ? (i + 1) == currentStep
                                ? cs.primary
                                : cs.primary.withValues(alpha: 0.35)
                          : cs.outlineVariant,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 4),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: (tt.labelSmall ?? const TextStyle()).copyWith(
                      color: (i + 1) == currentStep
                          ? cs.primary
                          : cs.onSurfaceVariant.withValues(alpha: 0.5),
                      fontWeight: (i + 1) == currentStep
                          ? FontWeight.bold
                          : FontWeight.normal,
                      fontSize: 10,
                    ),
                    child: Text(_labels[i]),
                  ),
                ],
              ),
            ),
            if (i < 3)
              Expanded(
                child: Container(
                  height: 2,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(
                    color: (i + 1) < maxStep
                        ? cs.primary.withValues(alpha: 0.35)
                        : cs.outlineVariant.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

// ── Date/time button ─────────────────────────────────────────────────────────

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

  String _formatDateFull(DateTime d) {
    const months = [
      'janeiro',
      'fevereiro',
      'março',
      'abril',
      'maio',
      'junho',
      'julho',
      'agosto',
      'setembro',
      'outubro',
      'novembro',
      'dezembro',
    ];
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '${d.day} de ${months[d.month - 1]} de ${d.year}, $h:$m';
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Icon(
                  Icons.calendar_today_outlined,
                  color: cs.onSurfaceVariant,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Data e Hora',
                    style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  Text(
                    _formatDateFull(date),
                    style: tt.bodyMedium?.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: cs.onSurfaceVariant,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
