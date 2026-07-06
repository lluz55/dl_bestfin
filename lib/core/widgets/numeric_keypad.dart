import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';

/// Teclas do teclado físico aceitas como equivalentes aos botões do numpad.
/// Não pode ser `const`: LogicalKeyboardKey sobrescreve `==`/`hashCode`.
final Map<LogicalKeyboardKey, String> _kDigitKeys = {
  LogicalKeyboardKey.digit0: '0',
  LogicalKeyboardKey.digit1: '1',
  LogicalKeyboardKey.digit2: '2',
  LogicalKeyboardKey.digit3: '3',
  LogicalKeyboardKey.digit4: '4',
  LogicalKeyboardKey.digit5: '5',
  LogicalKeyboardKey.digit6: '6',
  LogicalKeyboardKey.digit7: '7',
  LogicalKeyboardKey.digit8: '8',
  LogicalKeyboardKey.digit9: '9',
  LogicalKeyboardKey.numpad0: '0',
  LogicalKeyboardKey.numpad1: '1',
  LogicalKeyboardKey.numpad2: '2',
  LogicalKeyboardKey.numpad3: '3',
  LogicalKeyboardKey.numpad4: '4',
  LogicalKeyboardKey.numpad5: '5',
  LogicalKeyboardKey.numpad6: '6',
  LogicalKeyboardKey.numpad7: '7',
  LogicalKeyboardKey.numpad8: '8',
  LogicalKeyboardKey.numpad9: '9',
};

class NumericKeypad extends StatefulWidget {
  final Function(String) onKeyPressed;
  final VoidCallback onDeletePressed;
  final VoidCallback? onConfirmPressed;

  /// FocusNode externo opcional para que o widget pai controle quando o
  /// numpad deve receber eventos de teclado físico (ex.: só quando a página
  /// que o contém estiver realmente visível).
  final FocusNode? focusNode;

  /// Se true, solicita foco automaticamente ao ser construído. Só é seguro
  /// quando o numpad é o único conteúdo interativo relevante no momento
  /// (ex.: dentro de um bottom sheet/dialog dedicado). Para telas com
  /// múltiplas páginas construídas simultaneamente (PageView), prefira
  /// controlar o foco via [focusNode] externo.
  final bool autofocus;

  const NumericKeypad({
    super.key,
    required this.onKeyPressed,
    required this.onDeletePressed,
    this.onConfirmPressed,
    this.focusNode,
    this.autofocus = false,
  });

  @override
  State<NumericKeypad> createState() => _NumericKeypadState();
}

class _NumericKeypadState extends State<NumericKeypad> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    final digit = _kDigitKeys[event.logicalKey];
    if (digit != null) {
      HapticFeedback.lightImpact();
      widget.onKeyPressed(digit);
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.backspace) {
      HapticFeedback.mediumImpact();
      widget.onDeletePressed();
      return KeyEventResult.handled;
    }

    if (event is KeyDownEvent &&
        widget.onConfirmPressed != null &&
        (event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.numpadEnter)) {
      HapticFeedback.mediumImpact();
      widget.onConfirmPressed!();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final onKeyPressed = widget.onKeyPressed;
    final onDeletePressed = widget.onDeletePressed;
    final onConfirmPressed = widget.onConfirmPressed;

    return Focus(
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      onKeyEvent: _handleKeyEvent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var row in [
            ['1', '2', '3'],
            ['4', '5', '6'],
            ['7', '8', '9'],
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (var key in row)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: _KeyButton(
                          text: key,
                          onTap: () {
                            HapticFeedback.lightImpact();
                            onKeyPressed(key);
                          },
                        ),
                      ),
                    ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Double zero key
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: _KeyButton(
                      text: '00',
                      onTap: () {
                        HapticFeedback.lightImpact();
                        onKeyPressed('00');
                      },
                    ),
                  ),
                ),
                // Zero key
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: _KeyButton(
                      text: '0',
                      onTap: () {
                        HapticFeedback.lightImpact();
                        onKeyPressed('0');
                      },
                    ),
                  ),
                ),
                // Delete/Backspace key
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: _KeyButton(
                      icon: Icons.backspace_outlined,
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        onDeletePressed();
                      },
                      backgroundColor: cs.surfaceContainerHigh,
                      foregroundColor: cs.error,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (onConfirmPressed != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    onConfirmPressed();
                  },
                  icon: const Icon(Icons.check),
                  label: const Text(
                    'Confirmar Valor',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _KeyButton extends StatefulWidget {
  final String? text;
  final IconData? icon;
  final VoidCallback onTap;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const _KeyButton({
    this.text,
    this.icon,
    required this.onTap,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  State<_KeyButton> createState() => _KeyButtonState();
}

class _KeyButtonState extends State<_KeyButton>
    with SingleTickerProviderStateMixin {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.textTheme;

    final bg = widget.backgroundColor ?? cs.surfaceContainerLow;
    final fg = widget.foregroundColor ?? cs.onSurface;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          height: 60,
          decoration: BoxDecoration(
            color: _isPressed ? bg.withValues(alpha: 0.8) : bg,
            borderRadius: BorderRadius.circular(18),
          ),
          alignment: Alignment.center,
          child: widget.icon != null
              ? Icon(widget.icon, color: fg, size: 22)
              : Text(
                  widget.text!,
                  style: tt.headlineSmall?.copyWith(
                    color: fg,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ),
    );
  }
}
