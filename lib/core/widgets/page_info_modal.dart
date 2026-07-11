import 'package:flutter/material.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';

class PageInfoButton extends StatelessWidget {
  const PageInfoButton({
    super.key,
    required this.title,
    required this.description,
    this.features,
  });

  final String title;
  final String description;
  final List<String>? features;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.info_outline_rounded),
      tooltip: 'Sobre esta tela',
      onPressed: () => showPageInfoModal(
        context: context,
        title: title,
        description: description,
        features: features,
      ),
    );
  }
}

void showPageInfoModal({
  required BuildContext context,
  required String title,
  required String description,
  List<String>? features,
}) {
  showDialog(
    context: context,
    builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
      child: PageInfoContent(
        title: title,
        description: description,
        features: features,
      ),
    ),
  );
}

class PageInfoContent extends StatelessWidget {
  const PageInfoContent({
    super.key,
    required this.title,
    required this.description,
    this.features,
  });

  final String title;
  final String description;
  final List<String>? features;

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 24, color: cs.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                tooltip: 'Fechar',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    description,
                    style: tt.bodyLarge?.copyWith(
                      color: cs.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                  if (features != null && features!.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text(
                      'Funcionalidades',
                      style: tt.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: cs.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...features!.map(
                      (feature) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.check_circle_rounded,
                              size: 18,
                              color: cs.primary,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                feature,
                                style: tt.bodyMedium?.copyWith(
                                  color: cs.onSurfaceVariant,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
