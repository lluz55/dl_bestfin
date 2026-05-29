import 'package:flutter/material.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/utils/currency_formatter.dart';

class InstallmentWizardSheet extends StatefulWidget {
  final int totalAmountInCents;
  final String description;

  const InstallmentWizardSheet({
    super.key,
    required this.totalAmountInCents,
    required this.description,
  });

  @override
  State<InstallmentWizardSheet> createState() => _InstallmentWizardSheetState();
}

class _InstallmentWizardSheetState extends State<InstallmentWizardSheet> {
  int _installments = 2;

  int get _baseValue => widget.totalAmountInCents ~/ _installments;
  int get _remainder => widget.totalAmountInCents % _installments;
  int get _lastValue => _baseValue + _remainder;

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
            'Parcelar Compra',
            style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            widget.description,
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Nº de parcelas', style: tt.titleMedium),
              Text(
                '$_installments x',
                style: tt.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: cs.primary,
                ),
              ),
            ],
          ),
          Slider(
            value: _installments.toDouble(),
            min: 2,
            max: 12,
            divisions: 10,
            label: '$_installments',
            onChanged: (value) {
              setState(() {
                _installments = value.round();
              });
            },
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Parcelas 1 a ${_installments - 1}:'),
                    Text(
                      CurrencyFormatter.formatCents(_baseValue),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Última parcela:'),
                    Text(
                      CurrencyFormatter.formatCents(_lastValue),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total:',
                      style: tt.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      CurrencyFormatter.formatCents(widget.totalAmountInCents),
                      style: tt.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton(
              onPressed: () => Navigator.pop(context, _installments),
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Confirmar Parcelamento',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
