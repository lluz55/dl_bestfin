import 'package:flutter/material.dart';

class ModalOverlayWrapper extends StatelessWidget {
  final Widget child;
  final Widget overlay;

  const ModalOverlayWrapper({
    super.key,
    required this.child,
    required this.overlay,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(children: [child, overlay]);
  }
}
