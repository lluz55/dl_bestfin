import 'package:flutter/material.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';

class AppIconPicker extends StatefulWidget {
  const AppIconPicker({
    super.key,
    required this.selectedIconCodePoint,
    required this.onIconSelected,
  });

  final String selectedIconCodePoint;
  final ValueChanged<IconData> onIconSelected;

  static const Map<String, List<(IconData icon, String name)>>
  categorizedIcons = {
    'Finanças': [
      (Icons.account_balance_rounded, 'Banco'),
      (Icons.wallet_rounded, 'Carteira'),
      (Icons.trending_up_rounded, 'Investimentos'),
      (Icons.savings_rounded, 'Poupança'),
      (Icons.payments_rounded, 'Pagamentos'),
      (Icons.credit_card_rounded, 'Cartão'),
      (Icons.monetization_on_rounded, 'Moeda'),
      (Icons.attach_money_rounded, 'Dinheiro'),
      (Icons.shield_rounded, 'Reserva'),
      (Icons.account_balance_wallet_rounded, 'Saldo'),
    ],
    'Estilo de Vida': [
      (Icons.home_rounded, 'Moradia'),
      (Icons.directions_car_rounded, 'Transporte'),
      (Icons.restaurant_rounded, 'Alimentação'),
      (Icons.shopping_cart_rounded, 'Compras'),
      (Icons.favorite_rounded, 'Saúde'),
      (Icons.school_rounded, 'Educação'),
      (Icons.movie_rounded, 'Lazer'),
      (Icons.work_rounded, 'Trabalho'),
      (Icons.person_rounded, 'Pessoal'),
      (Icons.family_restroom_rounded, 'Família'),
    ],
    'Geral': [
      (Icons.star_rounded, 'Estrela'),
      (Icons.store_rounded, 'Loja'),
      (Icons.flight_rounded, 'Viagem'),
      (Icons.sports_esports_rounded, 'Jogos'),
      (Icons.lock_rounded, 'Segurança'),
      (Icons.build_rounded, 'Ferramentas'),
      (Icons.pets_rounded, 'Pet'),
      (Icons.local_gas_station_rounded, 'Combustível'),
      (Icons.phone_iphone_rounded, 'Celular'),
      (Icons.local_hospital_rounded, 'Médico'),
    ],
  };

  @override
  State<AppIconPicker> createState() => _AppIconPickerState();
}

class _AppIconPickerState extends State<AppIconPicker> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<(IconData icon, String name)> get _filteredIcons {
    if (_searchQuery.isEmpty) {
      return AppIconPicker.categorizedIcons.values.expand((list) => list).toList();
    }

    final query = _searchQuery.toLowerCase();
    return AppIconPicker.categorizedIcons.values
        .expand((list) => list)
        .where((item) => item.$2.toLowerCase().contains(query))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Selecione um ícone',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Buscar ícone...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHigh,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                  });
                },
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _searchQuery.isNotEmpty
                    ? _buildGrid(_filteredIcons, scrollController)
                    : ListView(
                        controller: scrollController,
                        children: AppIconPicker.categorizedIcons.entries.map((entry) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                child: Text(
                                  entry.key,
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                              _buildGrid(entry.value, null),
                              const SizedBox(height: 16),
                            ],
                          );
                        }).toList(),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGrid(
    List<(IconData icon, String name)> items,
    ScrollController? controller,
  ) {
    final theme = context.theme;

    return GridView.builder(
      controller: controller,
      shrinkWrap: controller == null,
      physics: controller == null
          ? const NeverScrollableScrollPhysics()
          : const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
      ),
      itemCount: items.length,
      itemBuilder: (context, idx) {
        final item = items[idx];
        final isSelected =
            item.$1.codePoint.toString() == widget.selectedIconCodePoint;

        return InkWell(
          onTap: () {
            widget.onIconSelected(item.$1);
            Navigator.pop(context);
          },
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: isSelected
                  ? theme.colorScheme.primaryContainer
                  : theme.colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? theme.colorScheme.primary
                    : Colors.transparent,
                width: 2,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  item.$1,
                  color: isSelected
                      ? theme.colorScheme.onPrimaryContainer
                      : theme.colorScheme.onSurface,
                  size: 28,
                ),
                const SizedBox(height: 4),
                Text(
                  item.$2,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 10,
                    color: isSelected
                        ? theme.colorScheme.onPrimaryContainer
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
