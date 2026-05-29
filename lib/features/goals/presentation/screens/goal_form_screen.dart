import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/widgets/app_page_appbar.dart';
import 'package:bestfin/core/utils/icon_mapper.dart';
import 'package:bestfin/core/widgets/account_selector.dart';
import 'package:bestfin/features/goals/domain/models/goal.dart';
import 'package:bestfin/features/goals/presentation/providers/goals_provider.dart';
import 'package:bestfin/features/goals/presentation/widgets/monthly_simulator_widget.dart';

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
  final _targetController = TextEditingController();

  int _targetAmountInCents = 0;
  DateTime? _targetDate;
  String? _accountId;
  String _color = '#1E88E5';
  String _icon = 'flag';
  GoalType _type = GoalType.saving;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final g = widget.existingGoal;
    if (g != null) {
      _nameController.text = g.name;
      _descController.text = g.description ?? '';
      _targetAmountInCents = g.targetAmountInCents;
      _targetController.text = (g.targetAmountInCents / 100)
          .toStringAsFixed(2)
          .replaceAll('.', ',');
      _targetDate = g.targetDate;
      _accountId = g.accountId;
      _color = g.color ?? '#1E88E5';
      _icon = g.icon ?? 'flag';
      _type = g.type;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _targetController.dispose();
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
      appBar: AppPageAppBar(
        title: isEditing ? 'Editar Meta' : 'Nova Meta',
      ),
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
            TextFormField(
              controller: _targetController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Valor alvo (R\$) *',
                hintText: '0,00',
                prefixIcon: const Icon(Icons.attach_money_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onChanged: (val) {
                final clean = val.replaceAll('.', '').replaceAll(',', '.');
                final parsed = double.tryParse(clean) ?? 0;
                setState(() => _targetAmountInCents = (parsed * 100).round());
              },
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Informe o valor alvo' : null,
            ),
            const SizedBox(height: 14),

            // Prazo
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

            // Tipo de Meta
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

            // Conta vinculada
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

            // Simulador mensal (somente se tem prazo e valor)
            if (_targetAmountInCents > 0 && _targetDate != null) ...[
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

// Seletor de ícone e cor
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

  static const _icons = [
    'flag',
    'home',
    'car_rental',
    'flight',
    'school',
    'favorite',
    'beach_access',
    'computer',
    'smartphone',
    'shopping_bag',
    'restaurant',
    'fitness_center',
    'savings',
    'account_balance',
    'child_care',
    'medical_services',
    'pets',
    'celebration',
  ];

  static const _colors = [
    '#1E88E5',
    '#43A047',
    '#E53935',
    '#FB8C00',
    '#8E24AA',
    '#00ACC1',
    '#FFB300',
    '#6D4C41',
    '#546E7A',
    '#EC407A',
    '#26A69A',
    '#7CB342',
  ];

  @override
  void initState() {
    super.initState();
    _icon = widget.selectedIcon;
    _color = widget.selectedColor;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final goalColor = _parseColor(_color, cs.primary);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Ícone',
            style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _icons.map((icon) {
              final selected = icon == _icon;
              return GestureDetector(
                onTap: () => setState(() => _icon = icon),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: selected
                        ? goalColor.withValues(alpha: 0.2)
                        : cs.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(14),
                    border: selected
                        ? Border.all(color: goalColor, width: 2)
                        : null,
                  ),
                  child: Icon(
                    IconMapper.fromString(icon),
                    color: selected ? goalColor : cs.onSurfaceVariant,
                    size: 22,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          Text(
            'Cor',
            style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _colors.map((hex) {
              final color = _parseColor(hex, cs.primary);
              final selected = hex == _color;
              return GestureDetector(
                onTap: () => setState(() => _color = hex),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: selected
                        ? Border.all(color: cs.onSurface, width: 3)
                        : Border.all(color: Colors.transparent, width: 3),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: color.withValues(alpha: 0.5),
                              blurRadius: 8,
                            ),
                          ]
                        : null,
                  ),
                  child: selected
                      ? const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 18,
                        )
                      : null,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                widget.onSelected(_icon, _color);
                Navigator.pop(context);
              },
              style: FilledButton.styleFrom(
                backgroundColor: goalColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Confirmar',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Color _parseColor(String hex, Color fallback) {
    try {
      final h = hex.replaceAll('#', '');
      return Color(int.parse('FF$h', radix: 16));
    } catch (_) {
      return fallback;
    }
  }
}
