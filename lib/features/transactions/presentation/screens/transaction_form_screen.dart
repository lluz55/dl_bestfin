import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bestfin/core/constants/transaction_types.dart';
import 'package:bestfin/core/constants/sentiment_types.dart';
import 'package:bestfin/core/constants/transaction_status.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/utils/adaptive_modal.dart';
import 'package:bestfin/core/widgets/app_button.dart';
import 'package:bestfin/core/providers/default_account_provider.dart';
import 'package:bestfin/core/widgets/app_page_appbar.dart';
import 'package:bestfin/core/widgets/account_selector.dart';
import 'package:bestfin/core/widgets/category_picker.dart';
import 'package:bestfin/core/widgets/category_icon.dart';
import 'package:bestfin/core/widgets/entity_autocomplete.dart';
import 'package:bestfin/core/widgets/pending_status_icon.dart';
import 'package:bestfin/core/widgets/sentiment_emoji_button.dart';
import 'package:bestfin/features/accounts/presentation/providers/accounts_provider.dart';
import 'package:bestfin/features/transactions/domain/models/transaction.dart';
import 'package:bestfin/features/transactions/presentation/providers/transaction_form_modal_provider.dart';
import 'package:bestfin/features/transactions/presentation/widgets/amount_input.dart';
import 'package:bestfin/features/transactions/presentation/widgets/date_time_button.dart';
import 'package:bestfin/features/transactions/presentation/widgets/description_autocomplete.dart';
import 'package:bestfin/features/transactions/presentation/widgets/transaction_type_tabs.dart';
import 'package:bestfin/features/installments/presentation/providers/installments_provider.dart';
import 'package:bestfin/features/installments/presentation/screens/installment_wizard_screen.dart';
import 'package:bestfin/features/transactions/presentation/providers/transactions_provider.dart';
import 'package:bestfin/features/transactions/presentation/widgets/delete_transaction_sheet.dart';
import 'package:bestfin/features/gamification/presentation/providers/gamification_providers.dart';
import 'package:bestfin/features/goals/presentation/providers/goals_provider.dart';
import 'package:bestfin/features/categories/presentation/providers/categories_provider.dart';
import 'package:bestfin/features/credit_cards/presentation/providers/credit_cards_provider.dart';
import 'package:bestfin/features/recurring/domain/models/recurring_rule.dart';
import 'package:bestfin/features/recurring/presentation/providers/recurring_provider.dart';
import 'package:bestfin/features/recurring/presentation/widgets/recurring_wizard_sheet.dart';
import 'package:bestfin/features/transactions/domain/models/split_entry.dart';
import 'package:bestfin/features/transactions/presentation/widgets/split_editor_sheet.dart';

class TransactionFormScreen extends ConsumerStatefulWidget {
  final TransactionModel? transaction;
  final TransactionType? initialType;
  final bool isCloning;

  /// Rascunho vindo do "Lançamento Rápido" (botão "Mais opções"), para não
  /// perder o que já foi digitado. Ignorado quando [transaction] está presente.
  final TransactionDraft? draft;

  /// Abre o assistente de recorrência ("Repetir") assim que o formulário
  /// monta. Ponto de entrada padrão para qualquer "nova transação
  /// recorrente" — hub de assinaturas, lista de recorrentes, etc. — que
  /// devem reusar este formulário em vez de implementar o próprio.
  final bool openRecurringWizardOnStart;
  final VoidCallback? onClose;

  const TransactionFormScreen({
    super.key,
    this.transaction,
    this.initialType,
    this.isCloning = false,
    this.draft,
    this.openRecurringWizardOnStart = false,
    this.onClose,
  });

  @override
  ConsumerState<TransactionFormScreen> createState() =>
      _TransactionFormScreenState();
}

class _TransactionFormScreenState extends ConsumerState<TransactionFormScreen> {
  final FocusNode _descriptionFocusNode = FocusNode();
  final FocusNode _entityFocusNode = FocusNode();
  final FocusNode _notesFocusNode = FocusNode();

  // Form state
  late TransactionType _type;
  late int _amountInCents;
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
  String? _goalId;
  SentimentType? _sentiment;

  late DateTime _date;
  int? _installmentCount;

  // Recurring state
  RecurringFrequency? _recurringFrequency;
  DateTime? _recurringStartDate;
  DateTime? _recurringEndDate;
  bool _recurringAutoConfirm = false;

  // Split state
  List<SplitEntry> _splits = [];
  bool _saving = false;

  /// Transação pendente (ainda não aconteceu). Só é editável pelo usuário
  /// quando a data não é futura — ver [_effectiveIsCompleted].
  bool _isPending = false;

