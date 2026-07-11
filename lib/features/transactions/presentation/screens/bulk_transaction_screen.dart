import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:bestfin/core/constants/transaction_status.dart';
import 'package:bestfin/core/constants/transaction_types.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/theme/breakpoints.dart';
import 'package:bestfin/core/providers/default_account_provider.dart';
import 'package:bestfin/core/utils/adaptive_modal.dart';
import 'package:bestfin/core/utils/currency_formatter.dart';
import 'package:bestfin/core/widgets/account_selector.dart';
import 'package:bestfin/core/widgets/app_button.dart';
import 'package:bestfin/core/widgets/app_page_appbar.dart';
import 'package:bestfin/core/widgets/category_icon.dart';
import 'package:bestfin/core/widgets/category_picker.dart';
import 'package:bestfin/core/widgets/entity_autocomplete.dart';
import 'package:bestfin/core/widgets/pending_status_icon.dart';
import 'package:bestfin/features/accounts/presentation/providers/accounts_provider.dart';
import 'package:bestfin/features/gamification/presentation/providers/gamification_providers.dart';
import 'package:bestfin/features/transactions/domain/models/bulk_transaction_item.dart';
import 'package:bestfin/features/transactions/domain/models/transaction.dart';
import 'package:bestfin/features/transactions/presentation/providers/transactions_provider.dart';
import 'package:bestfin/features/transactions/presentation/widgets/amount_input.dart';
import 'package:bestfin/features/transactions/presentation/widgets/date_time_button.dart';
import 'package:bestfin/features/transactions/presentation/widgets/description_autocomplete.dart';
import 'package:bestfin/features/transactions/presentation/widgets/transaction_form_modal_overlay.dart';
import 'package:bestfin/features/transactions/presentation/widgets/transaction_type_tabs.dart';

/// Abre a inserção em massa no mesmo padrão de apresentação do formulário de
/// criar/editar transação ([TransactionFormModalOverlay]): bottom sheet com
/// altura limitada (65% da tela) no mobile e painel adaptativo em telas
/// largas.
Future<void> showBulkTransactionModal(
  BuildContext context, {
  TransactionType initialType = TransactionType.expense,
}) {
  if (Breakpoints.isCompact(context)) {
    return showLimitedTransactionSheet<void>(
      context: context,
      builder: (sheetContext) => BulkTransactionScreen(
        initialType: initialType,
        onClose: () => Navigator.of(sheetContext).pop(),
      ),
    );
  }
  return showAdaptiveModal<void>(
    context: context,
    builder: (modalContext) => BulkTransactionScreen(
      initialType: initialType,
      onClose: () => Navigator.of(modalContext).pop(),
    ),
  );
}

/// Inserção de vários lançamentos de uma vez: todos compartilham tipo,
/// entidade, conta(s), data e status (cabeçalho do lote); descrição, valor e
/// categoria variam por linha. O lote é salvo tudo-ou-nada.
///
/// Quando [initialGroup] é informado, a tela abre em **modo de edição** de um
/// bloco agrupado já existente: os campos compartilhados e as linhas são
/// pré-preenchidos com os membros, e salvar substitui o bloco no lugar.
class BulkTransactionScreen extends ConsumerStatefulWidget {
  final TransactionType initialType;

  /// Fecha o modal quando a tela está hospedada em bottom sheet/painel
  /// (mesmo contrato do formulário individual). Nulo quando aberta como rota.
  final VoidCallback? onClose;

  /// Membros de um bloco agrupado a editar. Nulo = criação de um novo lote.
  final List<TransactionModel>? initialGroup;

  const BulkTransactionScreen({
    super.key,
    this.initialType = TransactionType.expense,
    this.onClose,
    this.initialGroup,
  });

  @override
  ConsumerState<BulkTransactionScreen> createState() =>
      _BulkTransactionScreenState();
}

