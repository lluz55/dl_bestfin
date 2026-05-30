import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/widgets/app_page_appbar.dart';
import 'package:bestfin/core/utils/icon_mapper.dart';
import 'package:bestfin/core/widgets/account_selector.dart';
import 'package:bestfin/core/widgets/color_picker.dart';
import 'package:bestfin/features/goals/domain/models/goal.dart';
import 'package:bestfin/features/goals/presentation/providers/goals_provider.dart';
import 'package:bestfin/features/goals/presentation/widgets/monthly_simulator_widget.dart';
import 'package:bestfin/features/goals/presentation/widgets/goal_category_selector.dart';
import 'package:bestfin/features/transactions/presentation/widgets/amount_input.dart';

class GoalFormScreen extends ConsumerStatefulWidget {
  final GoalModel? existingGoal;

  const GoalFormScreen({super.key, this.existingGoal});

  @override
  ConsumerState<GoalFormScreen> createState() => _GoalFormScreenState();
}

class _GoalFormScreenState extends ConsumerState<GoalFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();

  int _targetAmountInCents = 0;
  DateTime? _targetDate;
  String? _accountId;
  String _color = '#1E88E5';
  String _icon = 'flag';
  GoalType _type = GoalType.saving;
  bool _isRecurring = false;
  GoalRecurrenceFrequency? _recurrenceFrequency = GoalRecurrenceFrequency.monthly;
  List<String> _categoryIds = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final g = widget.existingGoal;
    if (g != null) {
      _nameController.text = g.name;
      _descController.text = g.description ?? '';
      _targetAmountInCents = g.targetAmountInCents;
      _targetDate = g.targetDate;
      _accountId = g.accountId;
      _color = g.color ?? '#1E88E5';
      _icon = g.icon ?? 'flag';
      _type = g.type;
      _isRecurring = g.isRecurring;
      _recurrenceFrequency = g.recurrenceFrequency ?? GoalRecurrenceFrequency.monthly;
      _categoryIds = List<String>.from(g.categoryIds);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickTargetDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate ?? DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _targetDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_targetAmountInCents <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Defina um valor alvo maior que R\$ 0,00'),
        ),
      );
      return;
    }

    if (_isRecurring && _recurrenceFrequency == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione a frequência de recorrência')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      if (widget.existingGoal == null) {
        await ref.read(createGoalProvider)(
          name: _nameController.text.trim(),
          description: _descController.text.trim().isEmpty
              ? null
              : _descController.text.trim(),
          targetAmountInCents: _targetAmountInCents,
          targetDate: _targetDate,
          accountId: _accountId,
          color: _color,
          icon: _icon,
          type: _type,
          isRecurring: _isRecurring,
          recurrenceFrequency: _isRecurring ? _recurrenceFrequency : null,
          categoryIds: _categoryIds,
        );
      } else {
        await ref
            .read(goalRepositoryProvider)
            .updateGoal(
              id: widget.existingGoal!.id,
              name: _nameController.text.trim(),
              description: _descController.text.trim().isEmpty
                  ? null
                  : _descController.text.trim(),
              targetAmountInCents: _targetAmountInCents,
              targetDate: _targetDate,
              accountId: _accountId,
              color: _color,
              icon: _icon,
              type: _type,
              isRecurring: _isRecurring,
              recurrenceFrequency: _isRecurring ? _recurrenceFrequency : null,
              categoryIds: _categoryIds,
            );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.existingGoal == null
                  ? 'Meta criada com sucesso!'
                  : 'Meta atualizada!',
            ),
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.textTheme;
    final isEditing = widget.existingGoal != null;
    final goalColor = _parseColor(_color, cs.primary);

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppPageAppBar(title: isEditing ? 'Editar Meta' : 'Nova Meta'),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 48),
          children: [
            // Ícone e cor (preview)
            Center(
              child: GestureDetector(
                onTap: _pickIconAndColor,
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: goalColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: goalColor.withValues(alpha: 0.4),
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        IconMapper.fromString(_icon),
                        size: 36,
                        color: goalColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Toque para personalizar',
                      style: tt.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Nome
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Nome da meta *',
                hintText: 'Ex: Viagem de férias',
                prefixIcon: const Icon(Icons.flag_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Informe um nome' : null,
            ),
            const SizedBox(height: 14),

            // Descrição
            TextFormField(
              controller: _descController,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Descrição (opcional)',
                hintText: 'Por que esse objetivo é importante?',
                prefixIcon: const Icon(Icons.notes_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Valor alvo
            AmountInput(
              amountInCents: _targetAmountInCents,
              label: 'Valor Alvo',
              color: context.colorScheme.primary,
              onChanged: (val) => setState(() => _targetAmountInCents = val),
            ),
            const SizedBox(height: 14),

            // Prazo (oculto se recorrente, pois o período define o ciclo)
            if (!_isRecurring) ...[
              _DateField(
                label: 'Prazo (opcional)',
                date: _targetDate,
                icon: Icons.calendar_month_rounded,
                placeholder: 'Sem prazo definido',
                onTap: _pickTargetDate,
                onClear: _targetDate != null
                    ? () => setState(() => _targetDate = null)
                    : null,
              ),
              const SizedBox(height: 24),
            ] else
              const SizedBox(height: 24),

            // ── Tipo de Meta ─────────────────────────────────────────────────
            Text(
              'Tipo de Meta',
              style: tt.labelLarge?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            SegmentedButton<GoalType>(
              segments: const [
                ButtonSegment<GoalType>(
                  value: GoalType.saving,
                  label: Text('Economia'),
                  icon: Icon(Icons.savings_rounded),
                ),
                ButtonSegment<GoalType>(
                  value: GoalType.spending,
                  label: Text('Orçamento'),
                  icon: Icon(Icons.shopping_bag_rounded),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (newSelection) {
                setState(() => _type = newSelection.first);
              },
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── Recorrência ──────────────────────────────────────────────────
            _SectionHeader(icon: Icons.repeat_rounded, label: 'Recorrência'),
            const SizedBox(height: 8),
            SwitchListTile.adaptive(
              value: _isRecurring,
              onChanged: (v) => setState(() => _isRecurring = v),
              title: const Text('Meta recorrente'),
              subtitle: Text(
                _isRecurring
                    ? 'O progresso reseta automaticamente a cada período'
                    : 'A meta não se repete automaticamente',
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              contentPadding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            if (_isRecurring) ...[
              const SizedBox(height: 10),
              SegmentedButton<GoalRecurrenceFrequency>(
                segments: GoalRecurrenceFrequency.values
                    .map(
                      (f) => ButtonSegment<GoalRecurrenceFrequency>(
                        value: f,
                        label: Text(f.label),
                      ),
                    )
                    .toList(),
                selected: {
                  _recurrenceFrequency ?? GoalRecurrenceFrequency.monthly,
                },
                onSelectionChanged: (s) =>
                    setState(() => _recurrenceFrequency = s.first),
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),

            // ── Categorias absorvidas ─────────────────────────────────────────
            _SectionHeader(
              icon: Icons.category_outlined,
              label: 'Absorção automática',
            ),
            const SizedBox(height: 4),
            Text(
              'Transações com as categorias abaixo serão automaticamente '
              'contabilizadas nesta meta.',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            GoalCategorySelector(
              selectedCategoryIds: _categoryIds,
              onChanged: (ids) => setState(() => _categoryIds = ids),
            ),
            const SizedBox(height: 24),

            // ── Conta vinculada ───────────────────────────────────────────────
            Text(
              'Conta vinculada (opcional)',
              style: tt.labelLarge?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            AccountSelector(
              selectedAccountId: _accountId,
              onAccountSelected: (acc) => setState(() => _accountId = acc?.id),
            ),
            const SizedBox(height: 24),

            // Simulador mensal (somente se tem prazo, valor e não é recorrente)
            if (_targetAmountInCents > 0 && _targetDate != null && !_isRecurring) ...[
              MonthlySimulatorWidget(
                remainingInCents: _targetAmountInCents,
                initialMonths: _monthsToTarget(),
              ),
              const SizedBox(height: 24),
            ],

            // Botão salvar
            SizedBox(
              height: 54,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        isEditing ? 'Salvar Alterações' : 'Criar Meta',
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

  int? _monthsToTarget() {
    if (_targetDate == null) return null;
    final now = DateTime.now();
    if (_targetDate!.isBefore(now)) return null;
    final months =
        (_targetDate!.year - now.year) * 12 + (_targetDate!.month - now.month);
    return months > 0 ? months : null;
  }

  Color _parseColor(String hex, Color fallback) {
    try {
      final h = hex.replaceAll('#', '');
      return Color(int.parse('FF$h', radix: 16));
    } catch (_) {
      return fallback;
    }
  }

  Future<void> _pickIconAndColor() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _IconColorPicker(
        selectedIcon: _icon,
        selectedColor: _color,
        onSelected: (icon, color) {
          setState(() {
            _icon = icon;
            _color = color;
          });
        },
      ),
    );
  }
}

// ── Section Header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SectionHeader({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: cs.primary),
        const SizedBox(width: 8),
        Text(
          label,
          style: tt.labelLarge?.copyWith(
            color: cs.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

// ── Date Field ───────────────────────────────────────────────────────────────

class _DateField extends StatelessWidget {
  final String label;
  final DateTime? date;
  final IconData icon;
  final String? placeholder;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _DateField({
    required this.label,
    required this.date,
    required this.icon,
    required this.onTap,
    this.placeholder,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final fmt = DateFormat('dd/MM/yyyy');

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(color: cs.outline),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: cs.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: tt.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    date != null ? fmt.format(date!) : (placeholder ?? '—'),
                    style: tt.bodyMedium?.copyWith(
                      color: date != null ? cs.onSurface : cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (onClear != null)
              GestureDetector(
                onTap: onClear,
                child: Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: cs.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Icon and Color Picker ────────────────────────────────────────────────────

class _IconColorPicker extends StatefulWidget {
  final String selectedIcon;
  final String selectedColor;
  final void Function(String icon, String color) onSelected;

  const _IconColorPicker({
    required this.selectedIcon,
    required this.selectedColor,
    required this.onSelected,
  });

  @override
  State<_IconColorPicker> createState() => _IconColorPickerState();
}

class _IconColorPickerState extends State<_IconColorPicker> {
  late String _icon;
  late String _color;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _icon = widget.selectedIcon;
    _color = widget.selectedColor;
  }

  static Color _hex(String hex) {
    final h = hex.replaceAll('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }

  Map<String, List<MapEntry<String, IconData>>> get _displayMap {
    if (_query.isEmpty) return IconMapper.categorized;
    final q = _query.toLowerCase();
    final filtered =
        IconMapper.all.entries.where((e) => e.key.contains(q)).toList();
    return {'Resultados': filtered};
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final goalColor = _hex(_color);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 4),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: goalColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: goalColor, width: 2),
                      ),
                      child: Icon(
                        IconMapper.fromString(_icon),
                        color: goalColor,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Personalizar',
                        style: tt.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    FilledButton(
                      onPressed: () {
                        widget.onSelected(_icon, _color);
                        Navigator.pop(ctx);
                      },
                      style: FilledButton.styleFrom(backgroundColor: goalColor),
                      child: const Text(
                        'Confirmar',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SearchBar(
                  hintText: 'Buscar ícone...',
                  leading: const Icon(Icons.search_rounded),
                  onChanged: (v) => setState(() => _query = v),
                  elevation: const WidgetStatePropertyAll(0),
                  backgroundColor:
                      WidgetStatePropertyAll(cs.surfaceContainerHighest),
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  children: [
                    for (final entry in _displayMap.entries)
                      if (entry.value.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.only(top: 16, bottom: 8),
                          child: Text(
                            entry.key,
                            style: tt.labelLarge
                                ?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 6,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                          ),
                          itemCount: entry.value.length,
                          itemBuilder: (ctx, i) {
                            final e = entry.value[i];
                            final isSelected = _icon == e.key;
                            return GestureDetector(
                              onTap: () => setState(() => _icon = e.key),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? goalColor.withValues(alpha: 0.15)
                                      : cs.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(12),
                                  border: isSelected
                                      ? Border.all(color: goalColor, width: 2)
                                      : null,
                                ),
                                child: Icon(
                                  e.value,
                                  size: 22,
                                  color: isSelected
                                      ? goalColor
                                      : cs.onSurfaceVariant,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    const SizedBox(height: 20),
                    Text(
                      'Cor',
                      style: tt.labelLarge?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: AppColorPicker.colors.map((item) {
                        final color = _hex(item.$1);
                        final selected = item.$1 == _color;
                        return Tooltip(
                          message: item.$2,
                          child: GestureDetector(
                            onTap: () => setState(() => _color = item.$1),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: selected
                                    ? Border.all(color: cs.onSurface, width: 3)
                                    : Border.all(
                                        color: Colors.transparent,
                                        width: 3,
                                      ),
                              ),
                              child: selected
                                  ? const Icon(
                                      Icons.check_rounded,
                                      color: Colors.white,
                                      size: 18,
                                    )
                                  : null,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