  bool get _isEditing =>
      widget.transaction != null &&
      widget.transaction!.id.isNotEmpty &&
      !_isCloningState;

  /// Transações futuras não expõem o toggle "Pendente": nascem não
  /// concluídas e só são marcadas como concluídas quando a data chegar
  /// (manual ou automaticamente, conforme configuração de recorrência).
  bool get _isFutureDate => TransactionStatus.isFutureDate(_date);

  /// Com data futura o toggle "Pendente" fica escondido, então o formulário
  /// não pode decidir o status: preserva o que já existia (ex: uma conta
  /// futura já quitada antecipadamente via "marcar como paga" na lista) ou,
  /// para uma transação nova, nasce não concluída.
  bool get _effectiveIsCompleted {
    if (!_isFutureDate) return !_isPending;
    return _isEditing ? widget.transaction!.isCompleted : false;
  }

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
    // Rascunho do "Lançamento Rápido" só se aplica a um formulário novo.
    final draft = tx == null ? widget.draft : null;

    _type =
        tx?.type ??
        draft?.type ??
        widget.initialType ??
        TransactionType.expense;
    _amountInCents = tx?.amount ?? draft?.amountInCents ?? 0;

    // Strip installment suffix from description when editing a parcelated transaction
    final rawDesc = tx?.description ?? draft?.description ?? '';
    final cleanedDesc = (tx?.installmentPlanId != null && !_isCloningState)
        ? rawDesc.replaceAll(RegExp(r'\s*\(\d+/\d+\)$'), '').trim()
        : rawDesc;
    _descriptionController = TextEditingController(text: cleanedDesc);
    _notesController = TextEditingController(text: tx?.notes ?? '');

    _accountId = tx?.accountId ?? draft?.accountId;
    _toAccountId = tx?.toAccountId ?? draft?.toAccountId;
    _selectedCreditCardId = tx?.creditCardId;

    _categoryId = tx?.categoryId ?? draft?.categoryId;
    _categoryName = tx?.category?.displayName;
    _categoryColor = tx?.category?.color;
    _categoryIcon = tx?.category?.icon;

    _entityId = tx?.entityId ?? draft?.entityId;
    _goalId = tx?.goalId;
    _sentiment = tx?.sentiment ?? draft?.sentiment;
    _splits = List<SplitEntry>.from(tx?.splits ?? []);
    _date = _isCloningState ? DateTime.now() : (tx?.date ?? DateTime.now());
    // Só datas futuras nascem pendentes/agendadas automaticamente; hoje e
    // datas passadas nascem confirmadas. Edição preserva o valor existente.
    _isPending = tx?.isPending ?? draft?.isPending ?? false;

    // Rascunho carrega só o id da categoria; resolve nome/cor/ícone p/ exibição.
    if (_categoryId != null && _categoryName == null) {
      for (final c in ref.read(allFlatCategoriesProvider)) {
        if (c.id == _categoryId) {
          _categoryName = c.displayName;
          _categoryColor = c.color;
          _categoryIcon = c.icon;
          break;
        }
      }
    }

    _descriptionController.addListener(_onDescriptionChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (widget.openRecurringWizardOnStart && !_isEditing) {
        await _openRecurringForm();
        if (!mounted) return;
      }
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
    super.dispose();
  }

