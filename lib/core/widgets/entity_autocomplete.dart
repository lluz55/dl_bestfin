import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:bestfin/core/widgets/loading_indicator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestfin/core/database/database_provider.dart';
import 'package:bestfin/core/database/app_database.dart' as db;
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';
import 'package:bestfin/core/providers/entity_categories_provider.dart';

final allEntitiesProvider = StreamProvider<List<db.Entity>>((ref) {
  final database = ref.watch(databaseProvider);
  return database.entitiesDao.watchAllEntities();
});

/// Lets a parent form force-resolve whatever the user typed into
/// [EntityAutocomplete] before validating/saving, instead of relying on the
/// field losing focus (which races with button taps — see [commit]).
class EntityAutocompleteController {
  _EntityAutocompleteState? _state;

  void _attach(_EntityAutocompleteState state) => _state = state;

  void _detach(_EntityAutocompleteState state) {
    if (_state == state) _state = null;
  }

  /// Resolves the currently typed text into a selected (or newly created)
  /// entity if it hasn't been resolved yet. Await this before checking
  /// whether the field was "filled in" — e.g. right before validating a page
  /// transition or saving — so a name the user typed but never explicitly
  /// picked from the suggestion list isn't treated as empty.
  Future<void> commit() => _state?._acceptTypedValue() ?? Future.value();
}

class EntityAutocomplete extends ConsumerStatefulWidget {
  final String? selectedEntityId;
  final String entityType; // 'payee', 'payer', etc.
  final Function(db.Entity?) onEntitySelected;
  final String label;
  final FocusNode? focusNode;
  final ValueChanged<String>? onFieldSubmitted;
  final EntityAutocompleteController? controller;

  const EntityAutocomplete({
    super.key,
    required this.selectedEntityId,
    required this.entityType,
    required this.onEntitySelected,
    this.label = 'Pagador / Recebedor',
    this.focusNode,
    this.onFieldSubmitted,
    this.controller,
  });

  @override
  ConsumerState<EntityAutocomplete> createState() => _EntityAutocompleteState();
}

