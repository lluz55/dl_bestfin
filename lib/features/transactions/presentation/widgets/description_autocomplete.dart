import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestfin/features/transactions/presentation/providers/transactions_provider.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';

/// Espera o usuário parar de digitar antes de consultar o histórico —
/// sem isso, cada tecla disparava um SELECT contra a tabela inteira.
const _suggestionsDebounce = Duration(milliseconds: 250);

class DescriptionAutocomplete extends ConsumerStatefulWidget {
  final TextEditingController controller;
  final String? transactionType;
  final Function(String) onSelected;
  final VoidCallback? onChanged;
  final FocusNode? focusNode;
  final ValueChanged<String>? onFieldSubmitted;

  /// Sobrescreve a decoração padrão do campo. Usado pela inserção em massa
  /// para encaixar o mesmo autocomplete do formulário em uma linha da tabela
  /// (sem borda e denso), mantendo as sugestões por histórico.
  final InputDecoration? decoration;
  final TextStyle? style;
  final TextCapitalization textCapitalization;

  const DescriptionAutocomplete({
    super.key,
    required this.controller,
    this.transactionType,
    required this.onSelected,
    this.onChanged,
    this.focusNode,
    this.onFieldSubmitted,
    this.decoration,
    this.style,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  ConsumerState<DescriptionAutocomplete> createState() =>
      _DescriptionAutocompleteState();
}

class _DescriptionAutocompleteState
    extends ConsumerState<DescriptionAutocomplete> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    if (widget.focusNode == null) _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final isMobile = MediaQuery.of(context).size.width < 600;

    return RawAutocomplete<String>(
      textEditingController: widget.controller,
      focusNode: _focusNode,
      // Sugestões flutuam acima do campo (overlay do próprio
      // RawAutocomplete) em vez de empurrar o resto do formulário.
      optionsViewOpenDirection: OptionsViewOpenDirection.up,
      optionsBuilder: (TextEditingValue textEditingValue) async {
        if (textEditingValue.text.isEmpty) {
          final results = await ref.read(
            recentDescriptionsProvider((
              query: '',
              type: widget.transactionType,
            )).future,
          );
          return results;
        }

        // Espera o usuário parar de digitar antes de consultar — evita um
        // SELECT por tecla enquanto o desktop reconstrói as opções.
        await Future.delayed(_suggestionsDebounce);
        if (widget.controller.text != textEditingValue.text) {
          return const Iterable<String>.empty();
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
          textCapitalization: widget.textCapitalization,
          style: widget.style,
          decoration:
              widget.decoration ??
              InputDecoration(
                labelText: widget.transactionType == 'transfer'
                    ? 'Descrição (opcional)'
                    : 'Descrição *',
                hintText: 'Ex: Compras no mercado, Freelance...',
                prefixIcon: const Icon(Icons.description_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
          onFieldSubmitted: (value) {
            onFieldSubmitted();
            widget.onFieldSubmitted?.call(value);
          },
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        // Mobile: faixa horizontal de chips (compacta, rolável).
        if (isMobile) {
          // bottomStart: com optionsViewOpenDirection.up, o framework
          // reserva todo o espaço disponível ACIMA do campo (que pode ser
          // quase a tela toda dentro de um bottom sheet) — alinhar pela
          // base é o que cola este conteúdo rente ao campo, em vez de
          // flutuar solto no topo desse espaço.
          return Align(
            alignment: AlignmentDirectional.bottomStart,
            child: SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                itemCount: options.length,
                itemBuilder: (BuildContext context, int index) {
                  final String option = options.elementAt(index);
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Material(
                      color: cs.surfaceContainerHigh,
                      elevation: 4,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        // canRequestFocus:false + onTapDown (em vez de
                        // onTap/ActionChip): tocar aqui não pode tirar o
                        // foco do campo antes do tap terminar, senão o
                        // RawAutocomplete esconde este overlay no meio do
                        // gesto e a seleção nunca dispara.
                        canRequestFocus: false,
                        onTapDown: (_) => onSelected(option),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: cs.outlineVariant,
                              width: 0.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.history,
                                color: cs.onSurfaceVariant,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                option,
                                style: TextStyle(
                                  color: cs.onSurface,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        }

        // Desktop/tablet: lista vertical.
        // bottomStart (ver comentário acima): cola a lista rente ao campo
        // em vez de alinhá-la ao topo do espaço reservado.
        return Align(
          alignment: AlignmentDirectional.bottomStart,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(16),
            color: cs.surfaceContainerHigh,
            child: Container(
              width: double.infinity,
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
                    // onTapDown (não onTap) evita a corrida com a perda de
                    // foco do campo ao tocar na opção: o foco tirado do
                    // TextField dispara um rebuild que pode remover esta
                    // lista antes do tap (pointer-up) terminar de ser
                    // reconhecido.
                    canRequestFocus: false,
                    onTapDown: (_) => onSelected(option),
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
    );
  }
}