  bool get _canSave {
    if (_amountInCents <= 0) return false;
    if (_type != TransactionType.transfer) {
      if (_descriptionController.text.trim().isEmpty) return false;
      if (_categoryId == null && _splits.isEmpty) return false;
      if (_entityId == null) return false;
    }
    if (_accountId == null) return false;
    if (_type == TransactionType.transfer) {
      if (_toAccountId == null) return false;
      if (_accountId == _toAccountId) return false;
    }
    return true;
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
      _isPending = TransactionStatus.isFutureDate(_date);
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

    final result = await showAdaptiveModal<InstallmentWizardResult>(
      context: context,
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
    final result = await showAdaptiveModal<RecurringWizardResult>(
      context: context,
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

  /// Fecha o formulário. Quando hospedado em [AdaptiveModalPanel] (desktop/
  /// tablet), o painel não tem Navigator próprio — é um overlay desenhado
  /// direto na árvore — então um `Navigator.pop(context)` aqui resolveria
  /// para o Navigator real do app (GoRouter) e populariam a rota errada.
  /// `widget.onClose` já existe para fechar o overlay nesse caso; só cai no
  /// pop de rota quando o formulário foi de fato empurrado como rota (mobile).
  void _closeForm() {
    final onClose = widget.onClose;
    if (onClose != null) {
      onClose();
    } else {
      Navigator.pop(context);
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
    if (_saving) return;
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
      if (_categoryId == null && _splits.isEmpty) {
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

    setState(() => _saving = true);

    if (_isInstallmentEdit) {
      try {
        await ref
            .read(installmentRepositoryProvider)
            .updateInstallmentPlan(
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
          _closeForm();
        }
      } catch (e) {
        if (mounted) {
          setState(() => _saving = false);
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
            _closeForm();
          }
        }
        return;
      } catch (e) {
        if (mounted) {
          setState(() => _saving = false);
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
            splits: _splits.isNotEmpty ? _splits : null,
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
            splits: _splits.isNotEmpty ? _splits : null,
          );
        }

        await ref.read(createRecurringRuleProvider)(
          baseTransactionId: baseTransactionId,
          frequency: _recurringFrequency!,
          interval: 1,
          startDate: _recurringStartDate ?? _date,
          endDate: _recurringEndDate,
          autoConfirm: _type == TransactionType.transfer
              ? false
              : _recurringAutoConfirm,
        );

        await ref.read(gamificationServiceProvider).onTransactionCreated();

        if (mounted) {
          await _checkAndOfferDefaultAccount(_accountId!);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Recorrência criada com sucesso!')),
            );
            _closeForm();
          }
        }
        return;
      } catch (e) {
        if (mounted) {
          setState(() => _saving = false);
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
          splits: _splits.isNotEmpty ? _splits : null,
          isCompleted: _effectiveIsCompleted,
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
          splits: _splits.isNotEmpty ? _splits : null,
          isCompleted: _effectiveIsCompleted,
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
          _closeForm();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao salvar transação: $e')));
      }
    }
  }

  // ── Layout helpers ─────────────────────────────────────────────────────────

  // Aligns content to the bottom of the available space and scrolls if overflow.
  /// Empilha os campos de uma seção. Antes cada "página" tinha seu próprio
  /// scroll; agora o formulário inteiro rola junto (ver [_buildBody]).
  Widget _bottomScrollable(List<Widget> children) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.textTheme;
    final isInModal = widget.onClose != null;

    ref.listen(activeAccountsProvider, (prev, next) {
      if (_accountId == null && widget.transaction == null && next.isNotEmpty) {
        _tryAutoSelectAccount();
      }
    });

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: isInModal
          ? null
          : AppPageAppBar(
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
          Expanded(child: _buildBody(cs, tt)),
        ],
      ),
      bottomNavigationBar: _buildFooter(cs, tt),
    );
  }

  /// Corpo em scroll único: valor no topo (abre o teclado modal ao tocar,
  /// como no Lançamento Rápido) seguido das seções O quê · Como · Extras.
  Widget _buildBody(ColorScheme cs, TextTheme tt) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AmountInput(
            amountInCents: _amountInCents,
            color: _activeColor,
            autoOpen: !_isEditing && _amountInCents == 0,
            onChanged: (v) => setState(() => _amountInCents = v),
          ),
          _sectionLabel(cs, tt, 'O QUÊ'),
          _buildPageOQue(cs, tt),
          _sectionLabel(cs, tt, 'COMO'),
          _buildPageComo(cs, tt),
          _sectionLabel(cs, tt, 'EXTRAS'),
          _buildPageExtras(cs, tt),
        ],
      ),
    );
  }

  Widget _sectionLabel(ColorScheme cs, TextTheme tt, String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 24, 4, 10),
      child: Text(
        text,
        style: tt.labelSmall?.copyWith(
          color: cs.onSurfaceVariant,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(ColorScheme cs, TextTheme tt) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
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
              _goalId = null;
            }
          });
        },
      ),
    );
  }

  // ── Footer ─────────────────────────────────────────────────────────────────

  Widget _buildFooter(ColorScheme cs, TextTheme tt) {
    final activeColor = _activeColor;
    final saveLabel = _isEditing
        ? 'Atualizar'
        : (_isCloningState ? 'Duplicar' : 'Salvar');

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: [
            if (widget.onClose != null) ...[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _saving ? null : widget.onClose,
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              flex: 2,
              child: AppButton(
                label: saveLabel,
                icon: Icons.check_rounded,
                color: activeColor,
                loading: _saving,
                onPressed: (_saving || !_canSave) ? null : _save,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Split ──────────────────────────────────────────────────────────────────

  Future<void> _openSplitEditor() async {
    final result = await showAdaptiveModal<List<SplitEntry>?>(
      context: context,
      builder: (_) => SplitEditorSheet(totalAmount: _amountInCents),
    );
    if (result != null && mounted) {
      setState(() {
        _splits = result;
        // Clear single category when user confirms splits
        _categoryId = null;
        _categoryName = null;
        _categoryColor = null;
        _categoryIcon = null;
      });
    }
  }

  /// Estado "dividida" do campo Categoria — mesmo formato visual do
  /// [_buildCategoryButton]; o toque abre o editor e o ✕ desfaz a divisão.
  Widget _buildSplitsField(ColorScheme cs, TextTheme tt, Color activeColor) {
    final names = _splits
        .where((s) => s.categoryName != null)
        .map((s) => s.categoryName!)
        .join(', ');

    return InkWell(
      onTap: _openSplitEditor,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: activeColor.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: activeColor.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: activeColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.call_split_rounded,
                color: activeColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Categoria · dividida',
                    style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  Text(
                    '${_splits.length} categoria${_splits.length > 1 ? 's' : ''} — $names',
                    style: tt.bodyMedium?.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => setState(() => _splits = []),
              icon: const Icon(Icons.close_rounded, size: 20),
              tooltip: 'Desfazer divisão',
              visualDensity: VisualDensity.compact,
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

  // ── Page 1: O quê ─────────────────────────────────────────────────────────

  Widget _buildPageOQue(ColorScheme cs, TextTheme tt) {
    final activeColor = _activeColor;

    return _bottomScrollable([
      // Description + sentiment
      IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: DescriptionAutocomplete(
                controller: _descriptionController,
                transactionType: _type.name,
                focusNode: _descriptionFocusNode,
                onSelected: (selection) {
                  setState(() => _descriptionController.text = selection);
                },
                onFieldSubmitted: (_) {
                  // Transferência não tem campo de entidade — pula direto para
                  // as observações, que existem para todos os tipos.
                  FocusScope.of(context).requestFocus(
                    _type == TransactionType.transfer
                        ? _notesFocusNode
                        : _entityFocusNode,
                  );
                },
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
      ),

      // Campo Categoria (exceto transferência). Quando a despesa está
      // dividida, o mesmo slot mostra o estado "dividida" do campo.
      if (_type != TransactionType.transfer) ...[
        const SizedBox(height: 16),
        if (_splits.isEmpty)
          _buildCategoryButton(cs, tt, activeColor)
        else
          _buildSplitsField(cs, tt, activeColor),
      ],
    ]);
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
            if (_type == TransactionType.expense)
              IconButton(
                onPressed: _openSplitEditor,
                icon: const Icon(Icons.call_split_rounded, size: 20),
                tooltip: 'Dividir entre categorias',
                visualDensity: VisualDensity.compact,
              ),
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
          excludeAccountId: _toAccountId,
        ),
        const SizedBox(height: 16),
        AccountSelector(
          selectedAccountId: _toAccountId,
          onAccountSelected: (acc) => setState(() => _toAccountId = acc?.id),
          hint: 'Conta de destino',
          showBalance: false,
          excludeAccountId: _accountId,
        ),
      ] else ...[
        EntityAutocomplete(
          selectedEntityId: _entityId,
          entityType: _type == TransactionType.income ? 'payer' : 'payee',
          label: _type == TransactionType.income ? 'Recebido de *' : 'Pago a *',
          onEntitySelected: (entity) {
            setState(() => _entityId = entity?.id);
          },
          focusNode: _entityFocusNode,
          onFieldSubmitted: (_) {
            FocusScope.of(context).requestFocus(_notesFocusNode);
          },
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
      DateTimeButton(date: _date, onTap: _pickDateTime),
    ]);
  }

  // ── Page 3: Extras ────────────────────────────────────────────────────────

  Widget _buildPageExtras(ColorScheme cs, TextTheme tt) {
    return _bottomScrollable([
      if (!_isFutureDate) ...[
        SwitchListTile.adaptive(
          value: _isPending,
          onChanged: (v) => setState(() => _isPending = v),
          contentPadding: EdgeInsets.zero,
          title: const Text('Pendente'),
          subtitle: Text(
            _isPending
                ? 'Pendente — ainda não aconteceu.'
                : 'Confirmada — já aconteceu.',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          secondary: PendingStatusIcon(
            isPending: _isPending,
            color: _activeColor,
          ),
        ),
        const Divider(height: 32),
      ],

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
                    )
                  : OutlinedButton.icon(
                      onPressed: _openInstallmentWizard,
                      icon: const Icon(Icons.date_range_outlined),
                      label: const Text('Parcelar'),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _recurringFrequency != null
                  ? FilledButton.icon(
                      onPressed: _clearRecurring,
                      icon: const Icon(Icons.close),
                      label: Text(_recurringFrequency!.label),
                    )
                  : OutlinedButton.icon(
                      onPressed: _openRecurringForm,
                      icon: const Icon(Icons.repeat),
                      label: const Text('Repetir'),
                    ),
            ),
          ],
        ),
      ],
    ]);
  }
}
