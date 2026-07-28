import 'package:flutter/material.dart';

class IconMapper {
  static const Map<String, IconData> _map = {
    // Finanças
    'money': Icons.attach_money,
    'payments': Icons.payments,
    'account_balance': Icons.account_balance,
    'account_balance_wallet': Icons.account_balance_wallet,
    'savings': Icons.savings,
    'credit_card': Icons.credit_card,
    'receipt': Icons.receipt,
    'receipt_long': Icons.receipt_long,
    'trending_up': Icons.trending_up,
    'trending_down': Icons.trending_down,
    'pie_chart': Icons.pie_chart,
    'bar_chart': Icons.bar_chart,
    'currency_exchange': Icons.currency_exchange,
    'swap_horiz': Icons.swap_horiz,
    'wallet': Icons.wallet,
    'local_atm': Icons.local_atm,
    'paid': Icons.paid,
    'credit_score': Icons.credit_score,
    'price_change': Icons.price_change,
    'price_check': Icons.price_check,
    'show_chart': Icons.show_chart,
    'subscriptions': Icons.subscriptions,
    // Casa
    'home': Icons.home,
    'house': Icons.house,
    'apartment': Icons.apartment,
    'bed': Icons.bed,
    'kitchen': Icons.kitchen,
    'chair': Icons.chair,
    'chair_alt': Icons.chair_alt,
    'cleaning_services': Icons.cleaning_services,
    'water_drop': Icons.water_drop,
    'bolt': Icons.bolt,
    'wifi': Icons.wifi,
    'tv': Icons.tv,
    'phone_android': Icons.phone_android,
    'computer': Icons.computer,
    'lightbulb': Icons.lightbulb,
    'heat_pump': Icons.heat_pump,
    'door_sliding': Icons.door_sliding,
    // Alimentação
    'restaurant': Icons.restaurant,
    'local_pizza': Icons.local_pizza,
    'local_cafe': Icons.local_cafe,
    'local_bar': Icons.local_bar,
    'fastfood': Icons.fastfood,
    'bakery_dining': Icons.bakery_dining,
    'lunch_dining': Icons.lunch_dining,
    'dinner_dining': Icons.dinner_dining,
    'local_grocery_store': Icons.local_grocery_store,
    'shopping_cart': Icons.shopping_cart,
    'grocery': Icons.local_grocery_store,
    'icecream': Icons.icecream,
    'liquor': Icons.liquor,
    'soup_kitchen': Icons.soup_kitchen,
    'ramen_dining': Icons.ramen_dining,
    'storefront': Icons.storefront,
    // Transporte
    'directions_car': Icons.directions_car,
    'directions_bus': Icons.directions_bus,
    'directions_subway': Icons.directions_subway,
    'directions_bike': Icons.directions_bike,
    'flight': Icons.flight,
    'train': Icons.train,
    'local_taxi': Icons.local_taxi,
    'two_wheeler': Icons.two_wheeler,
    'local_gas_station': Icons.local_gas_station,
    'electric_car': Icons.electric_car,
    'directions_run': Icons.directions_run,
    'directions_walk': Icons.directions_walk,
    'local_shipping': Icons.local_shipping,
    // Saúde
    'favorite': Icons.favorite,
    'local_hospital': Icons.local_hospital,
    'medical_services': Icons.medical_services,
    'medication': Icons.medication,
    'fitness_center': Icons.fitness_center,
    'spa': Icons.spa,
    'health_and_safety': Icons.health_and_safety,
    'psychology': Icons.psychology,
    'healing': Icons.healing,
    'vaccines': Icons.vaccines,
    'clean_hands': Icons.clean_hands,
    'medication_liquid': Icons.medication_liquid,
    // Educação
    'school': Icons.school,
    'menu_book': Icons.menu_book,
    'local_library': Icons.local_library,
    'science': Icons.science,
    'calculate': Icons.calculate,
    'laptop': Icons.laptop,
    'headphones': Icons.headphones,
    'create': Icons.create,
    'auto_stories': Icons.auto_stories,
    'history_edu': Icons.history_edu,
    'architecture': Icons.architecture,
    // Lazer
    'movie': Icons.movie,
    'sports_soccer': Icons.sports_soccer,
    'sports_esports': Icons.sports_esports,
    'music_note': Icons.music_note,
    'theater_comedy': Icons.theater_comedy,
    'beach_access': Icons.beach_access,
    'hiking': Icons.hiking,
    'camera_alt': Icons.camera_alt,
    'pool': Icons.pool,
    'piano': Icons.piano,
    'stadium': Icons.stadium,
    'palette': Icons.palette,
    'park': Icons.park,
    'festival': Icons.festival,
    // Vestuário
    'checkroom': Icons.checkroom,
    'shopping_bag': Icons.shopping_bag,
    'watch': Icons.watch,
    'dry_cleaning': Icons.dry_cleaning,
    'style': Icons.style,
    // Trabalho
    'work': Icons.work,
    'business': Icons.business,
    'business_center': Icons.business_center,
    'meeting_room': Icons.meeting_room,
    'print': Icons.print,
    'co_present': Icons.co_present,
    'badge': Icons.badge,
    'corporate_fare': Icons.corporate_fare,
    // Pessoas
    'people': Icons.people,
    'person': Icons.person,
    'family_restroom': Icons.family_restroom,
    'child_care': Icons.child_care,
    'pets': Icons.pets,
    'elderly': Icons.elderly,
    'pregnant_woman': Icons.pregnant_woman,
    'boy': Icons.boy,
    'girl': Icons.girl,
    // Especial
    'card_giftcard': Icons.card_giftcard,
    'cake': Icons.cake,
    'celebration': Icons.celebration,
    'redeem': Icons.redeem,
    'church': Icons.church,
    'volunteer_activism': Icons.volunteer_activism,
    'emoji_events': Icons.emoji_events,
    'workspace_premium': Icons.workspace_premium,
    'military_tech': Icons.military_tech,
    // Outros
    'category': Icons.category,
    'star': Icons.star,
    'flag': Icons.flag,
    'label': Icons.label,
    'bookmark': Icons.bookmark,
    'settings': Icons.settings,
    'security': Icons.security,
    'public': Icons.public,
    'build': Icons.build,
    'handshake': Icons.handshake,
    'help': Icons.help,
    'info': Icons.info,
    'key': Icons.key,
    'vpn_key': Icons.vpn_key,
    'lock': Icons.lock,
    'lock_open': Icons.lock_open,
  };

