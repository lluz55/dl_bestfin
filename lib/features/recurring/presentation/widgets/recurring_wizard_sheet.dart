import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/features/recurring/domain/models/recurring_rule.dart';
import 'package:bestfin/features/recurring/presentation/widgets/frequency_selector.dart';

class RecurringWizardResult {
  final RecurringFrequency frequency;
  final DateTime startDate;
  final DateTime? endDate;
  final bool autoConfirm;

  const RecurringWizardResult({
    required this.frequency,
    required this.startDate,
    required this.endDate,
    required this.autoConfirm,
  });
}

class RecurringWizardSheet extends StatefulWidget {
  final RecurringFrequency initialFrequency;
  final DateTime initialStartDate;
  final DateTime? initialEndDate;
  final bool initialAutoConfirm;
  final bool isTransfer;

  const RecurringWizardSheet({
    super.key,
    required this.initialFrequency,
    required this.initialStartDate,
    this.initialEndDate,
    required this.initialAutoConfirm,
    required this.isTransfer,
  });

  @override
  State<RecurringWizardSheet> createState() => _RecurringWizardSheetState();
}

class _RecurringWizardSheetState extends State<RecurringWizardSheet> {
  late RecurringFrequency _frequency;
  late DateTime _startDate;
  DateTime? _endDate;
  late bool _autoConfirm;

  @override
  void initState() {
    super.initState();
    _frequency = widget.initialFrequency;
    _startDate = widget.initialStartDate;
    _endDate = widget.initialEndDate;
    _autoConfirm = widget.initialAutoConfirm;
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _startDate = picked);
    }
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now().add(const Duration(days: 365)),
      firstDate: _startDate,
      lastDate: DateTime(2100),
      helpText: 'Data de encerramento (opcional)',
    );
    if (picked != null) {
      setState(() => _endDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.textTheme;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 24,
        right: 24,
        top: 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Repetir Transação',
              style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Configure a recorrência para esta transação.',
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            Text(
              'Frequência',
              style: tt.labelLarge?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            FrequencySelector(
              selected: _frequency,
              onChanged: (freq) => setState(() => _frequency = freq),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _DateField(
                    label: 'Início',
                    date: _startDate,
                    icon: Icons.play_circle_outline_rounded,
                    onTap: _pickStartDate,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DateField(
                    label: 'Término (opcional)',
                    date: _endDate,
                    icon: Icons.stop_circle_outlined,
                    placeholder: 'Indefinido',
                    onTap: _pickEndDate,
                    onClear: _endDate != null
                        ? () => setState(() => _endDate = null)
                        : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: cs.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
              child: SwitchListTile(
                title: Text(
                  'Confirmar automaticamente',
                  style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  widget.isTransfer
                      ? 'Transferências recorrentes sempre exigem aprovação manual por segurança'
                      : 'Transações geradas já serão marcadas como confirmadas',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
                value: widget.isTransfer ? false : _autoConfirm,
                onChanged: widget.isTransfer
                    ? null
                    : (val) => setState(() => _autoConfirm = val),
                secondary: Icon(
                  Icons.auto_fix_high_rounded,
                  color: widget.isTransfer
                      ? cs.onSurfaceVariant.withValues(alpha: 0.5)
                      : (_autoConfirm ? cs.primary : cs.onSurfaceVariant),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton(
                onPressed: () {
                  Navigator.pop(
                    context,
                    RecurringWizardResult(
                      frequency: _frequency,
                      startDate: _startDate,
                      endDate: _endDate,
                      autoConfirm: widget.isTransfer ? false : _autoConfirm,
                    ),
                  );
                },
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Confirmar Recorrência',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: cs.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: tt.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontSize: 10,
                    ),
                  ),
                  Text(
                    date != null ? fmt.format(date!) : (placeholder ?? '—'),
                    style: tt.bodySmall?.copyWith(
                      color: date != null ? cs.onSurface : cs.onSurfaceVariant,
                      fontWeight: date != null
                          ? FontWeight.w600
                          : FontWeight.normal,
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
