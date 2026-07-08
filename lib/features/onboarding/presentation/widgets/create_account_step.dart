import 'package:flutter/material.dart';
import 'package:bestfin/core/widgets/app_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestfin/core/constants/account_types.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/widgets/color_picker.dart';
import 'package:bestfin/features/onboarding/presentation/providers/onboarding_provider.dart';
import 'package:bestfin/features/transactions/presentation/widgets/amount_input.dart';

class CreateAccountStep extends ConsumerStatefulWidget {
  const CreateAccountStep({super.key, required this.onNext});

  final VoidCallback onNext;

  @override
  ConsumerState<CreateAccountStep> createState() => _CreateAccountStepState();
}

class _CreateAccountStepState extends ConsumerState<CreateAccountStep> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  AccountType _selectedType = AccountType.checking;
  late String _selectedColorHex;
  bool _colorCustomized = false;
  int _balanceCents = 0;

  @override
  void initState() {
    super.initState();
    // Restauração síncrona do rascunho — o usuário não perde nada ao voltar
    // um step (o PageView descarta a página) nem ao sair do app no meio.
    final draft = ref.read(onboardingAccountDraftProvider);
    if (draft != null) {
      _nameController.text = draft.name;
      _selectedType = AccountType.fromString(draft.type);
      _colorCustomized = draft.colorCustomized;
      _selectedColorHex = draft.colorHex.isNotEmpty
          ? draft.colorHex
          : _selectedType.defaultColorHex;
      _balanceCents = draft.balanceCents;
    } else {
      _selectedColorHex = _selectedType.defaultColorHex;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _saveDraft() {
    ref
        .read(onboardingAccountDraftProvider.notifier)
        .set(
          OnboardingAccountDraft(
            name: _nameController.text,
            type: _selectedType.name,
            colorHex: _selectedColorHex,
            colorCustomized: _colorCustomized,
            balanceCents: _balanceCents,
          ),
        );
  }

  /// Apenas valida e guarda o rascunho — a conta é criada de fato quando o
  /// onboarding é finalizado (OnboardingScreen._finish).
  void _save() {
    if (!_formKey.currentState!.validate()) return;
    _saveDraft();
    widget.onNext();
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
                  onChanged: (_) => _saveDraft(),
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
                      onSelected: (_) {
                        setState(() {
                          _selectedType = type;
                          if (!_colorCustomized) {
                            _selectedColorHex = type.defaultColorHex;
                          }
                        });
                        _saveDraft();
                      },
                      avatar: Icon(type.defaultIcon, size: 16),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                AmountInput(
                  amountInCents: _balanceCents,
                  label: 'Saldo atual',
                  color: cs.primary,
                  onChanged: (val) {
                    setState(() => _balanceCents = val);
                    _saveDraft();
                  },
                ),
                const SizedBox(height: 20),
                AppColorPicker(
                  selectedColorHex: _selectedColorHex,
                  onColorSelected: (color) {
                    setState(() {
                      _colorCustomized = true;
                      _selectedColorHex = color;
                    });
                    _saveDraft();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          AppButton(label: 'Continuar', expanded: true, onPressed: _save),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
