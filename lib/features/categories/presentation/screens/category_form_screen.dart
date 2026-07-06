import 'package:flutter/material.dart';
import 'package:bestfin/core/widgets/app_button.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/widgets/app_page_appbar.dart';
import 'package:bestfin/core/widgets/category_icon.dart';
import 'package:bestfin/core/widgets/category_multi_select_button.dart';
import 'package:bestfin/core/widgets/icon_color_picker_button.dart';
import 'package:bestfin/features/categories/domain/models/category.dart';
import 'package:bestfin/features/categories/presentation/providers/categories_provider.dart';

class CategoryFormScreen extends ConsumerStatefulWidget {
  const CategoryFormScreen({super.key, this.categoryToEdit});

  final CategoryModel? categoryToEdit;

  @override
  ConsumerState<CategoryFormScreen> createState() => _CategoryFormScreenState();
}

class _CategoryFormScreenState extends ConsumerState<CategoryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  late String _icon;
  late String _color;
  late String _type;
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
      _descriptionController.text = c.description ?? '';
      _selectedSubcategoryIds.addAll(c.children.map((child) => child.id));
    } else {
      _icon = 'category';
      _color = '#2196F3';
      _type = 'expense';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      final descriptionVal = _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim();

      final String categoryId;
      if (_isEditing) {
        categoryId = widget.categoryToEdit!.id;
        await ref.read(updateCategoryProvider)(
          id: categoryId,
          name: _nameController.text.trim(),
          icon: _icon,
          color: _color,
          type: _type,
          description: descriptionVal,
        );
      } else {
        categoryId = await ref.read(createCategoryProvider)(
          name: _nameController.text.trim(),
          icon: _icon,
          color: _color,
          type: _type,
          description: descriptionVal,
        );
      }

      await ref.read(setCategoryChildrenProvider)(
        categoryId,
        _selectedSubcategoryIds.toList(),
      );

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

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.textTheme;

    final allCategories = ref.watch(allFlatCategoriesProvider);
    final editingId = widget.categoryToEdit?.id;

    // All leaf categories of the same type that aren't this category
    final candidates =
        allCategories
            .where(
              (c) =>
                  !c.isArchived &&
                  !c.hasChildren &&
                  c.id != editingId &&
                  c.type == _type,
            )
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));

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

              // Descrição
              TextFormField(
                controller: _descriptionController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Descrição',
                  hintText:
                      'Breve descrição da categoria (ajuda a IA a classificar transações)',
                  filled: true,
                  fillColor: cs.surfaceContainerHigh,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
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
                onSelectionChanged: (s) => setState(() => _type = s.first),
              ),
              const SizedBox(height: 16),

              // Ícone e Cor (combinados)
              IconColorPickerButton(
                selectedIcon: _icon,
                selectedColorHex: _color,
                onChanged: (icon, color) => setState(() {
                  _icon = icon;
                  _color = color;
                }),
              ),
              const SizedBox(height: 16),

              // Subcategorias
              if (candidates.isNotEmpty) ...[
                Text(
                  'Subcategorias',
                  style: tt.labelLarge?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 8),
                CategoryMultiSelectButton(
                  selectedIds: _selectedSubcategoryIds.toList(),
                  onChanged: (ids) => setState(() {
                    _selectedSubcategoryIds
                      ..clear()
                      ..addAll(ids);
                  }),
                  candidates: candidates,
                  label: 'Usar como subcategorias',
                ),
                const SizedBox(height: 16),
              ],

              const SizedBox(height: 16),

              // Save button
              AppButton(
                label: _isEditing ? 'Salvar Alterações' : 'Criar Categoria',
                expanded: true,
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
