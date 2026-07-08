import 'package:flutter/material.dart';

enum AccountType {
  checking,
  savings,
  wallet,
  investment,
  reserve,
  foodVoucher,
  mealVoucher;

  String get id => name;

  String get label {
    switch (this) {
      case AccountType.checking:
        return 'Conta Corrente';
      case AccountType.savings:
        return 'Poupança';
      case AccountType.wallet:
        return 'Carteira';
      case AccountType.investment:
        return 'Investimento';
      case AccountType.reserve:
        return 'Reserva';
      case AccountType.foodVoucher:
        return 'Alimentação';
      case AccountType.mealVoucher:
        return 'Refeição';
    }
  }

  IconData get defaultIcon {
    switch (this) {
      case AccountType.checking:
        return Icons.account_balance_rounded;
      case AccountType.savings:
        return Icons.savings_rounded;
      case AccountType.wallet:
        return Icons.wallet_rounded;
      case AccountType.investment:
        return Icons.trending_up_rounded;
      case AccountType.reserve:
        return Icons.shield_rounded;
      case AccountType.foodVoucher:
        return Icons.local_grocery_store_rounded;
      case AccountType.mealVoucher:
        return Icons.restaurant_rounded;
    }
  }

  String get defaultColorHex {
    switch (this) {
      case AccountType.checking:
        return '#2196F3'; // Blue
      case AccountType.savings:
        return '#4CAF50'; // Green
      case AccountType.wallet:
        return '#FF9800'; // Orange
      case AccountType.investment:
        return '#009688'; // Teal
      case AccountType.reserve:
        return '#9C27B0'; // Purple
      case AccountType.foodVoucher:
        return '#8BC34A'; // Light Green
      case AccountType.mealVoucher:
        return '#FF5722'; // Deep Orange
    }
  }

  Color get defaultColor => hexToColor(defaultColorHex);

  static AccountType fromString(String value) {
    return AccountType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => AccountType.checking,
    );
  }

  static Color hexToColor(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }
}
