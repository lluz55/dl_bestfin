import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bestfin/core/constants/transaction_status.dart';
import 'package:bestfin/core/constants/transaction_types.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/providers/default_account_provider.dart';
import 'package:bestfin/core/providers/pending_default_provider.dart';
import 'package:bestfin/core/utils/adaptive_modal.dart';
import 'package:bestfin/core/utils/currency_formatter.dart';
import 'package:bestfin/core/widgets/account_selector.dart';
import 'package:bestfin/core/widgets/app_button.dart';
import 'package:bestfin/core/widgets/app_page_appbar.dart';
import 'package:bestfin/core/widgets/category_icon.dart';
import 'package:bestfin/core/widgets/category_picker.dart';
import 'package:bestfin/core/widgets/entity_autocomplete.dart';
import 'package:bestfin/core/widgets/numeric_keypad.dart';
import 'package:bestfin/features/accounts/presentation/providers/accounts_provider.dart';
import 'package:bestfin/features/gamification/presentation/providers/gamification_providers.dart';
import 'package:bestfin/features/transactions/domain/models/bulk_transaction_item.dart';
import 'package:bestfin/features/transactions/presentation/providers/transactions_provider.dart';
import 'package:bestfin/features/transactions/presentation/widgets/transaction_type_tabs.dart';

/// Inserção de vários lançamentos de uma vez: todos compartilham tipo,
/// entidade, conta(s), data e status (cabeçalho do lote); descrição, valor e
/// categoria variam por linha. O lote é salvo tudo-ou-nada.
class BulkTransactionScreen extends ConsumerStatefulWidget {
  final TransactionType initialType;

  const BulkTransactionScreen({
    super.key,
    this.initialType = TransactionType.expense,
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
  bool _saving = false;

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
    _type = widget.initialType;
    _date = DateTime.now();
    _isPending = ref.read(defaultPendingForPastProvider);
    _rows.addAll([_RowDraft(), _RowDraft(), _RowDraft()]);
    for (final row in _rows) {
      row.description.addListener(_onRowChanged);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _tryAutoSelectAccount();
    });
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

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    final wasFuture = _isFutureDate;
    setState(() {
      _date = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _date.hour,
        _date.minute,
      );
      // Deixou de ser futura: aplica o padrão de "Pendente" (não havia toggle
      // visível antes, então não existe escolha do usuário a preservar).
      if (wasFuture && !_isFutureDate) {
        _isPending = ref.read(defaultPendingForPastProvider);
      }
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
      builder: (_) => _AmountKeypadSheet(
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
      builder: (_) => const _AmountKeypadSheet(initialAmountInCents: 0),
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

  String _transferFallbackDescription() {
    final accounts = ref.read(activeAccountsProvider);
    final from = accounts.where((a) => a.id == _accountId).firstOrNull;
    final to = accounts.where((a) => a.id == _toAccountId).firstOrNull;
    return 'Transferência: ${from?.name ?? "Origem"} -> ${to?.name ?? "Destino"}';
  }

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _saving = true);

    final items = _filledRows.map((row) {
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
      );
    }).toList();

    try {
      await ref.read(createTransactionsBulkProvider)(items);
      await ref.read(gamificationServiceProvider).onTransactionCreated();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${items.length} transações cadastradas!')),
        );
        context.pop();
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
      context.pop();
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
        appBar: const AppPageAppBar(title: 'Inserir Vários'),
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
      _buildDateButton(cs, tt),
      if (!_isFutureDate)
        SwitchListTile.adaptive(
          value: _isPending,
          onChanged: (v) => setState(() => _isPending = v),
          contentPadding: EdgeInsets.zero,
          title: const Text('Pendente'),
          subtitle: Text(
            _isPending
                ? 'Ainda não aconteceu — conta no projetado, não no confirmado.'
                : 'Confirmada — já aconteceu.',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          secondary: Icon(
            _isPending
                ? Icons.schedule_rounded
                : Icons.check_circle_outline_rounded,
            color: _activeColor,
          ),
        ),
    ];
  }

  Widget _buildDateButton(ColorScheme cs, TextTheme tt) {
    final d = _date;
    final label =
        '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/'
        '${d.year}';
    return InkWell(
      onTap: _pickDate,
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
            Icon(Icons.calendar_today_outlined, color: cs.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Data',
                    style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  Text(
                    label,
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
              child: TextField(
                controller: row.description,
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
                  CurrencyFormatter.formatCents(row.amountInCents),
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
                    CurrencyFormatter.formatCents(_totalInCents),
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

/// Teclado numérico modal para editar o valor de uma linha — mesmo fluxo de
/// digitação do [AmountInput] do formulário, em versão enxuta.
class _AmountKeypadSheet extends StatefulWidget {
  final int initialAmountInCents;

  /// Preview ao vivo enquanto digita (usado na edição por linha). Quando nulo,
  /// o valor só chega ao chamador via `Navigator.pop` ao confirmar.
  final ValueChanged<int>? onChanged;

  const _AmountKeypadSheet({
    required this.initialAmountInCents,
    this.onChanged,
  });

  @override
  State<_AmountKeypadSheet> createState() => _AmountKeypadSheetState();
}

class _AmountKeypadSheetState extends State<_AmountKeypadSheet> {
  late String _digits;

  @override
  void initState() {
    super.initState();
    _digits = widget.initialAmountInCents == 0
        ? ''
        : widget.initialAmountInCents.toString();
  }

  // Centavos cabem folgadamente em 12 dígitos (~R$ 9,9 bi); acima disso o
  // int.parse arriscaria estourar e zerar o valor silenciosamente.
  static const _maxDigits = 12;

  void _handleKeyPress(String key) {
    if (key == ',') return;
    if ((_digits.isEmpty || _digits == '0') && (key == '0' || key == '00')) {
      return;
    }
    final next = _digits + key;
    if (next.length > _maxDigits) return;
    setState(() => _digits = next);
    _notifyChange();
  }

  void _handleDelete() {
    if (_digits.isEmpty) return;
    setState(() => _digits = _digits.substring(0, _digits.length - 1));
    _notifyChange();
  }

  void _notifyChange() {
    widget.onChanged?.call(int.tryParse(_digits) ?? 0);
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.textTheme;
    final currentCents = int.tryParse(_digits) ?? 0;

    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Digite o valor',
                style: tt.titleMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                CurrencyFormatter.formatCents(currentCents),
                style: tt.displayMedium?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 24),
              NumericKeypad(
                onKeyPressed: _handleKeyPress,
                onDeletePressed: _handleDelete,
                onConfirmPressed: () => Navigator.of(context).pop(currentCents),
                autofocus: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