class _RowDraft {
  final TextEditingController description = TextEditingController();
  int amountInCents = 0;
  String? categoryId;
  String? categoryName;
  String? categoryColor;
  String? categoryIcon;
  bool selected = false;

  void clearCategory() {
    categoryId = null;
    categoryName = null;
    categoryColor = null;
    categoryIcon = null;
  }

  void dispose() => description.dispose();
}

class _BulkTransactionScreenState extends ConsumerState<BulkTransactionScreen> {
  late TransactionType _type;
  String? _entityId;
  String? _accountId;
  String? _toAccountId;
  late DateTime _date;
  bool _isPending = false;
  bool _groupTogether = true;
  bool _saving = false;

  /// groupId do bloco em edição — null quando criando um novo lote.
  String? _editGroupId;

  bool get _isEditing => _editGroupId != null;

  final List<_RowDraft> _rows = [];

  /// Controllers de linhas removidas via swipe: descartados só no dispose da
  /// tela, para não disputar o ciclo de vida com a animação do Dismissible.
  final List<_RowDraft> _removedRows = [];

  bool get _isTransfer => _type == TransactionType.transfer;

  bool get _isFutureDate => TransactionStatus.isFutureDate(_date);

  /// Mesma semântica do formulário: data futura esconde o toggle "Pendente"
  /// e o lançamento nasce não concluído.
  bool get _effectiveIsCompleted => _isFutureDate ? false : !_isPending;

  Color get _activeColor {
    final colors = context.customColors;
    return _type == TransactionType.income
        ? colors.income
        : _isTransfer
        ? colors.transfer
        : colors.expense;
  }

  @override
  void initState() {
    super.initState();
    final group = widget.initialGroup;
    if (group != null && group.isNotEmpty) {
      _initFromGroup(group);
    } else {
      _type = widget.initialType;
      _date = DateTime.now();
      _rows.addAll([_RowDraft(), _RowDraft()]);
      for (final row in _rows) {
        row.description.addListener(_onRowChanged);
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _tryAutoSelectAccount();
    });
  }

