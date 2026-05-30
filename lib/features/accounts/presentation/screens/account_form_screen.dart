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
import 'package:bestfin/core/utils/icon_mapper.dart';
import 'package:bestfin/features/transactions/presentation/widgets/amount_input.dart';

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
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
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

  void _showPersonalizarSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PersonalizarSheet(
        selectedIconCodePoint: _iconCodePoint,
        selectedColorHex: _colorHex,
        onConfirm: (iconCodePoint, colorHex) => setState(() {
          _iconCodePoint = iconCodePoint;
          _colorHex = colorHex;
        }),
      ),
    );
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
                    // Personalizar (ícone + cor combinados)
                    _PersonalizarButton(
                      iconCodePoint: _iconCodePoint,
                      colorHex: _colorHex,
                      onTap: _showPersonalizarSheet,
                    ),
                    const SizedBox(height: 16),
                    // Currency input for initial balance (only visible during creation mode!)
                    if (!_isEditing) ...[
                      AmountInput(
                        amountInCents: _initialBalanceCents,
                        label: 'Saldo Inicial',
                        color: theme.colorScheme.primary,
                        onChanged: (val) =>
                            setState(() => _initialBalanceCents = val),
                      ),
                      const SizedBox(height: 24),
                    ],
                    const SizedBox(height: 32),
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

// ── Personalizar button ───────────────────────────────────────────────────────

class _PersonalizarButton extends StatelessWidget {
  final String iconCodePoint;
  final String colorHex;
  final VoidCallback onTap;

  const _PersonalizarButton({
    required this.iconCodePoint,
    required this.colorHex,
    required this.onTap,
  });

  static Color _hex(String hex) {
    final h = hex.replaceAll('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final color = _hex(colorHex);
    final iconData = IconMapper.fromCodePoint(int.parse(iconCodePoint));

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(iconData, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Personalizar',
                style: tt.bodyMedium?.copyWith(color: cs.onSurface),
              ),
            ),
            Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

// ── Personalizar sheet (ícone + cor) ─────────────────────────────────────────

class _PersonalizarSheet extends StatefulWidget {
  final String selectedIconCodePoint;
  final String selectedColorHex;
  final void Function(String iconCodePoint, String colorHex) onConfirm;

  const _PersonalizarSheet({
    required this.selectedIconCodePoint,
    required this.selectedColorHex,
    required this.onConfirm,
  });

  @override
  State<_PersonalizarSheet> createState() => _PersonalizarSheetState();
}

class _PersonalizarSheetState extends State<_PersonalizarSheet> {
  late String _iconCodePoint;
  late String _color;

  @override
  void initState() {
    super.initState();
    _iconCodePoint = widget.selectedIconCodePoint;
    _color = widget.selectedColorHex;
  }

  static Color _hex(String hex) {
    final h = hex.replaceAll('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final selectedColor = _hex(_color);
    final selectedIcon = IconMapper.fromCodePoint(int.parse(_iconCodePoint));

    return DraggableScrollableSheet(
      initialChildSize: 0.8,
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
                    color: cs.onSurfaceVariant.withValues(alpha: 0.3),
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
                        color: selectedColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: selectedColor, width: 2),
                      ),
                      child: Icon(selectedIcon, color: selectedColor, size: 26),
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
                        widget.onConfirm(_iconCodePoint, _color);
                        Navigator.pop(ctx);
                      },
                      child: const Text('Confirmar'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  children: [
                    Text(
                      'Ícone',
                      style: tt.labelLarge?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: 12),
                    for (final entry in AppIconPicker.categorizedIcons.entries)
                      if (entry.value.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 8),
                          child: Text(
                            entry.key,
                            style: tt.labelMedium
                                ?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 5,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                          ),
                          itemCount: entry.value.length,
                          itemBuilder: (ctx, i) {
                            final item = entry.value[i];
                            final code = item.$1.codePoint.toString();
                            final isSelected = code == _iconCodePoint;
                            return GestureDetector(
                              onTap: () => setState(() => _iconCodePoint = code),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? selectedColor.withValues(alpha: 0.15)
                                      : cs.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(14),
                                  border: isSelected
                                      ? Border.all(
                                          color: selectedColor,
                                          width: 2,
                                        )
                                      : null,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      item.$1,
                                      size: 26,
                                      color: isSelected
                                          ? selectedColor
                                          : cs.onSurfaceVariant,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      item.$2,
                                      style: tt.labelSmall?.copyWith(
                                        fontSize: 10,
                                        color: isSelected
                                            ? selectedColor
                                            : cs.onSurfaceVariant,
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                      ],
                    const SizedBox(height: 16),
                    Text(
                      'Cor',
                      style: tt.labelLarge?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: AppColorPicker.colors.map((item) {
                        final isSelected =
                            item.$1.toLowerCase() == _color.toLowerCase();
                        final color = AppColorPicker.hexToColor(item.$1);
                        return Tooltip(
                          message: item.$2,
                          child: InkWell(
                            onTap: () => setState(() => _color = item.$1),
                            customBorder: const CircleBorder(),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected
                                      ? cs.outline
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: isSelected
                                  ? const Icon(
                                      Icons.check,
                                      color: Colors.white,
                                      size: 20,
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
