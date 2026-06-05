import 'package:flutter/material.dart';

class ChatInputBar extends StatefulWidget {
  final bool enabled;
  final bool isGenerating;
  final void Function(String text) onSend;
  final VoidCallback? onStop;
  final VoidCallback? onImageTap;

  const ChatInputBar({
    super.key,
    required this.enabled,
    this.isGenerating = false,
    required this.onSend,
    this.onStop,
    this.onImageTap,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final _ctrl = TextEditingController();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() {
      final has = _ctrl.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _ctrl.text.trim();
    if (text.isEmpty || !widget.enabled || widget.isGenerating) return;
    _ctrl.clear();
    widget.onSend(text);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outlineVariant, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (widget.onImageTap != null)
              IconButton(
                icon: Icon(
                  Icons.add_photo_alternate_outlined,
                  color: cs.onSurfaceVariant,
                ),
                onPressed:
                    widget.enabled && !widget.isGenerating
                        ? widget.onImageTap
                        : null,
                tooltip: 'Digitalizar recibo',
              ),
            Expanded(
              child: TextField(
                controller: _ctrl,
                enabled: widget.enabled && !widget.isGenerating,
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  hintText: widget.isGenerating
                      ? 'Gerando resposta…'
                      : widget.enabled
                      ? 'Pergunte sobre suas finanças…'
                      : 'Aguardando modelo…',
                  hintStyle: TextStyle(color: cs.onSurfaceVariant),
                  filled: true,
                  fillColor: cs.surfaceContainerLow,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: widget.isGenerating
                  ? IconButton.filled(
                      key: const ValueKey('stop'),
                      style: IconButton.styleFrom(
                        backgroundColor: cs.errorContainer,
                        foregroundColor: cs.onErrorContainer,
                      ),
                      onPressed: widget.onStop,
                      icon: const Icon(Icons.stop_rounded),
                      tooltip: 'Parar geração',
                    )
                  : _hasText
                  ? IconButton.filled(
                      key: const ValueKey('send'),
                      onPressed: widget.enabled ? _submit : null,
                      icon: const Icon(Icons.send_rounded),
                    )
                  : IconButton(
                      key: const ValueKey('mic'),
                      onPressed: null,
                      icon: Icon(
                        Icons.mic_none_rounded,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