  /// Pré-preenche o cabeçalho compartilhado e uma linha por membro a partir de
  /// um bloco agrupado existente. Todos os membros compartilham tipo, entidade,
  /// conta, data e status (definidos no lote), então basta ler o primeiro.
  void _initFromGroup(List<TransactionModel> group) {
    final first = group.first;
    _editGroupId = first.groupId;
    _type = first.type;
    _entityId = first.entityId;
    _accountId = _type == TransactionType.transfer
        ? first.fromAccountId
        : first.accountId;
    _toAccountId = first.toAccountId;
    _date = first.date;
    _isPending = first.isPending;
    _groupTogether = true;

    for (final tx in group) {
      final row = _RowDraft();
      row.description.text = tx.description;
      row.amountInCents = tx.amount;
      row.categoryId = tx.categoryId;
      if (tx.category != null) {
        row.categoryName = tx.category!.displayName;
        row.categoryColor = tx.category!.color;
        row.categoryIcon = tx.category!.icon;
      }
      row.description.addListener(_onRowChanged);
      _rows.add(row);
    }
  }

  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }
    for (final row in _removedRows) {
      row.dispose();
    }
    super.dispose();
  }

  void _onRowChanged() => setState(() {});

  void _tryAutoSelectAccount() {
    if (_accountId != null) return;
    final accounts = ref.read(activeAccountsProvider);
    if (accounts.isEmpty) return;
    final defaultId = ref.read(defaultAccountIdProvider);
    setState(() {
      if (accounts.length == 1) {
        _accountId = accounts.first.id;
      } else if (defaultId != null && accounts.any((a) => a.id == defaultId)) {
        _accountId = defaultId;
      }
    });
  }

  // ── Validação ──────────────────────────────────────────────────────────────

  /// Linha totalmente vazia — ignorada ao salvar, não bloqueia o botão.
  bool _isRowEmpty(_RowDraft row) =>
      row.description.text.trim().isEmpty &&
      row.amountInCents == 0 &&
      row.categoryId == null;

  bool _isRowValid(_RowDraft row) {
    if (row.amountInCents <= 0) return false;
    if (!_isTransfer) {
      if (row.description.text.trim().isEmpty) return false;
      if (row.categoryId == null) return false;
    }
    return true;
  }

  List<_RowDraft> get _filledRows =>
      _rows.where((r) => !_isRowEmpty(r)).toList();

  bool get _canSave {
    if (_saving) return false;
    if (_accountId == null) return false;
    if (_isTransfer) {
      if (_toAccountId == null || _toAccountId == _accountId) return false;
    } else {
      if (_entityId == null) return false;
    }
    final filled = _filledRows;
    if (filled.isEmpty) return false;
    return filled.every(_isRowValid);
  }

  int get _totalInCents =>
      _filledRows.fold(0, (sum, r) => sum + r.amountInCents);

  bool get _hasUnsavedContent => _filledRows.isNotEmpty;

  // ── Ações do cabeçalho ─────────────────────────────────────────────────────

  void _onTypeChanged(TransactionType type) {
    if (type == _type) return;
    setState(() {
      // Categorias e entidades são escopadas por tipo — valores escolhidos no
      // tipo anterior deixariam o lote inconsistente.
      for (final row in _rows) {
        row.clearCategory();
      }
      _entityId = null;
      if (type != TransactionType.transfer) _toAccountId = null;
      _type = type;
    });
  }

  /// Mesmo fluxo de data+hora do formulário individual.
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

  // ── Ações das linhas ───────────────────────────────────────────────────────

  void _addRow() {
    final row = _RowDraft();
    row.description.addListener(_onRowChanged);
    setState(() => _rows.add(row));
  }

  void _removeRow(_RowDraft row) {
    setState(() {
      _rows.remove(row);
      row.description.removeListener(_onRowChanged);
      _removedRows.add(row);
    });
  }

  Future<void> _editRowAmount(_RowDraft row) async {
    await showAdaptiveModal<int>(
      context: context,
      builder: (_) => AmountKeypadSheet(
        initialAmountInCents: row.amountInCents,
        onChanged: (v) => setState(() => row.amountInCents = v),
      ),
    );
  }

  Future<void> _pickRowCategory(_RowDraft row) async {
    final cat = await showCategoryPicker(
      context,
      typeFilter: _type.name,
      selectedCategoryId: row.categoryId,
    );
    if (cat != null && mounted) {
      setState(() {
        row.categoryId = cat.id;
        row.categoryName = cat.displayName;
        row.categoryColor = cat.color;
        row.categoryIcon = cat.icon;
      });
    }
  }

  // ── Aplicação em massa ─────────────────────────────────────────────────────

  int get _selectedCount => _rows.where((r) => r.selected).length;

  Iterable<_RowDraft> get _applyTargets =>
      _selectedCount > 0 ? _rows.where((r) => r.selected) : _rows;

  void _toggleSelectAll(bool? value) {
    final select = value ?? false;
    setState(() {
      for (final row in _rows) {
        row.selected = select;
      }
    });
  }

  void _clearSelection() {
    for (final row in _rows) {
      row.selected = false;
    }
  }

  Future<void> _applyCategory() async {
    final cat = await showCategoryPicker(context, typeFilter: _type.name);
    if (cat == null || !mounted) return;
    setState(() {
      for (final row in _applyTargets) {
        row.categoryId = cat.id;
        row.categoryName = cat.displayName;
        row.categoryColor = cat.color;
        row.categoryIcon = cat.icon;
      }
      _clearSelection();
    });
  }

  Future<void> _applyAmount() async {
    final targets = _applyTargets.toList();
    // Aplica em massa só no confirmar: um valor digitado por engano e depois
    // cancelado não pode sobrescrever as linhas selecionadas.
    final cents = await showAdaptiveModal<int>(
      context: context,
      builder: (_) => const AmountKeypadSheet(initialAmountInCents: 0),
    );
    if (cents == null || cents <= 0 || !mounted) return;
    setState(() {
      for (final row in targets) {
        row.amountInCents = cents;
      }
      _clearSelection();
    });
  }

  void _removeSelected() {
    setState(() {
      final selected = _rows.where((r) => r.selected).toList();
      for (final row in selected) {
        _rows.remove(row);
        row.description.removeListener(_onRowChanged);
        _removedRows.add(row);
      }
      if (_rows.isEmpty) _addRowUnsafe();
    });
  }

  void _addRowUnsafe() {
    final row = _RowDraft();
    row.description.addListener(_onRowChanged);
    _rows.add(row);
  }

  // ── Salvar ─────────────────────────────────────────────────────────────────

  /// Fecha a tela: via [widget.onClose] quando hospedada em modal/bottom
  /// sheet (mesmo contrato do formulário individual), senão pop da rota.
  void _close() {
    final onClose = widget.onClose;
    if (onClose != null) {
      onClose();
    } else {
      context.pop();
    }
  }

  /// Cancela pelo botão do rodapé (modo modal): confirma o descarte se houver
  /// linhas preenchidas, como acontece ao usar o botão voltar.
  void _cancel() {
    if (_hasUnsavedContent) {
      _confirmDiscard();
    } else {
      _close();
    }
  }

  String _transferFallbackDescription() {
    final accounts = ref.read(activeAccountsProvider);
    final from = accounts.where((a) => a.id == _accountId).firstOrNull;
    final to = accounts.where((a) => a.id == _toAccountId).firstOrNull;
    return 'Transferência: ${from?.name ?? "Origem"} -> ${to?.name ?? "Destino"}';
  }

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _saving = true);

    // Um único id compartilhado por todas as linhas quando o usuário opta por
    // agrupar; só faz sentido a partir de 2 lançamentos. Na edição, reusa o
    // groupId do bloco para mantê-lo agrupado (ou desagrupa com null).
    final rows = _filledRows;
    final shouldGroup = _groupTogether && rows.length > 1;
    final groupId = shouldGroup ? (_editGroupId ?? const Uuid().v4()) : null;

    final items = rows.map((row) {
      final description = row.description.text.trim();
      return BulkTransactionItem(
        date: _date,
        description: description.isEmpty && _isTransfer
            ? _transferFallbackDescription()
            : description,
        type: _type.name,
        amount: row.amountInCents,
        categoryId: _isTransfer ? null : row.categoryId,
        entityId: _isTransfer ? null : _entityId,
        accountId: _accountId!,
        toAccountId: _isTransfer ? _toAccountId : null,
        isCompleted: _effectiveIsCompleted,
        groupId: groupId,
      );
    }).toList();

    try {
      if (_isEditing) {
        await ref.read(updateGroupedTransactionsProvider)(_editGroupId!, items);
      } else {
        await ref.read(createTransactionsBulkProvider)(items);
        await ref.read(gamificationServiceProvider).onTransactionCreated();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing
                  ? 'Bloco atualizado!'
                  : '${items.length} transações cadastradas!',
            ),
          ),
        );
        _close();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar transações: $e')),
        );
      }
    }
  }

  Future<void> _confirmDiscard() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Descartar lançamentos?'),
        content: const Text(
          'As linhas preenchidas serão perdidas. Deseja sair mesmo assim?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Continuar editando'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    if (leave == true && mounted) {
      _close();
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.textTheme;

    ref.listen(activeAccountsProvider, (prev, next) {
      if (_accountId == null && next.isNotEmpty) _tryAutoSelectAccount();
    });

    return PopScope(
      canPop: !_hasUnsavedContent || _saving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmDiscard();
      },
      child: Scaffold(
        backgroundColor: cs.surface,
        // Em modal o cabeçalho são as abas de tipo, como no formulário
        // individual hospedado em bottom sheet.
        appBar: widget.onClose != null
            ? null
            : AppPageAppBar(
                title: _isEditing ? 'Editar Bloco' : 'Inserir Vários',
              ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TransactionTypeTabs(
                selectedType: _type,
                onTypeChanged: _onTypeChanged,
              ),
            ),
            Divider(
              height: 1,
              thickness: 1,
              color: cs.outlineVariant.withValues(alpha: 0.3),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  _sectionLabel(cs, tt, 'DADOS COMPARTILHADOS'),
                  ..._buildSharedFields(cs, tt),
                  _sectionLabel(cs, tt, 'LANÇAMENTOS'),
                  _buildBulkToolbar(cs, tt),
                  _buildTableHeader(cs, tt),
                  for (final row in _rows) _buildRow(cs, tt, row),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _addRow,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Adicionar linha'),
                  ),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: _buildFooter(cs, tt),
      ),
    );
  }

  Widget _sectionLabel(ColorScheme cs, TextTheme tt, String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 10),
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

  List<Widget> _buildSharedFields(ColorScheme cs, TextTheme tt) {
    return [
      if (_isTransfer) ...[
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
          onEntitySelected: (entity) => setState(() => _entityId = entity?.id),
        ),
        const SizedBox(height: 16),
        AccountSelector(
          selectedAccountId: _accountId,
          onAccountSelected: (acc) => setState(() => _accountId = acc?.id),
          hint: 'Conta',
          showBalance: false,
        ),
      ],
      const SizedBox(height: 16),
      DateTimeButton(date: _date, onTap: _pickDateTime),
      if (!_isFutureDate)
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
      SwitchListTile.adaptive(
        value: _groupTogether,
        onChanged: (v) => setState(() => _groupTogether = v),
        contentPadding: EdgeInsets.zero,
        title: const Text('Agrupar em um só lançamento'),
        subtitle: Text(
          _groupTogether
              ? 'As linhas aparecem como um único item, mostrando só o total.'
              : 'Cada linha aparece como um lançamento separado.',
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        secondary: Icon(
          _groupTogether ? Icons.layers_rounded : Icons.layers_outlined,
          color: _activeColor,
        ),
      ),
    ];
  }

  // ── Tabela ─────────────────────────────────────────────────────────────────

  Widget _buildBulkToolbar(ColorScheme cs, TextTheme tt) {
    final selected = _selectedCount;
    return AnimatedSize(
      duration: const Duration(milliseconds: 150),
      alignment: Alignment.topCenter,
      child: selected == 0
          ? const SizedBox.shrink()
          : Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: _activeColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '$selected selecionada${selected > 1 ? 's' : ''}',
                      style: tt.labelMedium?.copyWith(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (!_isTransfer)
                    TextButton.icon(
                      onPressed: _applyCategory,
                      icon: const Icon(Icons.category_outlined, size: 16),
                      label: const Text('Categoria'),
                    ),
                  TextButton.icon(
                    onPressed: _applyAmount,
                    icon: const Icon(Icons.attach_money_rounded, size: 16),
                    label: const Text('Valor'),
                  ),
                  IconButton(
                    onPressed: _removeSelected,
                    icon: const Icon(Icons.delete_outline_rounded, size: 20),
                    tooltip: 'Remover selecionadas',
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildTableHeader(ColorScheme cs, TextTheme tt) {
    final headerStyle = tt.labelSmall?.copyWith(
      color: cs.onSurfaceVariant,
      fontWeight: FontWeight.w700,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Checkbox(
              tristate: true,
              value: _selectedCount == 0
                  ? false
                  : (_selectedCount == _rows.length ? true : null),
              onChanged: (v) => _toggleSelectAll(v ?? false),
              visualDensity: VisualDensity.compact,
            ),
          ),
          Expanded(child: Text('Descrição', style: headerStyle)),
          SizedBox(
            width: 96,
            child: Text(
              'Valor',
              style: headerStyle,
              textAlign: TextAlign.right,
            ),
          ),
          if (!_isTransfer)
            SizedBox(
              width: 56,
              child: Text(
                'Cat.',
                style: headerStyle,
                textAlign: TextAlign.center,
              ),
            ),
          // Alinha com a coluna do botão "remover linha" nas linhas.
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildRow(ColorScheme cs, TextTheme tt, _RowDraft row) {
    final showError = !_isRowEmpty(row) && !_isRowValid(row);

    return Dismissible(
      key: ObjectKey(row),
      direction: _rows.length > 1
          ? DismissDirection.endToStart
          : DismissDirection.none,
      onDismissed: (_) => _removeRow(row),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: cs.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.delete_outline_rounded, color: cs.onErrorContainer),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: row.selected
              ? _activeColor.withValues(alpha: 0.06)
              : cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: showError
                ? cs.error.withValues(alpha: 0.5)
                : cs.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 40,
              child: Checkbox(
                value: row.selected,
                onChanged: (v) => setState(() => row.selected = v ?? false),
                visualDensity: VisualDensity.compact,
              ),
            ),
            Expanded(
              // Mesmo autocomplete por histórico do formulário individual,
              // em decoração compacta para caber na linha da tabela.
              child: DescriptionAutocomplete(
                controller: row.description,
                transactionType: _type.name,
                textCapitalization: TextCapitalization.sentences,
                style: tt.bodyMedium,
                decoration: InputDecoration(
                  hintText: 'Descrição',
                  hintStyle: tt.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                  isDense: true,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onSelected: (_) => setState(() {}),
              ),
            ),
            InkWell(
              onTap: () => _editRowAmount(row),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 96,
                padding: const EdgeInsets.symmetric(vertical: 12),
                alignment: Alignment.centerRight,
                child: Text(
                  CurrencyFormatter.formatCents(
                    row.amountInCents,
                    ignoreVisibility: true,
                  ),
                  style: tt.bodyMedium?.copyWith(
                    color: row.amountInCents > 0
                        ? _activeColor
                        : cs.onSurfaceVariant.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            if (!_isTransfer)
              SizedBox(
                width: 56,
                child: IconButton(
                  onPressed: () => _pickRowCategory(row),
                  tooltip: row.categoryName ?? 'Selecionar categoria',
                  visualDensity: VisualDensity.compact,
                  icon: row.categoryIcon != null && row.categoryColor != null
                      ? CategoryIcon(
                          icon: row.categoryIcon!,
                          color: row.categoryColor!,
                          size: 22,
                        )
                      : Icon(
                          Icons.category_outlined,
                          color: cs.onSurfaceVariant,
                          size: 22,
                        ),
                ),
              ),
            // Remoção explícita da linha (além do swipe). Mantém sempre ao
            // menos uma linha — a última não pode ser removida.
            SizedBox(
              width: 40,
              child: _rows.length > 1
                  ? IconButton(
                      onPressed: () => _removeRow(row),
                      tooltip: 'Remover linha',
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        Icons.close_rounded,
                        color: cs.onSurfaceVariant,
                        size: 20,
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(ColorScheme cs, TextTheme tt) {
    final filled = _filledRows.length;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    CurrencyFormatter.formatCents(
                      _totalInCents,
                      ignoreVisibility: true,
                    ),
                    style: tt.titleMedium?.copyWith(
                      color: _activeColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '$filled lançamento${filled == 1 ? '' : 's'}',
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            if (widget.onClose != null) ...[
              OutlinedButton(
                onPressed: _saving ? null : _cancel,
                child: const Text('Cancelar'),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              flex: 2,
              child: AppButton(
                label: filled > 0 ? 'Salvar ($filled)' : 'Salvar',
                icon: Icons.check_rounded,
                color: _activeColor,
                loading: _saving,
                onPressed: _canSave ? _save : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
