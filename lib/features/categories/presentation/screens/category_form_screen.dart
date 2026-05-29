import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/widgets/app_page_appbar.dart';
import 'package:bestfin/core/utils/icon_mapper.dart';
import 'package:bestfin/core/widgets/category_icon.dart';
import 'package:bestfin/core/widgets/color_picker.dart';
import 'package:bestfin/features/categories/domain/models/category.dart';
import 'package:bestfin/features/categories/presentation/providers/categories_provider.dart';

class CategoryFormScreen extends ConsumerStatefulWidget {
  const CategoryFormScreen({
    super.key,
    this.categoryToEdit,
    this.initialParentId,
  });

  final CategoryModel? categoryToEdit;
  final String? initialParentId;

  @override
  ConsumerState<CategoryFormScreen> createState() => _CategoryFormScreenState();
}

class _CategoryFormScreenState extends ConsumerState<CategoryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  late String _icon;
  late String _color;
  late String _type;
  String? _parentId;
  final Set<String> _selectedSubcategoryIds = {};

  bool get _isEditing => widget.categoryToEdit != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final c = widget.categoryToEdit!;
      _nameController.text = c.name;
      _icon = c.icon;
      _color = c.color;
      _type = c.type;
      _parentId = c.parentId;
    } else {
      _icon = 'category';
      _color = '#2196F3';
      _type = 'expense';
      _parentId = widget.initialParentId;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      if (_isEditing) {
        await ref.read(updateCategoryProvider)(
          id: widget.categoryToEdit!.id,
          name: _nameController.text.trim(),
          icon: _icon,
          color: _color,
          type: _type,
          parentId: _parentId,
        );
      } else {
        final newCategoryId = await ref.read(createCategoryProvider)(
          name: _nameController.text.trim(),
          icon: _icon,
          color: _color,
          type: _type,
          parentId: _parentId,
        );

        if (_parentId == null && _selectedSubcategoryIds.isNotEmpty) {
          final allCategories = ref.read(allFlatCategoriesProvider);
          for (final subcatId in _selectedSubcategoryIds) {
            final subcat = allCategories.firstWhere((c) => c.id == subcatId);
            await ref.read(updateCategoryProvider)(
              id: subcat.id,
              name: subcat.name,
              icon: subcat.icon,
              color: subcat.color,
              type: subcat.type,
              parentId: newCategoryId,
            );
          }
        }
      }
      ref.invalidate(categoriesTreeProvider);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao salvar: $e')));
      }
    }
  }

  void _showIconPicker() {
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _IconPickerSheet(
        selectedIcon: _icon,
        onSelected: (name) => setState(() => _icon = name),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.textTheme;
    final shapes = context.shapes;

    final allCategories = ref.watch(allFlatCategoriesProvider);
    final rootCategories = allCategories
        .where((c) => c.isRoot && !c.isArchived)
        .toList();

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppPageAppBar(
        title: _isEditing ? 'Editar Categoria' : 'Nova Categoria',
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: 'Salvar',
            onPressed: _save,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 48),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Preview
              Center(
                child: Column(
                  children: [
                    CategoryIcon(icon: _icon, color: _color, size: 72)
                        .animate()
                        .scaleXY(begin: 0.8, end: 1, curve: Curves.easeOutBack),
                    const SizedBox(height: 8),
                    Text(
                      _nameController.text.isEmpty
                          ? 'Nome da Categoria'
                          : _nameController.text,
                      style: tt.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Nome
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Nome',
                  hintText: 'Ex: Alimentação',
                  filled: true,
                  fillColor: cs.surfaceContainerHigh,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),

              // Tipo
              Text(
                'Tipo',
                style: tt.labelLarge?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'expense',
                    label: Text('Despesa'),
                    icon: Icon(Icons.arrow_downward),
                  ),
                  ButtonSegment(
                    value: 'income',
                    label: Text('Receita'),
                    icon: Icon(Icons.arrow_upward),
                  ),
                  ButtonSegment(
                    value: 'transfer',
                    label: Text('Transfer.'),
                    icon: Icon(Icons.swap_horiz),
                  ),
                ],
                selected: {_type},
                onSelectionChanged: (s) => setState(() {
                  _type = s.first;
                  _selectedSubcategoryIds.clear();
                  _parentId = null;
                }),
              ),
              const SizedBox(height: 16),

              // Ícone
              InkWell(
                onTap: _showIconPicker,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(IconMapper.fromString(_icon), color: cs.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Ícone',
                          style: tt.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Subcategoria de (parent selector) — only for non-system and if there are root categories
              if (!_isEditing || widget.categoryToEdit?.isRoot == true)
                _ParentSelector(
                  selectedParentId: _parentId,
                  rootCategories: rootCategories
                      .where((c) => c.id != widget.categoryToEdit?.id)
                      .toList(),
                  onChanged: (id) => setState(() => _parentId = id),
                  cs: cs,
                  tt: tt,
                ),
              const SizedBox(height: 16),

              // Subcategorias a adotar
              if (!_isEditing && _parentId == null) ...[
                (() {
                  final candidates = allCategories
                      .where((c) =>
                          c.type == _type &&
                          !c.isSystem &&
                          !c.isArchived &&
                          c.children.isEmpty &&
                          c.id != widget.categoryToEdit?.id)
                      .toList();
                  if (candidates.isEmpty) return const SizedBox.shrink();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Usar outras categorias como subcategoria desta',
                        style: tt.labelLarge?.copyWith(color: cs.onSurfaceVariant),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Selecione as categorias existentes que passarão a ser subcategorias desta nova categoria:',
                              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: candidates.map((c) {
                                final isSelected =
                                    _selectedSubcategoryIds.contains(c.id);
                                return FilterChip(
                                  avatar: CircleAvatar(
                                    backgroundColor:
                                        c.parsedColor.withValues(alpha: 0.2),
                                    child: Icon(
                                      c.iconData,
                                      size: 14,
                                      color: c.parsedColor,
                                    ),
                                  ),
                                  label: Text(c.name),
                                  selected: isSelected,
                                  onSelected: (selected) {
                                    setState(() {
                                      if (selected) {
                                        _selectedSubcategoryIds.add(c.id);
                                      } else {
                                        _selectedSubcategoryIds.remove(c.id);
                                      }
                                    });
                                  },
                                  selectedColor: cs.primaryContainer,
                                  checkmarkColor: cs.primary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(
                                      color: isSelected
                                          ? cs.primary
                                          : Colors.transparent,
                                      width: 1,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  );
                })(),
              ],

              // Cor
              AppColorPicker(
                selectedColorHex: _color,
                previewIcon: IconMapper.fromString(_icon),
                onColorSelected: (hex) => setState(() => _color = hex),
              ),
              const SizedBox(height: 32),

              // Save button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cs.primary,
                    foregroundColor: cs.onPrimary,
                    shape: RoundedRectangleBorder(borderRadius: shapes.button),
                  ),
                  onPressed: _save,
                  child: Text(
                    _isEditing ? 'Salvar Alterações' : 'Criar Categoria',
                    style: tt.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.onPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ParentSelector extends StatelessWidget {
  const _ParentSelector({
    required this.selectedParentId,
    required this.rootCategories,
    required this.onChanged,
    required this.cs,
    required this.tt,
  });

  final String? selectedParentId;
  final List<CategoryModel> rootCategories;
  final ValueChanged<String?> onChanged;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    if (rootCategories.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String?>(
          value: selectedParentId,
          decoration: InputDecoration(
            labelText: 'Subcategoria de (opcional)',
            filled: true,
            fillColor: cs.surfaceContainerHigh,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
          items: [
            const DropdownMenuItem(
              value: null,
              child: Text('Nenhuma (categoria raiz)'),
            ),
            ...rootCategories.map(
              (c) => DropdownMenuItem(value: c.id, child: Text(c.name)),
            ),
          ],
          onChanged: onChanged,
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

// Icon picker bottom sheet using IconMapper string names
class _IconPickerSheet extends StatefulWidget {
  const _IconPickerSheet({
    required this.selectedIcon,
    required this.onSelected,
  });
  final String selectedIcon;
  final ValueChanged<String> onSelected;

  @override
  State<_IconPickerSheet> createState() => _IconPickerSheetState();
}

class _IconPickerSheetState extends State<_IconPickerSheet> {
  String _query = '';
  late String _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.selectedIcon;
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final shapes = context.shapes;
    final tt = context.textTheme;

    final categorized = IconMapper.categorized;
    final Map<String, List<MapEntry<String, IconData>>> displayMap;

    if (_query.isEmpty) {
      displayMap = categorized;
    } else {
      final q = _query.toLowerCase();
      final filtered = IconMapper.all.entries
          .where((e) => e.key.contains(q))
          .toList();
      displayMap = {'Resultados': filtered};
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: shapes.bottomSheet,
          ),
          child: Column(
            children: [
              // Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 4),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Escolher ícone',
                      style: tt.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SearchBar(
                      hintText: 'Buscar ícone...',
                      leading: const Icon(Icons.search),
                      onChanged: (v) => setState(() => _query = v),
                      elevation: const WidgetStatePropertyAll(0),
                      backgroundColor: WidgetStatePropertyAll(
                        cs.surfaceContainerHighest,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  children: [
                    for (final entry in displayMap.entries)
                      if (entry.value.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.only(top: 16, bottom: 8),
                          child: Text(
                            entry.key,
                            style: tt.labelLarge?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 6,
                                mainAxisSpacing: 8,
                                crossAxisSpacing: 8,
                              ),
                          itemCount: entry.value.length,
                          itemBuilder: (context, i) {
                            final iconEntry = entry.value[i];
                            final isSelected = _selected == iconEntry.key;
                            return GestureDetector(
                              onTap: () {
                                setState(() => _selected = iconEntry.key);
                                widget.onSelected(iconEntry.key);
                                Navigator.of(context).pop();
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? cs.primaryContainer
                                      : cs.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(12),
                                  border: isSelected
                                      ? Border.all(color: cs.primary, width: 2)
                                      : null,
                                ),
                                child: Icon(
                                  iconEntry.value,
                                  size: 22,
                                  color: isSelected
                                      ? cs.primary
                                      : cs.onSurfaceVariant,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
