import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EntityCategory {
  final String id;
  final String label;
  final IconData icon;
  final String iconKey;

  const EntityCategory({
    required this.id,
    required this.label,
    required this.icon,
    required this.iconKey,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'iconKey': iconKey,
  };

  factory EntityCategory.fromJson(
    Map<String, dynamic> json,
    Map<String, IconData> iconMap,
  ) {
    final iconKey = json['iconKey'] as String;
    return EntityCategory(
      id: json['id'] as String,
      label: json['label'] as String,
      iconKey: iconKey,
      icon: iconMap[iconKey] ?? Icons.person_outline,
    );
  }
}

final Map<String, IconData> entityIconMap = {
  'person': Icons.person_outline,
  'store': Icons.store_outlined,
  'restaurant': Icons.restaurant_outlined,
  'subscription': Icons.credit_card_outlined,
  'work': Icons.work_outline,
  'government': Icons.account_balance_outlined,
  'health': Icons.medical_services_outlined,
  'transport': Icons.directions_bus_outlined,
  'education': Icons.school_outlined,
  'leisure': Icons.movie_outlined,
  'online_service': Icons.language_outlined,
  'donation': Icons.volunteer_activism_outlined,
  'supermarket': Icons.shopping_cart_outlined,
  'utilities': Icons.lightbulb_outline,
  'home': Icons.home_outlined,
  'pets': Icons.pets_outlined,
  'auto': Icons.directions_car_outlined,
  'travel': Icons.flight_outlined,
  'investment': Icons.trending_up_outlined,
  'insurance': Icons.shield_outlined,
  'family': Icons.family_restroom_outlined,
  'fitness': Icons.fitness_center_outlined,
  'shopping_bag': Icons.shopping_bag_outlined,
  'gift': Icons.card_giftcard_outlined,
  'party': Icons.celebration_outlined,
  'repair': Icons.construction_outlined,
  'savings': Icons.savings_outlined,
  'gas': Icons.local_gas_station_outlined,
  'pharmacy': Icons.local_pharmacy_outlined,
  'game': Icons.sports_esports_outlined,
  'wifi': Icons.wifi_outlined,
};

const List<EntityCategory> defaultEntityCategories = [
  EntityCategory(
    id: 'person',
    label: 'Pessoa',
    icon: Icons.person_outline,
    iconKey: 'person',
  ),
  EntityCategory(
    id: 'store',
    label: 'Loja/Mercado',
    icon: Icons.store_outlined,
    iconKey: 'store',
  ),
  EntityCategory(
    id: 'restaurant',
    label: 'Restaurante/Delivery',
    icon: Icons.restaurant_outlined,
    iconKey: 'restaurant',
  ),
  EntityCategory(
    id: 'subscription',
    label: 'Assinatura/SaaS',
    icon: Icons.credit_card_outlined,
    iconKey: 'subscription',
  ),
  EntityCategory(
    id: 'work',
    label: 'Trabalho/Freelance',
    icon: Icons.work_outline,
    iconKey: 'work',
  ),
  EntityCategory(
    id: 'government',
    label: 'Governo/Imposto',
    icon: Icons.account_balance_outlined,
    iconKey: 'government',
  ),
  EntityCategory(
    id: 'health',
    label: 'Saúde',
    icon: Icons.medical_services_outlined,
    iconKey: 'health',
  ),
  EntityCategory(
    id: 'transport',
    label: 'Transporte',
    icon: Icons.directions_bus_outlined,
    iconKey: 'transport',
  ),
  EntityCategory(
    id: 'education',
    label: 'Educação',
    icon: Icons.school_outlined,
    iconKey: 'education',
  ),
  EntityCategory(
    id: 'leisure',
    label: 'Lazer/Entretenimento',
    icon: Icons.movie_outlined,
    iconKey: 'leisure',
  ),
  EntityCategory(
    id: 'online_service',
    label: 'Serviço Online',
    icon: Icons.language_outlined,
    iconKey: 'online_service',
  ),
  EntityCategory(
    id: 'donation',
    label: 'Doação/Presente',
    icon: Icons.volunteer_activism_outlined,
    iconKey: 'donation',
  ),
  // Additional relevant categories
  EntityCategory(
    id: 'supermarket',
    label: 'Supermercado',
    icon: Icons.shopping_cart_outlined,
    iconKey: 'supermarket',
  ),
  EntityCategory(
    id: 'utilities',
    label: 'Contas / Serviços',
    icon: Icons.lightbulb_outline,
    iconKey: 'utilities',
  ),
  EntityCategory(
    id: 'home',
    label: 'Moradia / Aluguel',
    icon: Icons.home_outlined,
    iconKey: 'home',
  ),
  EntityCategory(
    id: 'pets',
    label: 'Pets',
    icon: Icons.pets_outlined,
    iconKey: 'pets',
  ),
  EntityCategory(
    id: 'auto',
    label: 'Automóvel / Veículo',
    icon: Icons.directions_car_outlined,
    iconKey: 'auto',
  ),
  EntityCategory(
    id: 'travel',
    label: 'Viagens',
    icon: Icons.flight_outlined,
    iconKey: 'travel',
  ),
  EntityCategory(
    id: 'investment',
    label: 'Investimentos',
    icon: Icons.trending_up_outlined,
    iconKey: 'investment',
  ),
  EntityCategory(
    id: 'insurance',
    label: 'Seguros',
    icon: Icons.shield_outlined,
    iconKey: 'insurance',
  ),
  EntityCategory(
    id: 'family',
    label: 'Família',
    icon: Icons.family_restroom_outlined,
    iconKey: 'family',
  ),
  EntityCategory(
    id: 'shopping_bag',
    label: 'Compras / Vestuário',
    icon: Icons.shopping_bag_outlined,
    iconKey: 'shopping_bag',
  ),
  EntityCategory(
    id: 'fitness',
    label: 'Esporte / Academia',
    icon: Icons.fitness_center_outlined,
    iconKey: 'fitness',
  ),
  EntityCategory(
    id: 'repair',
    label: 'Manutenção / Reparos',
    icon: Icons.construction_outlined,
    iconKey: 'repair',
  ),
];

const kCustomEntityCategoriesKey = 'custom_entity_categories';

class EntityCategoriesNotifier extends Notifier<List<EntityCategory>> {
  @override
  List<EntityCategory> build() {
    final list = List<EntityCategory>.from(defaultEntityCategories);
    _loadCustomCategories();
    return list;
  }

  Future<void> _loadCustomCategories() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(kCustomEntityCategoriesKey);
      if (jsonString != null) {
        final List<dynamic> decoded = jsonDecode(jsonString);
        final customList = decoded
            .map(
              (item) => EntityCategory.fromJson(
                item as Map<String, dynamic>,
                entityIconMap,
              ),
            )
            .toList();

        final Set<String> existingIds = state.map((c) => c.id).toSet();
        final filteredCustom = customList
            .where((c) => !existingIds.contains(c.id))
            .toList();

        state = [...state, ...filteredCustom];
      }
    } catch (e) {
      debugPrint('Failed to load custom entity categories: $e');
    }
  }

  Future<EntityCategory> addCustomCategory(String label, String iconKey) async {
    final id = 'custom_${DateTime.now().millisecondsSinceEpoch}';
    final newCategory = EntityCategory(
      id: id,
      label: label,
      iconKey: iconKey,
      icon: entityIconMap[iconKey] ?? Icons.person_outline,
    );

    state = [...state, newCategory];

    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(kCustomEntityCategoriesKey);
      List<dynamic> currentCustoms = [];
      if (jsonString != null) {
        currentCustoms = jsonDecode(jsonString);
      }
      currentCustoms.add(newCategory.toJson());
      await prefs.setString(
        kCustomEntityCategoriesKey,
        jsonEncode(currentCustoms),
      );
    } catch (e) {
      debugPrint('Failed to save custom entity category: $e');
    }

    return newCategory;
  }
}

final entityCategoriesProvider =
    NotifierProvider<EntityCategoriesNotifier, List<EntityCategory>>(
      EntityCategoriesNotifier.new,
    );
