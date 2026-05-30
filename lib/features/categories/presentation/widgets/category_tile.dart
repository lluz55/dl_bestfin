import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/widgets/category_icon.dart';
import 'package:bestfin/features/categories/domain/models/category.dart';

class CategoryTile extends StatefulWidget {
  const CategoryTile({
    super.key,
    required this.category,
    this.index,
    this.isReorderMode = false,
    this.onEdit,
    this.onDelete,
    this.delay = Duration.zero,
    this.initiallyExpanded = false,
  });

  final CategoryModel category;
  final int? index;
  final bool isReorderMode;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final Duration delay;
  final bool initiallyExpanded;

  @override
  State<CategoryTile> createState() => _CategoryTileState();
}

class _CategoryTileState extends State<CategoryTile> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.textTheme;
    final motion = context.motion;
    final category = widget.category;

    return Column(
          children: [
            _TileRow(
              category: category,
              expanded: _expanded,
              hasChildren: category.hasChildren,
              index: widget.index,
              isReorderMode: widget.isReorderMode,
              onToggle: category.hasChildren
                  ? () => setState(() => _expanded = !_expanded)
                  : null,
              onEdit: widget.onEdit,
              onDelete: widget.onDelete,
              cs: cs,
              tt: tt,
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Column(
                  children: [
                    for (final child in category.children)
                      _SubcategoryTile(
                        category: child,
                        onEdit: null,
                        onDelete: null,
                        cs: cs,
                        tt: tt,
                      ),
                  ],
                ),
              ),
              crossFadeState: _expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: motion.morphDuration,
              sizeCurve: motion.morphCurve,
            ),
          ],
        )
        .animate(delay: widget.delay)
        .fadeIn(duration: motion.fastDuration)
        .slideX(begin: -0.05, end: 0, curve: Curves.easeOut);
  }
}

class _TileRow extends StatelessWidget {
  const _TileRow({
    required this.category,
    required this.expanded,
    required this.hasChildren,
    this.index,
    this.isReorderMode = false,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    required this.cs,
    required this.tt,
  });

  final CategoryModel category;
  final bool expanded;
  final bool hasChildren;
  final int? index;
  final bool isReorderMode;
  final VoidCallback? onToggle;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              CategoryIcon(
                icon: category.icon,
                color: category.color,
                size: 40,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          category.name,
                          style: tt.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (category.isSystem) ...[
                          const SizedBox(width: 6),
                          _TypeBadge(label: 'Sistema', color: cs.secondary),
                        ],
                      ],
                    ),
                    Text(
                      _subtitle,
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (hasChildren) ...[
                AnimatedRotation(
                  turns: expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 250),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 4),
              ],
              if (onEdit != null || onDelete != null)
                _MoreMenu(
                  isSystem: category.isSystem,
                  onEdit: onEdit,
                  onDelete: onDelete,
                  cs: cs,
                ),
              if (isReorderMode && index != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: ReorderableDragStartListener(
                    index: index!,
                    child: Icon(Icons.drag_handle, color: cs.onSurfaceVariant),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String get _subtitle {
    final parts = [category.typeLabel];
    if (category.hasChildren) {
      parts.add('${category.children.length} subcategorias');
    }
    if (category.description != null &&
        category.description!.trim().isNotEmpty) {
      parts.add(category.description!.trim());
    }
    return parts.join(' · ');
  }
}

class _SubcategoryTile extends StatelessWidget {
  const _SubcategoryTile({
    required this.category,
    required this.onEdit,
    required this.onDelete,
    required this.cs,
    required this.tt,
  });

  final CategoryModel category;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            Icons.subdirectory_arrow_right,
            size: 16,
            color: cs.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          CategoryIcon(
            icon: category.icon,
            color: category.color,
            parentIcon: category.parentIcon,
            parentColor: category.parentColor,
            size: 32,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.displayName,
                  style: tt.bodyMedium?.copyWith(color: cs.onSurface),
                ),
                if (category.description != null &&
                    category.description!.trim().isNotEmpty)
                  Text(
                    category.description!.trim(),
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
              ],
            ),
          ),
          if (onEdit != null || onDelete != null)
            _MoreMenu(
              isSystem: category.isSystem,
              onEdit: onEdit,
              onDelete: onDelete,
              cs: cs,
            ),
        ],
      ),
    );
  }
}

class _MoreMenu extends StatelessWidget {
  const _MoreMenu({
    required this.isSystem,
    required this.onEdit,
    required this.onDelete,
    required this.cs,
  });

  final bool isSystem;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, color: cs.onSurfaceVariant, size: 20),
      onSelected: (value) {
        if (value == 'edit') onEdit?.call();
        if (value == 'delete') onDelete?.call();
      },
      itemBuilder: (_) => [
        if (onEdit != null)
          const PopupMenuItem(value: 'edit', child: Text('Editar')),
        if (onDelete != null && !isSystem)
          PopupMenuItem(
            value: 'delete',
            child: Text('Excluir', style: TextStyle(color: cs.error)),
          ),
        if (isSystem)
          const PopupMenuItem(
            enabled: false,
            child: Text('Categoria do sistema'),
          ),
      ],
    );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
