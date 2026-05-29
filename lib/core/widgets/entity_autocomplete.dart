import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestfin/core/database/database_provider.dart';
import 'package:bestfin/core/database/app_database.dart' as db;
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';

final allEntitiesProvider = StreamProvider<List<db.Entity>>((ref) {
  final database = ref.watch(databaseProvider);
  return database.entitiesDao.watchAllEntities();
});

class EntityAutocomplete extends ConsumerStatefulWidget {
  final String? selectedEntityId;
  final String entityType; // 'payee', 'payer', etc.
  final Function(db.Entity?) onEntitySelected;
  final String label;

  const EntityAutocomplete({
    super.key,
    required this.selectedEntityId,
    required this.entityType,
    required this.onEntitySelected,
    this.label = 'Pagador / Recebedor',
  });

  @override
  ConsumerState<EntityAutocomplete> createState() => _EntityAutocompleteState();
}

class _EntityAutocompleteState extends ConsumerState<EntityAutocomplete> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  db.Entity? _currentEntity;

  final List<Map<String, dynamic>> _categories = [
    {'id': 'person', 'label': 'Pessoa', 'icon': Icons.person_outline},
    {'id': 'store', 'label': 'Loja/Mercado', 'icon': Icons.store_outlined},
    {'id': 'restaurant', 'label': 'Restaurante/Delivery', 'icon': Icons.restaurant_outlined},
    {'id': 'subscription', 'label': 'Assinatura/SaaS', 'icon': Icons.credit_card_outlined},
    {'id': 'work', 'label': 'Trabalho/Freelance', 'icon': Icons.work_outline},
    {'id': 'government', 'label': 'Governo/Imposto', 'icon': Icons.account_balance_outlined},
    {'id': 'health', 'label': 'Saúde', 'icon': Icons.medical_services_outlined},
    {'id': 'transport', 'label': 'Transporte', 'icon': Icons.directions_bus_outlined},
    {'id': 'education', 'label': 'Educação', 'icon': Icons.school_outlined},
    {'id': 'leisure', 'label': 'Lazer/Entretenimento', 'icon': Icons.movie_outlined},
    {'id': 'online_service', 'label': 'Serviço Online', 'icon': Icons.language_outlined},
    {'id': 'donation', 'label': 'Doação/Presente', 'icon': Icons.volunteer_activism_outlined},
  ];

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<String?> _showCategoryPicker() async {
    return showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Selecione a Categoria',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Flexible(
                child: GridView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 1,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final cat = _categories[index];
                    return InkWell(
                      onTap: () => Navigator.pop(context, cat['id']),
                      borderRadius: BorderRadius.circular(12),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(cat['icon'], size: 32, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(height: 4),
                          Text(
                            cat['label'],
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
  }

  Future<void> _createNewEntity(String name) async {
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

        return LayoutBuilder(
          builder: (context, constraints) {
            return RawAutocomplete<String>(
              textEditingController: _controller,
              focusNode: _focusNode,
              optionsBuilder: (TextEditingValue textEditingValue) {
                final search = textEditingValue.text.trim();
                if (search.isEmpty) {
                  return filteredEntities.map((e) => e.name);
                }

                final matched = filteredEntities
                    .where(
                      (e) =>
                          e.name.toLowerCase().contains(search.toLowerCase()),
                    )
                    .map((e) => e.name)
                    .toList();

                // Adiciona opção de criação inline se não houver correspondência exata
                final hasExactMatch = filteredEntities.any(
                  (e) => e.name.toLowerCase() == search.toLowerCase(),
                );

                if (!hasExactMatch && search.isNotEmpty) {
                  return [...matched, 'Criar "$search"'];
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
                    if (_currentEntity != null && _currentEntity!.category != null) {
                      final cat = _categories.firstWhere(
                        (c) => c['id'] == _currentEntity!.category,
                        orElse: () => {'icon': Icons.person_outline},
                      );
                      prefixIcon = cat['icon'];
                    }

                    return TextField(
                      controller: textController,
                      focusNode: focusNode,
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
                              final cat = _categories.firstWhere(
                                (c) => c['id'] == entity.category,
                                orElse: () => {'icon': Icons.person_rounded},
                              );
                              iconData = cat['icon'];
                            }
                          }

                          return InkWell(
                            onTap: () => onSelected(option),
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
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      error: (_, __) => TextField(
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
