import 'package:bestfin/cli/tui/screens/base.dart';
import 'package:bestfin/cli/tui/term.dart';
import 'package:bestfin/core/utils/icon_mapper.dart';
import 'package:bestfin/features/categories/domain/models/category.dart';

/// Categorias: árvore (pai → filhas), criação, edição, vínculo de subcategorias,
/// reordenação das raízes, arquivamento e exclusão.
class CategoriesScreen extends Screen {
  CategoriesScreen(super.ctx);

  @override
  String get title => 'Categorias';

  @override
  Future<void> run() async {
    while (true) {
      final tree = await ctx.categories.watchCategoriesTree().first;
      final flat = _flatten(tree);

      final items = flat
          .map(
            (e) =>
                '${'  ' * e.depth}${e.depth > 0 ? '└ ' : ''}'
                '${Term.pad(e.category.name, 28 - e.depth * 2)} '
                '${Term.gray}${Term.pad(_typeLabel(e.category.type), 12)}'
                '${e.category.isSystem ? ' sistema' : ''}${Term.reset}',
          )
          .toList();

      final choice = listMenu(
        title,
        items: items,
        subtitle: '${tree.length} raiz(es) • ${flat.length} no total',
        emptyMessage: 'Nenhuma categoria. Aperte "n" para criar.',
        actions: const [
          TermAction('n', 'nova'),
          TermAction('e', 'editar'),
          TermAction('s', 'subcategorias'),
          TermAction('o', 'reordenar raízes'),
          TermAction('d', 'excluir'),
        ],
      );
      if (choice == null) return;

      final (key, i) = choice;
      final cat = i >= 0 && i < flat.length ? flat[i].category : null;
      switch (key) {
        case 'n':
          await _create();
        case 'e':
          if (cat != null) await _edit(cat);
        case 's':
          if (cat != null) await _editChildren(cat, tree);
        case 'o':
          await _reorderRoots(tree);
        case 'd':
          if (cat != null) await _delete(cat);
        case '':
          if (cat != null) _detail(cat);
      }
    }
  }

  List<({CategoryModel category, int depth})> _flatten(
    List<CategoryModel> roots, [
    int depth = 0,
  ]) {
    final out = <({CategoryModel category, int depth})>[];
    for (final c in roots) {
      out.add((category: c, depth: depth));
      if (c.children.isNotEmpty) out.addAll(_flatten(c.children, depth + 1));
    }
    return out;
  }

  static String _typeLabel(String type) => switch (type) {
    'income' => 'Receita',
    'expense' => 'Despesa',
    'transfer' => 'Transferência',
    _ => type,
  };

  void _detail(CategoryModel c) {
    Term.pager('Categoria — ${c.name}', [
      '',
      '  ${Term.bold}${c.displayName}${Term.reset}',
      '',
      '  Tipo:          ${_typeLabel(c.type)}',
      '  Ícone:         ${c.icon}',
      '  Cor:           ${c.color}',
      '  Sistema:       ${c.isSystem ? 'sim' : 'não'}',
      '  Arquivada:     ${c.isArchived ? 'sim' : 'não'}',
      if (c.description != null && c.description!.isNotEmpty)
        '  Descrição:     ${c.description}',
      '  Subcategorias: ${c.children.isEmpty ? '—' : c.children.map((x) => x.name).join(', ')}',
      '  ID:            ${Term.gray}${c.id}${Term.reset}',
      '',
    ]);
  }

  Future<void> _create() async {
    Term.clear();
    Term.header('Nova categoria');
    Term.writeln();

    final name = Term.input('Nome:', allowEmpty: false);
    if (name == null || name.trim().isEmpty) return;

    final typeIndex = Term.select(
      'Tipo',
      items: const ['Despesa', 'Receita', 'Transferência'],
    );
    if (typeIndex == null) return;
    final type = ['expense', 'income', 'transfer'][typeIndex];

    final icon = _pickIcon();
    if (icon == null) return;

    final color = Term.input('Cor (hex, ex #4CAF50):', initial: '#607D8B');
    if (color == null) return;

    final description = Term.input('Descrição (opcional):');
    if (description == null) return;

    await guard(
      () => ctx.categories.createCategory(
        name: name.trim(),
        icon: icon,
        color: color.trim().isEmpty ? '#607D8B' : color.trim(),
        type: type,
        description: description.trim().isEmpty ? null : description.trim(),
      ),
      successMessage: 'Categoria "${name.trim()}" criada.',
    );
  }

