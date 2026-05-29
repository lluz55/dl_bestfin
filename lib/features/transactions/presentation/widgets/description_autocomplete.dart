import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestfin/features/transactions/presentation/providers/transactions_provider.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';

class DescriptionAutocomplete extends ConsumerStatefulWidget {
  final TextEditingController controller;
  final String? transactionType;
  final Function(String) onSelected;
  final VoidCallback? onChanged;

  const DescriptionAutocomplete({
    super.key,
    required this.controller,
    this.transactionType,
    required this.onSelected,
    this.onChanged,
  });

  @override
  ConsumerState<DescriptionAutocomplete> createState() => _DescriptionAutocompleteState();
}

class _DescriptionAutocompleteState extends ConsumerState<DescriptionAutocomplete> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;

    return RawAutocomplete<String>(
      textEditingController: widget.controller,
      focusNode: _focusNode,
      optionsBuilder: (TextEditingValue textEditingValue) async {
        if (textEditingValue.text.isEmpty) {
          // Quando vazio, podemos sugerir os mais recentes sem filtro de query
          final results = await ref.read(
            recentDescriptionsProvider((
              query: '',
              type: widget.transactionType,
            )).future,
          );
          return results;
        }

        final results = await ref.read(
          recentDescriptionsProvider((
            query: textEditingValue.text,
            type: widget.transactionType,
          )).future,
        );
        return results;
      },
      onSelected: widget.onSelected,
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: 'Descrição',
            hintText: 'Ex: Compras no mercado, Freelance...',
            prefixIcon: const Icon(Icons.description_outlined),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          onFieldSubmitted: (value) => onFieldSubmitted(),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(16),
            color: cs.surfaceContainerHigh,
            child: Container(
              width: MediaQuery.of(context).size.width - 40, // Padding do ListView
              constraints: const BoxConstraints(maxHeight: 250),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (BuildContext context, int index) {
                  final String option = options.elementAt(index);
                  return InkWell(
                    onTap: () => onSelected(option),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.history,
                            color: cs.onSurfaceVariant,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              option,
                              style: TextStyle(
                                color: cs.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
