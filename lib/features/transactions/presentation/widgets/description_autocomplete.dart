import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestfin/features/transactions/presentation/providers/transactions_provider.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';

class DescriptionAutocomplete extends ConsumerStatefulWidget {
  final TextEditingController controller;
  final String? transactionType;
  final Function(String) onSelected;
  final VoidCallback? onChanged;
  final FocusNode? focusNode;
  final ValueChanged<String>? onFieldSubmitted;

  const DescriptionAutocomplete({
    super.key,
    required this.controller,
    this.transactionType,
    required this.onSelected,
    this.onChanged,
    this.focusNode,
    this.onFieldSubmitted,
  });

  @override
  ConsumerState<DescriptionAutocomplete> createState() =>
      _DescriptionAutocompleteState();
}

class _DescriptionAutocompleteState
    extends ConsumerState<DescriptionAutocomplete> {
  late final FocusNode _focusNode;
  List<String> _suggestions = [];
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChange);
    widget.controller.addListener(_onTextChanged);
    _loadSuggestions();
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    widget.controller.removeListener(_onTextChanged);
    if (widget.focusNode == null) _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {
      _showSuggestions = _focusNode.hasFocus;
    });
    if (_focusNode.hasFocus) {
      _loadSuggestions();
    }
  }

  void _onTextChanged() {
    widget.onChanged?.call();
    _loadSuggestions();
  }

  Future<void> _loadSuggestions() async {
    final text = widget.controller.text;
    final results = await ref.read(
      recentDescriptionsProvider((
        query: text,
        type: widget.transactionType,
      )).future,
    );
    if (mounted) {
      setState(() {
        _suggestions = results.toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isMobile && _showSuggestions && _suggestions.isNotEmpty) ...[
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              itemCount: _suggestions.length,
              itemBuilder: (BuildContext context, int index) {
                final String option = _suggestions[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ActionChip(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    labelPadding: EdgeInsets.zero,
                    avatar: Icon(
                      Icons.history,
                      color: cs.onSurfaceVariant,
                      size: 16,
                    ),
                    label: Text(
                      option,
                      style: TextStyle(
                        color: cs.onSurface,
                        fontSize: 13,
                      ),
                    ),
                    backgroundColor: cs.surfaceContainerLow,
                    side: BorderSide(
                      color: cs.outlineVariant,
                      width: 0.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    onPressed: () {
                      widget.controller.text = option;
                      widget.onSelected(option);
                    },
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
        RawAutocomplete<String>(
          textEditingController: widget.controller,
          focusNode: _focusNode,
          optionsBuilder: (TextEditingValue textEditingValue) async {
            if (isMobile) {
              return const Iterable<String>.empty();
            }

            if (textEditingValue.text.isEmpty) {
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
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Descrição',
                hintText: 'Ex: Compras no mercado, Freelance...',
                prefixIcon: const Icon(Icons.description_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onFieldSubmitted: (value) {
                onFieldSubmitted();
                widget.onFieldSubmitted?.call(value);
              },
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
                  width:
                      MediaQuery.of(context).size.width - 40, // Padding do ListView
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
                                  style: TextStyle(color: cs.onSurface),
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
        ),
      ],
    );
  }
}
