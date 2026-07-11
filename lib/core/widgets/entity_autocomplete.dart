import 'package:flutter/material.dart';
import 'package:bestfin/core/widgets/loading_indicator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestfin/core/database/database_provider.dart';
import 'package:bestfin/core/database/app_database.dart' as db;
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/theme/breakpoints.dart';
import 'package:bestfin/core/utils/adaptive_modal.dart';
import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';
import 'package:bestfin/core/providers/entity_categories_provider.dart';

final allEntitiesProvider = StreamProvider<List<db.Entity>>((ref) {
  final database = ref.watch(databaseProvider);
  return database.entitiesDao.watchAllEntities();
});

class EntityAutocomplete extends ConsumerStatefulWidget {
  final String? selectedEntityId;
  final String entityType; // 'payee', 'payer', etc.
  final Function(db.Entity?) onEntitySelected;
  final String label;
  final FocusNode? focusNode;
  final ValueChanged<String>? onFieldSubmitted;

  const EntityAutocomplete({
    super.key,
    required this.selectedEntityId,
    required this.entityType,
    required this.onEntitySelected,
    this.label = 'Pagador / Recebedor',
    this.focusNode,
    this.onFieldSubmitted,
  });

  @override
  ConsumerState<EntityAutocomplete> createState() => _EntityAutocompleteState();
}

class _EntityAutocompleteState extends ConsumerState<EntityAutocomplete> {
  final TextEditingController _controller = TextEditingController();
  late final FocusNode _focusNode;
  db.Entity? _currentEntity;
  List<db.Entity> _filteredEntities = const [];