class _EntityAutocompleteState extends ConsumerState<EntityAutocomplete> {
  final TextEditingController _controller = TextEditingController();
  late final FocusNode _focusNode;
  db.Entity? _currentEntity;
  bool _showSuggestions = false;
  List<db.Entity> _lastFilteredEntities = [];

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChange);
    _controller.addListener(_onTextChanged);
    widget.controller?._attach(this);
  }

  @override
  void dispose() {
    widget.controller?._detach(this);
    _controller.removeListener(_onTextChanged);
    _focusNode.removeListener(_onFocusChange);
    _controller.dispose();
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {
      _showSuggestions = _focusNode.hasFocus;
    });
    if (!_focusNode.hasFocus) {
      _acceptTypedValue();
    }
  }

  db.Entity? _matchByName(String name) {
    for (final e in _lastFilteredEntities) {
      if (e.name.toLowerCase() == name.toLowerCase()) return e;
    }
    return null;
  }

  /// Resolves whatever the user typed into a selected entity even if they
  /// never explicitly tapped a suggestion — e.g. they typed a brand-new name
  /// and just moved on to the next field. Without this, the typed text stays
  /// visible in the field but [_currentEntity] (and therefore the value
  /// reported via [EntityAutocomplete.onEntitySelected]) is never set, so the
  /// form treats the field as empty and rejects a name that looks "entered".
  /// Unlike the explicit "Criar" suggestion, this path skips the category
  /// picker so it never blocks on an extra modal.
  Future<void> _acceptTypedValue() async {
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

    final existing = _matchByName(text);
    final entity = existing ?? await _persistNewEntity(text);
    if (!mounted) return;
    widget.onEntitySelected(entity);
    setState(() {
      _currentEntity = entity;
      _controller.text = entity.name;
    });
  }

  void _onTextChanged() {
    setState(() {});
  }

  Future<EntityCategory?> _showCreateCategorySheet() async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    String selectedIconKey = 'person';

    return showModalBottomSheet<EntityCategory>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
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
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
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
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Consumer(
          builder: (context, ref, child) {
            final categories = ref.watch(entityCategoriesProvider);
            return SizedBox(
              height: MediaQuery.of(context).size.height * 0.65,
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  Text(
                    'Selecione a Categoria',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
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

  /// Inserts a new entity with an optional category and returns it. Category
  /// is metadata only (nullable in the table) — never a reason to fail the
  /// user's actual intent of registering this name.
  Future<db.Entity> _persistNewEntity(String name, {String? categoryId}) async {
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

    return db.Entity(
      id: newId,
      name: name,
      type: widget.entityType,
      category: categoryId,
      useCount: 0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  // Explicit "Criar" selection: offers a category picker, but dismissing it
  // (tapping outside, back button) still creates the entity without a
  // category instead of silently discarding the name the user typed.
  Future<void> _createNewEntity(String name) async {
    final categoryId = await _showCategoryPicker();
    final created = await _persistNewEntity(name, categoryId: categoryId);
    if (!mounted) return;

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
          // Não limpa o texto agressivamente se o usuário estiver digitando
          if (!_focusNode.hasFocus && _controller.text.isNotEmpty) {
            _controller.clear();
          }
        }

        final filteredEntities = entities
            .where((e) => e.type == widget.entityType)
            .toList();
        _lastFilteredEntities = filteredEntities;

        final search = _controller.text.trim();
        final List<String> suggestions = [];
        if (search.isEmpty) {
          suggestions.addAll(filteredEntities.map((e) => e.name));
        } else {
          final matched = filteredEntities
              .where((e) => e.name.toLowerCase().contains(search.toLowerCase()))
              .map((e) => e.name)
              .toList();
          suggestions.addAll(matched);

          final hasExactMatch = filteredEntities.any(
            (e) => e.name.toLowerCase() == search.toLowerCase(),
          );

          if (!hasExactMatch && search.isNotEmpty) {
            suggestions.add('Criar "$search"');
          }
        }

        final isMobile = MediaQuery.of(context).size.width < 600;

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isMobile && _showSuggestions && suggestions.isNotEmpty) ...[
              SizedBox(
                height: 40,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  itemCount: suggestions.length,
                  itemBuilder: (BuildContext context, int index) {
                    final String option = suggestions[index];
                    final isCreateOption = option.startsWith('Criar "');

                    IconData iconData = isCreateOption
                        ? Icons.add_circle_outline
                        : Icons.person_rounded;

                    if (!isCreateOption) {
                      final entity = filteredEntities.firstWhere(
                        (e) => e.name == option,
                        orElse: () => filteredEntities.first,
                      );
                      if (entity.category != null) {
                        final cat = categories.firstWhere(
                          (c) => c.id == entity.category,
                          orElse: () => const EntityCategory(
                            id: '',
                            label: '',
                            icon: Icons.person_rounded,
                            iconKey: '',
                          ),
                        );
                        iconData = cat.icon;
                      }
                    }

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ActionChip(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        labelPadding: EdgeInsets.zero,
                        avatar: Icon(
                          iconData,
                          color: isCreateOption
                              ? cs.primary
                              : cs.onSurfaceVariant,
                          size: 16,
                        ),
                        label: Text(
                          option,
                          style: TextStyle(
                            color: isCreateOption ? cs.primary : cs.onSurface,
                            fontWeight: isCreateOption
                                ? FontWeight.bold
                                : FontWeight.normal,
                            fontSize: 13,
                          ),
                        ),
                        backgroundColor: cs.surfaceContainerLow,
                        side: BorderSide(
                          color: isCreateOption
                              ? cs.primary.withValues(alpha: 0.5)
                              : cs.outlineVariant,
                          width: 0.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        onPressed: () async {
                          if (isCreateOption) {
                            final name = option.substring(7, option.length - 1);
                            await _createNewEntity(name);
                          } else {
                            final entity = filteredEntities.firstWhere(
                              (e) => e.name == option,
                            );
                            widget.onEntitySelected(entity);
                            setState(() {
                              _currentEntity = entity;
                              _controller.text = entity.name;
                            });
                          }
                        },
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
            LayoutBuilder(
              builder: (context, constraints) {
                return RawAutocomplete<String>(
                  textEditingController: _controller,
                  focusNode: _focusNode,
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    if (isMobile) {
                      return const Iterable<String>.empty();
                    }

                    final searchVal = textEditingValue.text.trim();
                    if (searchVal.isEmpty) {
                      return filteredEntities.map((e) => e.name);
                    }

                    final matched = filteredEntities
                        .where(
                          (e) => e.name.toLowerCase().contains(
                            searchVal.toLowerCase(),
                          ),
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
                          textInputAction: TextInputAction.done,
                          onSubmitted: (value) {
                            onFieldSubmitted();
                            _acceptTypedValue();
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
                    final isLinux =
                        defaultTargetPlatform == TargetPlatform.linux;
                    return Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        elevation: 8,
                        borderRadius: BorderRadius.circular(16),
                        color: cs.surfaceContainerHigh,
                        child: Container(
                          width: constraints.maxWidth,
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
                              final isCreateOption = option.startsWith(
                                'Criar "',
                              );

                              IconData iconData = isCreateOption
                                  ? Icons.add_circle_outline
                                  : Icons.person_rounded;

                              if (!isCreateOption) {
                                final entity = filteredEntities.firstWhere(
                                  (e) => e.name == option,
                                  orElse: () => filteredEntities.first,
                                );
                                if (entity.category != null) {
                                  final cat = categories.firstWhere(
                                    (c) => c.id == entity.category,
                                    orElse: () => const EntityCategory(
                                      id: '',
                                      label: '',
                                      icon: Icons.person_rounded,
                                      iconKey: '',
                                    ),
                                  );
                                  iconData = cat.icon;
                                }
                              }

                              return InkWell(
                                onTap: isLinux
                                    ? null
                                    : () => onSelected(option),
                                onTapDown: isLinux
                                    ? (_) => onSelected(option)
                                    : null,
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
            ),
          ],
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