  static IconData fromString(String name) => _map[name] ?? Icons.category;

  static Map<String, IconData> get all => _map;

  static Map<String, List<MapEntry<String, IconData>>> get categorized => {
    'Finanças': _entries([
      'money',
      'payments',
      'account_balance',
      'account_balance_wallet',
      'savings',
      'credit_card',
      'receipt',
      'receipt_long',
      'trending_up',
      'trending_down',
      'pie_chart',
      'bar_chart',
      'currency_exchange',
      'swap_horiz',
      'wallet',
      'local_atm',
      'paid',
      'credit_score',
      'price_change',
      'price_check',
      'show_chart',
      'subscriptions',
    ]),
    'Casa': _entries([
      'home',
      'house',
      'apartment',
      'bed',
      'kitchen',
      'chair',
      'chair_alt',
      'cleaning_services',
      'water_drop',
      'bolt',
      'wifi',
      'tv',
      'phone_android',
      'computer',
      'lightbulb',
      'heat_pump',
      'door_sliding',
    ]),
    'Alimentação': _entries([
      'restaurant',
      'local_pizza',
      'local_cafe',
      'local_bar',
      'fastfood',
      'bakery_dining',
      'lunch_dining',
      'dinner_dining',
      'local_grocery_store',
      'shopping_cart',
      'icecream',
      'liquor',
      'soup_kitchen',
      'ramen_dining',
      'storefront',
    ]),
    'Transporte': _entries([
      'directions_car',
      'directions_bus',
      'directions_subway',
      'directions_bike',
      'flight',
      'train',
      'local_taxi',
      'two_wheeler',
      'local_gas_station',
      'electric_car',
      'directions_run',
      'directions_walk',
      'local_shipping',
    ]),
    'Saúde': _entries([
      'favorite',
      'local_hospital',
      'medical_services',
      'medication',
      'fitness_center',
      'spa',
      'health_and_safety',
      'psychology',
      'healing',
      'vaccines',
      'clean_hands',
      'medication_liquid',
    ]),
    'Educação': _entries([
      'school',
      'menu_book',
      'local_library',
      'science',
      'calculate',
      'laptop',
      'headphones',
      'create',
      'auto_stories',
      'history_edu',
      'architecture',
    ]),
    'Lazer': _entries([
      'movie',
      'sports_soccer',
      'sports_esports',
      'music_note',
      'theater_comedy',
      'beach_access',
      'hiking',
      'camera_alt',
      'pool',
      'piano',
      'stadium',
      'palette',
      'park',
      'festival',
    ]),
    'Vestuário': _entries([
      'checkroom',
      'shopping_bag',
      'watch',
      'dry_cleaning',
      'style',
    ]),
    'Trabalho': _entries([
      'work',
      'business',
      'business_center',
      'meeting_room',
      'print',
      'co_present',
      'badge',
      'corporate_fare',
    ]),
    'Pessoas': _entries([
      'people',
      'person',
      'family_restroom',
      'child_care',
      'pets',
      'elderly',
      'pregnant_woman',
      'boy',
      'girl',
    ]),
    'Especial': _entries([
      'card_giftcard',
      'cake',
      'celebration',
      'redeem',
      'church',
      'volunteer_activism',
      'emoji_events',
      'workspace_premium',
      'military_tech',
    ]),
    'Outros': _entries([
      'category',
      'star',
      'flag',
      'label',
      'bookmark',
      'settings',
      'security',
      'public',
      'build',
      'handshake',
      'help',
      'info',
      'key',
      'vpn_key',
      'lock',
      'lock_open',
    ]),
  };

