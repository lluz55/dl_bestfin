import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/utils/currency_formatter.dart';

class InstallmentWizardResult {
  final int installments;
  final int totalAmount;

  const InstallmentWizardResult({
    required this.installments,
    required this.totalAmount,
  });
}

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
  final TextEditingController _installmentsController = TextEditingController(
    text: '2',
  );
  final TextEditingController _interestController = TextEditingController();

  @override
  void dispose() {
    _installmentsController.dispose();
    _interestController.dispose();
    super.dispose();
  }

  double get _rate =>
      double.tryParse(_interestController.text.replaceAll(',', '.')) ?? 0.0;

  int get _calculatedTotal {
    final rate = _rate;
    if (rate <= 0) {
      return widget.totalAmountInCents;
    }
    final i = rate / 100.0;
    final double factor = math.pow(1 + i, _installments).toDouble();
    final double pmt = widget.totalAmountInCents * (i * factor) / (factor - 1);
    return (pmt * _installments).round();
  }

  int get _baseValue {
    final total = _calculatedTotal;
    return total ~/ _installments;
  }

  int get _remainder {
    final total = _calculatedTotal;
    return total % _installments;
  }

  int get _lastValue => _baseValue + _remainder;

  void _increment() {
    setState(() {
      _installments++;
      _installmentsController.text = _installments.toString();
    });
  }

  void _decrement() {
    if (_installments > 2) {
      setState(() {
        _installments--;
        _installmentsController.text = _installments.toString();
      });
    }
  }

  void _updateInstallmentsFromText(String val) {
    final parsed = int.tryParse(val);
    if (parsed != null && parsed >= 2) {
      setState(() {
        _installments = parsed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.textTheme;
    final calculatedTotal = _calculatedTotal;

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
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Nº de parcelas', style: tt.titleSmall),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          IconButton.filledTonal(
                            onPressed: _decrement,
                            icon: const Icon(Icons.remove),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: _installmentsController,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onChanged: _updateInstallmentsFromText,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filledTonal(
                            onPressed: _increment,
                            icon: const Icon(Icons.add),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Juros (% ao mês)', style: tt.titleSmall),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _interestController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          hintText: '0,00',
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Slider(
              value: math.min(12, _installments).toDouble(),
              min: 2,
              max: 12,
              divisions: 10,
              label: '$_installments',
              onChanged: (value) {
                setState(() {
                  _installments = value.round();
                  _installmentsController.text = _installments.toString();
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
                        style: context.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
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
                        style: context.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
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
                        CurrencyFormatter.formatCents(calculatedTotal),
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
              child: FilledButton(
                onPressed: () {
                  Navigator.pop(
                    context,
                    InstallmentWizardResult(
                      installments: _installments,
                      totalAmount: calculatedTotal,
                    ),
                  );
                },
                child: const Text('Confirmar Parcelamento'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
