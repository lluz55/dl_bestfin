import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestfin/core/constants/account_types.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/widgets/app_page_appbar.dart';
import 'package:bestfin/core/widgets/color_picker.dart';
import 'package:bestfin/core/widgets/icon_picker.dart';
import 'package:bestfin/features/accounts/domain/models/account.dart';
import 'package:bestfin/features/accounts/presentation/providers/accounts_provider.dart';
import 'package:bestfin/features/accounts/presentation/widgets/account_card.dart';

class AccountFormScreen extends ConsumerStatefulWidget {
  const AccountFormScreen({super.key, this.accountToEdit});

  final Account? accountToEdit;

  @override
  ConsumerState<AccountFormScreen> createState() => _AccountFormScreenState();
}

class _AccountFormScreenState extends ConsumerState<AccountFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late String _name;
  late AccountType _type;
  late String _iconCodePoint;
  late String _colorHex;
  late int _initialBalanceCents;

  final _nameController = TextEditingController();
  final _balanceController = TextEditingController();

  bool get _isEditing => widget.accountToEdit != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final acc = widget.accountToEdit!;
      _name = acc.name;
      _type = acc.type;
      _iconCodePoint = acc.icon;
      _colorHex = acc.color;
      _initialBalanceCents = acc.balance;
      _nameController.text = _name;
    } else {
      _name = '';
      _type = AccountType.checking;
      _iconCodePoint = AccountType.checking.defaultIcon.codePoint.toString();
      _colorHex = AccountType.checking.defaultColorHex;
      _initialBalanceCents = 0;
      _balanceController.text = '0,00';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  void _onTypeChanged(AccountType? newType) {
    if (newType == null) return;
    setState(() {
      _type = newType;
      // Also update icon and color to default if they weren't customized
      if (!_isEditing) {
        _iconCodePoint = newType.defaultIcon.codePoint.toString();
        _colorHex = newType.defaultColorHex;
      }
    });
  }

  void _showIconPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AppIconPicker(
        selectedIconCodePoint: _iconCodePoint,
        onIconSelected: (icon) {
          setState(() {
            _iconCodePoint = icon.codePoint.toString();
          });
        },
      ),
    );
  }

  void _onBalanceChanged(String value) {
    if (value.isEmpty) return;

    // Formatting currency in real time (e.g. 10.50 -> 10,50)
    final clean = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.isEmpty) return;

    final cents = int.parse(clean);
    final double amount = cents / 100.0;
    final formatted = amount.toStringAsFixed(2).replaceAll('.', ',');

    _balanceController.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );

    setState(() {
      _initialBalanceCents = cents;
    });
  }

  Future<void> _saveForm() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      if (_isEditing) {
        final updateUseCase = ref.read(updateAccountProvider);
        await updateUseCase(
          id: widget.accountToEdit!.id,
          name: _nameController.text,
          type: _type.name,
          icon: _iconCodePoint,
          color: _colorHex,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Conta atualizada com sucesso.')),
          );
        }
      } else {
        final createUseCase = ref.read(createAccountProvider);
        await createUseCase(
          name: _nameController.text,
          type: _type.name,
          icon: _iconCodePoint,
          color: _colorHex,
          initialBalance: _initialBalanceCents,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Conta criada com sucesso.')),
          );
        }
      }

      // Invalidate accounts provider so it loads fresh data
      ref.invalidate(accountsProvider);

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao salvar conta: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    // Local live preview account model
    final previewAccount = Account(
      id: widget.accountToEdit?.id ?? '',
      name: _name.isEmpty ? 'Nome da Conta' : _name,
      type: _type,
      icon: _iconCodePoint,
      color: _colorHex,
      isActive: widget.accountToEdit?.isActive ?? true,
      balance: _isEditing
          ? widget.accountToEdit!.balance
          : _initialBalanceCents,
    );

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppPageAppBar(
        title: _isEditing ? 'Editar Conta' : 'Nova Conta',
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _saveForm,
            tooltip: 'Salvar',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 12),
            // Live Preview of Account Card at the top
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: AccountCard(
                account: previewAccount,
                onTap: () {}, // Noop in preview
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Nome da Conta',
                        hintText: 'Ex: Conta Principal',
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainerHigh,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Por favor, insira o nome da conta.';
                        }
                        return null;
                      },
                      onChanged: (val) {
                        setState(() {
                          _name = val;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<AccountType>(
                      value: _type,
                      decoration: InputDecoration(
                        labelText: 'Tipo de Conta',
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainerHigh,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      items: AccountType.values.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(type.label),
                        );
                      }).toList(),
                      onChanged: _onTypeChanged,
                    ),
                    const SizedBox(height: 16),
                    // Icon Picker Trigger
                    InkWell(
                      onTap: _showIconPicker,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Ícone da Conta',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            Row(
                              children: [
                                Icon(
                                  IconData(
                                    int.parse(_iconCodePoint),
                                    fontFamily: 'MaterialIcons',
                                  ),
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.chevron_right,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Currency input for initial balance (only visible during creation mode!)
                    if (!_isEditing) ...[
                      TextFormField(
                        controller: _balanceController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Saldo Inicial (R\$)',
                          filled: true,
                          fillColor: theme.colorScheme.surfaceContainerHigh,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          prefixText: 'R\$ ',
                        ),
                        onChanged: _onBalanceChanged,
                      ),
                      const SizedBox(height: 24),
                    ],
                    // Color Picker swatch selector
                    AppColorPicker(
                      selectedColorHex: _colorHex,
                      previewIcon: IconData(
                        int.parse(_iconCodePoint),
                        fontFamily: 'MaterialIcons',
                      ),
                      onColorSelected: (color) {
                        setState(() {
                          _colorHex = color;
                        });
                      },
                    ),
                    const SizedBox(height: 48),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: theme.colorScheme.onPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: _saveForm,
                        child: Text(
                          _isEditing ? 'Salvar Alterações' : 'Criar Conta',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onPrimary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
