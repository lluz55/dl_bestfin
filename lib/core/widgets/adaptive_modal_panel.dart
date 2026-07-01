import 'package:flutter/material.dart';

class AdaptiveModalPanel extends StatefulWidget {
  const AdaptiveModalPanel({
    super.key,
    required this.onClose,
    required this.builder,
    this.maxWidth = 480,
    this.maxHeightFraction = 0.6,
    this.minWidth = 320,
  });

  final VoidCallback onClose;
  final Widget Function(BuildContext context, VoidCallback requestClose)
  builder;
  final double maxWidth;
  final double maxHeightFraction;
  final double minWidth;

  @override
  State<AdaptiveModalPanel> createState() => _AdaptiveModalPanelState();
}

class _AdaptiveModalPanelState extends State<AdaptiveModalPanel>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleClose() {
    _controller.reverse().then((_) {
      if (mounted) {
        widget.onClose();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GestureDetector(
          onTap: _handleClose,
          child: AnimatedBuilder(
            animation: _fadeAnimation,
            builder: (context, child) {
              return Container(
                color: Colors.black.withValues(
                  alpha: 0.4 * _fadeAnimation.value,
                ),
              );
            },
          ),
        ),
        Positioned(
          right: 24,
          bottom: 24,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.scale(
                scale: 0.9 + (0.1 * _scaleAnimation.value),
                child: Opacity(
                  opacity: _fadeAnimation.value,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: widget.maxWidth,
                      maxHeight:
                          MediaQuery.of(context).size.height *
                          widget.maxHeightFraction,
                      minWidth: widget.minWidth,
                    ),
                    child: Material(
                      elevation: 12,
                      borderRadius: BorderRadius.circular(20),
                      clipBehavior: Clip.antiAlias,
                      child: widget.builder(context, _handleClose),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
