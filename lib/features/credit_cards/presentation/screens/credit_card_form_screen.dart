import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/widgets/app_page_appbar.dart';
import 'package:bestfin/core/widgets/color_picker.dart';
import 'package:bestfin/core/widgets/account_selector.dart';
import 'package:bestfin/features/accounts/domain/models/account.dart';
import 'package:bestfin/features/credit_cards/domain/models/credit_card.dart';
import 'package:bestfin/features/credit_cards/presentation/providers/credit_cards_provider.dart';
import 'package:go_router/go_router.dart';

class CreditCardFormScreen extends ConsumerStatefulWidget {
  final CreditCardModel? card;

  const CreditCardFormScreen({super.key, this.card});

  @override
  ConsumerState<CreditCardFormScreen> createState() =>
      _CreditCardFormScreenState();
}

enum ClosingDayMode { fixed, dynamicOffset }

class _CreditCardFormScreenState extends ConsumerState<CreditCardFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _limitController;
  ClosingDayMode _closingMode = ClosingDayMode.fixed;
  int _closingDay = 5;
  int _closingOffset = 7;
  int _dueDay = 15;
  String _selectedColorHex = '#2196F3';
  String? _selectedAccountId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final card = widget.card;
    if (card != null) {
      _nameController = TextEditingController(text: card.name);
      final double limitValue = card.limitAmount / 100.0;
      _limitController = TextEditingController(
        text: limitValue.toStringAsFixed(2).replaceAll('.', ','),
      );
      if (card.closingDay <= 0) {
        _closingMode = ClosingDayMode.dynamicOffset;
        _closingOffset = -card.closingDay;
        _closingDay = 5;
      } else {
        _closingMode = ClosingDayMode.fixed;
        _closingDay = card.closingDay;
        _closingOffset = 7;
      }
      _dueDay = card.dueDay;
      _selectedColorHex = card.color ?? '#2196F3';
      _selectedAccountId = card.accountId;
    } else {
      _nameController = TextEditingController();
      _limitController = TextEditingController();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _limitController.dispose();
    super.dispose();
  }

  Future<void> _saveForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione uma conta para vincular ao cartão')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final name = _nameController.text.trim();
    final limitStr = _limitController.text
        .replaceAll('.', '')
        .replaceAll(',', '.')
        .trim();
    final double limitDouble = double.tryParse(limitStr) ?? 0.0;
    final int limitCents = (limitDouble * 100).round();

    final closingDayValue = _closingMode == ClosingDayMode.fixed
        ? _closingDay
        : -_closingOffset;

    try {
      final repository = ref.read(creditCardRepositoryProvider);

      if (widget.card != null) {
        await repository.updateCreditCard(
          id: widget.card!.id,
          name: name,
          limitAmount: limitCents,
          closingDay: closingDayValue,
          dueDay: _dueDay,
          accountId: _selectedAccountId,
          color: _selectedColorHex,
        );
      } else {
        await repository.createCreditCard(
          name: name,
          limitAmount: limitCents,
          closingDay: closingDayValue,
          dueDay: _dueDay,
          accountId: _selectedAccountId!,
          color: _selectedColorHex,
        );
      }

      if (mounted) {
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao salvar cartão: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.textTheme;
    final isEditing = widget.card != null;

    final List<int> days = List.generate(28, (i) => i + 1);

    Widget buildAccountField() {
      return AccountSelector(
        selectedAccountId: _selectedAccountId,
        onAccountSelected: (Account? acc) {
          setState(() => _selectedAccountId = acc?.id);
        },
        hint: 'Selecione a conta vinculada',
      );
    }

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppPageAppBar(
        title: isEditing ? 'Editar Cartão' : 'Novo Cartão',
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20.0),
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Nome do Cartão',
                      hintText: 'Ex: Inter Black, Nubank Platinum',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Por favor, insira o nome do cartão';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: _limitController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Limite do Cartão (R\$)',
                      hintText: '0,00',
                      prefixText: 'R\$ ',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Por favor, insira o limite do cartão';
                      }
                      final clean = val
                          .replaceAll('.', '')
                          .replaceAll(',', '.')
                          .trim();
                      if (double.tryParse(clean) == null ||
                          double.parse(clean) <= 0) {
                        return 'Por favor, insira um valor válido maior que zero';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),
                  buildAccountField(),
                  const SizedBox(height: 18),
                  Text(
                    'Configuração do Fechamento',
                    style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<ClosingDayMode>(
                    segments: const [
                      ButtonSegment<ClosingDayMode>(
                        value: ClosingDayMode.fixed,
                        label: Text('Dia Fixo'),
                        icon: Icon(Icons.calendar_today_rounded),
                      ),
                      ButtonSegment<ClosingDayMode>(
                        value: ClosingDayMode.dynamicOffset,
                        label: Text('Antes do Vencimento'),
                        icon: Icon(Icons.history_rounded),
                      ),
                    ],
                    selected: {_closingMode},
                    onSelectionChanged: (Set<ClosingDayMode> newSelection) {
                      setState(() {
                        _closingMode = newSelection.first;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _closingMode == ClosingDayMode.fixed
                            ? DropdownButtonFormField<int>(
                                value: _closingDay,
                                decoration: InputDecoration(
                                  labelText: 'Dia de Fechamento',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                items: days.map((day) {
                                  return DropdownMenuItem<int>(
                                    value: day,
                                    child: Text(day.toString().padLeft(2, '0')),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _closingDay = val);
                                  }
                                },
                              )
                            : DropdownButtonFormField<int>(
                                value: _closingOffset,
                                decoration: InputDecoration(
                                  labelText: 'Dias Antes',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                items: List.generate(20, (i) => i + 1).map((offset) {
                                  return DropdownMenuItem<int>(
                                    value: offset,
                                    child: Text('$offset ${offset == 1 ? 'dia' : 'dias'}'),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _closingOffset = val);
                                  }
                                },
                              ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: _dueDay,
                          decoration: InputDecoration(
                            labelText: 'Dia de Vencimento',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          items: days.map((day) {
                            return DropdownMenuItem<int>(
                              value: day,
                              child: Text(day.toString().padLeft(2, '0')),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _dueDay = val);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  AppColorPicker(
                    selectedColorHex: _selectedColorHex,
                    onColorSelected: (hex) {
                      setState(() => _selectedColorHex = hex);
                    },
                    previewIcon: Icons.credit_card_rounded,
                  ),
                  const SizedBox(height: 36),
                  ElevatedButton(
                    onPressed: _saveForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cs.primary,
                      foregroundColor: cs.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      isEditing ? 'SALVAR ALTERAÇÕES' : 'CADASTRAR CARTÃO',
                      style: tt.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
