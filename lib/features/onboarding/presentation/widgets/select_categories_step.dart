import 'package:flutter/material.dart';
import 'package:bestfin/core/widgets/app_button.dart';
import 'package:bestfin/core/widgets/loading_indicator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/widgets/category_icon.dart';
import 'package:bestfin/features/categories/presentation/providers/categories_provider.dart';

class SelectCategoriesStep extends ConsumerWidget {
  const SelectCategoriesStep({super.key, required this.onNext});

  final VoidCallback onNext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = context.colorScheme;
    final tt = context.textTheme;
    final categoriesAsync = ref.watch(categoriesTreeProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text(
            'Categorias padrão',
            style: tt.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Já configuramos categorias para você. Adicione as suas ou personalize depois.',
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: categoriesAsync.when(
              data: (categories) {
                final rootCategories = categories
                    .where((c) => c.isRoot)
                    .toList();
                return ListView.separated(
                  itemCount: rootCategories.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final cat = rootCategories[index];
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          CategoryIcon(
                            icon: cat.icon,
                            color: cat.color,
                            size: 36,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              cat.name,
                              style: tt.bodyMedium?.copyWith(
                                color: cs.onSurface,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.check_circle_rounded,
                            size: 18,
                            color: cs.primary,
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: AppLoadingIndicator()),
              error: (_, __) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      color: cs.error,
                      size: 40,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Não foi possível carregar as categorias',
                      style: tt.bodyMedium?.copyWith(color: cs.error),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => ref.invalidate(categoriesTreeProvider),
                      child: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          AppButton(
            label: 'Nova categoria',
            icon: Icons.add_rounded,
            variant: AppButtonVariant.outlined,
            expanded: true,
            onPressed: () async {
              // Rota liberada pelo guard do router durante o onboarding.
              final created = await context.push<bool>('/categories/new');
              if (created == true) ref.invalidate(categoriesTreeProvider);
            },
          ),
          const SizedBox(height: 12),
          AppButton(label: 'Continuar', expanded: true, onPressed: onNext),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
