import 'package:flutter/material.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/utils/adaptive_modal.dart';
import 'package:bestfin/core/utils/currency_formatter.dart';
import 'package:bestfin/core/widgets/numeric_keypad.dart';

class AmountInput extends StatefulWidget {
  final int amountInCents;
  final ValueChanged<int> onChanged;
  final String label;
  final Color? color;
  final bool autoOpen;
  final VoidCallback? onConfirmed;
  final FocusNode? focusNode;

  const AmountInput({
    super.key,
    required this.amountInCents,
    required this.onChanged,
    this.label = 'Valor',
    this.color,
    this.autoOpen = false,
    this.onConfirmed,
    this.focusNode,
  });

  @override
  State<AmountInput> createState() => _AmountInputState();
}

class _AmountInputState extends State<AmountInput> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChange);
    if (widget.autoOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showKeypad(context);
      });
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _focusNode.hasFocus) {
          _showKeypad(context);
          _focusNode.unfocus();
        }
      });
    }
  }

  void _showKeypad(BuildContext context) {
    showAdaptiveModal(
      context: context,
      builder: (context) {
        return AmountKeypadSheet(
          initialAmountInCents: widget.amountInCents,
          onChanged: widget.onChanged,
          onConfirmed: widget.onConfirmed,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.textTheme;

    final displayColor = widget.color ?? cs.primary;

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
              widget.label,
              style: tt.labelLarge?.copyWith(
                color: displayColor.withValues(alpha: 0.7),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              CurrencyFormatter.formatCents(
                widget.amountInCents,
                ignoreVisibility: true,
              ),
              style: tt.displayLarge?.copyWith(
                color: displayColor,
                fontWeight: FontWeight.w900,
                fontSize: widget.amountInCents.toString().length > 7 ? 36 : 44,
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

/// Teclado numérico modal compartilhado por todos os fluxos de digitação de
/// valor (formulário, lançamento rápido e inserção em massa). Ao confirmar,
/// fecha com o valor em centavos como resultado do `Navigator.pop`, para
/// chamadores que preferem receber o valor só na confirmação.
class AmountKeypadSheet extends StatefulWidget {
  final int initialAmountInCents;

  /// Preview ao vivo enquanto digita. Quando nulo, o valor só chega ao
  /// chamador via resultado do `Navigator.pop` ao confirmar.
  final ValueChanged<int>? onChanged;
  final VoidCallback? onConfirmed;

  const AmountKeypadSheet({
    super.key,
    required this.initialAmountInCents,
    this.onChanged,
    this.onConfirmed,
  });

  @override
  State<AmountKeypadSheet> createState() => _AmountKeypadSheetState();
}

class _AmountKeypadSheetState extends State<AmountKeypadSheet> {
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

    // Evita zeros à esquerda redundantes ou iniciais
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

    setState(() {
      _digits = _digits.substring(0, _digits.length - 1);
    });

    _notifyChange();
  }

  void _notifyChange() {
    final cents = int.tryParse(_digits) ?? 0;
    widget.onChanged?.call(cents);
  }

  void _handleConfirm() {
    final cents = int.tryParse(_digits) ?? 0;
    widget.onConfirmed?.call();
    Navigator.of(context).pop(cents);
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
                CurrencyFormatter.formatCents(
                  currentCents,
                  ignoreVisibility: true,
                ),
                style: tt.displayMedium?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 24),
              NumericKeypad(
                onKeyPressed: _handleKeyPress,
                onDeletePressed: _handleDelete,
                onConfirmPressed: _handleConfirm,
                autofocus: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
