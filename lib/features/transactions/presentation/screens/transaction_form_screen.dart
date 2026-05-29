import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bestfin/core/constants/transaction_types.dart';
import 'package:bestfin/core/constants/sentiment_types.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/widgets/app_page_appbar.dart';
import 'package:bestfin/core/widgets/account_selector.dart';
import 'package:bestfin/core/widgets/category_picker.dart';
import 'package:bestfin/core/widgets/category_icon.dart';
import 'package:bestfin/core/widgets/entity_autocomplete.dart';
import 'package:bestfin/core/widgets/sentiment_selector.dart';
import 'package:bestfin/features/transactions/domain/models/transaction.dart';
import 'package:bestfin/features/transactions/presentation/widgets/description_autocomplete.dart';
import 'package:bestfin/features/transactions/presentation/widgets/amount_input.dart';
import 'package:bestfin/features/transactions/presentation/widgets/transaction_type_tabs.dart';
import 'package:bestfin/features/installments/presentation/providers/installments_provider.dart';
import 'package:bestfin/features/installments/presentation/screens/installment_wizard_screen.dart';
import 'package:bestfin/core/utils/date_formatter.dart';
import 'package:bestfin/features/transactions/presentation/providers/transactions_provider.dart';
import 'package:bestfin/features/ai/presentation/providers/ai_provider.dart';
import 'package:bestfin/core/utils/icon_mapper.dart';
import 'package:bestfin/features/gamification/presentation/providers/gamification_providers.dart';
import 'package:bestfin/features/goals/presentation/providers/goals_provider.dart';

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

  late TransactionType _type;
  late int _amountInCents;
  late TextEditingController _descriptionController;
  late bool _isCloningState;

  bool get _isEditing =>
      widget.transaction != null &&
      widget.transaction!.id.isNotEmpty &&
      !_isCloningState;

  void _onDescriptionChanged() {
    setState(() {}); // Trigger rebuild to update suggestion chip as user types
  }

  late TextEditingController _notesController;

  String? _accountId;
  String? _toAccountId; // For transfer

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

    _categoryId = tx?.categoryId;
    _categoryName = tx?.category?.name;
    _categoryColor = tx?.category?.color;
    _categoryIcon = tx?.category?.icon;

    _entityId = tx?.entityId;
    _goalId = tx?.goalId;
    _sentiment = tx?.sentiment;
    _date = _isCloningState ? DateTime.now() : (tx?.date ?? DateTime.now());

    _descriptionController.addListener(_onDescriptionChanged);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _date = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _date.hour,
          _date.minute,
        );
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_date),
    );
    if (picked != null) {
      setState(() {
        _date = DateTime(
          _date.year,
          _date.month,
          _date.day,
          picked.hour,
          picked.minute,
        );
      });
    }
  }

  @override
  void dispose() {
    _descriptionController.removeListener(_onDescriptionChanged);
    _descriptionController.dispose();
    _notesController.dispose();
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
        _categoryName = cat.name;
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

  /// Abre o formulário de recorrência, passando os dados da transação atual.
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
              entityId: _entityId,
              sentiment: _sentiment?.name,
              notes: _notesController.text.trim().isEmpty
                  ? null
                  : _notesController.text.trim(),
            );

        // Update streaks and badges
        await ref.read(gamificationServiceProvider).onTransactionCreated();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Parcelamento criado com sucesso!')),
          );
          Navigator.pop(context);
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
          entityId: _entityId,
          accountId: _accountId!,
          toAccountId: _toAccountId,
          sentiment: _sentiment?.name,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
        );
      } else {
        await ref.read(createTransactionProvider)(
          date: _date,
          description: _descriptionController.text.trim(),
          type: _type.name,
          amount: _amountInCents,
          categoryId: _categoryId,
          entityId: _entityId,
          accountId: _accountId!,
          toAccountId: _toAccountId,
          sentiment: _sentiment?.name,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
        );
      }

      // Update streaks and badges
      await ref.read(gamificationServiceProvider).onTransactionCreated();

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

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppPageAppBar(
        title: _isEditing
            ? 'Editar Transação'
            : (_isCloningState ? 'Duplicar Transação' : 'Nova Transação'),
        actions: [
          if (_isEditing)
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
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 48),
          children: [
            // Tabs Despesa / Receita / Transferência
            TransactionTypeTabs(
              selectedType: _type,
              onTypeChanged: (type) {
                setState(() {
                  _type = type;
                  // Limpa categoria incompatível
                  if (type == TransactionType.transfer) {
                    _categoryId = null;
                    _categoryName = null;
                    _categoryIcon = null;
                    _categoryColor = null;
                  } else if (_categoryId != null && _categoryName != null) {
                    // Mantém se compatível, senão limpa
                  }
                });
              },
            ),
            const SizedBox(height: 24),

            // Amount Input giant
            AmountInput(
              amountInCents: _amountInCents,
              color: activeColor,
              onChanged: (val) {
                setState(() {
                  _amountInCents = val;
                });
              },
            ),
            const SizedBox(height: 24),

            // Descrição da Transação com Autocomplete
            DescriptionAutocomplete(
              controller: _descriptionController,
              transactionType: _type.name,
              onSelected: (selection) {
                setState(() {
                  _descriptionController.text = selection;
                });
              },
              onChanged: _onDescriptionChanged,
            ),
            const SizedBox(height: 8),
            // AI Category Suggestion Chip
            () {
              final suggestion = ref.watch(
                autoCategorizeProvider(_descriptionController.text),
              );
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
                      },
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            }(),
            const SizedBox(height: 16),

            // Contas Envolvidas
            if (_type == TransactionType.transfer) ...[
              Text(
                'Conta de Origem',
                style: tt.labelLarge?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              AccountSelector(
                selectedAccountId: _accountId,
                onAccountSelected: (acc) {
                  setState(() {
                    _accountId = acc?.id;
                  });
                },
                hint: 'Selecione a conta de origem',
              ),
              const SizedBox(height: 16),
              Text(
                'Conta de Destino',
                style: tt.labelLarge?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              AccountSelector(
                selectedAccountId: _toAccountId,
                onAccountSelected: (acc) {
                  setState(() {
                    _toAccountId = acc?.id;
                  });
                },
                hint: 'Selecione a conta de destino',
              ),
            ] else ...[
              Text(
                'Conta',
                style: tt.labelLarge?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              AccountSelector(
                selectedAccountId: _accountId,
                onAccountSelected: (acc) {
                  setState(() {
                    _accountId = acc?.id;
                  });
                },
                hint: 'Selecione uma conta',
              ),
            ],
            const SizedBox(height: 16),

            // Categoria (Escondido em transferências)
            if (_type != TransactionType.transfer) ...[
              Text(
                'Categoria',
                style: tt.labelLarge?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: _pickCategory,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: cs.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      if (_categoryId != null &&
                          _categoryIcon != null &&
                          _categoryColor != null) ...[
                        CategoryIcon(
                          icon: _categoryIcon!,
                          color: _categoryColor!,
                          size: 40,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _categoryName!,
                            style: tt.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: cs.onSurface,
                            ),
                          ),
                        ),
                      ] else ...[
                        Icon(
                          Icons.category_outlined,
                          color: cs.onSurfaceVariant,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Selecione uma categoria',
                            style: tt.bodyMedium?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                      Icon(
                        Icons.keyboard_arrow_right_rounded,
                        color: cs.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Autocomplete de Favorecidos / Entidades
            EntityAutocomplete(
              selectedEntityId: _entityId,
              entityType: _type == TransactionType.income ? 'payer' : 'payee',
              label: _type == TransactionType.income
                  ? 'Recebido de (Pagador)'
                  : 'Pago a (Recebedor)',
              onEntitySelected: (entity) {
                setState(() {
                  _entityId = entity?.id;
                });
              },
            ),
            const SizedBox(height: 16),

            // Seletor de Sentimentos
            SentimentSelector(
              selectedSentiment: _sentiment,
              onSentimentSelected: (sentiment) {
                setState(() {
                  _sentiment = sentiment;
                });
              },
            ),
            const SizedBox(height: 24),

            // Vínculo com Meta
            Text(
              'Vincular a uma Meta',
              style: tt.labelLarge?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Consumer(
              builder: (context, ref, child) {
                final goalsAsync = ref.watch(activeGoalsProvider);
                return goalsAsync.when(
                  data: (goals) {
                    if (goals.isEmpty) {
                      return Text(
                        'Nenhuma meta ativa encontrada',
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      );
                    }
                    return DropdownButtonFormField<String>(
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
                          (g) => DropdownMenuItem(
                            value: g.id,
                            child: Text(g.name),
                          ),
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

            // Data e Hora
            Text(
              'Data e Hora',
              style: tt.labelLarge?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text(DateFormatter.formatDate(_date)),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickTime,
                    icon: const Icon(Icons.access_time),
                    label: Text(
                      '${_date.hour.toString().padLeft(2, '0')}:${_date.minute.toString().padLeft(2, '0')}',
                    ),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Observações libres
            TextFormField(
              controller: _notesController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Observações / Notas',
                hintText:
                    'Adicione informações adicionais sobre essa transação...',
                alignLabelWithHint: true,
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(bottom: 40),
                  child: Icon(Icons.notes_outlined),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Parcelamento e Recorrência
            if (_type != TransactionType.transfer) ...[
              Row(
                children: [
                  Expanded(
                    child: _installmentCount != null
                        ? FilledButton.icon(
                            onPressed: _clearInstallment,
                            icon: const Icon(Icons.close),
                            label: Text('Parcelado em ${_installmentCount}x'),
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
                    child: OutlinedButton.icon(
                      onPressed: () => _openRecurringForm(),
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
              const SizedBox(height: 32),
            ],

            // Botão de Ação Salvar
            SizedBox(
              height: 54,
              child: FilledButton(
                onPressed: _save,
                style: FilledButton.styleFrom(
                  backgroundColor: activeColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  _isEditing
                      ? 'Atualizar Transação'
                      : (_isCloningState
                          ? 'Confirmar Duplicação'
                          : 'Confirmar Transação'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