  /// Evita abrir o seletor de categoria duas vezes ao criar uma entidade nova:
  /// tocar em `Criar "..."` chama [_createNewEntity] e, ao abrir o modal, o
  /// campo perde o foco disparando [_commitTypedText], que tentaria criar de
  /// novo. Este flag serializa a criação em um único fluxo.
  bool _isCreatingEntity = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChange);
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _focusNode.removeListener(_onFocusChange);
    _controller.dispose();
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) {
      _commitTypedText();
    }
  }

  void _onTextChanged() {
    setState(() {});
  }

  /// Resolve o texto digitado ao perder o foco ou ao confirmar no teclado:
  /// seleciona a entidade existente com nome igual (ignorando maiúsculas) ou
  /// cria uma nova automaticamente, em vez de simplesmente descartar o texto
  /// quando o usuário não toca explicitamente no chip/opção "Criar".
  Future<void> _commitTypedText() async {
    // Criação já em andamento (disparada pela opção "Criar"): não abrir um
    // segundo seletor de categoria.
    if (_isCreatingEntity) return;
    final text = _controller.text.trim();
    if (text.isEmpty) {
      if (_currentEntity != null) {
        widget.onEntitySelected(null);
        setState(() => _currentEntity = null);
      }
      return;
    }
    if (_currentEntity != null &&
        _currentEntity!.name.toLowerCase() == text.toLowerCase()) {
      return;
    }
    final match = _filteredEntities.firstWhere(
      (e) => e.name.toLowerCase() == text.toLowerCase(),
      orElse: () => db.Entity(
        id: '',
        name: '',
        type: '',
        useCount: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    if (match.id.isNotEmpty) {
      widget.onEntitySelected(match);
      setState(() {
        _currentEntity = match;
        _controller.text = match.name;
      });
    } else {
      // Nome novo confirmado (Enter/Próximo/perda de foco): abre o seletor de
      // categoria — categoria do recebedor/pagador é obrigatória ao criar.
      await _createNewEntity(text);
    }
  }

  Future<EntityCategory?> _showCreateCategorySheet() async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    String selectedIconKey = 'person';

    return showAdaptiveModal<EntityCategory>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Nova Categoria',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: nameController,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: 'Nome da Categoria',
                        hintText: 'Ex: Academia, Presentes...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        prefixIcon: Icon(
                          entityIconMap[selectedIconKey] ??
                              Icons.category_outlined,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Digite o nome da categoria';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Selecione um Ícone',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 180,
                      child: GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 6,
                              mainAxisSpacing: 8,
                              crossAxisSpacing: 8,
                            ),
                        itemCount: entityIconMap.keys.length,
                        itemBuilder: (context, index) {
                          final key = entityIconMap.keys.elementAt(index);
                          final icon = entityIconMap[key]!;
                          final isSelected = key == selectedIconKey;

                          return InkWell(
                            onTap: () {
                              setModalState(() {
                                selectedIconKey = key;
                              });
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Theme.of(
                                        context,
                                      ).colorScheme.primaryContainer
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(
                                          context,
                                        ).colorScheme.outlineVariant,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Icon(
                                icon,
                                color: isSelected
                                    ? Theme.of(
                                        context,
                                      ).colorScheme.onPrimaryContainer
                                    : Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: () async {
                        if (formKey.currentState!.validate()) {
                          final label = nameController.text.trim();
                          final newCat = await ref
                              .read(entityCategoriesProvider.notifier)
                              .addCustomCategory(label, selectedIconKey);
                          if (context.mounted) {
                            Navigator.pop(context, newCat);
                          }
                        }
                      },
                      child: const Text('Salvar Categoria'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<String?> _showCategoryPicker() async {
    // Usa o mesmo apresentador adaptativo do modal de nova/editar transação:
    // bottom sheet no mobile e painel flutuante (canto inferior direito) em
    // telas largas — garantindo tamanho e posicionamento idênticos.
    return showAdaptiveModal<String>(
      context: context,
      builder: (context) {
        final tt = context.textTheme;
        final isCompact = Breakpoints.isCompact(context);
        return Consumer(
          builder: (context, ref, child) {
            final categories = ref.watch(entityCategoriesProvider);
            return SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      isCompact ? 8 : 20,
                      16,
                      12,
                    ),
                    child: Text(
                      'Selecione a Categoria',
                      style: tt.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Flexible(
                    child: GridView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            childAspectRatio: 1,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                          ),
                      itemCount: categories.length + 1,
                      itemBuilder: (context, index) {
                        if (index == categories.length) {
                          return InkWell(
                            onTap: () async {
                              final newCat = await _showCreateCategorySheet();
                              if (newCat != null && context.mounted) {
                                Navigator.pop(context, newCat.id);
                              }
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.primary,
                                  style: BorderStyle.solid,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_circle_outline,
                                    size: 32,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Incluir Nova',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        final cat = categories[index];
                        return InkWell(
                          onTap: () => Navigator.pop(context, cat.id),
                          borderRadius: BorderRadius.circular(12),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                cat.icon,
                                size: 32,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                cat.label,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 10),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _createNewEntity(String name) async {
    if (_isCreatingEntity) return;
    _isCreatingEntity = true;
    try {
      await _createNewEntityInner(name);
    } finally {
      _isCreatingEntity = false;
    }
  }

  Future<void> _createNewEntityInner(String name) async {
    final categoryId = await _showCategoryPicker();
    if (categoryId == null) return;

    final database = ref.read(databaseProvider);
    final newId = const Uuid().v4();

    final newEntity = db.EntitiesCompanion.insert(
      id: newId,
      name: name,
      type: widget.entityType,
      category: drift.Value(categoryId),
      useCount: const drift.Value(0),
      createdAt: drift.Value(DateTime.now()),
      updatedAt: drift.Value(DateTime.now()),
    );

    await database.entitiesDao.insertEntity(newEntity);

    final created = db.Entity(
      id: newId,
      name: name,
      type: widget.entityType,
      category: categoryId,
      useCount: 0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    widget.onEntitySelected(created);
    setState(() {
      _currentEntity = created;
      _controller.text = name;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final entitiesAsync = ref.watch(allEntitiesProvider);
    final categories = ref.watch(entityCategoriesProvider);

    return entitiesAsync.when(
      data: (entities) {
        // Encontra entidade selecionada se houver
        if (widget.selectedEntityId != null &&
            _currentEntity?.id != widget.selectedEntityId) {
          final found = entities.firstWhere(
            (e) => e.id == widget.selectedEntityId,
            orElse: () => db.Entity(
              id: '',
              name: '',
              type: '',
              useCount: 0,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );
          if (found.id.isNotEmpty) {
            _currentEntity = found;
            _controller.text = found.name;
          }
        } else if (widget.selectedEntityId == null) {
          _currentEntity = null;
        }

        final filteredEntities = entities
            .where((e) => e.type == widget.entityType)
            .toList();
        _filteredEntities = filteredEntities;

        final isMobile = MediaQuery.of(context).size.width < 600;

        IconData iconForOption(String option, bool isCreateOption) {
          if (isCreateOption) return Icons.add_circle_outline;
          final entity = filteredEntities.firstWhere(
            (e) => e.name == option,
            orElse: () => filteredEntities.first,
          );
          if (entity.category == null) return Icons.person_rounded;
          final cat = categories.firstWhere(
            (c) => c.id == entity.category,
            orElse: () => const EntityCategory(
              id: '',
              label: '',
              icon: Icons.person_rounded,
              iconKey: '',
            ),
          );
          return cat.icon;
        }

        return RawAutocomplete<String>(
          textEditingController: _controller,
          focusNode: _focusNode,
          // Sugestões flutuam acima do campo (overlay do próprio
          // RawAutocomplete) em vez de empurrar o resto do formulário.
          optionsViewOpenDirection: OptionsViewOpenDirection.up,
          optionsBuilder: (TextEditingValue textEditingValue) {
            final searchVal = textEditingValue.text.trim();
            if (searchVal.isEmpty) {
              return filteredEntities.map((e) => e.name);
            }

            final matched = filteredEntities
                .where(
                  (e) => e.name.toLowerCase().contains(searchVal.toLowerCase()),
                )
                .map((e) => e.name)
                .toList();

            final hasExactMatch = filteredEntities.any(
              (e) => e.name.toLowerCase() == searchVal.toLowerCase(),
            );

            if (!hasExactMatch && searchVal.isNotEmpty) {
              return [...matched, 'Criar "$searchVal"'];
            }
            return matched;
          },
          onSelected: (String selection) async {
            if (selection.startsWith('Criar "')) {
              final name = selection.substring(7, selection.length - 1);
              await _createNewEntity(name);
            } else {
              final entity = filteredEntities.firstWhere(
                (e) => e.name == selection,
              );
              widget.onEntitySelected(entity);
              setState(() {
                _currentEntity = entity;
                _controller.text = entity.name;
              });
            }
          },
          fieldViewBuilder:
              (context, textController, focusNode, onFieldSubmitted) {
                IconData prefixIcon = Icons.person_outline;
                if (_currentEntity != null &&
                    _currentEntity!.category != null) {
                  final cat = categories.firstWhere(
                    (c) => c.id == _currentEntity!.category,
                    orElse: () => const EntityCategory(
                      id: '',
                      label: '',
                      icon: Icons.person_outline,
                      iconKey: '',
                    ),
                  );
                  prefixIcon = cat.icon;
                }

                return TextField(
                  controller: textController,
                  focusNode: focusNode,
                  textInputAction: widget.onFieldSubmitted != null
                      ? TextInputAction.next
                      : TextInputAction.done,
                  onSubmitted: (value) async {
                    await _commitTypedText();
                    onFieldSubmitted();
                    widget.onFieldSubmitted?.call(value);
                  },
                  decoration: InputDecoration(
                    labelText: widget.label,
                    hintText: 'Digite o nome do favorecido...',
                    prefixIcon: Icon(prefixIcon),
                    suffixIcon: textController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              textController.clear();
                              widget.onEntitySelected(null);
                              setState(() {
                                _currentEntity = null;
                              });
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                );
              },
          optionsViewBuilder: (context, onSelected, options) {
            // Mobile: faixa horizontal de chips (compacta, rolável).
            if (isMobile) {
              // bottomStart: com optionsViewOpenDirection.up, o framework
              // reserva todo o espaço disponível ACIMA do campo (que pode
              // ser quase a tela toda dentro de um bottom sheet) — alinhar
              // pela base é o que cola este conteúdo rente ao campo, em vez
              // de flutuar solto no topo desse espaço.
              return Align(
                alignment: AlignmentDirectional.bottomStart,
                child: SizedBox(
                  height: 40,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      final option = options.elementAt(index);
                      final isCreateOption = option.startsWith('Criar "');
                      final iconData = iconForOption(option, isCreateOption);

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Material(
                          color: cs.surfaceContainerHigh,
                          elevation: 4,
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            // canRequestFocus:false + onTapDown (em vez de
                            // onTap/ActionChip): tocar aqui não pode tirar o
                            // foco do campo antes do tap terminar, senão o
                            // RawAutocomplete esconde este overlay no meio
                            // do gesto e a seleção nunca dispara.
                            canRequestFocus: false,
                            onTapDown: (_) => onSelected(option),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isCreateOption
                                      ? cs.primary.withValues(alpha: 0.5)
                                      : cs.outlineVariant,
                                  width: 0.5,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    iconData,
                                    color: isCreateOption
                                        ? cs.primary
                                        : cs.onSurfaceVariant,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    option,
                                    style: TextStyle(
                                      color: isCreateOption
                                          ? cs.primary
                                          : cs.onSurface,
                                      fontWeight: isCreateOption
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              );
            }

            // Desktop/tablet: lista vertical.
            // bottomStart (ver comentário acima): cola a lista rente ao
            // campo em vez de alinhá-la ao topo do espaço reservado.
            return Align(
              alignment: AlignmentDirectional.bottomStart,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(16),
                color: cs.surfaceContainerHigh,
                child: Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxHeight: 250),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: cs.outlineVariant),
                  ),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (BuildContext context, int index) {
                      final String option = options.elementAt(index);
                      final isCreateOption = option.startsWith('Criar "');
                      final iconData = iconForOption(option, isCreateOption);

                      return InkWell(
                        // onTapDown (não onTap) evita a corrida com a
                        // perda de foco do campo ao tocar na opção: o
                        // foco tirado do TextField dispara um rebuild
                        // que pode remover esta lista antes do tap
                        // (pointer-up) terminar de ser reconhecido.
                        canRequestFocus: false,
                        onTapDown: (_) => onSelected(option),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                iconData,
                                color: isCreateOption
                                    ? cs.primary
                                    : cs.onSurfaceVariant,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  option,
                                  style: TextStyle(
                                    color: isCreateOption
                                        ? cs.primary
                                        : cs.onSurface,
                                    fontWeight: isCreateOption
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        );
      },
      loading: () => TextField(
        enabled: false,
        decoration: InputDecoration(
          labelText: widget.label,
          prefixIcon: const Icon(Icons.person_outline),
          suffixIcon: const SizedBox(
            width: 20,
            height: 20,
            child: AppLoadingIndicator(strokeWidth: 2),
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      error: (error, stackTrace) => TextField(
        enabled: false,
        decoration: InputDecoration(
          labelText: widget.label,
          prefixIcon: const Icon(Icons.person_outline),
          helperText: 'Erro ao carregar favorecidos',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }
}
