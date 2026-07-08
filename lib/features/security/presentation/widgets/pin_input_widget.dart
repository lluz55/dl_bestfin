import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';

class PinInputWidget extends StatefulWidget {
  const PinInputWidget({
    super.key,
    required this.onComplete,
    this.errorMessage,
    this.enabled = true,
  });

  final void Function(String pin) onComplete;
  final String? errorMessage;
  final bool enabled;

  @override
  State<PinInputWidget> createState() => PinInputWidgetState();
}

class PinInputWidgetState extends State<PinInputWidget>
    with SingleTickerProviderStateMixin {
  String _pin = '';
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void shake() {
    setState(() => _pin = '');
    _shakeController.forward(from: 0);
  }

  /// Limpa os dígitos sem animação de erro. Deve ser chamado pelo pai ao
  /// reaproveitar o widget para uma nova entrada (ex.: etapa de confirmação
  /// do PIN) — sem isso `_pin` fica cheio e o teclado para de responder.
  void clear() {
    if (_pin.isEmpty) return;
    setState(() => _pin = '');
  }

  KeyEventResult _onHardwareKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.backspace) {
      _onBackspace();
      return KeyEventResult.handled;
    }
    final char = event.character;
    if (char != null && char.length == 1 && '0123456789'.contains(char)) {
      _onKey(char);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _onKey(String digit) {
    if (!widget.enabled || _pin.length >= 4) return;
    setState(() => _pin += digit);
    if (_pin.length == 4) {
      widget.onComplete(_pin);
    }
  }

  void _onBackspace() {
    if (!widget.enabled || _pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.textTheme;

    // Focus com autofocus permite digitar o PIN pelo teclado físico
    // (essencial no Linux desktop, onde só existe o numpad em tela).
    return Focus(
      autofocus: true,
      onKeyEvent: _onHardwareKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _shakeAnimation,
            builder: (context, child) {
              final offset = _shakeController.isAnimating
                  ? 8 * (0.5 - (_shakeAnimation.value - 0.5).abs()) * 2
                  : 0.0;
              return Transform.translate(
                offset: Offset(offset * 10, 0),
                child: child,
              );
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (i) {
                final filled = i < _pin.length;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled ? cs.primary : Colors.transparent,
                    border: Border.all(
                      color: filled ? cs.primary : cs.outline,
                      width: 2,
                    ),
                  ),
                );
              }),
            ),
          ),
          if (widget.errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              widget.errorMessage!,
              style: tt.bodySmall?.copyWith(color: cs.error),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 32),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: widget.enabled ? 1 : 0.4,
            child: IgnorePointer(
              ignoring: !widget.enabled,
              child: _buildNumpad(cs, tt),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumpad(ColorScheme cs, TextTheme tt) {
    return Column(
      children: [
        for (final row in [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: row
                .map((d) => _NumKey(digit: d, onTap: () => _onKey(d)))
                .toList(),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 80),
            _NumKey(digit: '0', onTap: () => _onKey('0')),
            SizedBox(
              width: 80,
              height: 80,
              child: IconButton(
                onPressed: _onBackspace,
                icon: Icon(
                  Icons.backspace_outlined,
                  color: cs.onSurface,
                  size: 24,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _NumKey extends StatelessWidget {
  const _NumKey({required this.digit, required this.onTap});

  final String digit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.textTheme;

    return SizedBox(
      width: 80,
      height: 80,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(40),
        child: Center(
          child: Text(
            digit,
            style: tt.headlineSmall?.copyWith(
              fontWeight: FontWeight.w500,
              color: cs.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