  Future<void> _edit(CategoryModel c) async {
    Term.clear();
    Term.header('Editar categoria — ${c.name}');
    Term.writeln();

    final name = Term.input('Nome:', initial: c.name, allowEmpty: false);
    if (name == null) return;

    final types = ['expense', 'income', 'transfer'];
    final typeIndex = Term.select(
      'Tipo',
      items: const ['Despesa', 'Receita', 'Transferência'],
      initialIndex: types.indexOf(c.type).clamp(0, 2),
    );
    if (typeIndex == null) return;

    final icon = _pickIcon(current: c.icon);
    if (icon == null) return;

    final color = Term.input('Cor (hex):', initial: c.color);
    if (color == null) return;

    final description = Term.input(
      'Descrição (opcional):',
      initial: c.description ?? '',
    );
    if (description == null) return;

    await guard(
      () => ctx.categories.updateCategory(
        id: c.id,
        name: name.trim(),
        icon: icon,
        color: color.trim().isEmpty ? c.color : color.trim(),
        type: types[typeIndex],
        description: description.trim().isEmpty ? null : description.trim(),
      ),
      successMessage: 'Categoria atualizada.',
    );
  }

  /// Escolhe um nome de ícone entre os suportados pelo `IconMapper` —
  /// as mesmas chaves usadas pela GUI.
  String? _pickIcon({String? current}) {
    final keys = IconMapper.all.keys.toList()..sort();
    final initial = current == null ? 0 : keys.indexOf(current);
    final i = Term.select(
      'Ícone',
      items: keys,
      subtitle: 'mesmas chaves usadas pelo app gráfico',
      initialIndex: initial < 0 ? 0 : initial,
    );
    return i == null ? null : keys[i];
  }

  /// Define quais categorias raiz viram filhas de [parent].
  Future<void> _editChildren(
    CategoryModel parent,
    List<CategoryModel> tree,
  ) async {
    final candidates = tree
        .where((c) => c.id != parent.id && c.type == parent.type)
        .toList();
    if (candidates.isEmpty) {
      Term.alert(
        'Subcategorias',
        'Não há outras categorias raiz do mesmo tipo para vincular.',
      );
      return;
    }
    final currentIds = parent.children.map((c) => c.id).toSet();
    final initial = <int>{
      for (var i = 0; i < candidates.length; i++)
        if (currentIds.contains(candidates[i].id)) i,
    };

    final picked = pickMulti<CategoryModel>(
      'Subcategorias de ${parent.name}',
      candidates,
      (c) => c.name,
      initial: initial,
    );
    if (picked == null) return;

    await guard(
      () => ctx.categories.setCategoryChildren(
        parent.id,
        picked.map((i) => candidates[i].id).toList(),
      ),
      successMessage: 'Subcategorias atualizadas.',
    );
  }

  /// Reordena as categorias raiz (mesma ordem exibida na GUI).
  Future<void> _reorderRoots(List<CategoryModel> tree) async {
    if (tree.length < 2) {
      Term.alert('Reordenar', 'É preciso ao menos duas categorias raiz.');
      return;
    }
    final order = [...tree];
    var index = 0;
    while (true) {
      Term.clear();
      Term.header(
        'Reordenar categorias',
        subtitle: 'setas movem o cursor • J/K movem o item • s salva',
      );
      for (var i = 0; i < order.length; i++) {
        final cursor = i == index ? '${Term.cyan}❯ ${Term.reset}' : '  ';
        Term.writeln('$cursor${order[i].name}');
      }
      Term.footer(const [
        TermAction('↑↓', 'navegar'),
        TermAction('J/K', 'mover item'),
        TermAction('s', 'salvar'),
        TermAction('q', 'cancelar'),
      ]);

      final key = Term.readKey();
      if (key.code == KeyCode.up) {
        index = index == 0 ? order.length - 1 : index - 1;
      } else if (key.code == KeyCode.down) {
        index = (index + 1) % order.length;
      } else if (key.isChar && key.char == 'K' && index > 0) {
        final item = order.removeAt(index);
        order.insert(--index, item);
      } else if (key.isChar && key.char == 'J' && index < order.length - 1) {
        final item = order.removeAt(index);
        order.insert(++index, item);
      } else if (key.is_('s')) {
        await guard(
          () => ctx.categories.saveRootOrder(order.map((c) => c.id).toList()),
          successMessage: 'Ordem salva.',
        );
        return;
      } else if (key.code == KeyCode.esc ||
          key.code == KeyCode.ctrlC ||
          key.is_('q')) {
        return;
      }
    }
  }

  Future<void> _delete(CategoryModel c) async {
    if (c.isSystem) {
      Term.alert(
        'Excluir categoria',
        'Categorias do sistema não podem ser excluídas.',
      );
      return;
    }
    final hasTx = await ctx.categories.hasTransactions(c.id);
    if (hasTx) {
      Term.clear();
      Term.header('Categoria em uso — ${c.name}');
      Term.writeln();
      Term.warn('Existem lançamentos usando esta categoria.');
      Term.writeln();
      if (Term.confirm('Arquivar em vez de excluir?', defaultYes: true)) {
        await guard(
          () => ctx.categories.archiveCategory(c.id),
          successMessage: 'Categoria arquivada.',
        );
      }
      return;
    }
    if (!Term.confirm('Excluir "${c.name}"?')) return;
    await guard(
      () => ctx.categories.deleteCategory(c.id),
      successMessage: 'Categoria excluída.',
    );
  }
}
