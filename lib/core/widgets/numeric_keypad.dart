import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';

class NumericKeypad extends StatelessWidget {
  final Function(String) onKeyPressed;
  final VoidCallback onDeletePressed;
  final VoidCallback? onConfirmPressed;

  const NumericKeypad({
    super.key,
    required this.onKeyPressed,
    required this.onDeletePressed,
    this.onConfirmPressed,
  });

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;

    return Column(
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
              // Decimal key or comma
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: _KeyButton(
                    text: ',',
                    onTap: () {
                      HapticFeedback.lightImpact();
                      onKeyPressed(',');
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
                  onConfirmPressed!();
                },
                icon: const Icon(Icons.check),
                label: const Text(
                  'Confirmar Valor',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ),
      ],
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
            boxShadow: _isPressed
                ? []
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
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
