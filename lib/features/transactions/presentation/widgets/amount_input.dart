import 'package:flutter/material.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/utils/currency_formatter.dart';
import 'package:bestfin/core/widgets/numeric_keypad.dart';

class AmountInput extends StatelessWidget {
  final int amountInCents;
  final ValueChanged<int> onChanged;
  final String label;
  final Color? color;

  const AmountInput({
    super.key,
    required this.amountInCents,
    required this.onChanged,
    this.label = 'Valor',
    this.color,
  });

  void _showKeypad(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return _KeypadSheet(
          initialAmountInCents: amountInCents,
          onChanged: onChanged,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.textTheme;

    final displayColor = color ?? cs.primary;

    return GestureDetector(
      onTap: () => _showKeypad(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: displayColor.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: displayColor.withValues(alpha: 0.15),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              label,
              style: tt.labelLarge?.copyWith(
                color: displayColor.withValues(alpha: 0.7),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              CurrencyFormatter.formatCents(amountInCents),
              style: tt.displayLarge?.copyWith(
                color: displayColor,
                fontWeight: FontWeight.w900,
                fontSize: amountInCents.toString().length > 7 ? 36 : 44,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.edit_outlined,
                  size: 14,
                  color: displayColor.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 4),
                Text(
                  'Toque para editar',
                  style: tt.bodySmall?.copyWith(
                    color: displayColor.withValues(alpha: 0.5),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _KeypadSheet extends StatefulWidget {
  final int initialAmountInCents;
  final ValueChanged<int> onChanged;

  const _KeypadSheet({
    required this.initialAmountInCents,
    required this.onChanged,
  });

  @override
  State<_KeypadSheet> createState() => _KeypadSheetState();
}

class _KeypadSheetState extends State<_KeypadSheet> {
  late String _digits;

  @override
  void initState() {
    super.initState();
    // Inicia com os dígitos atuais (em centavos)
    _digits = widget.initialAmountInCents == 0
        ? ''
        : widget.initialAmountInCents.toString();
  }

  void _handleKeyPress(String key) {
    if (key == ',')
      return; // Teclado opera de forma automática de centavos para reais

    if (_digits == '0' && key == '0') return;

    setState(() {
      _digits += key;
    });

    _notifyChange();
  }

  void _handleDelete() {
    if (_digits.isEmpty) return;

    setState(() {
      _digits = _digits.substring(0, _digits.length - 1);
    });

    _notifyChange();
  }

  void _notifyChange() {
    final cents = int.tryParse(_digits) ?? 0;
    widget.onChanged(cents);
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.textTheme;

    final int currentCents = int.tryParse(_digits) ?? 0;

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
                onConfirmPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