  static List<MapEntry<String, IconData>> _entries(List<String> keys) =>
      keys.map((k) => MapEntry(k, _map[k] ?? Icons.category)).toList();

  static IconData fromCodePoint(int codePoint) {
    if (codePoint == Icons.account_balance_rounded.codePoint) {
      return Icons.account_balance_rounded;
    }
    if (codePoint == Icons.wallet_rounded.codePoint) {
      return Icons.wallet_rounded;
    }
    if (codePoint == Icons.trending_up_rounded.codePoint) {
      return Icons.trending_up_rounded;
    }
    if (codePoint == Icons.savings_rounded.codePoint) {
      return Icons.savings_rounded;
    }
    if (codePoint == Icons.payments_rounded.codePoint) {
      return Icons.payments_rounded;
    }
    if (codePoint == Icons.credit_card_rounded.codePoint) {
      return Icons.credit_card_rounded;
    }
    if (codePoint == Icons.monetization_on_rounded.codePoint) {
      return Icons.monetization_on_rounded;
    }
    if (codePoint == Icons.attach_money_rounded.codePoint) {
      return Icons.attach_money_rounded;
    }
    if (codePoint == Icons.shield_rounded.codePoint) {
      return Icons.shield_rounded;
    }
    if (codePoint == Icons.account_balance_wallet_rounded.codePoint) {
      return Icons.account_balance_wallet_rounded;
    }

    if (codePoint == Icons.home_rounded.codePoint) return Icons.home_rounded;
    if (codePoint == Icons.directions_car_rounded.codePoint) {
      return Icons.directions_car_rounded;
    }
    if (codePoint == Icons.restaurant_rounded.codePoint) {
      return Icons.restaurant_rounded;
    }
    if (codePoint == Icons.shopping_cart_rounded.codePoint) {
      return Icons.shopping_cart_rounded;
    }
    if (codePoint == Icons.favorite_rounded.codePoint) {
      return Icons.favorite_rounded;
    }
    if (codePoint == Icons.school_rounded.codePoint) {
      return Icons.school_rounded;
    }
    if (codePoint == Icons.movie_rounded.codePoint) return Icons.movie_rounded;
    if (codePoint == Icons.work_rounded.codePoint) return Icons.work_rounded;
    if (codePoint == Icons.person_rounded.codePoint) {
      return Icons.person_rounded;
    }
    if (codePoint == Icons.family_restroom_rounded.codePoint) {
      return Icons.family_restroom_rounded;
    }

    if (codePoint == Icons.star_rounded.codePoint) return Icons.star_rounded;
    if (codePoint == Icons.store_rounded.codePoint) return Icons.store_rounded;
    if (codePoint == Icons.flight_rounded.codePoint) {
      return Icons.flight_rounded;
    }
    if (codePoint == Icons.sports_esports_rounded.codePoint) {
      return Icons.sports_esports_rounded;
    }
    if (codePoint == Icons.lock_rounded.codePoint) return Icons.lock_rounded;
    if (codePoint == Icons.build_rounded.codePoint) return Icons.build_rounded;
    if (codePoint == Icons.pets_rounded.codePoint) return Icons.pets_rounded;
    if (codePoint == Icons.local_gas_station_rounded.codePoint) {
      return Icons.local_gas_station_rounded;
    }
    if (codePoint == Icons.phone_iphone_rounded.codePoint) {
      return Icons.phone_iphone_rounded;
    }
    if (codePoint == Icons.local_hospital_rounded.codePoint) {
      return Icons.local_hospital_rounded;
    }

    return Icons.help_outline;
  }
}
