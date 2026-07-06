import 'package:flutter/material.dart';
import 'package:bestfin/core/widgets/app_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/widgets/app_page_appbar.dart';
import 'package:bestfin/core/providers/default_account_provider.dart';
import 'package:bestfin/features/accounts/presentation/providers/accounts_provider.dart';
import 'package:bestfin/features/financing/presentation/providers/financing_provider.dart';
import 'package:bestfin/features/transactions/presentation/widgets/amount_input.dart';

class FinancingFormScreen extends ConsumerStatefulWidget {
  final VoidCallback? onClose;

  const FinancingFormScreen({super.key, this.onClose});

  @override
  ConsumerState<FinancingFormScreen> createState() =>
      _FinancingFormScreenState();
}

class _FinancingFormScreenState extends ConsumerState<FinancingFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _installmentsController = TextEditingController();
  final _rateController = TextEditingController();

  int _totalAmountCents = 0;
  int _totalInstallments = 12;
  double _interestRate = 1.0; // % per month
  String _amortizationSystem = 'sac'; // sac, price
  String? _selectedAccountId;
  DateTime _firstDueDate = DateTime.now().add(const Duration(days: 30));

  final List<Map<String, String>> _systems = [
    {
      'value': 'sac',
      'label': 'SAC (Amortização Constante, Parcelas Decrescentes)',
    },
    {'value': 'price', 'label': 'Price (Parcelas Fixas)'},
  ];

  @override
  void initState() {
    super.initState();
    _totalAmountCents = 0;
    _installmentsController.text = '12';
    _rateController.text = '1,00';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _selectedAccountId != null) return;
      final accounts = ref.read(activeAccountsProvider);
      if (accounts.isEmpty) return;
      final defaultId = ref.read(defaultAccountIdProvider);
      setState(() {
        if (accounts.length == 1) {
          _selectedAccountId = accounts.first.id;
        } else if (defaultId != null &&
            accounts.any((a) => a.id == defaultId)) {
          _selectedAccountId = defaultId;
        }
      });
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _installmentsController.dispose();
    _rateController.dispose();
    super.dispose();
  }

  void _onRateChanged(String value) {
    if (value.isEmpty) return;
    final clean = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.isEmpty) return;
    final valueInt = int.parse(clean);
    final double rate = valueInt / 100.0;
    final formatted = rate.toStringAsFixed(2).replaceAll('.', ',');

    _rateController.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );

    setState(() {
      _interestRate = rate;
    });
  }

  Future<void> _selectFirstDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _firstDueDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
    );
    if (picked != null) {
      setState(() {
        _firstDueDate = picked;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_totalAmountCents <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe o valor do financiamento')),
      );
      return;
    }

    final repo = ref.read(financingRepositoryProvider);
    final name = _nameController.text.trim();

    try {
      await repo.createFinancing(
        name: name,
        totalAmount: _totalAmountCents,
        interestRate: _interestRate,
        totalInstallments: _totalInstallments,
        amortizationSystem: _amortizationSystem,
        firstDueDate: _firstDueDate,
        linkedAccountId: _selectedAccountId,
      );

      ref.invalidate(financingsStreamProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Contrato de financiamento cadastrado com sucesso!',
            ),
            backgroundColor: context.colorScheme.primary,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar contrato: $e'),
            backgroundColor: context.colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final activeAccounts = ref.watch(activeAccountsProvider);
    final isInModal = widget.onClose != null;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: isInModal
          ? null
          : const AppPageAppBar(title: 'Novo Financiamento'),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // Name
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Nome do Financiamento',
                hintText: 'Ex: Apartamento, Carro Novo',
                prefixIcon: const Icon(Icons.title_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Informe o nome do contrato';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Amortization System
            DropdownButtonFormField<String>(
              value: _amortizationSystem,
              decoration: InputDecoration(
                labelText: 'Sistema de Amortização',
                prefixIcon: const Icon(Icons.calculate_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              items: _systems.map((s) {
                return DropdownMenuItem<String>(
                  value: s['value'],
                  child: Text(
                    s['label']!,
                    style: const TextStyle(fontSize: 13),
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _amortizationSystem = val;
                  });
                }
              },
            ),
            const SizedBox(height: 16),

            // Total Amount Financed
            AmountInput(
              amountInCents: _totalAmountCents,
              label: 'Valor Total Financiado',
              color: context.colorScheme.primary,
              onChanged: (val) => setState(() => _totalAmountCents = val),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                // Installments (months)
                Expanded(
                  child: TextFormField(
                    controller: _installmentsController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Parcelas (Meses)',
                      prefixIcon: const Icon(Icons.calendar_today_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onChanged: (val) {
                      final parsed = int.tryParse(val) ?? 12;
                      setState(() {
                        _totalInstallments = parsed;
                      });
                    },
                    validator: (val) {
                      if (_totalInstallments <= 0) {
                        return 'Mínimo 1 parcela';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                // Interest Rate
                Expanded(
                  child: TextFormField(
                    controller: _rateController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Taxa (% a.m.)',
                      suffixText: '%',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onChanged: _onRateChanged,
                    validator: (val) {
                      if (_interestRate < 0) {
                        return 'Informe a taxa';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Linked Account
            DropdownButtonFormField<String>(
              value: _selectedAccountId,
              decoration: InputDecoration(
                labelText: 'Conta Bancária Vinculada',
                prefixIcon: const Icon(Icons.account_balance_wallet_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('Nenhuma conta vinculada'),
                ),
                ...activeAccounts.map((acc) {
                  return DropdownMenuItem<String>(
                    value: acc.id,
                    child: Text(acc.name),
                  );
                }),
              ],
              onChanged: (val) {
                setState(() {
                  _selectedAccountId = val;
                });
              },
            ),
            const SizedBox(height: 16),

            // First Payment Date Selection
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: cs.outlineVariant, width: 1),
              ),
              leading: const Icon(Icons.event_note_rounded),
              title: const Text('Primeiro Pagamento'),
              subtitle: Text(
                '${_firstDueDate.day.toString().padLeft(2, '0')}/${_firstDueDate.month.toString().padLeft(2, '0')}/${_firstDueDate.year}',
              ),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
              onTap: _selectFirstDueDate,
            ),
            const SizedBox(height: 32),

            // Save Button
            AppButton(
              label: 'Cadastrar Contrato',
              expanded: true,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}
