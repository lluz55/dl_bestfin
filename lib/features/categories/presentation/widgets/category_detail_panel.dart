import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/widgets/category_icon.dart';
import 'package:bestfin/features/categories/domain/models/category.dart';

class CategoryDetailPanel extends ConsumerWidget {
  const CategoryDetailPanel({
    required this.category,
    super.key,
    this.onEdit,
    this.onDelete,
  });

  final CategoryModel category;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = context.colorScheme;
    final tt = context.textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Header(category: category),
        const SizedBox(height: 24),
        _InfoSection(category: category, cs: cs, tt: tt),
        if (category.hasChildren) ...[
          const SizedBox(height: 24),
          _SubcategoriesSection(category: category, cs: cs, tt: tt),
        ],
        const SizedBox(height: 24),
        _Actions(onEdit: onEdit, onDelete: onDelete, category: category, cs: cs),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.category});
  final CategoryModel category;

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.textTheme;

    return Row(
      children: [
        CategoryIcon(icon: category.icon, color: category.color, size: 64),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                category.name,
                style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  _Badge(
                    label: category.typeLabel,
                    color: category.type == 'both'
                        ? cs.primary
                        : category.type == 'income'
                            ? context.customColors.income
                            : category.type == 'expense'
                                ? cs.error
                                : cs.secondary,
                  ),
                  const SizedBox(width: 8),
                  if (category.isSystem)
                    _Badge(label: 'Sistema', color: cs.outline),
                  if (category.isArchived)
                    _Badge(label: 'Arquivada', color: cs.error),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  const _InfoSection({
    required this.category,
    required this.cs,
    required this.tt,
  });

  final CategoryModel category;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Informações', style: tt.titleSmall?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: 12),
          _InfoRow(
            icon: Icons.description_outlined,
            label: 'Descrição',
            value: category.description?.trim().isNotEmpty == true
                ? category.description!.trim()
                : 'Sem descrição',
            cs: cs,
            tt: tt,
            muted: category.description?.trim().isEmpty ?? true,
          ),
          const SizedBox(height: 8),
          _InfoRow(
            icon: Icons.account_tree_outlined,
            label: 'Subcategorias',
            value: category.hasChildren
                ? '${category.children.length} subcategorias'
                : 'Nenhuma',
            cs: cs,
            tt: tt,
            muted: !category.hasChildren,
          ),
          if (category.parentName != null) ...[
            const SizedBox(height: 8),
            _InfoRow(
              icon: Icons.subdirectory_arrow_left,
              label: 'Categoria pai',
              value: category.parentName!,
              cs: cs,
              tt: tt,
            ),
          ],
          const SizedBox(height: 8),
          _InfoRow(
            icon: Icons.calendar_today_outlined,
            label: 'Criada em',
            value: _formatDate(category.createdAt),
            cs: cs,
            tt: tt,
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.cs,
    required this.tt,
    this.muted = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final ColorScheme cs;
  final TextTheme tt;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: cs.onSurfaceVariant),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: 2),
              Text(
                value,
                style: tt.bodySmall?.copyWith(
                  color: muted ? cs.onSurfaceVariant.withValues(alpha: 0.6) : cs.onSurface,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SubcategoriesSection extends StatelessWidget {
  const _SubcategoriesSection({
    required this.category,
    required this.cs,
    required this.tt,
  });

  final CategoryModel category;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Subcategorias',
                style: tt.titleSmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              const Spacer(),
              Text(
                '${category.children.length}',
                style: tt.labelMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...category.children.map(
            (child) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  CategoryIcon(
                    icon: child.icon,
                    color: child.color,
                    parentIcon: category.icon,
                    parentColor: category.color,
                    size: 28,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      child.name,
                      style: tt.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _Badge(
                    label: child.typeLabel,
                    color: child.type == 'both'
                        ? cs.primary
                        : child.type == 'income'
                            ? context.customColors.income
                            : child.type == 'expense'
                                ? cs.error
                                : cs.secondary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.onEdit,
    required this.onDelete,
    required this.category,
    required this.cs,
  });

  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final CategoryModel category;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (onEdit != null)
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Editar'),
            ),
          ),
        if (onDelete != null && !category.isSystem) ...[
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onDelete,
              icon: Icon(Icons.delete_outlined, size: 18, color: cs.error),
              label: Text('Excluir', style: TextStyle(color: cs.error)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: cs.error.withValues(alpha: 0.4)),
              ),
            ),
          ),
        ],
      ],
    );
  }
}