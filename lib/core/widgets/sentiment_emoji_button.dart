import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:bestfin/core/constants/sentiment_types.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';

class SentimentEmojiButton extends StatefulWidget {
  final SentimentType? selectedSentiment;
  final ValueChanged<SentimentType?> onSentimentSelected;
  final double? height;

  const SentimentEmojiButton({
    super.key,
    required this.selectedSentiment,
    required this.onSentimentSelected,
    this.height,
  });

  @override
  State<SentimentEmojiButton> createState() => _SentimentEmojiButtonState();
}

class _SentimentEmojiButtonState extends State<SentimentEmojiButton> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlay;

  void _showPicker() {
    HapticFeedback.lightImpact();
    _overlay = OverlayEntry(
      builder: (context) => _SentimentPickerOverlay(
        layerLink: _layerLink,
        selectedSentiment: widget.selectedSentiment,
        onSelected: (s) {
          _hidePicker();
          widget.onSentimentSelected(s);
        },
        onDismiss: _hidePicker,
      ),
    );
    Overlay.of(context).insert(_overlay!);
  }

  void _hidePicker() {
    _overlay?.remove();
    _overlay = null;
  }

  @override
  void dispose() {
    _hidePicker();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final selected = widget.selectedSentiment;

    return CompositedTransformTarget(
      link: _layerLink,
      child: GestureDetector(
        onTap: _overlay == null ? _showPicker : _hidePicker,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          width: 56,
          height: widget.height,
          decoration: BoxDecoration(
            color: selected != null
                ? selected.color.withValues(alpha: 0.15)
                : cs.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected != null
                  ? selected.color.withValues(alpha: 0.6)
                  : cs.outlineVariant.withValues(alpha: 0.5),
              width: 1,
            ),
          ),
          child: Center(
            child: Text(
              selected?.emoji ?? '😶',
              style: const TextStyle(fontSize: 22),
            ),
          ),
        ),
      ),
    );
  }
}

class _SentimentPickerOverlay extends StatefulWidget {
  final LayerLink layerLink;
  final SentimentType? selectedSentiment;
  final ValueChanged<SentimentType?> onSelected;
  final VoidCallback onDismiss;

  const _SentimentPickerOverlay({
    required this.layerLink,
    required this.selectedSentiment,
    required this.onSelected,
    required this.onDismiss,
  });

  @override
  State<_SentimentPickerOverlay> createState() =>
      _SentimentPickerOverlayState();
}

class _SentimentPickerOverlayState extends State<_SentimentPickerOverlay> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Stack(
      children: [
        // Barrier transparente
        GestureDetector(
          onTap: widget.onDismiss,
          behavior: HitTestBehavior.translucent,
          child: const SizedBox.expand(),
        ),
        CompositedTransformFollower(
          link: widget.layerLink,
          showWhenUnlinked: false,
          targetAnchor: Alignment.topRight,
          followerAnchor: Alignment.bottomRight,
          offset: const Offset(0, -12),
          child: AnimatedOpacity(
            opacity: _visible ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 180),
            child: AnimatedScale(
              scale: _visible ? 1.0 : 0.7,
              alignment: Alignment.bottomRight,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutBack,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(24),
                color: cs.surfaceContainerHighest,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: cs.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.selectedSentiment != null) ...[
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            widget.onSelected(null);
                          },
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: cs.errorContainer.withValues(alpha: 0.15),
                              border: Border.all(
                                color: cs.error.withValues(alpha: 0.3),
                                width: 1.5,
                              ),
                            ),
                            child: Center(
                              child: Icon(
                                Icons.block_rounded,
                                color: cs.error,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      for (final sentiment in SentimentType.values) ...[
                        _PickerEmojiButton(
                          sentiment: sentiment,
                          isSelected: widget.selectedSentiment == sentiment,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            final isAlreadySelected =
                                widget.selectedSentiment == sentiment;
                            widget.onSelected(
                              isAlreadySelected ? null : sentiment,
                            );
                          },
                        ),
                        if (sentiment != SentimentType.values.last)
                          const SizedBox(width: 4),
                      ],
                    ],
                  ),
                ),
              ).animate().fadeIn(duration: 180.ms),
            ),
          ),
        ),
      ],
    );
  }
}

class _PickerEmojiButton extends StatefulWidget {
  final SentimentType sentiment;
  final bool isSelected;
  final VoidCallback onTap;

  const _PickerEmojiButton({
    required this.sentiment,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_PickerEmojiButton> createState() => _PickerEmojiButtonState();
}

class _PickerEmojiButtonState extends State<_PickerEmojiButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.85 : (widget.isSelected ? 1.15 : 1.0),
        duration: const Duration(milliseconds: 120),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: widget.isSelected
                ? widget.sentiment.color.withValues(alpha: 0.2)
                : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(
              color: widget.isSelected
                  ? widget.sentiment.color
                  : Colors.transparent,
              width: 2,
            ),
          ),
          child: Center(
            child: Text(
              widget.sentiment.emoji,
              style: const TextStyle(fontSize: 24),
            ),
          ),
        ),
      ),
    );
  }
}
