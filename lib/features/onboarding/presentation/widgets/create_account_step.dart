import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestfin/core/constants/account_types.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/widgets/color_picker.dart';
import 'package:bestfin/features/accounts/presentation/providers/accounts_provider.dart';
import 'package:bestfin/features/transactions/presentation/widgets/amount_input.dart';

class CreateAccountStep extends ConsumerStatefulWidget {
  const CreateAccountStep({super.key, required this.onNext});

  final VoidCallback onNext;

  @override
  ConsumerState<CreateAccountStep> createState() => _CreateAccountStepState();
}

class _CreateAccountStepState extends ConsumerState<CreateAccountStep> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController(text: 'Conta Principal');
  AccountType _selectedType = AccountType.checking;
  late String _selectedColorHex;
  int _balanceCents = 0;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedColorHex = _selectedType.defaultColorHex;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final createUseCase = ref.read(createAccountProvider);
    await createUseCase(
      name: _nameController.text.trim(),
      type: _selectedType.name,
      icon: _selectedType.defaultIcon.codePoint.toString(),
      color: _selectedColorHex,
      initialBalance: _balanceCents,
    );

    ref.invalidate(accountsProvider);
    if (mounted) widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text(
            'Sua primeira conta',
            style: tt.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Adicione a conta que você usa no dia a dia. Você pode adicionar mais depois.',
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 32),
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Nome da conta',
                    hintText: 'Ex: Nubank, Itaú, Carteira',
                    prefixIcon: const Icon(Icons.account_balance_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 20),
                Text(
                  'Tipo de conta',
                  style: tt.labelLarge?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: AccountType.values.map((type) {
                    final selected = _selectedType == type;
                    return FilterChip(
                      label: Text(type.label),
                      selected: selected,
                      onSelected: (_) => setState(() {
                        _selectedType = type;
                        _selectedColorHex = type.defaultColorHex;
                      }),
                      avatar: Icon(type.defaultIcon, size: 16),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                AmountInput(
                  amountInCents: _balanceCents,
                  label: 'Saldo atual',
                  color: cs.primary,
                  onChanged: (val) => setState(() => _balanceCents = val),
                ),
                const SizedBox(height: 20),
                AppColorPicker(
                  selectedColorHex: _selectedColorHex,
                  onColorSelected: (color) {
                    setState(() {
                      _selectedColorHex = color;
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: _saving
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                : Text(
                    'Continuar',
                    style: tt.titleMedium?.copyWith(
                      color: cs.onPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: widget.onNext,
            style: TextButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            child: Text(
              'Pular por enquanto',
              style: tt.labelLarge?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
